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

  Future<void> deleteExercise(int id) async {
    final db = ref.read(databaseProvider);
    // exercise_muscles cascades — foreign keys are on at runtime, unlike
    // during a migration.
    await (db.delete(db.exercises)..where((e) => e.id.equals(id))).go();
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
