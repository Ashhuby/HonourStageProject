import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:riverpod/riverpod.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/local_database.dart';
import '../domain/activity.dart';
import '../domain/muscle.dart';
import 'exercise_catalogue.dart';
import 'package:drift/drift.dart';

// This must match the filename exactly
part 'exercise_repository.g.dart';

@riverpod
class ExerciseRepository extends _$ExerciseRepository {
  @override
  void build() {}

  /// Creates a custom exercise and its muscle rows in one transaction.
  ///
  /// `bodyPart` is written from the primary muscle's group, which is the only
  /// place that denormalisation is produced — see `_syncBodyPartToPrimaryGroup`
  /// for the migration's equivalent. A transaction so the column and the
  /// muscle rows can never disagree.
  Future<int> addExercise(
    String name,
    String equipmentType, {
    required Muscle primary,
    Set<Muscle> secondary = const {},
    String metricType = 'weightReps',
    ExerciseCategory category = ExerciseCategory.strength,
    CardioModality? modality,
  }) async {
    // The same biconditional the database trigger enforces, checked here so
    // an abort from SQLite is never the first thing the user meets.
    assert(
      (category == ExerciseCategory.cardio) == (modality != null),
      'modality is required for cardio and forbidden otherwise',
    );

    final db = ref.read(databaseProvider);
    return db.transaction(() async {
      final id = await db
          .into(db.exercises)
          .insert(
            ExercisesCompanion.insert(
              name: name,
              bodyPart: primary.group.label,
              equipmentType: equipmentType,
              isCustom: const Value(true),
              metricType: Value(metricType),
              category: Value(category.name),
              modality: Value(modality?.name),
            ),
          );
      await _writeMuscles(db, id, primary: primary, secondary: secondary);
      return id;
    });
  }

  /// Replaces an exercise's muscles, keeping `bodyPart` in step.
  Future<void> setMuscles(
    int exerciseId, {
    required Muscle primary,
    Set<Muscle> secondary = const {},
  }) async {
    final db = ref.read(databaseProvider);
    await db.transaction(() async {
      await (db.delete(
        db.exerciseMuscles,
      )..where((m) => m.exerciseId.equals(exerciseId))).go();
      await _writeMuscles(
        db,
        exerciseId,
        primary: primary,
        secondary: secondary,
      );
      await (db.update(db.exercises)..where((e) => e.id.equals(exerciseId)))
          .write(ExercisesCompanion(bodyPart: Value(primary.group.label)));
    });
  }

  /// Re-files an existing exercise.
  ///
  /// The mitigation for the v10 backfill, which categorises custom exercises
  /// from their metric type and says openly that it will misfile a loaded
  /// carry logged by distance. Without this there was no way to correct one:
  /// `setMuscles` existed on this repository and nothing called it.
  ///
  /// [metricType] is deliberately not editable here. Changing it invalidates
  /// every record computed under the old comparator — a weightReps record
  /// makes no sense read as a distance — and silently rebuilding a user's
  /// personal bests is worse than not offering the change.
  Future<void> updateExercise(
    int id, {
    required String name,
    required String equipmentType,
    required ExerciseCategory category,
    CardioModality? modality,
    required Muscle primary,
    Set<Muscle> secondary = const {},
  }) async {
    assert(
      (category == ExerciseCategory.cardio) == (modality != null),
      'modality is required for cardio and forbidden otherwise',
    );

    final db = ref.read(databaseProvider);
    await db.transaction(() async {
      await (db.update(db.exercises)..where((e) => e.id.equals(id))).write(
        ExercisesCompanion(
          name: Value(name),
          equipmentType: Value(equipmentType),
          bodyPart: Value(primary.group.label),
          category: Value(category.name),
          modality: Value(modality?.name),
          // Custom rows go dirty so the correction uploads. A seeded row has
          // no remote identity, so leaving syncedAt alone is right for it.
          syncedAt: const Value(null),
        ),
      );
      await (db.delete(
        db.exerciseMuscles,
      )..where((m) => m.exerciseId.equals(id))).go();
      await _writeMuscles(db, id, primary: primary, secondary: secondary);
    });
  }

  Future<void> _writeMuscles(
    AppDatabase db,
    int exerciseId, {
    required Muscle primary,
    required Set<Muscle> secondary,
  }) async {
    await db
        .into(db.exerciseMuscles)
        .insert(
          ExerciseMusclesCompanion.insert(
            exerciseId: exerciseId,
            muscle: primary.name,
            isPrimary: const Value(true),
          ),
          mode: InsertMode.insertOrReplace,
        );
    for (final muscle in secondary) {
      // A secondary that repeats the primary would violate the composite key
      // and, more to the point, is meaningless.
      if (muscle == primary) continue;
      await db
          .into(db.exerciseMuscles)
          .insert(
            ExerciseMusclesCompanion.insert(
              exerciseId: exerciseId,
              muscle: muscle.name,
            ),
            mode: InsertMode.insertOrReplace,
          );
    }
  }

  /// Retires an exercise without destroying what was logged against it.
  ///
  /// A soft delete, matching every other table: a hard one threw on the
  /// foreign key the moment the exercise had ever been used, so the swipe
  /// gesture in the library silently failed for exactly the exercises the user
  /// had trained. `watchExercises` and `watchExerciseCatalogue` both filter on
  /// `deletedAt`, so it leaves the library immediately, while its sets, records
  /// and routine entries stay intact and its history still reads.
  ///
  /// `syncedAt` is cleared so the retirement propagates, which is how the sync
  /// service recognises a soft delete on every other table.
  Future<void> deleteExercise(int id) async {
    final db = ref.read(databaseProvider);
    await (db.update(db.exercises)..where((e) => e.id.equals(id))).write(
      ExercisesCompanion(
        deletedAt: Value(DateTime.now()),
        syncedAt: const Value(null),
      ),
    );
  }
}

/// Every exercise, name-ordered. Unchanged: the session and progress screens
/// only need names and metric types, so they do not pay for the muscle join.
@riverpod
Stream<List<Exercise>> watchExercises(Ref ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.exercises)
        ..where((e) => e.deletedAt.isNull())
        ..orderBy([(e) => OrderingTerm.asc(e.name)]))
      .watch();
}

/// Every exercise with the muscles it trains — what the library, the picker
/// and the body map read.
///
/// A *left* outer join, deliberately: an exercise carrying no muscle rows must
/// still appear (under "Unassigned"), not vanish. Drift watches both tables,
/// so editing a muscle row re-emits the catalogue.
@riverpod
Stream<List<ExerciseWithMuscles>> watchExerciseCatalogue(Ref ref) {
  final db = ref.watch(databaseProvider);
  final query =
      (db.select(db.exercises)
            ..where((e) => e.deletedAt.isNull())
            ..orderBy([(e) => OrderingTerm.asc(e.name)]))
          .join([
            leftOuterJoin(
              db.exerciseMuscles,
              db.exerciseMuscles.exerciseId.equalsExp(db.exercises.id),
            ),
          ]);

  return query.watch().map(
    (rows) => foldCatalogueRows(
      rows,
      exercises: db.exercises,
      muscles: db.exerciseMuscles,
    ),
  );
}
