import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:fitness_app/core/database/database_provider.dart';
import 'package:fitness_app/core/database/local_database.dart';
import 'package:fitness_app/features/workout/data/exercise_catalogue.dart';
import 'package:fitness_app/features/workout/data/exercise_repository.dart';
import 'package:fitness_app/features/workout/domain/muscle.dart';

/// Tests the write path and the catalogue stream for the muscle taxonomy.
///
/// The `bodyPart` column survives v9 as a denormalised cache of the primary
/// muscle's group, maintained in exactly one place. These tests pin that it
/// really is maintained, and that the stream's outer join does not quietly
/// become an inner one — which would make any exercise without muscle rows
/// disappear from the library rather than showing as unassigned.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  ExerciseRepository repository() =>
      container.read(exerciseRepositoryProvider.notifier);

  /// Reads the first value a provider emits, keeping the auto-disposed
  /// subscription alive for the duration of the read.
  Future<T> firstValue<T>(ProviderListenable<AsyncValue<T>> provider) async {
    final sub = container.listen(provider, (_, _) {});
    try {
      var value = container.read(provider);
      while (!value.hasValue) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        value = container.read(provider);
      }
      return value.requireValue;
    } finally {
      sub.close();
    }
  }

  Future<List<ExerciseWithMuscles>> catalogue() =>
      firstValue(watchExerciseCatalogueProvider);

  // ---------------------------------------------------------------------------
  // Writing
  // ---------------------------------------------------------------------------

  test('addExercise stores the muscles and derives bodyPart', () async {
    final id = await repository().addExercise(
      'Preacher Curl',
      'Barbell',
      primary: Muscle.biceps,
      secondary: {Muscle.forearms},
    );

    final row = await (db.select(
      db.exercises,
    )..where((e) => e.id.equals(id))).getSingle();
    // Biceps is a muscle, not a group — the cached label is its group, Arms.
    expect(row.bodyPart, 'Arms');
    expect(row.isCustom, isTrue);

    final muscles = await (db.select(
      db.exerciseMuscles,
    )..where((m) => m.exerciseId.equals(id))).get();
    expect(muscles, hasLength(2));
    expect(muscles.firstWhere((m) => m.isPrimary).muscle, Muscle.biceps.name);
    expect(
      muscles.firstWhere((m) => !m.isPrimary).muscle,
      Muscle.forearms.name,
    );
  });

  test('a secondary repeating the primary is ignored, not written twice', () {
    // The composite primary key would reject it anyway; this pins that the
    // repository does not rely on the database to throw.
    return expectLater(
      repository()
          .addExercise(
            'Odd Lift',
            'Barbell',
            primary: Muscle.chest,
            secondary: {Muscle.chest, Muscle.triceps},
          )
          .then((id) async {
            final muscles = await (db.select(
              db.exerciseMuscles,
            )..where((m) => m.exerciseId.equals(id))).get();
            return muscles.length;
          }),
      completion(2),
    );
  });

  test('setMuscles replaces the old set and updates bodyPart', () async {
    final id = await repository().addExercise(
      'Mystery Lift',
      'Barbell',
      primary: Muscle.chest,
      secondary: {Muscle.triceps},
    );

    await repository().setMuscles(
      id,
      primary: Muscle.quads,
      secondary: {Muscle.glutes, Muscle.hamstrings},
    );

    final entry = (await catalogue()).firstWhere((e) => e.id == id);
    expect(entry.primary, Muscle.quads);
    expect(entry.secondary, [Muscle.hamstrings, Muscle.glutes]);
    expect(entry.exercise.bodyPart, 'Legs');
  });

  test('deleting an exercise cascades its muscle rows away', () async {
    // The cascade is load-bearing at runtime — beforeOpen turns foreign keys
    // on — even though it is inert during a migration.
    final id = await repository().addExercise(
      'Zercher Squat',
      'Barbell',
      primary: Muscle.quads,
      secondary: {Muscle.glutes},
    );

    await repository().deleteExercise(id);

    final orphans = await db.select(db.exerciseMuscles).get();
    expect(orphans, isEmpty);
  });

  // ---------------------------------------------------------------------------
  // Reading
  // ---------------------------------------------------------------------------

  test('the catalogue folds join rows into one entry per exercise', () async {
    await repository().addExercise(
      'Deadlift',
      'Barbell',
      primary: Muscle.lowerBack,
      secondary: {Muscle.glutes, Muscle.hamstrings, Muscle.traps},
    );

    final entries = await catalogue();
    expect(entries, hasLength(1));
    expect(entries.single.primary, Muscle.lowerBack);
    // Secondaries come back in Muscle declaration order, not insertion order.
    expect(entries.single.secondary, [
      Muscle.traps,
      Muscle.hamstrings,
      Muscle.glutes,
    ]);
  });

  test('an exercise with no muscle rows still appears, unassigned', () async {
    // The join must stay a LEFT outer join. An inner join would make this row
    // vanish from the library entirely — silently, and only for the rows a
    // sync download had not yet classified.
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            name: 'Unclassified',
            bodyPart: 'Chest',
            equipmentType: 'Barbell',
          ),
        );

    final entries = await catalogue();
    expect(entries, hasLength(1));
    expect(entries.single.primary, isNull);
    expect(entries.single.name, 'Unclassified');
    // It still reads, falling back to the stored label.
    expect(entries.single.muscleLabel, 'Chest');
  });

  test('the catalogue is name-ordered', () async {
    for (final name in ['Squat', 'Bench Press', 'Deadlift']) {
      await repository().addExercise(name, 'Barbell', primary: Muscle.quads);
    }

    final entries = await catalogue();
    expect(entries.map((e) => e.name), ['Bench Press', 'Deadlift', 'Squat']);
  });

  test('soft-deleted exercises are excluded', () async {
    final id = await repository().addExercise(
      'Retired Lift',
      'Barbell',
      primary: Muscle.chest,
    );
    await (db.update(db.exercises)..where((e) => e.id.equals(id))).write(
      ExercisesCompanion(deletedAt: Value(DateTime(2026, 5, 1))),
    );

    expect(await catalogue(), isEmpty);
  });

  test('editing only a muscle row re-emits the catalogue', () async {
    final id = await repository().addExercise(
      'Row',
      'Barbell',
      primary: Muscle.lats,
    );

    final emissions = <List<ExerciseWithMuscles>>[];
    final sub = container.listen(watchExerciseCatalogueProvider, (_, next) {
      if (next.hasValue) emissions.add(next.requireValue);
    });
    addTearDown(sub.close);

    await Future<void>.delayed(const Duration(milliseconds: 20));
    await repository().setMuscles(
      id,
      primary: Muscle.lats,
      secondary: {Muscle.biceps},
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(emissions, isNotEmpty);
    expect(emissions.last.single.secondary, [Muscle.biceps]);
  });
}
