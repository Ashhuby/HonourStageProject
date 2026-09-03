/// What actually happened in a workout session.
///
/// The obvious way to answer "how many PRs did I hit that day" is to look for
/// `PersonalBests` rows whose `achievedAt` falls inside the session. That is
/// wrong, and quietly so: the table holds **one row per record key**,
/// overwritten the moment it is beaten. A bench PR from March disappears from
/// it in April, so the number shown against March's session would silently
/// shrink as the user kept training. There is no link from a record back to
/// the set or session that earned it.
///
/// So this replays instead. Walking every set forward in time and keeping a
/// running best per key answers "was this a PR *when it happened*", which is
/// the question being asked, and answers it identically for a session from
/// last year and one from this morning. The same pass yields first-time
/// exercises for free — the earliest set for each exercise.
///
/// Pure functions over plain records, so none of this needs a database.
library;

import '../data/personal_best_repository.dart';
import 'distance_bucket.dart';

/// One logged set, joined to the context the replay needs.
///
/// Deliberately not `WorkoutSet`: keeping this a plain record makes the fold
/// testable without Drift, and makes explicit that the exercise's metric type
/// — which lives on another table — has to be joined in.
typedef LoggedSet = ({
  int sessionId,
  int exerciseId,
  String exerciseName,
  String metricType,
  DateTime timestamp,
  double weight,
  int reps,
  int? durationSeconds,
  double? distanceMetres,
});

/// A session, reduced to the window a badge can be attributed to.
typedef SessionWindow = ({
  int sessionId,
  DateTime startTime,
  DateTime? endTime,
});

/// A badge the user has earned, and when.
typedef EarnedBadge = ({String badgeKey, DateTime earnedAt});

/// Badges a session can be credited with.
///
/// `first_custom_exercise` is earned by an act of curation rather than of
/// training — the editor evaluates badges when an exercise is created, which
/// can happen mid-workout from the picker. Excluding it by name is honest;
/// excluding it by timing would be luck.
const Set<String> kSessionAttributableBadges = {
  'first_workout',
  'streak_7_day',
  'streak_30_day',
  'first_pr',
  'pr_10',
  'sets_50',
  'sets_500',
  'first_cardio',
  'first_mobility',
  'marathon_distance',
};

/// How long after a session ends a badge may still belong to it.
///
/// `endSession` writes `endTime` and *then* evaluates badges, and each
/// evaluation is several SQL round trips — so `first_workout`, the streaks and
/// the set-count badges are all stamped a moment after the session's own
/// `endTime`. Without this grace the attribution would miss precisely the
/// badges most worth showing.
///
/// Generous enough for a thirty-day streak scan on a slow phone, far shorter
/// than any real gap between workouts.
const Duration kBadgeAttributionGrace = Duration(seconds: 30);

/// The notable things about one session.
class SessionHighlights {
  const SessionHighlights({
    this.prCount = 0,
    this.firstTimeExercises = const [],
    this.badgeKeys = const [],
  });

  /// Sets that beat every comparable set logged before them.
  final int prCount;

  /// Exercises whose earliest logged set falls in this session, in log order.
  final List<String> firstTimeExercises;

  /// App badges earned during the session.
  final List<String> badgeKeys;

  bool get isEmpty =>
      prCount == 0 && firstTimeExercises.isEmpty && badgeKeys.isEmpty;
}

/// Replays every logged set and reports what each session achieved.
///
/// [setsOldestFirst] must be every non-deleted set from every non-deleted
/// session, ordered by timestamp — the same population
/// `recalculateForExercise` rebuilds records from, **including sessions still
/// in progress**, because `logSet` awards records immediately and those
/// records are real. Filtering to completed sessions belongs in the rendering,
/// not here; doing it here would let these verdicts drift from the records
/// table.
Map<int, SessionHighlights> replaySessionHighlights({
  required List<LoggedSet> setsOldestFirst,
  required List<SessionWindow> sessionsByStartTime,
  required List<EarnedBadge> earnedBadges,
}) {
  final prCounts = <int, int>{};
  final firsts = <int, List<String>>{};

  final best = <(int, double), PbRecord>{};
  final seenExercises = <int>{};

  for (final set in setsOldestFirst) {
    if (seenExercises.add(set.exerciseId)) {
      (firsts[set.sessionId] ??= []).add(set.exerciseName);
    }

    // Distance records are filed under standard buckets, so a run shorter than
    // the smallest earns nothing — the same rule live logging applies.
    final double? bucket = set.metricType == 'distanceTime'
        ? distanceBucketFor(set.distanceMetres ?? 0.0)
        : 0.0;
    if (bucket == null) continue;

    // The key deliberately omits the metric type, even though the records
    // table's unique key includes it. Metric type lives on the exercise and
    // the user can change it, and `recalculateForExercise` replays all of an
    // exercise's history under whatever it is *now* — so keying on it here
    // would keep two parallel bests for a changed exercise and disagree with
    // the rebuilt table.
    final key = (set.exerciseId, bucket);

    final candidate = PbRecord(
      weight: set.weight,
      reps: set.reps,
      durationSeconds: set.durationSeconds,
      distanceMetres: bucket,
      achievedAt: set.timestamp,
    );

    final current = best[key];
    if (current == null || setBeats(candidate, current, set.metricType)) {
      best[key] = candidate;
      prCounts[set.sessionId] = (prCounts[set.sessionId] ?? 0) + 1;
    }
  }

  final badges = _attributeBadges(sessionsByStartTime, earnedBadges);

  final sessionIds = {...prCounts.keys, ...firsts.keys, ...badges.keys};
  return {
    for (final id in sessionIds)
      id: SessionHighlights(
        prCount: prCounts[id] ?? 0,
        firstTimeExercises: firsts[id] ?? const [],
        badgeKeys: badges[id] ?? const [],
      ),
  };
}

/// Assigns each badge to the session it was most likely earned in.
///
/// A badge belongs to the latest session that had already started when it was
/// stamped, provided it was stamped no later than that session's end plus
/// [kBadgeAttributionGrace]. "Latest session started before it" needs no
/// tolerance at the front; the grace only absorbs the write-ordering lag at
/// the back, and the upper bound is what stops a badge earned days later being
/// pinned to the last workout.
Map<int, List<String>> _attributeBadges(
  List<SessionWindow> sessionsByStartTime,
  List<EarnedBadge> earnedBadges,
) {
  final bySession = <int, List<String>>{};
  if (sessionsByStartTime.isEmpty) return bySession;

  for (final badge in earnedBadges) {
    if (!kSessionAttributableBadges.contains(badge.badgeKey)) continue;

    SessionWindow? candidate;
    for (final session in sessionsByStartTime) {
      if (!session.startTime.isAfter(badge.earnedAt)) {
        candidate = session;
      } else {
        break;
      }
    }
    if (candidate == null) continue;

    final closed = candidate.endTime;
    if (closed != null &&
        badge.earnedAt.isAfter(closed.add(kBadgeAttributionGrace))) {
      continue;
    }
    (bySession[candidate.sessionId] ??= []).add(badge.badgeKey);
  }
  return bySession;
}
