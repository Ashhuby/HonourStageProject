import 'package:drift/drift.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/database/database_provider.dart';
import '../domain/progress_series.dart';
import '../domain/session_highlights.dart';
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
Future<ExerciseProgress> getProgressSeriesForExercise(
  Ref ref,
  int exerciseId,
) async {
  final db = ref.read(databaseProvider);

  final exercise = await (db.select(
    db.exercises,
  )..where((e) => e.id.equals(exerciseId))).getSingleOrNull();
  final metric = detailMetricFor(exercise?.metricType ?? 'weightReps');

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

  final samples = <SetSample>[
    for (final row in rows)
      (
        date: row.readTable(db.workoutSessions).startTime,
        weight: row.readTable(db.workoutSets).weight,
        reps: row.readTable(db.workoutSets).reps,
        durationSeconds: row.readTable(db.workoutSets).durationSeconds,
        distanceMetres: row.readTable(db.workoutSets).distanceMetres,
      ),
  ];

  return ExerciseProgress(
    metric: metric,
    points: sessionTotals(samples, metric),
  );
}

/// The record series for one exercise — the best effort per session.
///
/// Sibling of [getProgressSeriesForExercise], which answers "how much did I
/// do"; this answers "am I improving", so it takes the session *best* rather
/// than the session total, and cardio is judged on pace rather than distance.
///
/// A provider rather than a `FutureBuilder` over a raw query, which is what
/// the PR chart used to do — building the future inside `build` meant a fresh
/// query on every rebuild, and no way for the chart to notice a new record.
@riverpod
Future<ExerciseProgress> getRecordSeriesForExercise(
  Ref ref,
  int exerciseId,
) async {
  final db = ref.watch(databaseProvider);

  final exercise = await (db.select(
    db.exercises,
  )..where((e) => e.id.equals(exerciseId))).getSingleOrNull();
  final metric = recordMetricFor(exercise?.metricType ?? 'weightReps');

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

  final samples = <SetSample>[
    for (final row in rows)
      (
        date: row.readTable(db.workoutSessions).startTime,
        weight: row.readTable(db.workoutSets).weight,
        reps: row.readTable(db.workoutSets).reps,
        durationSeconds: row.readTable(db.workoutSets).durationSeconds,
        distanceMetres: row.readTable(db.workoutSets).distanceMetres,
      ),
  ];

  return ExerciseProgress(
    metric: metric,
    points: sessionBests(samples, metric),
  );
}

/// An exercise's progress series, together with the metric that chose it.
///
/// The metric travels with the points because the caller has to label the
/// axis and the heading, and deriving it twice invites the two disagreeing.
class ExerciseProgress {
  const ExerciseProgress({required this.metric, required this.points});

  final ProgressMetric metric;

  /// Empty when the metric says nothing about this exercise — which is what
  /// makes the caller's `isEmpty` guard meaningful. Volume used to return a
  /// list of zeroes here for every metric type but `weightReps`.
  final List<SeriesPoint> points;
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

/// A finished session, with the routine and split it belonged to.
///
/// The history list showed a bare date because its provider returned bare
/// rows — even though every session carries a `routineId` and
/// the app therefore knows perfectly well it was Push Day from PPL.
class CompletedSession {
  const CompletedSession({
    required this.session,
    this.routineName,
    this.splitName,
  });

  final WorkoutSession session;

  /// Null for a freestyle session, and also for one whose routine has since
  /// been deleted — `routineId` carries no `onDelete` clause, so a session can
  /// outlive the routine it names. Both render as freestyle rather than as an
  /// error.
  final String? routineName;
  final String? splitName;

  int get id => session.id;
  DateTime get startTime => session.startTime;
  Duration? get duration => session.endTime?.difference(session.startTime);

  String get title => routineName ?? freestyleSessionTitle;

  /// The split, when the routine belongs to one — "PPL" beneath "Push Day".
  String? get subtitle => routineName == null ? null : splitName;

