/// Every counter a badge can be measured against, computed from the local
/// database in one pass.
///
/// This exists so a badge criterion can answer two questions with one number.
/// "Have you earned it" is `value >= target`; "how close are you" is
/// `value / target`. The award engine and the progress ring on a locked tile
/// read the same [BadgeStats] map, so they cannot disagree about what counts.
///
/// Functions here take an [AppDatabase] rather than a `Ref`, which makes the
/// whole criterion layer testable against an in-memory database without the
/// Riverpod container — the thing `badge_service_test.dart` previously worked
/// around by reimplementing the award logic inline.
library;

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:riverpod/riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/database/local_database.dart';
import '../../profile/data/profile_provider.dart';
import '../domain/activity.dart';
import '../domain/badge_catalogue.dart';
import '../domain/muscle.dart';
import '../domain/rank.dart';
import 'badge_unlock_queue.dart';
import 'rank_up_queue.dart';
import 'personal_best_repository.dart';
import 'strength_standards_data.dart';

part 'badge_stats.g.dart';

/// A snapshot of the user's training history, one entry per [BadgeStat].
///
/// A stat that was not requested is simply absent; [statValue] reads a missing
/// entry as zero, so a partial snapshot can never award a badge by accident.
typedef BadgeStats = Map<BadgeStat, num>;

/// How long a break has to be before returning from it counts as a comeback.
const Duration kComebackGap = Duration(days: 14);

/// Reads a stat from a snapshot, treating absence as zero.
num statValue(BadgeStats stats, BadgeStat stat) => stats[stat] ?? 0;

/// Where a badge stands: what the counter reads now, and what it must reach.
typedef BadgeProgress = ({num current, num target});

/// The progress of [def] against a stats snapshot.
///
/// [current] is clamped to [target] so a user with 900 sets does not see
/// "900 / 500" on a badge they have already earned.
BadgeProgress progressFor(BadgeDefinition def, BadgeStats stats) {
  final raw = statValue(stats, def.stat);
  return (current: raw < def.target ? raw : def.target, target: def.target);
}

/// The fraction of [def] completed, in 0..1.
double progressFractionFor(BadgeDefinition def, BadgeStats stats) {
  final p = progressFor(def, stats);
  if (p.target <= 0) return 1;
  return (p.current / p.target).clamp(0.0, 1.0).toDouble();
}

/// Whether [def]'s criterion is met by a stats snapshot.
bool isEarnedBy(BadgeDefinition def, BadgeStats stats) =>
    statValue(stats, def.stat) >= def.target;

// ---------------------------------------------------------------------------
// Computation
// ---------------------------------------------------------------------------

