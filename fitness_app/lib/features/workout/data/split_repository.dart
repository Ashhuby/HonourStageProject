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
  return db.select(db.workoutSplits).watch();
}

@riverpod
Stream<List<WorkoutRoutine>> watchRoutinesForSplit(Ref ref, int splitId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.workoutRoutines)
        ..where((r) => r.splitId.equals(splitId))
        ..orderBy([(r) => OrderingTerm.asc(r.orderIndex)]))
      .watch();
}

@riverpod
Stream<List<RoutineExercise>> watchExercisesForRoutine(Ref ref, int routineId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.routineExercises)
        ..where((re) => re.routineId.equals(routineId))
        ..orderBy([(re) => OrderingTerm.asc(re.orderIndex)]))
      .watch();
}

// --- REPOSITORY ---

@riverpod
class SplitRepository extends _$SplitRepository {
  @override
  void build() {}

  // Creates a new split with a given name
  Future<int> createSplit(String name) async {
    final db = ref.read(databaseProvider);
    return db.into(db.workoutSplits).insert(
          WorkoutSplitsCompanion.insert(name: name),
        );
  }

  // Deletes a split — cascade will handle routines and routine exercises
  Future<void> deleteSplit(int splitId) async {
    final db = ref.read(databaseProvider);
    await (db.delete(db.workoutSplits)
          ..where((s) => s.id.equals(splitId)))
        .go();
  }

  // Adds a named day (routine) to a split
  Future<int> addRoutineToSplit(String name, int splitId) async {
    final db = ref.read(databaseProvider);

    // Get current max orderIndex for this split so we append to the end
    final existing = await (db.select(db.workoutRoutines)
          ..where((r) => r.splitId.equals(splitId)))
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

  // Adds an exercise to a routine template with optional target sets/reps
  Future<void> addExerciseToRoutine({
    required int routineId,
    required int exerciseId,
    int targetSets = 3,
    int targetReps = 10,
  }) async {
    final db = ref.read(databaseProvider);

    final existing = await (db.select(db.routineExercises)
          ..where((re) => re.routineId.equals(routineId)))
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

  // Removes an exercise from a routine template
  Future<void> removeExerciseFromRoutine(int routineExerciseId) async {
    final db = ref.read(databaseProvider);
    await (db.delete(db.routineExercises)
          ..where((re) => re.id.equals(routineExerciseId)))
        .go();
  }

  // Deletes a routine and all its exercises
  Future<void> deleteRoutine(int routineId) async {
    final db = ref.read(databaseProvider);
    await (db.delete(db.workoutRoutines)
          ..where((r) => r.id.equals(routineId)))
        .go();
  }
}