  /// What the user wrote about this session, if anything.
  String? get note => session.sessionNote;
}

/// Completed sessions, newest first, each named by its routine and split.
///
/// Left outer joins throughout: a freestyle session has no routine, and a
/// routine-backed one may point at a routine that no longer exists. Follows
/// the shape of [watchActiveSession], which does the same join one level
/// shallower.
@riverpod
Stream<List<CompletedSession>> watchCompletedSessionDetails(Ref ref) {
  final db = ref.watch(databaseProvider);

  final query =
      db.select(db.workoutSessions).join([
          leftOuterJoin(
            db.workoutRoutines,
            db.workoutRoutines.id.equalsExp(db.workoutSessions.routineId),
          ),
          leftOuterJoin(
            db.workoutSplits,
            db.workoutSplits.id.equalsExp(db.workoutRoutines.splitId),
          ),
        ])
        ..where(db.workoutSessions.endTime.isNotNull())
        ..where(db.workoutSessions.deletedAt.isNull())
        ..orderBy([OrderingTerm.desc(db.workoutSessions.startTime)]);

  return query.watch().map(
    (rows) => [
      for (final row in rows)
        CompletedSession(
          session: row.readTable(db.workoutSessions),
          routineName: row.readTableOrNull(db.workoutRoutines)?.name,
          splitName: row.readTableOrNull(db.workoutSplits)?.name,
        ),
    ],
  );
}

/// What each session achieved — records set, exercises tried for the first
/// time, badges earned.
///
/// One pass over the whole history rather than a query per session. That is
/// not only cheaper: a personal-best verdict for one session depends on every
/// set logged before it, so a per-session query would rescan all of history
/// anyway — and the history list is a `shrinkWrap` list with no viewport
/// culling, so every row builds on every frame.
///
/// The population deliberately matches `recalculateForExercise`: non-deleted
/// sets in non-deleted sessions, **including sessions still in progress**,
/// because `logSet` awards records immediately. Filtering to completed
/// sessions happens when rendering; doing it here would let these verdicts
/// disagree with the records table.
@riverpod
Stream<Map<int, SessionHighlights>> watchSessionHighlights(Ref ref) {
  final db = ref.watch(databaseProvider);

  final setsQuery =
      db.select(db.workoutSets).join([
          innerJoin(
            db.exercises,
            db.exercises.id.equalsExp(db.workoutSets.exerciseId),
          ),
          innerJoin(
            db.workoutSessions,
            db.workoutSessions.id.equalsExp(db.workoutSets.sessionId),
          ),
        ])
        ..where(db.workoutSets.deletedAt.isNull())
        ..where(db.workoutSessions.deletedAt.isNull())
        ..orderBy([OrderingTerm.asc(db.workoutSets.timestamp)]);

  final sessionsQuery = db.select(db.workoutSessions)
    ..where((s) => s.deletedAt.isNull())
    ..orderBy([(s) => OrderingTerm.asc(s.startTime)]);

  final badgesQuery = db.select(db.badges)
    ..where((b) => b.earnedAt.isNotNull());

  return setsQuery.watch().asyncMap((rows) async {
    final sessions = await sessionsQuery.get();
    final badges = await badgesQuery.get();

    return replaySessionHighlights(
      setsOldestFirst: [
        for (final row in rows)
          (
            sessionId: row.readTable(db.workoutSets).sessionId,
            exerciseId: row.readTable(db.exercises).id,
            exerciseName: row.readTable(db.exercises).name,
            metricType: row.readTable(db.exercises).metricType,
            timestamp: row.readTable(db.workoutSets).timestamp,
            weight: row.readTable(db.workoutSets).weight,
            reps: row.readTable(db.workoutSets).reps,
            durationSeconds: row.readTable(db.workoutSets).durationSeconds,
            distanceMetres: row.readTable(db.workoutSets).distanceMetres,
          ),
      ],
      sessionsByStartTime: [
        for (final session in sessions)
          (
            sessionId: session.id,
            startTime: session.startTime,
            endTime: session.endTime,
          ),
      ],
      earnedBadges: [
        for (final badge in badges)
          if (badge.earnedAt != null)
            (badgeKey: badge.badgeKey, earnedAt: badge.earnedAt!),
      ],
    );
  });
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

  /// Attaches a note to a session, or clears it.
  ///
  /// `sessionNote` has been a column since the schema had sync columns at all,
  /// and it round-trips through Supabase in both directions — but nothing in
  /// the app ever wrote one, so it has only ever held null.
  ///
  /// Blank input clears the note rather than storing an empty string: a note
  /// either says something or does not exist, and two ways of saying "nothing"
  /// is one too many.
  Future<void> setSessionNote(int sessionId, String? note) async {
    final db = ref.read(databaseProvider);
    final trimmed = note?.trim();

    await (db.update(
      db.workoutSessions,
    )..where((s) => s.id.equals(sessionId))).write(
      WorkoutSessionsCompanion(
        sessionNote: Value(trimmed == null || trimmed.isEmpty ? null : trimmed),
        // Dirty, so the note reaches the other device.
        syncedAt: const Value(null),
      ),
    );
  }

  /// Soft-deletes a session and all its sets, then rebuilds the records those
  /// sets were holding.
  ///
  /// A personal best is evidence of a set that was logged, so removing the
  /// session containing it has to withdraw it — the contract [deleteSet] and
  /// [updateSet] already honour. Without this, discarding a workout in which
  /// you mistyped 800kg left the 800kg record standing.
  Future<void> deleteSession(int sessionId) async {
    final db = ref.read(databaseProvider);
    final now = DateTime.now();

    // Gathered before the delete: afterwards these sets are hidden from the
    // very query that says which exercises need rebuilding.
    final affected = await (db.select(db.workoutSets).join([
      innerJoin(
        db.exercises,
        db.exercises.id.equalsExp(db.workoutSets.exerciseId),
      ),
    ])..where(db.workoutSets.sessionId.equals(sessionId))).get();

    final touched = {
      for (final row in affected)
        row.readTable(db.exercises).id: row.readTable(db.exercises).metricType,
    };

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

    // Outside the transaction. Drift would show the rebuild the uncommitted
    // delete — its executor is zone-scoped — so this is not a correctness
    // requirement; it keeps the write lock short and many round trips out of
    // it, matching how deleteSet already writes and then rebuilds.
    final records = ref.read(personalBestRepositoryProvider.notifier);
    for (final entry in touched.entries) {
      await records.recalculateForExercise(
        exerciseId: entry.key,
        metricType: entry.value,
      );
    }
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