/// Computes the requested stats from the local database.
///
/// [prCount] is passed in rather than queried so this stays decoupled from
/// [PersonalBestRepository], matching the existing contract of
/// `BadgeService.evaluateAll`. [bodyweightKg] comes from the profile, which
/// lives in `SharedPreferences` and not in the database at all; when it is
/// null the bodyweight ratio is reported as zero and its badges never award.
///
/// [only] restricts the work. Awarding runs after every logged set, so the
/// caller passes just the stats that still-unearned badges read — as badges
/// are earned the query load falls away to nothing. Passing null computes
/// everything, which is what the badges screen wants.
Future<BadgeStats> computeBadgeStats(
  AppDatabase db, {
  required int prCount,
  double? bodyweightKg,
  Set<BadgeStat>? only,
}) async {
  final stats = <BadgeStat, num>{};
  bool wants(BadgeStat s) => only == null || only.contains(s);
  bool wantsAny(Iterable<BadgeStat> s) => s.any(wants);

  if (wants(BadgeStat.prCount)) stats[BadgeStat.prCount] = prCount;

  // --- Scalar aggregates over the set and exercise tables ------------------
  //
  // Written as SQL rather than as twenty `selectOnly` builders: this is a
  // table of one-line aggregates, and the SQL says what each one is in a way
  // the builder chain does not. All of them are indexed COUNT/SUM scans.

  if (wants(BadgeStat.totalSets)) {
    stats[BadgeStat.totalSets] = await _scalar(
      db,
      'SELECT COUNT(*) AS v FROM workout_sets WHERE deleted_at IS NULL',
    );
  }

  if (wants(BadgeStat.totalVolumeKg)) {
    // weight x reps, the same definition as ProgressMetric.volume in
    // domain/progress_series.dart. The two must agree: a user comparing the
    // volume chart against this badge is comparing the same number.
    stats[BadgeStat.totalVolumeKg] = await _scalar(
      db,
      'SELECT COALESCE(SUM(weight * reps), 0) AS v '
      'FROM workout_sets WHERE deleted_at IS NULL',
    );
  }

  if (wants(BadgeStat.totalDistanceMetres)) {
    stats[BadgeStat.totalDistanceMetres] = await _scalar(
      db,
      'SELECT COALESCE(SUM(distance_metres), 0) AS v '
      'FROM workout_sets WHERE deleted_at IS NULL',
    );
  }

  if (wants(BadgeStat.distinctExercises)) {
    stats[BadgeStat.distinctExercises] = await _scalar(
      db,
      'SELECT COUNT(DISTINCT exercise_id) AS v '
      'FROM workout_sets WHERE deleted_at IS NULL',
    );
  }

  if (wants(BadgeStat.customExercises)) {
    stats[BadgeStat.customExercises] = await _scalar(
      db,
      'SELECT COUNT(*) AS v FROM exercises '
      'WHERE is_custom = 1 AND deleted_at IS NULL',
    );
  }

  if (wants(BadgeStat.splitsCreated)) {
    stats[BadgeStat.splitsCreated] = await _scalar(
      db,
      'SELECT COUNT(*) AS v FROM workout_splits WHERE deleted_at IS NULL',
    );
  }

  for (final entry in const {
    BadgeStat.cardioSets: ExerciseCategory.cardio,
    BadgeStat.mobilitySets: ExerciseCategory.mobility,
  }.entries) {
    if (!wants(entry.key)) continue;
    stats[entry.key] = await _scalar(
      db,
      'SELECT COUNT(*) AS v FROM workout_sets s '
      'JOIN exercises e ON e.id = s.exercise_id '
      'WHERE s.deleted_at IS NULL AND e.category = ?',
      [Variable<String>(entry.value.name)],
    );
  }

  if (wants(BadgeStat.maxRepsOneExerciseOneSession)) {
    // The most reps of a single exercise inside a single session — an
    // aggregate of an aggregate, so the grouping has to happen in a subquery.
    stats[BadgeStat.maxRepsOneExerciseOneSession] = await _scalar(
      db,
      'SELECT COALESCE(MAX(total), 0) AS v FROM ('
      '  SELECT SUM(reps) AS total FROM workout_sets '
      '  WHERE deleted_at IS NULL '
      '  GROUP BY session_id, exercise_id'
      ')',
    );
  }

  if (wants(BadgeStat.muscleGroupsTrained)) {
    stats[BadgeStat.muscleGroupsTrained] = await _muscleGroupsTrained(db);
  }

  if (wants(BadgeStat.bestBigLiftBodyweightRatio)) {
    stats[BadgeStat.bestBigLiftBodyweightRatio] = await _bestBigLiftRatio(
      db,
      bodyweightKg,
    );
  }

  // --- Everything derived from the session timeline ------------------------
  //
  // Seven stats, one fetch. Streaks, weekly counts, gaps and time-of-day are
  // all folds over the same ordered list of session start times, and reading
  // that list once is cheaper than seven date-range queries.
  const sessionDerived = {
    BadgeStat.completedSessions,
    BadgeStat.currentStreakDays,
    BadgeStat.longestSessionMinutes,
    BadgeStat.maxSessionsInWeek,
    BadgeStat.earlyMorningSessions,
    BadgeStat.lateNightSessions,
    BadgeStat.weekendPairs,
    BadgeStat.comebackReturns,
    BadgeStat.sessionsWithNotes,
  };
  if (wantsAny(sessionDerived)) {
    final sessions =
        await (db.select(db.workoutSessions)
              ..where((s) => s.deletedAt.isNull())
              ..where((s) => s.endTime.isNotNull())
              ..orderBy([(s) => OrderingTerm.asc(s.startTime)]))
            .get();

    stats.addAll(sessionTimelineStats(sessions));
  }

  return stats;
}

