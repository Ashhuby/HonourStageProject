import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/features/workout/domain/distance_bucket.dart';
import 'package:fitness_app/features/workout/domain/session_highlights.dart';

/// Tests the session-history replay.
///
/// The thesis of the whole design is the first test in this file: a set that
/// was a personal best when it happened must still be reported as one after a
/// later session beats it. The obvious implementation — counting
/// `PersonalBests` rows whose `achievedAt` falls in the session — fails it,
/// because that table keeps one row per key and overwrites it.
void main() {
  var clock = DateTime(2026, 3, 1, 9);

  LoggedSet set({
    required int sessionId,
    int exerciseId = 1,
    String exerciseName = 'Bench Press',
    String metricType = 'weightReps',
    DateTime? at,
    double weight = 0,
    int reps = 0,
    int? durationSeconds,
    double? distanceMetres,
  }) {
    clock = clock.add(const Duration(minutes: 3));
    return (
      sessionId: sessionId,
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      metricType: metricType,
      timestamp: at ?? clock,
      weight: weight,
      reps: reps,
      durationSeconds: durationSeconds,
      distanceMetres: distanceMetres,
    );
  }

  Map<int, SessionHighlights> replay(
    List<LoggedSet> sets, {
    List<SessionWindow> sessions = const [],
    List<EarnedBadge> badges = const [],
  }) => replaySessionHighlights(
    setsOldestFirst: sets,
    sessionsByStartTime: sessions,
    earnedBadges: badges,
  );

  // ---------------------------------------------------------------------------
  // Personal bests, judged at the time
  // ---------------------------------------------------------------------------

  group('personal bests', () {
    test('an earlier PR is still a PR after a later one beats it', () {
      // The case a timestamp window gets wrong. In April the records table
      // holds only the 105kg row, so March's session would report zero.
      final result = replay([
        set(sessionId: 1, weight: 100, reps: 5),
        set(sessionId: 2, weight: 105, reps: 5),
      ]);

      expect(result[1]!.prCount, 1);
      expect(result[2]!.prCount, 1);
    });

    test('the first set of an exercise is always a record', () {
      expect(replay([set(sessionId: 1, weight: 60, reps: 8)])[1]!.prCount, 1);
    });

    test('a lighter or equal set is not a record', () {
      final result = replay([
        set(sessionId: 1, weight: 100, reps: 5),
        set(sessionId: 2, weight: 95, reps: 12),
        set(sessionId: 3, weight: 100, reps: 5),
      ]);

      expect(result[1]!.prCount, 1);
      expect(result[2]?.prCount ?? 0, 0);
      expect(result[3]?.prCount ?? 0, 0);
    });

    test('more reps at the same weight is a record', () {
      final result = replay([
        set(sessionId: 1, weight: 100, reps: 5),
        set(sessionId: 2, weight: 100, reps: 6),
      ]);

      expect(result[2]!.prCount, 1);
    });

    test('several records in one session all count', () {
      final result = replay([
        set(sessionId: 1, weight: 100, reps: 5),
        set(sessionId: 1, weight: 105, reps: 5),
        set(sessionId: 1, weight: 110, reps: 5),
      ]);

      expect(result[1]!.prCount, 3);
    });

    test('exercises are judged independently', () {
      final result = replay([
        set(sessionId: 1, weight: 100, reps: 5),
        set(
          sessionId: 1,
          exerciseId: 2,
          exerciseName: 'Squat',
          weight: 60,
          reps: 5,
        ),
      ]);

      expect(result[1]!.prCount, 2);
    });
  });

  group('bodyweight sets', () {
    test('weighted and unweighted each win their own contest', () {
      // Both share one record slot, judged under different rules depending on
      // which is challenging — the routing live logging does, reproduced by a
      // single running best.
      final result = replay([
        set(sessionId: 1, metricType: 'bodyweightReps', reps: 10),
        set(sessionId: 2, metricType: 'bodyweightReps', weight: 20, reps: 5),
        set(sessionId: 3, metricType: 'bodyweightReps', reps: 12),
      ]);

      expect(result[1]!.prCount, 1);
      expect(result[2]!.prCount, 1);
      expect(result[3]!.prCount, 1);
    });

    test('fewer unweighted reps than the standing best is not a record', () {
      final result = replay([
        set(sessionId: 1, metricType: 'bodyweightReps', reps: 12),
        set(sessionId: 2, metricType: 'bodyweightReps', reps: 11),
      ]);

      expect(result[2]?.prCount ?? 0, 0);
    });
  });

  group('distance and time', () {
    test('the same bucket at a slower time is not a record', () {
      // 5000m then 5200m is the same 5K twice. Keyed on the raw distance the
      // second would find no standing record and count as a PR.
      final result = replay([
        set(
          sessionId: 1,
          metricType: 'distanceTime',
          distanceMetres: 5000,
          durationSeconds: 1500,
        ),
        set(
          sessionId: 2,
          metricType: 'distanceTime',
          distanceMetres: 5200,
          durationSeconds: 1600,
        ),
      ]);

      expect(result[1]!.prCount, 1);
      expect(result[2]?.prCount ?? 0, 0);
    });

    test('a faster time over the same bucket is a record', () {
      final result = replay([
        set(
          sessionId: 1,
          metricType: 'distanceTime',
          distanceMetres: 5000,
          durationSeconds: 1500,
        ),
        set(
          sessionId: 2,
          metricType: 'distanceTime',
          distanceMetres: 5000,
          durationSeconds: 1440,
        ),
      ]);

      expect(result[2]!.prCount, 1);
    });

    test('a different bucket earns its own record', () {
      final result = replay([
        set(
          sessionId: 1,
          metricType: 'distanceTime',
          distanceMetres: 5000,
          durationSeconds: 1500,
        ),
        set(
          sessionId: 2,
          metricType: 'distanceTime',
          distanceMetres: 10000,
          durationSeconds: 3300,
        ),
      ]);

      expect(result[2]!.prCount, 1);
    });

    test('an effort below the smallest standard distance earns nothing', () {
      // Asserted against distanceBucketFor rather than a hand-written number,
      // so the two cannot drift apart.
      expect(distanceBucketFor(60), isNull);

      final result = replay([
        set(
          sessionId: 1,
          metricType: 'distanceTime',
          distanceMetres: 60,
          durationSeconds: 12,
        ),
      ]);

      expect(result[1]?.prCount ?? 0, 0);
    });
  });

  group('timed holds', () {
    test('a longer hold is a record', () {
      final result = replay([
        set(sessionId: 1, metricType: 'timeOnly', durationSeconds: 60),
        set(sessionId: 2, metricType: 'timeOnly', durationSeconds: 90),
        set(sessionId: 3, metricType: 'timeOnly', durationSeconds: 75),
      ]);

      expect(result[1]!.prCount, 1);
      expect(result[2]!.prCount, 1);
      expect(result[3]?.prCount ?? 0, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // First-time exercises
  // ---------------------------------------------------------------------------

  group('first-time exercises', () {
    test('only the session that introduced an exercise reports it', () {
      final result = replay([
        set(sessionId: 1, weight: 60, reps: 8),
        set(sessionId: 3, weight: 70, reps: 8),
      ]);

      expect(result[1]!.firstTimeExercises, ['Bench Press']);
      expect(result[3]!.firstTimeExercises, isEmpty);
    });

    test('several new exercises are listed in the order they were logged', () {
      final result = replay([
        set(sessionId: 1, exerciseId: 2, exerciseName: 'Squat', weight: 60),
        set(
          sessionId: 1,
          exerciseId: 1,
          exerciseName: 'Bench Press',
          weight: 60,
        ),
      ]);

      expect(result[1]!.firstTimeExercises, ['Squat', 'Bench Press']);
    });

    test('a repeat inside the same session is listed once', () {
      final result = replay([
        set(sessionId: 1, weight: 60, reps: 8),
        set(sessionId: 1, weight: 65, reps: 8),
      ]);

      expect(result[1]!.firstTimeExercises, ['Bench Press']);
    });
  });

  // ---------------------------------------------------------------------------
  // Badges
  // ---------------------------------------------------------------------------

  group('badge attribution', () {
    final start = DateTime(2026, 3, 1, 9);
    final end = DateTime(2026, 3, 1, 10);
    final window = (sessionId: 1, startTime: start, endTime: end);

    test('a badge stamped just after the session still belongs to it', () {
      // endSession writes endTime and *then* evaluates badges, so the
      // session-completion badges always land after their own session ends.
      final result = replay(
        [],
        sessions: [window],
        badges: [
          (
            badgeKey: 'first_workout',
            earnedAt: end.add(const Duration(milliseconds: 40)),
          ),
        ],
      );

      expect(result[1]!.badgeKeys, ['first_workout']);
    });

    test('a badge earned days later is not attributed', () {
      final result = replay(
        [],
        sessions: [window],
        badges: [
          (badgeKey: 'pr_10', earnedAt: end.add(const Duration(days: 2))),
        ],
      );

      expect(result[1]?.badgeKeys ?? const [], isEmpty);
    });

    test('a badge goes to the session running at the time', () {
      final later = (
        sessionId: 2,
        startTime: DateTime(2026, 3, 3, 9),
        endTime: DateTime(2026, 3, 3, 10),
      );
      final result = replay(
        [],
        sessions: [window, later],
        badges: [
          (badgeKey: 'first_cardio', earnedAt: DateTime(2026, 3, 3, 9, 30)),
        ],
      );

      expect(result[2]!.badgeKeys, ['first_cardio']);
      expect(result[1]?.badgeKeys ?? const [], isEmpty);
    });

    test('a badge earned before any session belongs to none', () {
      final result = replay(
        [],
        sessions: [window],
        badges: [(badgeKey: 'first_workout', earnedAt: DateTime(2026, 2, 1))],
      );

      expect(result, isEmpty);
    });

    test('creating a custom exercise is not a workout achievement', () {
      // It is earned by curating the library, and the editor evaluates badges
      // — so it can land mid-session and would otherwise be miscredited.
      final result = replay(
        [],
        sessions: [window],
        badges: [
          (
            badgeKey: 'first_custom_exercise',
            earnedAt: DateTime(2026, 3, 1, 9, 30),
          ),
        ],
      );

      expect(result[1]?.badgeKeys ?? const [], isEmpty);
    });

    test('an unfinished session has no upper bound to fall outside', () {
      final open = (sessionId: 9, startTime: start, endTime: null);
      final result = replay(
        [],
        sessions: [open],
        badges: [
          (
            badgeKey: 'first_pr',
            earnedAt: start.add(const Duration(minutes: 5)),
          ),
        ],
      );

      expect(result[9]!.badgeKeys, ['first_pr']);
    });
  });

  // ---------------------------------------------------------------------------
  // Edges
  // ---------------------------------------------------------------------------

  test('an empty history yields an empty map rather than throwing', () {
    expect(replay([]), isEmpty);
  });

  test('a session with nothing notable is absent from the map', () {
    // The UI shows no chips at all for such a session, rather than an empty
    // chip row.
    final result = replay([
      set(sessionId: 1, weight: 100, reps: 5),
      set(sessionId: 2, weight: 90, reps: 5),
    ]);

    expect(result.containsKey(2), isFalse);
  });
}
