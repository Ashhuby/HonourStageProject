import 'package:drift/drift.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/local_database.dart';
import 'personal_best_repository.dart';
import 'badge_service.dart';

part 'session_repository.g.dart';

class WorkoutSetWithExercise {
  final WorkoutSet set;
  final String exerciseName;

  /// The exercise's metric type — decides which fields a set records, and so
  /// which fields an edit offers.
  final String metricType;

  const WorkoutSetWithExercise({
    required this.set,
    required this.exerciseName,
    this.metricType = 'weightReps',
  });
}

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

  final query =
      db.select(db.workoutSets).join([
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
Stream<Map<DateTime, int>> getAttendanceData(Ref ref) {
  final db = ref.watch(databaseProvider);

  final sessionsStream =
      (db.select(db.workoutSessions)
            ..where((s) => s.endTime.isNotNull())
            ..where((s) => s.deletedAt.isNull()))
          .watch();

  return sessionsStream.map((sessions) {
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
  });
}

@riverpod
Future<int> getWeeklyStreak(Ref ref) async {
  final attendanceData = await ref.read(getAttendanceDataProvider.future);

  if (attendanceData.isEmpty) return 0;

  final today = DateTime.now();
  int streak = 0;

  for (int weeksBack = 0; weeksBack < 52; weeksBack++) {
    final weekStart = today.subtract(
      Duration(days: today.weekday - 1 + (weeksBack * 7)),
    );
    final weekEnd = weekStart.add(const Duration(days: 6));

    final hasSession = attendanceData.keys.any(
      (date) =>
          !date.isBefore(
            DateTime(weekStart.year, weekStart.month, weekStart.day),
          ) &&
          !date.isAfter(DateTime(weekEnd.year, weekEnd.month, weekEnd.day)),
    );

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

  final query =
      db.select(db.workoutSets).join([
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
            metricType: row.readTable(db.exercises).metricType,
          ),
        )
        .toList(),
  );
}

/// A session that was started and never finished.
///
/// [title] is the routine's name, or a freestyle label when the session has
/// no routine — enough to reopen the session screen exactly as it was left.
class ActiveSession {
  final WorkoutSession session;
  final String title;

  const ActiveSession({required this.session, required this.title});

  int? get routineId => session.routineId;
}

/// Label used for a session that was started without a routine.
const String freestyleSessionTitle = 'Freestyle Session';

/// The session currently in progress, or null when there is none.
///
/// A session with no [WorkoutSessions.endTime] is in progress: it is skipped
/// by sync and by every history query, so without a way back into it the
/// workout is stranded. Killing the app mid-set is the common cause.
///
/// The most recent one wins if several were left open by older builds.
@riverpod
Stream<ActiveSession?> watchActiveSession(Ref ref) {
  final db = ref.watch(databaseProvider);

  final query =
      db.select(db.workoutSessions).join([
          leftOuterJoin(
            db.workoutRoutines,
            db.workoutRoutines.id.equalsExp(db.workoutSessions.routineId),
          ),
        ])
        ..where(db.workoutSessions.endTime.isNull())
        ..where(db.workoutSessions.deletedAt.isNull())
        ..orderBy([OrderingTerm.desc(db.workoutSessions.startTime)])
        ..limit(1);

  return query.watch().map((rows) {
    if (rows.isEmpty) return null;
    final row = rows.first;
    final routine = row.readTableOrNull(db.workoutRoutines);
    return ActiveSession(
      session: row.readTable(db.workoutSessions),
      title: routine?.name ?? freestyleSessionTitle,
    );
  });
}

/// How many sets have been logged in [sessionId].
@riverpod
Stream<int> watchSetCountForSession(Ref ref, int sessionId) {
  final db = ref.watch(databaseProvider);
  final count = db.workoutSets.id.count();

  final query = db.selectOnly(db.workoutSets)
    ..addColumns([count])
    ..where(db.workoutSets.sessionId.equals(sessionId))
    ..where(db.workoutSets.deletedAt.isNull());

  return query.watchSingle().map((row) => row.read(count) ?? 0);
}

/// A previous session's work on a single exercise.
///
/// Surfaced while logging so the user can see what they lifted last time
/// without leaving the session screen.
class LastSessionPerformance {
  final DateTime date;
  final List<WorkoutSet> sets;

  const LastSessionPerformance({required this.date, required this.sets});
}

/// Rows scanned when looking up the previous session's sets.
///
/// Rows arrive newest-session-first, so the most recent session's sets are
/// always inside this window — no realistic session logs 50 sets of a single
/// exercise. Bounding the query keeps it cheap as history grows.
const int _lastPerformanceRowLimit = 50;

/// Sets logged for [exerciseId] in the most recent completed session, ignoring
/// [currentSessionId] so the session in progress never reports back to itself.
///
/// Emits null when the exercise has not been logged in a completed session.
@riverpod
Stream<LastSessionPerformance?> watchLastPerformanceForExercise(
  Ref ref,
  int exerciseId,
  int currentSessionId,
) {
  final db = ref.watch(databaseProvider);

  final query =
      db.select(db.workoutSets).join([
          innerJoin(
            db.workoutSessions,
            db.workoutSessions.id.equalsExp(db.workoutSets.sessionId),
          ),
        ])
        ..where(db.workoutSets.exerciseId.equals(exerciseId))
        ..where(db.workoutSets.sessionId.equals(currentSessionId).not())
        ..where(db.workoutSets.deletedAt.isNull())
        ..where(db.workoutSessions.endTime.isNotNull())
        ..where(db.workoutSessions.deletedAt.isNull())
        ..orderBy([
          OrderingTerm.desc(db.workoutSessions.startTime),
          OrderingTerm.asc(db.workoutSets.timestamp),
        ])
        ..limit(_lastPerformanceRowLimit);

  return query.watch().map((rows) {
    if (rows.isEmpty) return null;
    final session = rows.first.readTable(db.workoutSessions);
    final sets = rows
        .map((row) => row.readTable(db.workoutSets))
        .where((set) => set.sessionId == session.id)
        .toList();
    return LastSessionPerformance(date: session.startTime, sets: sets);
  });
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
    return db
        .into(db.workoutSessions)
        .insert(
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
    await (db.update(db.workoutSessions)..where((s) => s.id.equals(sessionId)))
        .write(WorkoutSessionsCompanion(endTime: Value(DateTime.now())));

    // Evaluate session-completion badges.
    // PR count is required by evaluateAll — fetch it here so BadgeService
    // stays decoupled from PersonalBestRepository.
    final prCount = await ref
        .read(personalBestRepositoryProvider.notifier)
        .getTotalPrCount();

    await ref
        .read(badgeServiceProvider.notifier)
        .evaluateAll(totalPrCount: prCount);
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
    await db
        .into(db.workoutSets)
        .insert(
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

    await ref
        .read(badgeServiceProvider.notifier)
        .evaluateAll(totalPrCount: prCount);

    // 4. Return the PR result so the UI can surface it immediately.
    return prResult;
  }

  /// Corrects a logged set.
  ///
  /// Fields not relevant to the exercise's metric type are cleared, so a set
  /// edited from one shape to another cannot keep stale values. The records
  /// for the exercise are rebuilt afterwards — the old values may have earned
  /// a personal best that the correction withdraws.
  Future<void> updateSet({
    required int setId,
    double weight = 0.0,
    int reps = 0,
    int? durationSeconds,
    double? distanceMetres,
  }) async {
    final db = ref.read(databaseProvider);

    await (db.update(db.workoutSets)..where((s) => s.id.equals(setId))).write(
      WorkoutSetsCompanion(
        weight: Value(weight),
        reps: Value(reps),
        durationSeconds: Value(durationSeconds),
        distanceMetres: Value(distanceMetres),
        syncedAt: const Value(null),
      ),
    );

    await _rebuildRecordsForSet(setId);
  }

  /// Soft-deletes a set — marks it dirty so sync propagates the delete.
  ///
  /// Any record the set earned is rebuilt from what survives, so a mistyped
  /// lift does not leave a personal best behind once it is removed.
  Future<void> deleteSet(int setId) async {
    final db = ref.read(databaseProvider);
    await (db.update(db.workoutSets)..where((s) => s.id.equals(setId))).write(
      WorkoutSetsCompanion(
        deletedAt: Value(DateTime.now()),
        syncedAt: const Value(null),
      ),
    );

    await _rebuildRecordsForSet(setId);
  }

  /// Rebuilds the personal bests for the exercise [setId] belongs to.
  Future<void> _rebuildRecordsForSet(int setId) async {
    final db = ref.read(databaseProvider);

    final row = await (db.select(db.workoutSets).join([
      innerJoin(
        db.exercises,
        db.exercises.id.equalsExp(db.workoutSets.exerciseId),
      ),
    ])..where(db.workoutSets.id.equals(setId))).getSingleOrNull();
    if (row == null) return;

    final exercise = row.readTable(db.exercises);
    await ref
        .read(personalBestRepositoryProvider.notifier)
        .recalculateForExercise(
          exerciseId: exercise.id,
          metricType: exercise.metricType,
        );
  }

  /// Soft-deletes a session and all its sets.
  Future<void> deleteSession(int sessionId) async {
    final db = ref.read(databaseProvider);
    final now = DateTime.now();

    await db.transaction(() async {
      await (db.update(
        db.workoutSets,
      )..where((s) => s.sessionId.equals(sessionId))).write(
        WorkoutSetsCompanion(
          deletedAt: Value(now),
          syncedAt: const Value(null),
        ),
      );

      await (db.update(
        db.workoutSessions,
      )..where((s) => s.id.equals(sessionId))).write(
        WorkoutSessionsCompanion(
          deletedAt: Value(now),
          syncedAt: const Value(null),
        ),
      );
    });
  }
}

/// Rows scanned when working out which exercises were used most recently.
///
/// Bounded for the same reason as [_lastPerformanceRowLimit]: the picker only
/// ever shows a handful of names, and 200 sets is far more history than is
/// needed to find them.
const int _recentExerciseRowLimit = 200;

/// Exercise ids the user logged most recently, newest first and de-duplicated.
///
/// Derived from sets already logged, so it needs no schema support — there is
/// no `lastUsedAt` column and this deliberately avoids adding one.
@riverpod
Stream<List<int>> watchRecentExerciseIds(Ref ref, {int limit = 6}) {
  final db = ref.watch(databaseProvider);

  final query = db.select(db.workoutSets)
    ..where((s) => s.deletedAt.isNull())
    ..orderBy([(s) => OrderingTerm.desc(s.timestamp)])
    ..limit(_recentExerciseRowLimit);

  return query.watch().map((rows) {
    final recent = <int>[];
    for (final row in rows) {
      if (recent.contains(row.exerciseId)) continue;
      recent.add(row.exerciseId);
      if (recent.length == limit) break;
    }
    return recent;
  });
}