/// The stats that fall out of the session timeline.
///
/// Pure over plain rows and separated from the query so the date arithmetic —
/// the part with the edge cases — is testable without a database.
/// [sessions] must be completed sessions ordered by [startTime] ascending.
BadgeStats sessionTimelineStats(List<WorkoutSession> sessions) {
  final stats = <BadgeStat, num>{
    BadgeStat.completedSessions: sessions.length,
    BadgeStat.currentStreakDays: 0,
    BadgeStat.longestSessionMinutes: 0,
    BadgeStat.maxSessionsInWeek: 0,
    BadgeStat.earlyMorningSessions: 0,
    BadgeStat.lateNightSessions: 0,
    BadgeStat.weekendPairs: 0,
    BadgeStat.comebackReturns: 0,
    BadgeStat.sessionsWithNotes: 0,
  };
  if (sessions.isEmpty) return stats;

  DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

  final days = <DateTime>{};
  final perWeek = <DateTime, int>{};
  var early = 0;
  var late = 0;
  var longest = 0;
  var comebacks = 0;
  var noted = 0;
  DateTime? previousDay;

  for (final session in sessions) {
    final start = session.startTime;
    final day = dayOf(start);
    days.add(day);

    if (start.hour < 6) early++;
    if (start.hour >= 22) late++;

    // Whitespace is not a note. `showSessionNoteDialog` distinguishes a
    // cleared note from a cancelled edit, so an empty string can reach the
    // column.
    if ((session.sessionNote ?? '').trim().isNotEmpty) noted++;

    final end = session.endTime;
    if (end != null) {
      final minutes = end.difference(start).inMinutes;
      if (minutes > longest) longest = minutes;
    }

    // Monday-aligned week, matching getWeeklyStreak and the attendance
    // heatmap in progress_screen.dart.
    final monday = day.subtract(Duration(days: day.weekday - 1));
    perWeek[monday] = (perWeek[monday] ?? 0) + 1;

    // A return only counts once per break, so this compares against the
    // previous *day* trained rather than the previous session — several
    // sessions on the comeback day are one comeback.
    if (previousDay != null &&
        day != previousDay &&
        day.difference(previousDay).inDays >= kComebackGap.inDays) {
      comebacks++;
    }
    previousDay = day;
  }

  // Consecutive calendar days ending today. A calendar-day streak, not a
  // 24-hour rolling window: training at 11pm and again at 6am is two days,
  // which is what every mainstream fitness app means by a streak.
  final today = dayOf(DateTime.now());
  var streak = 0;
  while (days.contains(today.subtract(Duration(days: streak)))) {
    streak++;
  }

  // Both days of one weekend. Saturday is the anchor; the Sunday two days
  // either side of a different weekend must not pair with it.
  var weekendPairs = 0;
  for (final day in days) {
    if (day.weekday == DateTime.saturday &&
        days.contains(day.add(const Duration(days: 1)))) {
      weekendPairs++;
    }
  }

  stats[BadgeStat.currentStreakDays] = streak;
  stats[BadgeStat.longestSessionMinutes] = longest;
  stats[BadgeStat.maxSessionsInWeek] = perWeek.values.fold<int>(
    0,
    (best, n) => n > best ? n : best,
  );
  stats[BadgeStat.earlyMorningSessions] = early;
  stats[BadgeStat.lateNightSessions] = late;
  stats[BadgeStat.weekendPairs] = weekendPairs;
  stats[BadgeStat.comebackReturns] = comebacks;
  stats[BadgeStat.sessionsWithNotes] = noted;
  return stats;
}

/// How many of the six [MuscleGroup]s have ever been trained.
///
/// Counted through each exercise's *primary* muscle only. A bench press
/// brushing the triceps should not tick off Arms — the badge asks whether you
/// have trained a group, not whether a group has been involved.
///
/// The group is derived in Dart because it is deliberately not stored:
/// `exercise_muscles.muscle` holds the muscle, and group is functionally
/// dependent on it (see the note on the `ExerciseMuscles` table).
Future<int> _muscleGroupsTrained(AppDatabase db) async {
  final rows = await db
      .customSelect(
        'SELECT DISTINCT em.muscle AS muscle FROM workout_sets s '
        'JOIN exercise_muscles em ON em.exercise_id = s.exercise_id '
        'WHERE s.deleted_at IS NULL AND em.is_primary = 1',
        readsFrom: {db.workoutSets, db.exerciseMuscles},
      )
      .get();

  final groups = <MuscleGroup>{};
  for (final row in rows) {
    final muscle = Muscle.byNameOrNull(row.read<String?>('muscle'));
    if (muscle != null) groups.add(muscle.group);
  }
  return groups.length;
}

