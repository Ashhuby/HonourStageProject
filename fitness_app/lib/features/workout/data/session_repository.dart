import 'package:drift/drift.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:fitness_app/core/database/database_provider.dart';
import 'package:fitness_app/core/database/local_database.dart';

part 'session_repository.g.dart';

class WorkoutSetWithExercise {
  final WorkoutSet set;
  final String exerciseName;

  const WorkoutSetWithExercise({
    required this.set,
    required this.exerciseName,
  });
}

// Watches all sets for a session, joined with exercise names
@riverpod
Stream<List<WorkoutSetWithExercise>> watchSetsForSession(
  Ref ref,
  int sessionId,
) {
  final db = ref.watch(databaseProvider);

  final query = db.select(db.workoutSets).join([
    innerJoin(
      db.exercises,
      db.exercises.id.equalsExp(db.workoutSets.exerciseId),
    ),
  ])
    ..where(db.workoutSets.sessionId.equals(sessionId))
    ..orderBy([OrderingTerm.asc(db.workoutSets.timestamp)]);

  return query.watch().map(
        (rows) => rows
            .map(
              (row) => WorkoutSetWithExercise(
                set: row.readTable(db.workoutSets),
                exerciseName: row.readTable(db.exercises).name,
              ),
            )
            .toList(),
      );
}

@riverpod
class SessionRepository extends _$SessionRepository {
  @override
  void build() {}

  // Creates a new session and returns its ID
  Future<int> startSession({int? routineId}) async {
    final db = ref.read(databaseProvider);
    return db.into(db.workoutSessions).insert(
          WorkoutSessionsCompanion.insert(
            startTime: DateTime.now(),
            routineId: Value(routineId),
          ),
        );
  }

  // Writes endTime to close the session
  Future<void> endSession(int sessionId) async {
    final db = ref.read(databaseProvider);
    await (db.update(db.workoutSessions)
          ..where((s) => s.id.equals(sessionId)))
        .write(
      WorkoutSessionsCompanion(
        endTime: Value(DateTime.now()),
      ),
    );
  }

  // Logs a single set — written to DB immediately
  Future<void> logSet({
    required int sessionId,
    required int exerciseId,
    required double weight,
    required int reps,
  }) async {
    final db = ref.read(databaseProvider);
    await db.into(db.workoutSets).insert(
          WorkoutSetsCompanion.insert(
            sessionId: sessionId,
            exerciseId: exerciseId,
            weight: weight,
            reps: reps,
          ),
        );
  }

  // Deletes a logged set
  Future<void> deleteSet(int setId) async {
    final db = ref.read(databaseProvider);
    await (db.delete(db.workoutSets)..where((s) => s.id.equals(setId))).go();
  }
}