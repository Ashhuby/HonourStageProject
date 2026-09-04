import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/core/database/local_database.dart';
import 'package:fitness_app/features/workout/data/badge_service.dart';
import 'package:fitness_app/features/workout/data/badge_stats.dart';

/// Tests that each badge's criterion means what its name says.
///
/// [badge_stats_test.dart] proves the counters; this proves the wiring — that
/// `sets_50` really is fifty sets and not fifty of something else, and that a
/// threshold is crossed at the value on the tin.
///
/// These used to reimplement the award logic inline, because [BadgeService]
/// needs a Riverpod `Ref` and could not be called directly. That made them
/// tests of the test's own SQL. [computeBadgeStats] takes an [AppDatabase]
/// instead, so the criteria can now be checked against the real thing.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // forTesting skips the seed in onCreate, so the badge rows are written by
    // hand to match what _seedBadges() does in production.
    await _seedBadges(db);
  });

  tearDown(() async {
    await db.close();
  });

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  BadgeDefinition badge(String key) =>
      kAllBadges.firstWhere((b) => b.key == key);

  /// Whether [key]'s criterion is met by the database as it now stands.
  Future<bool> earns(String key, {int prCount = 0}) async {
    final stats = await computeBadgeStats(db, prCount: prCount);
    return isEarnedBy(badge(key), stats);
  }

  Future<int> insertCompletedSession(DateTime date) async {
    // Normalise to midday so a session cannot slide into the previous day
    // under a timezone offset.
    final day = DateTime(date.year, date.month, date.day, 12);
    return db
        .into(db.workoutSessions)
        .insert(
          WorkoutSessionsCompanion.insert(
            startTime: day,
            endTime: Value(day.add(const Duration(hours: 1))),
          ),
        );
  }

  Future<int> insertExercise(String name, {bool isCustom = false}) {
    return db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            name: name,
            bodyPart: 'Chest',
            equipmentType: 'Barbell',
            isCustom: Value(isCustom),
          ),
        );
  }

  // `exercises.name` carries a unique index, so repeated batches need
  // distinct names.
  var batchNumber = 0;

  Future<void> insertSets(int count) async {
    final sessionId = await insertCompletedSession(DateTime.now());
    final exerciseId = await insertExercise('Bench Press ${batchNumber++}');
    await db.batch((b) {
      for (var i = 0; i < count; i++) {
        b.insert(
          db.workoutSets,
          WorkoutSetsCompanion.insert(
            sessionId: sessionId,
            exerciseId: exerciseId,
            weight: const Value(60),
            reps: const Value(10),
          ),
        );
      }
    });
  }

  /// Sessions on each of the last [days] calendar days, today included.
  Future<void> insertStreak(int days) async {
    final today = DateTime.now();
    for (var i = 0; i < days; i++) {
      await insertCompletedSession(
        DateTime(today.year, today.month, today.day - i),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Seeding
  // ---------------------------------------------------------------------------

  group('Badge seeding', () {
    test('every defined badge is seeded as unearned', () async {
      final rows = await db.select(db.badges).get();
      expect(rows.length, kAllBadges.length);
      expect(rows.every((r) => r.earnedAt == null), isTrue);
    });

    test('re-seeding does not overwrite earned badges', () async {
      await (db.update(db.badges)
            ..where((b) => b.badgeKey.equals('first_workout')))
          .write(BadgesCompanion(earnedAt: Value(DateTime(2026, 2, 1))));

      await _seedBadges(db); // simulates the upgrade path

      final row = await (db.select(
        db.badges,
      )..where((b) => b.badgeKey.equals('first_workout'))).getSingle();
      expect(row.earnedAt, DateTime(2026, 2, 1));
    });
  });

  // ---------------------------------------------------------------------------
  // Sessions
  // ---------------------------------------------------------------------------

  group('first_workout', () {
    test('needs one completed session', () async {
      expect(await earns('first_workout'), isFalse);
      await insertCompletedSession(DateTime.now());
      expect(await earns('first_workout'), isTrue);
    });

    test('a session still in progress does not count', () async {
      await db
          .into(db.workoutSessions)
          .insert(WorkoutSessionsCompanion.insert(startTime: DateTime.now()));
      expect(await earns('first_workout'), isFalse);
    });
  });

  group('session milestones', () {
    test('sessions_10 lands on the tenth', () async {
      for (var i = 0; i < 9; i++) {
        await insertCompletedSession(DateTime(2026, 1, 1 + i));
      }
      expect(await earns('sessions_10'), isFalse);

      await insertCompletedSession(DateTime(2026, 1, 10));
      expect(await earns('sessions_10'), isTrue);
      expect(await earns('sessions_50'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Streaks
  // ---------------------------------------------------------------------------

  group('streaks', () {
    test('7 consecutive days earns the 7-day badge and not the 30', () async {
      await insertStreak(7);
      expect(await earns('streak_3_day'), isTrue);
      expect(await earns('streak_7_day'), isTrue);
      expect(await earns('streak_30_day'), isFalse);
    });

    test('a break stops the streak short', () async {
      final today = DateTime.now();
      // Days 0-4, then a gap at day 5, then more history behind it.
      for (var i = 0; i < 5; i++) {
        await insertCompletedSession(
          DateTime(today.year, today.month, today.day - i),
        );
      }
      for (var i = 6; i < 12; i++) {
        await insertCompletedSession(
          DateTime(today.year, today.month, today.day - i),
        );
      }
      expect(await earns('streak_3_day'), isTrue);
      expect(await earns('streak_7_day'), isFalse);
    });

    test('30 consecutive days is 30, and 29 is not', () async {
      await insertStreak(29);
      expect(await earns('streak_30_day'), isFalse);

      final today = DateTime.now();
      await insertCompletedSession(
        DateTime(today.year, today.month, today.day - 29),
      );
      expect(await earns('streak_30_day'), isTrue);
      expect(await earns('streak_100_day'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Sets and volume
  // ---------------------------------------------------------------------------

  group('set milestones', () {
    test('sets_50 lands on the fiftieth set', () async {
      await insertSets(49);
      expect(await earns('sets_50'), isFalse);

      await insertSets(1);
      expect(await earns('sets_50'), isTrue);
      expect(await earns('sets_500'), isFalse);
    });

    test('sets_500 needs five hundred', () async {
      await insertSets(500);
      expect(await earns('sets_500'), isTrue);
    });
  });

  group('volume milestones', () {
    test('ten tonnes is ten thousand kilograms moved', () async {
      // 16 sets of 60 kg x 10 is 9,600 kg.
      await insertSets(16);
      expect(await earns('volume_10t'), isFalse);

      await insertSets(1); // 10,200 kg
      expect(await earns('volume_10t'), isTrue);
      expect(await earns('volume_100t'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Personal bests
  // ---------------------------------------------------------------------------

  group('personal best milestones', () {
    test('first_pr needs one, pr_10 needs ten', () async {
      expect(await earns('first_pr'), isFalse);
      expect(await earns('first_pr', prCount: 1), isTrue);

      expect(await earns('pr_10', prCount: 9), isFalse);
      expect(await earns('pr_10', prCount: 10), isTrue);
      expect(await earns('pr_50', prCount: 10), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Curation
  // ---------------------------------------------------------------------------

  group('curation', () {
    test('first_custom_exercise ignores the seeded library', () async {
      await insertExercise('Bench Press');
      expect(await earns('first_custom_exercise'), isFalse);

      await insertExercise('My Own Lift', isCustom: true);
      expect(await earns('first_custom_exercise'), isTrue);
    });

    test('first_split needs a split', () async {
      expect(await earns('first_split'), isFalse);
      await db
          .into(db.workoutSplits)
          .insert(WorkoutSplitsCompanion.insert(name: 'Push Pull Legs'));
      expect(await earns('first_split'), isTrue);
    });
  });
}

// ---------------------------------------------------------------------------
// Test-local seed
// ---------------------------------------------------------------------------

/// Mirrors production's badge seed.
///
/// Driven from [kAllBadges] rather than a third hardcoded list — production
/// kept its own copy until recently, so a badge added to the definitions had
/// no row and could never be awarded.
Future<void> _seedBadges(AppDatabase db) async {
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
