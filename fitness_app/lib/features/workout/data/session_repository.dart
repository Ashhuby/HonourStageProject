import 'package:drift/drift.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:fitness_app/core/database/database_provider.dart';
import 'package:fitness_app/core/database/local_database.dart';
import 'personal_best_repository.dart';
import 'badge_service.dart';

part 'session_repository.g.dart';

class WorkoutSetWithExercise {
  final WorkoutSet set;
  final String exerciseName;

  const WorkoutSetWithExercise({
    required this.set,
    required this.exerciseName,
  });
}

// ---------------------------------------------------------------------------
// Queries (unchanged from original)
// ---------------------------------------------------------------------------

@riverpod
Stream<List<WorkoutSession>> watchCompletedSessions(Ref ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.workoutSessions)
        ..where((s) => s.endTime.isNotNull())
        ..where((s) => s.deletedAt.isNull())
        ..orderBy([(s) => OrderingTerm.desc(s.startTime)]))
      .watch();
}

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
    ..where(db.workoutSessions.deletedAt.isNull())
    ..where(db.workoutSets.deletedAt.isNull())
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

@riverpod
Future<Map<DateTime, int>> getAttendanceData(Ref ref) async {
  final db = ref.read(databaseProvider);

  final sessions = await (db.select(db.workoutSessions)
        ..where((s) => s.endTime.isNotNull())
        ..where((s) => s.deletedAt.isNull()))
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
        !date.isAfter(DateTime(weekEnd.year, weekEnd.month, weekEnd.day)));

    if (hasSession) {
      streak++;
    } else if (weeksBack > 0) {
      break;
    }
  }

  return streak;
}

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
    ..where(db.workoutSets.deletedAt.isNull())
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

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

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

  /// Ends a session and evaluates badge triggers that fire on session
  /// completion: first_workout, streak triggers, and set count milestones.
  Future<void> endSession(int sessionId) async {
    final db = ref.read(databaseProvider);
    await (db.update(db.workoutSessions)
          ..where((s) => s.id.equals(sessionId)))
        .write(WorkoutSessionsCompanion(
      endTime: Value(DateTime.now()),
    ));

    // Evaluate session-completion badges.
    // PR count is required by evaluateAll — fetch it here so BadgeService
    // stays decoupled from PersonalBestRepository.
    final prCount = await ref
        .read(personalBestRepositoryProvider.notifier)
        .getTotalPrCount();

    await ref.read(badgeServiceProvider.notifier).evaluateAll(
          totalPrCount: prCount,
        );
  }

  /// Logs a set, checks for a new personal best, and evaluates badge
  /// triggers. Returns a [PrResult] if a new PR was set, null otherwise.
  ///
  /// [metricType] controls which fields are relevant:
  ///   weightReps:     weight + reps
  ///   bodyweightReps: reps only (weight optional for added weight)
  ///   timeOnly:       durationSeconds only
  ///   distanceTime:   distanceMetres + durationSeconds
  Future<PrResult?> logSet({
    required int sessionId,
    required int exerciseId,
    required String exerciseName,
    required String metricType,
    double weight = 0.0,
    int reps = 0,
    int? durationSeconds,
    double? distanceMetres,
  }) async {
    final db = ref.read(databaseProvider);

    // 1. Insert the set into the database.
    await db.into(db.workoutSets).insert(
          WorkoutSetsCompanion.insert(
            sessionId: sessionId,
            exerciseId: exerciseId,
            weight: Value(weight),
            reps: Value(reps),
            durationSeconds: Value(durationSeconds),
            distanceMetres: Value(distanceMetres),
          ),
        );

    // 2. Check for a new PR — routes by metricType.
    final prResult = await ref
        .read(personalBestRepositoryProvider.notifier)
        .checkAndSavePr(
          exerciseId: exerciseId,
          exerciseName: exerciseName,
          metricType: metricType,
          weight: weight,
          reps: reps,
          durationSeconds: durationSeconds,
          distanceMetres: distanceMetres,
        );

    // 3. Evaluate badges after every set.
    final prCount = await ref
        .read(personalBestRepositoryProvider.notifier)
        .getTotalPrCount();

    await ref.read(badgeServiceProvider.notifier).evaluateAll(
          totalPrCount: prCount,
        );

    // 4. Return the PR result so the UI can surface it immediately.
    return prResult;
  }

  /// Soft-deletes a set — marks it dirty so sync propagates the delete.
  Future<void> deleteSet(int setId) async {
    final db = ref.read(databaseProvider);
    await (db.update(db.workoutSets)..where((s) => s.id.equals(setId)))
        .write(WorkoutSetsCompanion(
      deletedAt: Value(DateTime.now()),
      syncedAt: const Value(null),
    ));
  }

  /// Soft-deletes a session and all its sets.
  Future<void> deleteSession(int sessionId) async {
    final db = ref.read(databaseProvider);
    final now = DateTime.now();

    await db.transaction(() async {
      await (db.update(db.workoutSets)
            ..where((s) => s.sessionId.equals(sessionId)))
          .write(WorkoutSetsCompanion(
        deletedAt: Value(now),
        syncedAt: const Value(null),
      ));

      await (db.update(db.workoutSessions)
            ..where((s) => s.id.equals(sessionId)))
          .write(WorkoutSessionsCompanion(
        deletedAt: Value(now),
        syncedAt: const Value(null),
      ));
    });
  }
}