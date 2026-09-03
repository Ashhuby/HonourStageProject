import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:fitness_app/core/database/database_provider.dart';
import 'package:fitness_app/core/database/local_database.dart';
import 'package:fitness_app/features/workout/data/exercise_catalogue.dart';
import 'package:fitness_app/features/workout/data/exercise_repository.dart';
import 'package:fitness_app/features/workout/domain/activity.dart';
import 'package:fitness_app/features/workout/domain/muscle.dart';

/// Tests re-filing an exercise, and retiring one.
///
/// Editing exists because the v10 backfill categorises custom exercises from
/// their metric type and openly misfiles a loaded carry logged by distance.
/// Without a way to correct one the misfiling would be permanent.
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

  Future<Exercise> row(int id) =>
      (db.select(db.exercises)..where((e) => e.id.equals(id))).getSingle();

  // ---------------------------------------------------------------------------
  // Re-filing
  // ---------------------------------------------------------------------------

  test('a misfiled carry can be moved back to strength', () async {
    // Exactly the case the v10 backfill gets wrong: logged by distance, so it
    // was filed as Cardio / Other, but it is a loaded carry.
    final id = await repository().addExercise(
      'Farmers Carry',
      'Dumbbell',
      primary: Muscle.forearms,
      metricType: 'distanceTime',
      category: ExerciseCategory.cardio,
      modality: CardioModality.other,
    );

    await repository().updateExercise(
      id,
      name: 'Farmers Carry',
      equipmentType: 'Dumbbell',
      category: ExerciseCategory.strength,
      primary: Muscle.forearms,
      secondary: {Muscle.traps, Muscle.abs},
    );

    final entry = (await catalogue()).single;
    expect(entry.category, ExerciseCategory.strength);
    expect(entry.modality, isNull);
    expect(entry.secondary, [Muscle.traps, Muscle.abs]);
    // bodyPart follows the primary's group, as it does on every write path.
    expect(entry.exercise.bodyPart, 'Arms');
  });

  test('moving to cardio requires a modality and stores it', () async {
    final id = await repository().addExercise(
      'Canal Loop',
      'Body Weight',
      primary: Muscle.quads,
      metricType: 'distanceTime',
    );

    await repository().updateExercise(
      id,
      name: 'Canal Loop',
      equipmentType: 'Body Weight',
      category: ExerciseCategory.cardio,
      modality: CardioModality.run,
      primary: Muscle.quads,
    );

    final entry = (await catalogue()).single;
    expect(entry.category, ExerciseCategory.cardio);
    expect(entry.modality, CardioModality.run);
  });

  test('a rename keeps the exercise and its history', () async {
    final id = await repository().addExercise(
      'Bench',
      'Barbell',
      primary: Muscle.chest,
      secondary: {Muscle.triceps},
    );

    await repository().updateExercise(
      id,
      name: 'Bench Press',
      equipmentType: 'Barbell',
      category: ExerciseCategory.strength,
      primary: Muscle.chest,
      secondary: {Muscle.triceps},
    );

    final entry = (await catalogue()).single;
    expect(entry.id, id, reason: 'the same row, so sets still point at it');
    expect(entry.name, 'Bench Press');
    expect(entry.secondary, [Muscle.triceps]);
  });

  test('an edit marks the row dirty so the correction uploads', () async {
    final id = await repository().addExercise(
      'Sled Drag',
      'Other',
      primary: Muscle.quads,
      metricType: 'distanceTime',
    );
    await (db.update(db.exercises)..where((e) => e.id.equals(id))).write(
      ExercisesCompanion(syncedAt: Value(DateTime(2026, 6, 1))),
    );

    await repository().updateExercise(
      id,
      name: 'Sled Drag',
      equipmentType: 'Other',
      category: ExerciseCategory.cardio,
      modality: CardioModality.other,
      primary: Muscle.quads,
    );

    expect((await row(id)).syncedAt, isNull);
  });

  test('the old muscles are replaced, not added to', () async {
    final id = await repository().addExercise(
      'Row',
      'Machine',
      primary: Muscle.lats,
      secondary: {Muscle.biceps, Muscle.rearDelts},
    );

    await repository().updateExercise(
      id,
      name: 'Row',
      equipmentType: 'Machine',
      category: ExerciseCategory.strength,
      primary: Muscle.lats,
      secondary: {Muscle.forearms},
    );

    final muscles = await (db.select(
      db.exerciseMuscles,
    )..where((m) => m.exerciseId.equals(id))).get();
    expect(muscles, hasLength(2));
    expect(
      muscles.map((m) => m.muscle),
      containsAll([Muscle.lats.name, Muscle.forearms.name]),
    );
  });

  // ---------------------------------------------------------------------------
  // Retiring
  // ---------------------------------------------------------------------------

  test('an exercise with logged sets can be deleted', () async {
    // The hard delete this replaced threw on the foreign key here, so the
    // swipe gesture silently failed for exactly the exercises the user had
    // actually trained.
    final id = await repository().addExercise(
      'Zercher Squat',
      'Barbell',
      primary: Muscle.quads,
    );

    final sessionId = await db
        .into(db.workoutSessions)
        .insert(
          WorkoutSessionsCompanion.insert(startTime: DateTime(2026, 6, 1)),
        );
    await db
        .into(db.workoutSets)
        .insert(
          WorkoutSetsCompanion.insert(
            sessionId: sessionId,
            exerciseId: id,
            weight: const Value(100),
            reps: const Value(5),
          ),
        );

    await repository().deleteExercise(id);

    expect(await catalogue(), isEmpty, reason: 'gone from the library');

    final sets = await db.select(db.workoutSets).get();
    expect(sets, hasLength(1), reason: 'the logged set survives');
    expect(sets.single.exerciseId, id);
  });
}
