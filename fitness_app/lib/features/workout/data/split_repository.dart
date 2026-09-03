import 'package:drift/drift.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/set_formatter.dart';
import '../../../core/database/local_database.dart';

part 'split_repository.g.dart';

/// A routine's planned exercise paired with the exercise row it points at.
///
/// The whole [Exercise] is carried rather than a handful of copied columns, so
/// callers that need a real exercise — the session screen's picker, for one —
/// do not have to synthesise one and guess at the fields they lack.
class RoutineExerciseWithName {
  final RoutineExercise routineExercise;
  final Exercise exercise;

  const RoutineExerciseWithName({
    required this.routineExercise,
    required this.exercise,
  });

  String get exerciseName => exercise.name;

  /// The plan for this exercise, phrased in the units it is measured in.
  String get targetSummary => formatTargetSummary(
    targetSets: routineExercise.targetSets,
    targetReps: routineExercise.targetReps,
    metricType: exercise.metricType,
    targetDistanceMetres: routineExercise.targetDistanceMetres,
    targetDurationSeconds: routineExercise.targetDurationSeconds,
  );
  String get bodyPart => exercise.bodyPart;
  String get equipmentType => exercise.equipmentType;
  String get metricType => exercise.metricType;
}

// --- STREAMS ---
@riverpod
Stream<List<RoutineExerciseWithName>> watchExercisesForRoutineWithNames(
  Ref ref,
  int routineId,
) {
  final db = ref.watch(databaseProvider);

  final query =
      db.select(db.routineExercises).join([
          innerJoin(
            db.exercises,
            db.exercises.id.equalsExp(db.routineExercises.exerciseId),
          ),
        ])
        ..where(db.routineExercises.routineId.equals(routineId))
        ..where(db.routineExercises.deletedAt.isNull())
        ..orderBy([OrderingTerm.asc(db.routineExercises.orderIndex)]);

  return query.watch().map(
    (rows) => rows
        .map(
          (row) => RoutineExerciseWithName(
            routineExercise: row.readTable(db.routineExercises),
            exercise: row.readTable(db.exercises),
          ),
        )
        .toList(),
  );
}

@riverpod
Stream<List<WorkoutSplit>> watchSplits(Ref ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.workoutSplits,
  )..where((s) => s.deletedAt.isNull())).watch();
}

@riverpod
Stream<List<WorkoutRoutine>> watchRoutinesForSplit(Ref ref, int splitId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.workoutRoutines)
        ..where((r) => r.splitId.equals(splitId))
        ..where((r) => r.deletedAt.isNull())
        ..orderBy([(r) => OrderingTerm.asc(r.orderIndex)]))
      .watch();
}

@riverpod
Stream<List<RoutineExercise>> watchExercisesForRoutine(Ref ref, int routineId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.routineExercises)
        ..where((re) => re.routineId.equals(routineId))
        ..where((re) => re.deletedAt.isNull())
        ..orderBy([(re) => OrderingTerm.asc(re.orderIndex)]))
      .watch();
}

// --- REPOSITORY ---

@riverpod
class SplitRepository extends _$SplitRepository {
  @override
  void build() {}

  Future<int> createSplit(String name) async {
    final db = ref.read(databaseProvider);
    return db
        .into(db.workoutSplits)
        .insert(WorkoutSplitsCompanion.insert(name: name));
  }

  /// Renames a split.
  ///
  /// Creating and deleting were the only operations a split had, so fixing a
  /// typo meant deleting it — and [deleteSplit] takes every routine and every
  /// planned exercise with it. A name is the one thing about a split that is
  /// safe to change.
  ///
  /// A blank name is ignored rather than stored: a split with no name is
  /// unfindable, and the dialog would have to invent a placeholder to render
  /// it.
  Future<void> renameSplit(int splitId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final db = ref.read(databaseProvider);
    await (db.update(
      db.workoutSplits,
    )..where((s) => s.id.equals(splitId))).write(
      WorkoutSplitsCompanion(name: Value(trimmed), syncedAt: const Value(null)),
    );
  }

  /// Renames a routine — a training day within a split.
  ///
  /// Session history names the routine a session belonged to, so this rewrites
  /// history's labels too. That is the right behaviour: renaming "Push A" to
  /// "Push" should not leave old sessions insisting on the old name, because
  /// they are the same day.
  Future<void> renameRoutine(int routineId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final db = ref.read(databaseProvider);
    await (db.update(
      db.workoutRoutines,
    )..where((r) => r.id.equals(routineId))).write(
      WorkoutRoutinesCompanion(
        name: Value(trimmed),
        syncedAt: const Value(null),
      ),
    );
  }

