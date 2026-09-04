import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/core/database/local_database.dart';
import 'package:fitness_app/features/workout/data/badge_stats.dart';
import 'package:fitness_app/features/workout/domain/activity.dart';
import 'package:fitness_app/features/workout/domain/badge_catalogue.dart';
import 'package:fitness_app/features/workout/domain/muscle.dart';

/// Tests the counters every badge is measured against.
///
/// This is where the criteria are actually proven. [computeBadgeStats] takes
/// an [AppDatabase] rather than a `Ref`, so the whole criterion layer can be
/// exercised against real SQL on an in-memory database — the previous badge
/// tests had to reimplement the award logic inline because [BadgeService]
/// needed a Riverpod container, which meant they proved the test's own queries
/// rather than the app's.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  // ---------------------------------------------------------------------------
  // Fixtures
  // ---------------------------------------------------------------------------

  Future<int> addExercise(
    String name, {
    ExerciseCategory category = ExerciseCategory.strength,
    CardioModality? modality,
    Muscle primary = Muscle.quads,
    bool isCustom = false,
  }) async {
    final id = await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            name: name,
            bodyPart: primary.group.label,
            equipmentType: 'Barbell',
            isCustom: Value(isCustom),
            category: Value(category.name),
            modality: Value(modality?.name),
          ),
        );
    await db
        .into(db.exerciseMuscles)
        .insert(
          ExerciseMusclesCompanion.insert(
            exerciseId: id,
            muscle: primary.name,
            isPrimary: const Value(true),
          ),
        );
    return id;
  }

  Future<int> addSession(
    DateTime start, {
    Duration length = const Duration(hours: 1),
    String? note,
    bool completed = true,
  }) {
    return db
        .into(db.workoutSessions)
        .insert(
          WorkoutSessionsCompanion.insert(
            startTime: start,
            endTime: Value(completed ? start.add(length) : null),
            sessionNote: Value(note),
          ),
        );
  }

  Future<void> addSet(
    int sessionId,
    int exerciseId, {
    double weight = 0,
    int reps = 0,
    double? distanceMetres,
    bool deleted = false,
  }) async {
    await db
        .into(db.workoutSets)
        .insert(
          WorkoutSetsCompanion.insert(
            sessionId: sessionId,
            exerciseId: exerciseId,
            weight: Value(weight),
            reps: Value(reps),
            distanceMetres: Value(distanceMetres),
            deletedAt: Value(deleted ? DateTime.now() : null),
          ),
        );
  }

  Future<BadgeStats> stats({int prCount = 0, double? bodyweightKg}) {
    return computeBadgeStats(db, prCount: prCount, bodyweightKg: bodyweightKg);
  }

  DateTime daysAgo(int n) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day - n, 12);
  }

  // ---------------------------------------------------------------------------
  // Volume, sets and distance
  // ---------------------------------------------------------------------------

  group('set totals', () {
    test('volume is weight times reps, summed', () async {
      final squat = await addExercise('Squat');
      final session = await addSession(daysAgo(0));
      await addSet(session, squat, weight: 100, reps: 5);
      await addSet(session, squat, weight: 60, reps: 10);

      final s = await stats();
      expect(statValue(s, BadgeStat.totalVolumeKg), 1100);
      expect(statValue(s, BadgeStat.totalSets), 2);
    });

    test('a soft-deleted set counts towards nothing', () async {
      final squat = await addExercise('Squat');
      final session = await addSession(daysAgo(0));
      await addSet(session, squat, weight: 100, reps: 5);
      await addSet(session, squat, weight: 100, reps: 5, deleted: true);

      final s = await stats();
      expect(statValue(s, BadgeStat.totalSets), 1);
      expect(statValue(s, BadgeStat.totalVolumeKg), 500);
    });

    test('distance accumulates across cardio sets', () async {
      final run = await addExercise(
        'Running',
        category: ExerciseCategory.cardio,
        modality: CardioModality.run,
      );
      final session = await addSession(daysAgo(0));
      await addSet(session, run, distanceMetres: 5000);
      await addSet(session, run, distanceMetres: 7000);

      final s = await stats();
      expect(statValue(s, BadgeStat.totalDistanceMetres), 12000);
      expect(statValue(s, BadgeStat.cardioSets), 2);
      expect(statValue(s, BadgeStat.mobilitySets), 0);
    });

    test('an empty database reports zero, not null', () async {
      final s = await stats();
      for (final stat in BadgeStat.values) {
        expect(statValue(s, stat), 0, reason: '${stat.name} should be zero');
      }
    });

    test('reps of one exercise are counted per session, not overall', () async {
      final pushUp = await addExercise('Push Up');
      final first = await addSession(daysAgo(1));
      final second = await addSession(daysAgo(0));
      // 60 + 60 across two sessions is not a century; 40 + 70 in one is.
      await addSet(first, pushUp, reps: 60);
      await addSet(second, pushUp, reps: 40);
      await addSet(second, pushUp, reps: 70);

      final s = await stats();
      expect(statValue(s, BadgeStat.maxRepsOneExerciseOneSession), 110);
    });
  });

  // ---------------------------------------------------------------------------
  // The session timeline
  // ---------------------------------------------------------------------------

  group('session timeline', () {
    test('a streak counts consecutive calendar days ending today', () async {
      for (var i = 0; i < 4; i++) {
        await addSession(daysAgo(i));
      }
      final s = await stats();
      expect(statValue(s, BadgeStat.currentStreakDays), 4);
      expect(statValue(s, BadgeStat.completedSessions), 4);
    });

    test('a gap breaks the streak even with sessions behind it', () async {
      await addSession(daysAgo(0));
      // Nothing yesterday.
      for (var i = 2; i < 10; i++) {
        await addSession(daysAgo(i));
      }
      final s = await stats();
      expect(statValue(s, BadgeStat.currentStreakDays), 1);
    });

    test('two sessions in one day are one day of streak', () async {
      await addSession(daysAgo(0));
      await addSession(daysAgo(0).add(const Duration(hours: 4)));
      final s = await stats();
      expect(statValue(s, BadgeStat.currentStreakDays), 1);
      expect(statValue(s, BadgeStat.completedSessions), 2);
    });

    test('an in-progress session counts towards nothing', () async {
      await addSession(daysAgo(0), completed: false);
      final s = await stats();
      expect(statValue(s, BadgeStat.completedSessions), 0);
      expect(statValue(s, BadgeStat.currentStreakDays), 0);
    });

    test('the longest session is reported in minutes', () async {
      await addSession(daysAgo(2), length: const Duration(minutes: 45));
      await addSession(daysAgo(1), length: const Duration(minutes: 95));
      final s = await stats();
      expect(statValue(s, BadgeStat.longestSessionMinutes), 95);
    });

    test('time of day is read from the session start', () async {
      final base = daysAgo(3);
      await addSession(DateTime(base.year, base.month, base.day, 5, 30));
      await addSession(DateTime(base.year, base.month, base.day, 23, 10));
      await addSession(DateTime(base.year, base.month, base.day, 13));

      final s = await stats();
      expect(statValue(s, BadgeStat.earlyMorningSessions), 1);
      expect(statValue(s, BadgeStat.lateNightSessions), 1);
    });

    test('a weekend pair needs both days of the same weekend', () async {
      // Walk back to a known Saturday so the test does not depend on today.
      var saturday = daysAgo(0);
      while (saturday.weekday != DateTime.saturday) {
        saturday = saturday.subtract(const Duration(days: 1));
      }

      await addSession(saturday);
      var s = await stats();
      expect(statValue(s, BadgeStat.weekendPairs), 0);

      await addSession(saturday.add(const Duration(days: 1)));
      s = await stats();
      expect(statValue(s, BadgeStat.weekendPairs), 1);
    });

    test('a comeback needs a two-week gap', () async {
      await addSession(daysAgo(40));
      await addSession(daysAgo(39));
      var s = await stats();
      expect(statValue(s, BadgeStat.comebackReturns), 0);

      await addSession(daysAgo(20));
      s = await stats();
      expect(statValue(s, BadgeStat.comebackReturns), 1);
    });

    test('the busiest week is counted Monday to Sunday', () async {
      // Anchor on a Monday so the five sessions cannot straddle two weeks.
      var monday = daysAgo(7);
      while (monday.weekday != DateTime.monday) {
        monday = monday.subtract(const Duration(days: 1));
      }
      for (var i = 0; i < 5; i++) {
        await addSession(monday.add(Duration(days: i)));
      }

      final s = await stats();
      expect(statValue(s, BadgeStat.maxSessionsInWeek), 5);
    });
  });

  // ---------------------------------------------------------------------------
  // Breadth
  // ---------------------------------------------------------------------------

  group('breadth', () {
    test('muscle groups are counted through primary muscles', () async {
      final squat = await addExercise('Squat', primary: Muscle.quads);
      final bench = await addExercise('Bench Press', primary: Muscle.chest);
      final curl = await addExercise('Curl', primary: Muscle.biceps);

      final session = await addSession(daysAgo(0));
      await addSet(session, squat, weight: 100, reps: 5);
      await addSet(session, bench, weight: 80, reps: 5);
      await addSet(session, curl, weight: 20, reps: 10);

      final s = await stats();
      // Legs, Chest and Arms — three of six.
      expect(statValue(s, BadgeStat.muscleGroupsTrained), 3);
      expect(statValue(s, BadgeStat.distinctExercises), 3);
    });

    test('an untrained exercise counts towards no group', () async {
      await addExercise('Deadlift', primary: Muscle.hamstrings);
      final s = await stats();
      expect(statValue(s, BadgeStat.muscleGroupsTrained), 0);
    });

    test('notes, splits and custom exercises are counted', () async {
      await addSession(daysAgo(2), note: 'felt strong');
      await addSession(daysAgo(1));
      await addSession(daysAgo(0), note: 'tired');
      await addExercise('My Lift', isCustom: true);
      await db
          .into(db.workoutSplits)
          .insert(WorkoutSplitsCompanion.insert(name: 'PPL'));

      final s = await stats();
      expect(statValue(s, BadgeStat.sessionsWithNotes), 2);
      expect(statValue(s, BadgeStat.customExercises), 1);
      expect(statValue(s, BadgeStat.splitsCreated), 1);
    });
  });

  // ---------------------------------------------------------------------------
  // Bodyweight ratio
  // ---------------------------------------------------------------------------

  group('bodyweight ratio', () {
    test('is measured against the barbell lifts only', () async {
      final legPress = await addExercise('Leg Press');
      final bench = await addExercise('Bench Press');
      final session = await addSession(daysAgo(0));

      // A heavy leg press is not a claim the standards can compare.
      await addSet(session, legPress, weight: 300, reps: 5);
      await addSet(session, bench, weight: 80, reps: 3);

      final s = await stats(bodyweightKg: 80);
      expect(statValue(s, BadgeStat.bestBigLiftBodyweightRatio), 1.0);
    });

    test('is zero when the profile has no bodyweight', () async {
      final bench = await addExercise('Bench Press');
      final session = await addSession(daysAgo(0));
      await addSet(session, bench, weight: 100, reps: 3);

      final s = await stats();
      expect(statValue(s, BadgeStat.bestBigLiftBodyweightRatio), 0);
    });

    test('a set with no reps is not a lift', () async {
      final bench = await addExercise('Bench Press');
      final session = await addSession(daysAgo(0));
      await addSet(session, bench, weight: 200, reps: 0);

      final s = await stats(bodyweightKg: 100);
      expect(statValue(s, BadgeStat.bestBigLiftBodyweightRatio), 0);
    });
  });

  // ---------------------------------------------------------------------------
  // The `only` filter — the optimisation the award path depends on
  // ---------------------------------------------------------------------------

  group('only', () {
    test('computes the requested stats and leaves the rest absent', () async {
      final squat = await addExercise('Squat');
      final session = await addSession(daysAgo(0));
      await addSet(session, squat, weight: 100, reps: 5);

      final s = await computeBadgeStats(
        db,
        prCount: 0,
        only: {BadgeStat.totalSets},
      );

      expect(s.containsKey(BadgeStat.totalSets), isTrue);
      expect(s.containsKey(BadgeStat.totalVolumeKg), isFalse);
      // Absent must read as zero, so a partial snapshot cannot award a badge.
      expect(statValue(s, BadgeStat.totalVolumeKg), 0);
    });

    test('one session-derived stat still fills the whole group', () async {
      await addSession(daysAgo(0));
      final s = await computeBadgeStats(
        db,
        prCount: 0,
        only: {BadgeStat.currentStreakDays},
      );
      expect(statValue(s, BadgeStat.currentStreakDays), 1);
      expect(statValue(s, BadgeStat.completedSessions), 1);
    });
  });

  // ---------------------------------------------------------------------------
  // Progress reporting
  // ---------------------------------------------------------------------------

  group('progress', () {
    final sets500 = kAllBadges.firstWhere((b) => b.key == 'sets_500');

    test('reports current against target', () {
      final p = progressFor(sets500, {BadgeStat.totalSets: 370});
      expect(p.current, 370);
      expect(p.target, 500);
      expect(progressFractionFor(sets500, {BadgeStat.totalSets: 370}), 0.74);
    });

    test('clamps past the target rather than reading 900 / 500', () {
      final p = progressFor(sets500, {BadgeStat.totalSets: 900});
      expect(p.current, 500);
      expect(progressFractionFor(sets500, {BadgeStat.totalSets: 900}), 1.0);
    });

    test('isEarnedBy is true exactly at the threshold', () {
      expect(isEarnedBy(sets500, {BadgeStat.totalSets: 499}), isFalse);
      expect(isEarnedBy(sets500, {BadgeStat.totalSets: 500}), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Formatting
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // Awarding
  // ---------------------------------------------------------------------------

  group('awarding', () {
    /// The badge rows, as production's `_seedBadges()` writes them.
    Future<void> seedBadges() async {
      await db.batch((b) {
        for (final badge in kAllBadges) {
          b.insert(
            db.badges,
            BadgesCompanion.insert(badgeKey: badge.key),
            onConflict: DoUpdate(
              (_) => BadgesCompanion.insert(badgeKey: badge.key),
              target: [db.badges.badgeKey],
            ),
          );
        }
      });
    }

    Future<Set<String>> earnedKeys() async {
      final rows = await (db.select(
        db.badges,
      )..where((b) => b.earnedAt.isNotNull())).get();
      return {for (final row in rows) row.badgeKey};
    }

    /// Four sessions inside one Monday-aligned week, which is Full Week's
    /// criterion exactly.
    Future<void> trainFourTimesInAWeek() async {
      for (var i = 0; i < 4; i++) {
        await addSession(DateTime(2026, 3, 2 + i, 9));
      }
    }

    test('a criterion already met is awarded', () async {
      // The retroactive case: the history satisfies the badge, but no set has
      // been logged since, so nothing has ever evaluated it. This is what an
      // upgrade that adds badges looks like from the database's side.
      await seedBadges();
      await trainFourTimesInAWeek();

      final stats = await computeBadgeStats(db, prCount: 0);
      final awarded = await awardEarnedBadges(db, stats);

      expect(awarded, contains('week_4_sessions'));
      expect(await earnedKeys(), contains('week_4_sessions'));
    });

    test('no badge is left complete and locked', () async {
      // The bug this guards: the badges screen computes progress from live
      // state while awarding only ran on a logged set, so "Next up" could
      // recommend a badge sitting at 100%. After reconciling, a locked badge
      // must have somewhere left to go.
      await seedBadges();
      await trainFourTimesInAWeek();

      final stats = await computeBadgeStats(db, prCount: 0);
      await awardEarnedBadges(db, stats);

      final earned = await earnedKeys();
      for (final badge in kAllBadges) {
        if (earned.contains(badge.key)) continue;
        expect(
          progressFractionFor(badge, stats),
          lessThan(1),
          reason: '${badge.key} is complete but still locked',
        );
      }
    });

    test('awarding twice awards nothing the second time', () async {
      await seedBadges();
      await trainFourTimesInAWeek();

      final stats = await computeBadgeStats(db, prCount: 0);
      final first = await awardEarnedBadges(db, stats);
      final second = await awardEarnedBadges(db, stats);

      expect(first, isNotEmpty);
      expect(second, isEmpty);
    });

    test('an unseeded badge is a candidate but cannot be awarded', () async {
      // No rows at all — the state an install would be in if a migration
      // forgot to re-seed. Nothing should be awarded, and nothing should
      // throw: the fault has to stay visible on the badges screen rather than
      // crash the set that triggered it.
      await trainFourTimesInAWeek();

      final stats = await computeBadgeStats(db, prCount: 0);
      expect(await unearnedBadges(db), hasLength(kAllBadges.length));
      expect(await awardEarnedBadges(db, stats), isEmpty);
    });
  });

  group('formatPair', () {
    test('rescales volume to tonnes and distance to kilometres', () {
      expect(BadgeStat.totalVolumeKg.formatPair(3400, 10000), '3.4 / 10.0 t');
      expect(
        BadgeStat.totalVolumeKg.formatPair(250000, 1000000),
        '250 / 1000 t',
      );
      expect(
        BadgeStat.totalDistanceMetres.formatPair(12000, 42195),
        '12.0 / 42.2 km',
      );
    });

    test('names the unit once, and not at all when compact', () {
      expect(BadgeStat.totalSets.formatPair(370, 500), '370 / 500 sets');
      expect(
        BadgeStat.totalSets.formatPair(370, 500, compact: true),
        '370 / 500',
      );
    });

    test('writes the bodyweight ratio as a multiple', () {
      expect(
        BadgeStat.bestBigLiftBodyweightRatio.formatPair(1.4, 2),
        '1.40 / 2.00x',
      );
    });
  });
}