/// The heaviest barbell lift logged, as a multiple of the user's bodyweight.
///
/// Restricted to the lifts [hasStrengthStandards] recognises. "Lift your own
/// bodyweight" is a claim about a barbell, and a leg press at bodyweight is
/// not the same claim — the app already knows which exercises are comparable,
/// so the badge borrows that judgement rather than inventing a second one.
///
/// Zero when the profile has no bodyweight: an unanswerable question is not
/// an achievement, so the badge stays locked rather than guessing.
Future<double> _bestBigLiftRatio(AppDatabase db, double? bodyweightKg) async {
  if (bodyweightKg == null || bodyweightKg <= 0) return 0;

  final rows = await db
      .customSelect(
        'SELECT e.name AS name, MAX(s.weight) AS best FROM workout_sets s '
        'JOIN exercises e ON e.id = s.exercise_id '
        'WHERE s.deleted_at IS NULL AND s.reps >= 1 AND s.weight > 0 '
        'GROUP BY e.name',
        readsFrom: {db.workoutSets, db.exercises},
      )
      .get();

  var best = 0.0;
  for (final row in rows) {
    final name = row.read<String>('name');
    if (!hasStrengthStandards(name)) continue;
    // MAX over a REAL column, but SQLite is free to hand back an int for a
    // whole-number weight — read the raw value for the same reason _scalar
    // does.
    final weight = row.data['best'];
    if (weight is num && weight > best) best = weight.toDouble();
  }
  return best / bodyweightKg;
}

/// Runs a single-column aggregate and reads it as a number.
///
/// Read from the raw row rather than through `QueryRow.read<T>`, which needs
/// one concrete Dart type and these queries do not have one: `COUNT` comes
/// back an int, `SUM` over a REAL column a double, and `SUM` over an empty
/// table a null that `COALESCE` has already turned into an int zero.
Future<num> _scalar(
  AppDatabase db,
  String sql, [
  List<Variable> variables = const [],
]) async {
  final row = await db.customSelect(sql, variables: variables).getSingle();
  final value = row.data['v'];
  return value is num ? value : 0;
}

// ---------------------------------------------------------------------------
// Awarding
// ---------------------------------------------------------------------------
//
// Awarding lives here, beside the criteria it reads, rather than in
// `BadgeService`. Both callers need it: the service evaluates after a set is
// logged, and the badges screen reconciles whatever it finds when it computes
// progress. Sharing one implementation is what keeps them from disagreeing.

/// The definitions with no row yet, or a row that has never been earned.
///
/// A definition with no row at all is included: it will fail to award, but
/// silently dropping it here would hide the real fault, which is a missed seed
/// after adding a badge.
Future<List<BadgeDefinition>> unearnedBadges(AppDatabase db) async {
  final rows = await (db.select(
    db.badges,
  )..where((b) => b.earnedAt.isNotNull())).get();

  final earnedKeys = {for (final row in rows) row.badgeKey};
  return [
    for (final def in kAllBadges)
      if (!earnedKeys.contains(def.key)) def,
  ];
}

/// Stamps `earnedAt` on every unearned badge whose criterion [stats] already
/// meets, and returns the keys awarded.
///
/// [candidates] is the unearned set when the caller has already computed it;
/// omitting it costs one query.
Future<List<String>> awardEarnedBadges(
  AppDatabase db,
  BadgeStats stats, {
  List<BadgeDefinition>? candidates,
}) async {
  final awarded = <String>[];
  for (final def in candidates ?? await unearnedBadges(db)) {
    if (!isEarnedBy(def, stats)) continue;
    if (await _awardIfNotEarned(db, def.key)) awarded.add(def.key);
  }
  return awarded;
}