  /// Changes what a routine plans for one exercise.
  ///
  /// The target dialog has always been able to edit — it takes an `initial` —
  /// but nothing ever passed one, so a target could only be set when the
  /// exercise was first added and never corrected.
  Future<void> updateRoutineExerciseTarget(
    int routineExerciseId, {
    required int targetSets,
    required int targetReps,
    double? targetDistanceMetres,
    int? targetDurationSeconds,
  }) async {
    final db = ref.read(databaseProvider);
    await (db.update(
      db.routineExercises,
    )..where((re) => re.id.equals(routineExerciseId))).write(
      RoutineExercisesCompanion(
        targetSets: Value(targetSets),
        targetReps: Value(targetReps),
        targetDistanceMetres: Value(targetDistanceMetres),
        targetDurationSeconds: Value(targetDurationSeconds),
        syncedAt: const Value(null),
      ),
    );
  }

  /// Reorders a routine's exercises to match [orderedIds].
  ///
  /// `orderIndex` has existed since routines did, and until now was only ever
  /// written — set to the count at the time an exercise was added and never
  /// touched again. The order is the order you do them in, so it is worth
  /// being able to change.
  ///
  /// Every row is rewritten from its position in the list rather than the two
  /// being swapped, which also compacts the gaps [removeExerciseFromRoutine]
  /// leaves behind when it soft-deletes something from the middle.
  Future<void> reorderRoutineExercises(List<int> orderedIds) async {
    final db = ref.read(databaseProvider);

    await db.transaction(() async {
      for (var index = 0; index < orderedIds.length; index++) {
        await (db.update(
          db.routineExercises,
        )..where((re) => re.id.equals(orderedIds[index]))).write(
          RoutineExercisesCompanion(
            orderIndex: Value(index),
            syncedAt: const Value(null),
          ),
        );
      }
    });
  }

  /// Soft-deletes a split and all its child routines and routine exercises.
  Future<void> deleteSplit(int splitId) async {
    final db = ref.read(databaseProvider);
    final now = DateTime.now();

    await db.transaction(() async {
      // Soft-delete routine exercises first
      final routines = await (db.select(
        db.workoutRoutines,
      )..where((r) => r.splitId.equals(splitId))).get();

      for (final routine in routines) {
        await (db.update(
          db.routineExercises,
        )..where((re) => re.routineId.equals(routine.id))).write(
          RoutineExercisesCompanion(
            deletedAt: Value(now),
            syncedAt: const Value(null),
          ),
        );
      }

      // Soft-delete routines
      await (db.update(
        db.workoutRoutines,
      )..where((r) => r.splitId.equals(splitId))).write(
        WorkoutRoutinesCompanion(
          deletedAt: Value(now),
          syncedAt: const Value(null),
        ),
      );

      // Soft-delete the split
      await (db.update(
        db.workoutSplits,
      )..where((s) => s.id.equals(splitId))).write(
        WorkoutSplitsCompanion(
          deletedAt: Value(now),
          syncedAt: const Value(null),
        ),
      );
    });
  }

  Future<int> addRoutineToSplit(String name, int splitId) async {
    final db = ref.read(databaseProvider);
    final count =
        await (db.select(db.workoutRoutines)
              ..where((r) => r.splitId.equals(splitId))
              ..where((r) => r.deletedAt.isNull()))
            .get();

    return db
        .into(db.workoutRoutines)
        .insert(
          WorkoutRoutinesCompanion.insert(
            name: name,
            splitId: splitId,
            orderIndex: count.length,
          ),
        );
  }

  Future<void> addExerciseToRoutine({
    required int routineId,
    required int exerciseId,
    int? targetSets,
    int? targetReps,
    double? targetDistanceMetres,
    int? targetDurationSeconds,
  }) async {
    final db = ref.read(databaseProvider);
    final existing =
        await (db.select(db.routineExercises)
              ..where((re) => re.routineId.equals(routineId))
              ..where((re) => re.deletedAt.isNull()))
            .get();

    await db
        .into(db.routineExercises)
        .insert(
          RoutineExercisesCompanion.insert(
            routineId: routineId,
            exerciseId: exerciseId,
            orderIndex: existing.length,
            targetSets: Value.absentIfNull(targetSets),
            targetReps: Value.absentIfNull(targetReps),
            targetDistanceMetres: Value(targetDistanceMetres),
            targetDurationSeconds: Value(targetDurationSeconds),
          ),
        );
  }

  Future<void> removeExerciseFromRoutine(int routineExerciseId) async {
    final db = ref.read(databaseProvider);
    await (db.update(
      db.routineExercises,
    )..where((re) => re.id.equals(routineExerciseId))).write(
      RoutineExercisesCompanion(
        deletedAt: Value(DateTime.now()),
        syncedAt: const Value(null),
      ),
    );
  }

  /// Soft-deletes a routine and all its exercises.
  Future<void> deleteRoutine(int routineId) async {
    final db = ref.read(databaseProvider);
    final now = DateTime.now();

    await db.transaction(() async {
      await (db.update(
        db.routineExercises,
      )..where((re) => re.routineId.equals(routineId))).write(
        RoutineExercisesCompanion(
          deletedAt: Value(now),
          syncedAt: const Value(null),
        ),
      );

      await (db.update(
        db.workoutRoutines,
      )..where((r) => r.id.equals(routineId))).write(
        WorkoutRoutinesCompanion(
          deletedAt: Value(now),
          syncedAt: const Value(null),
        ),
      );
    });
  }
}
