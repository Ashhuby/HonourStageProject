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

// Watches all completed sessions, most recent first
@riverpod
Stream<List<WorkoutSession>> watchCompletedSessions(Ref ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.workoutSessions)
        ..where((s) => s.endTime.isNotNull())
        ..orderBy([(s) => OrderingTerm.desc(s.startTime)]))
      .watch();
}

// Returns volume data points for a specific exercise across all sessions
// Volume = weight × reps per set, summed per session
@riverpod
Future<List<VolumeDataPoint>> getVolumeForExercise(
  Ref ref,
  int exerciseId,
) async {
  final db = ref.read(databaseProvider);

  final query = db.select(db.workoutSets).join([
    innerJoin(
      db.workoutSessions,
      db.workoutSessions.id.equalsExp(db.workoutSets.sessionId),
    ),
  ])
    ..where(db.workoutSets.exerciseId.equals(exerciseId))
    ..where(db.workoutSessions.endTime.isNotNull())
    ..orderBy([OrderingTerm.asc(db.workoutSessions.startTime)]);

  final rows = await query.get();

  final Map<int, VolumeDataPoint> sessionVolume = {};
  for (final row in rows) {
    final set = row.readTable(db.workoutSets);
    final session = row.readTable(db.workoutSessions);
    final volume = set.weight * set.reps;

    if (sessionVolume.containsKey(session.id)) {
      sessionVolume[session.id] = VolumeDataPoint(
        sessionId: session.id,
        date: session.startTime,
        totalVolume: sessionVolume[session.id]!.totalVolume + volume,
      );
    } else {
      sessionVolume[session.id] = VolumeDataPoint(
        sessionId: session.id,
        date: session.startTime,
        totalVolume: volume,
      );
    }
  }

  return sessionVolume.values.toList();
}

class VolumeDataPoint {
  final int sessionId;
  final DateTime date;
  final double totalVolume;

  const VolumeDataPoint({
    required this.sessionId,
    required this.date,
    required this.totalVolume,
  });
}

// Returns a map of dates to session count for the attendance heatmap
@riverpod
Future<Map<DateTime, int>> getAttendanceData(Ref ref) async {
  final db = ref.read(databaseProvider);

  final sessions = await (db.select(db.workoutSessions)
        ..where((s) => s.endTime.isNotNull()))
      .get();

  final Map<DateTime, int> attendanceMap = {};
  for (final session in sessions) {
    final date = DateTime(
      session.startTime.year,
      session.startTime.month,
      session.startTime.day,
    );
    attendanceMap[date] = (attendanceMap[date] ?? 0) + 1;
  }

  return attendanceMap;
}

// Returns current weekly streak — consecutive weeks with at least one session
@riverpod
Future<int> getWeeklyStreak(Ref ref) async {
  final attendanceData = await ref.watch(getAttendanceDataProvider.future);

  if (attendanceData.isEmpty) return 0;

  final today = DateTime.now();
  int streak = 0;

  for (int weeksBack = 0; weeksBack < 52; weeksBack++) {
    final weekStart = today
        .subtract(Duration(days: today.weekday - 1 + (weeksBack * 7)));
    final weekEnd = weekStart.add(const Duration(days: 6));

    final hasSession = attendanceData.keys.any((date) =>
        !date.isBefore(
            DateTime(weekStart.year, weekStart.month, weekStart.day)) &&
        !date.isAfter(
            DateTime(weekEnd.year, weekEnd.month, weekEnd.day)));

    if (hasSession) {
      streak++;
    } else if (weeksBack > 0) {
      break;
    }
  }

  return streak;
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

  Future<int> startSession({int? routineId}) async {
    final db = ref.read(databaseProvider);
    return db.into(db.workoutSessions).insert(
          WorkoutSessionsCompanion.insert(
            startTime: DateTime.now(),
            routineId: Value(routineId),
          ),
        );
  }

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

  Future<void> deleteSet(int setId) async {
    final db = ref.read(databaseProvider);
    await (db.delete(db.workoutSets)..where((s) => s.id.equals(setId))).go();
  }
}