/// Stamps `earnedAt` on a badge row unless it is already earned. Returns
/// whether a new award was actually written, so a repeated evaluation cannot
/// celebrate the same badge twice.
Future<bool> _awardIfNotEarned(AppDatabase db, String key) async {
  final row = await (db.select(
    db.badges,
  )..where((b) => b.badgeKey.equals(key))).getSingleOrNull();

  if (row == null || row.earnedAt != null) return false;

  await (db.update(db.badges)..where((b) => b.badgeKey.equals(key))).write(
    BadgesCompanion(
      earnedAt: Value(DateTime.now()),
      // Mark dirty for sync — the same pattern as every other syncable table.
      syncedAt: const Value(null),
    ),
  );
  return true;
}

/// Awards what [stats] has earned and queues the celebrations for it.
///
/// The one entry point both callers use — the service after a set is logged,
/// and the progress stream when the badges screen reconciles — so awarding,
/// the unlock celebration and the rank-up cannot come apart from each other.
Future<List<String>> awardAndCelebrate(
  Ref ref,
  AppDatabase db,
  BadgeStats stats, {
  List<BadgeDefinition>? candidates,
}) async {
  final unearned = candidates ?? await unearnedBadges(db);
  final awarded = await awardEarnedBadges(db, stats, candidates: unearned);
  if (awarded.isEmpty) return awarded;

  ref.read(badgeUnlockQueueProvider.notifier).enqueue(awarded);

  // A rank is a summary of the badges held, so it can only ever move when
  // badges are awarded — worked out here from what just changed rather than
  // watched, so the user is told about it instead of finding a header reading
  // differently the next time they look.
  final stillLocked = {for (final def in unearned) def.key};
  final heldBefore = [
    for (final def in kAllBadges)
      if (!stillLocked.contains(def.key)) def.tier,
  ];
  final justEarned = awarded.toSet();
  final heldAfter = [
    ...heldBefore,
    for (final def in unearned)
      if (justEarned.contains(def.key)) def.tier,
  ];

  final climbedTo = rankForPoints(rankPointsOf(heldAfter));
  if (climbedTo != rankForPoints(rankPointsOf(heldBefore))) {
    ref.read(rankUpQueueProvider.notifier).announce(climbedTo);
  }

  return awarded;
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// The full stats snapshot, for the badges screen.
///
/// A stream rather than a future because the badges screen lives inside the
/// home screen's `IndexedStack` and is therefore built once and never
/// disposed — a one-shot future would show the numbers as they stood when the
/// app launched. The trivial query exists only for its `readsFrom` set: drift
/// re-emits when any of those tables is written, which is exactly when a stat
/// can have moved.
@riverpod
Stream<BadgeStats> badgeProgress(Ref ref) {
  final db = ref.watch(databaseProvider);

  return db
      .customSelect(
        // The literal is a name, not decoration. Drift caches query streams
        // on the SQL text and its variables, so two watchers sharing a query
        // string share one stream — and one `readsFrom`, whichever registered
        // first. Four providers here all used 'SELECT 1 AS v', so they
        // collapsed into a single stream that only woke for the tables the
        // winner happened to declare. Writes to the others were never
        // announced; the screen refreshed roughly every thirty seconds,
        // whenever the background sync touched a table that was on the list.
        "SELECT 'badge_progress' AS watcher",
        readsFrom: {
          db.workoutSets,
          db.workoutSessions,
          db.exercises,
          db.workoutSplits,
          db.badges,
        },
      )
      .watch()
      .asyncMap((_) async {
        final prCount = await ref
            .read(personalBestRepositoryProvider.notifier)
            .getTotalPrCount();
        final profile = await ref.read(profileNotifierProvider.future);

        final stats = await computeBadgeStats(
          db,
          prCount: prCount,
          bodyweightKg: profile.bodyweightKg,
        );

        // Awarding is event-driven — it runs when a set is logged and when a
        // session ends — but progress is derived from state, so the two drift
        // apart. A criterion that came true any other way (the catalogue
        // growing on an upgrade, a note written, a split built) left the badge
        // locked while this very snapshot showed it at 100%, which is how the
        // "Next up" list ended up recommending a badge that was already done.
        // Reconciling here means reading progress also settles the awards.
        await awardAndCelebrate(ref, db, stats);

        return stats;
      });
}
