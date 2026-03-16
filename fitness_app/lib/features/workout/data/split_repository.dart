import 'package:drift/drift.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:fitness_app/core/database/database_provider.dart';
import 'package:fitness_app/core/database/local_database.dart';

part 'split_repository.g.dart';

class RoutineExerciseWithName {
  final RoutineExercise routineExercise;
  final String exerciseName;
  final String bodyPart;
  final String equipmentType;

  const RoutineExerciseWithName({
    required this.routineExercise,
    required this.exerciseName,
    required this.bodyPart,
    required this.equipmentType,
  });
}

// --- STREAMS ---
@riverpod
Stream<List<RoutineExerciseWithName>> watchExercisesForRoutineWithNames(
  Ref ref,
  int routineId,
) {
  final db = ref.watch(databaseProvider);

  final query = db.select(db.routineExercises).join([
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
                exerciseName: row.readTable(db.exercises).name,
                bodyPart: row.readTable(db.exercises).bodyPart,
                equipmentType: row.readTable(db.exercises).equipmentType,
              ),
            )
            .toList(),
      );
}

@riverpod
Stream<List<WorkoutSplit>> watchSplits(Ref ref) {
  final db = ref.watch(databaseProvider);
  // Exclude soft-deleted splits from UI
  return (db.select(db.workoutSplits)
        ..where((s) => s.deletedAt.isNull()))
      .watch();
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
    return db.into(db.workoutSplits).insert(
          WorkoutSplitsCompanion.insert(name: name),
        );
  }

  /// Soft-deletes a split and all its child routines and routine exercises.
  /// Clears syncedAt on all records so the sync service propagates deletes.
  Future<void> deleteSplit(int splitId) async {
    final db = ref.read(databaseProvider);
    final now = DateTime.now();

    await db.transaction(() async {
      // Soft-delete all routine exercises under this split
      final routines = await (db.select(db.workoutRoutines)
            ..where((r) => r.splitId.equals(splitId)))
          .get();

      for (final routine in routines) {
        await (db.update(db.routineExercises)
              ..where((re) => re.routineId.equals(routine.id)))
            .write(WorkoutRoutinesCompanion(
          deletedAt: Value(now),
          syncedAt: const Value(null),
        ));
      }

      // Soft-delete all routines under this split
      await (db.update(db.workoutRoutines)
            ..where((r) => r.splitId.equals(splitId)))
          .write(WorkoutRoutinesCompanion(
        deletedAt: Value(now),
        syncedAt: const Value(null),
      ));

      // Soft-delete the split itself
      await (db.update(db.workoutSplits)
            ..where((s) => s.id.equals(splitId)))
          .write(WorkoutSplitsCompanion(
        deletedAt: Value(now),
        syncedAt: const Value(null),
      ));
    });
  }

  Future<int> addRoutineToSplit(String name, int splitId) async {
    final db = ref.read(databaseProvider);

    final existing = await (db.select(db.workoutRoutines)
          ..where((r) => r.splitId.equals(splitId))
          ..where((r) => r.deletedAt.isNull()))
        .get();
    final nextIndex = existing.length;

    return db.into(db.workoutRoutines).insert(
          WorkoutRoutinesCompanion.insert(
            name: name,
            splitId: splitId,
            orderIndex: nextIndex,
          ),
        );
  }

  Future<void> addExerciseToRoutine({
    required int routineId,
    required int exerciseId,
    int targetSets = 3,
    int targetReps = 10,
  }) async {
    final db = ref.read(databaseProvider);

    final existing = await (db.select(db.routineExercises)
          ..where((re) => re.routineId.equals(routineId))
          ..where((re) => re.deletedAt.isNull()))
        .get();
    final nextIndex = existing.length;

    await db.into(db.routineExercises).insert(
          RoutineExercisesCompanion.insert(
            routineId: routineId,
            exerciseId: exerciseId,
            orderIndex: nextIndex,
            targetSets: Value(targetSets),
            targetReps: Value(targetReps),
          ),
        );
  }

  /// Soft-deletes a single routine exercise.
  Future<void> removeExerciseFromRoutine(int routineExerciseId) async {
    final db = ref.read(databaseProvider);
    await (db.update(db.routineExercises)
          ..where((re) => re.id.equals(routineExerciseId)))
        .write(RoutineExercisesCompanion(
      deletedAt: Value(DateTime.now()),
      syncedAt: const Value(null),
    ));
  }

  /// Soft-deletes a routine and all its exercises.
  Future<void> deleteRoutine(int routineId) async {
    final db = ref.read(databaseProvider);
    final now = DateTime.now();

    await db.transaction(() async {
      await (db.update(db.routineExercises)
            ..where((re) => re.routineId.equals(routineId)))
          .write(RoutineExercisesCompanion(
        deletedAt: Value(now),
        syncedAt: const Value(null),
      ));

      await (db.update(db.workoutRoutines)
            ..where((r) => r.id.equals(routineId)))
          .write(WorkoutRoutinesCompanion(
        deletedAt: Value(now),
        syncedAt: const Value(null),
      ));
    });
  }
}