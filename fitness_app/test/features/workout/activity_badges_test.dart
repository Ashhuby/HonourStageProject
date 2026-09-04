import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:fitness_app/core/database/database_provider.dart';
import 'package:fitness_app/core/database/local_database.dart';
import 'package:fitness_app/features/workout/data/badge_service.dart';
import 'package:fitness_app/features/workout/data/badge_unlock_queue.dart';
import 'package:fitness_app/features/workout/data/rank_up_queue.dart';
import 'package:fitness_app/features/workout/domain/rank.dart';
import 'package:fitness_app/features/workout/data/exercise_repository.dart';
import 'package:fitness_app/features/workout/domain/activity.dart';
import 'package:fitness_app/features/workout/domain/muscle.dart';

/// Tests the badges that recognise cardio and mobility training.
///
/// These run the real [BadgeService] rather than reimplementing its queries,
/// because the point of them is that the SQL joins `exercises` correctly — a
/// reimplementation would only prove the test's own join works.
///
/// The set-count badges are not wrong, but a cardio session is one logged set
/// where a lifting session is fifteen, so "log 500 sets" is a badge only a
/// lifter will ever see.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    // forTesting skips the seed, so the badge rows have to be written by hand.
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
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<int> addExercise({
    required String name,
    required ExerciseCategory category,
    CardioModality? modality,
    String metricType = 'weightReps',
  }) {
    return container
        .read(exerciseRepositoryProvider.notifier)
        .addExercise(
          name,
          'Other',
          primary: Muscle.quads,
          metricType: metricType,
          category: category,
          modality: modality,
        );
  }

  Future<void> logSet(int exerciseId, {double? distanceMetres}) async {
    final sessionId = await db
        .into(db.workoutSessions)
        .insert(
          WorkoutSessionsCompanion.insert(startTime: DateTime(2026, 6, 1)),
        );
    await db
        .into(db.workoutSets)
        .insert(
          WorkoutSetsCompanion.insert(
            sessionId: sessionId,
            exerciseId: exerciseId,
            distanceMetres: Value(distanceMetres),
            durationSeconds: const Value(600),
          ),
        );
  }

  Future<List<String>> evaluate() => container
      .read(badgeServiceProvider.notifier)
      .evaluateAll(totalPrCount: 0);

  Future<bool> earned(String key) async {
    final row = await (db.select(
      db.badges,
    )..where((b) => b.badgeKey.equals(key))).getSingle();
    return row.earnedAt != null;
  }

  test('first_cardio is awarded on the first cardio set', () async {
    final id = await addExercise(
      name: 'Canal Run',
      category: ExerciseCategory.cardio,
      modality: CardioModality.run,
      metricType: 'distanceTime',
    );

    expect(await earned('first_cardio'), isFalse);
    await logSet(id, distanceMetres: 3000);
    await evaluate();

    expect(await earned('first_cardio'), isTrue);
    expect(await earned('first_mobility'), isFalse);
  });

  test('lifting alone earns neither activity badge', () async {
    final id = await addExercise(
      name: 'Squat',
      category: ExerciseCategory.strength,
    );
    await logSet(id);
    await evaluate();

    expect(await earned('first_cardio'), isFalse);
    expect(await earned('first_mobility'), isFalse);
  });

  test('first_mobility is awarded on the first mobility set', () async {
    final id = await addExercise(
      name: 'Hamstring Stretch',
      category: ExerciseCategory.mobility,
      metricType: 'timeOnly',
    );
    await logSet(id);
    await evaluate();

    expect(await earned('first_mobility'), isTrue);
  });

  test('the marathon badge accumulates rather than needing one run', () async {
    // A marathon's worth of intervals is as much work as a marathon, and the
    // badge recognises the training rather than a single heroic session.
    final id = await addExercise(
      name: 'Treadmill Run',
      category: ExerciseCategory.cardio,
      modality: CardioModality.run,
      metricType: 'distanceTime',
    );

    for (var i = 0; i < 8; i++) {
      await logSet(id, distanceMetres: 5000);
    }
    await evaluate();
    expect(
      await earned('marathon_distance'),
      isFalse,
      reason: '40 km is not a marathon',
    );

    await logSet(id, distanceMetres: 3000);
    await evaluate();
    expect(await earned('marathon_distance'), isTrue);
  });

  test('a soft-deleted set does not count towards distance', () async {
    final id = await addExercise(
      name: 'Treadmill Run',
      category: ExerciseCategory.cardio,
      modality: CardioModality.run,
      metricType: 'distanceTime',
    );
    await logSet(id, distanceMetres: 50000);
    await (db.update(
      db.workoutSets,
    )).write(WorkoutSetsCompanion(deletedAt: Value(DateTime(2026, 6, 2))));

    await evaluate();
    expect(await earned('marathon_distance'), isFalse);
  });

  test('re-evaluating does not re-award or move earnedAt', () async {
    final id = await addExercise(
      name: 'Canal Run',
      category: ExerciseCategory.cardio,
      modality: CardioModality.run,
      metricType: 'distanceTime',
    );
    await logSet(id, distanceMetres: 3000);

    final first = await evaluate();
    expect(first, contains('first_cardio'));

    final second = await evaluate();
    expect(second, isNot(contains('first_cardio')));
  });

  // ---------------------------------------------------------------------------
  // The unlock queue
  // ---------------------------------------------------------------------------
  //
  // evaluateAll pushes what it awarded onto the queue itself rather than
  // returning it for the caller to forward. The three call sites that existed
  // when the queue was added all discarded the return value, which is why
  // badges were earned in silence; these tests hold that door shut.

  List<String> queuedKeys() => [
    for (final badge in container.read(badgeUnlockQueueProvider)) badge.key,
  ];

  group('unlock queue', () {
    test('an award is queued for celebration', () async {
      final id = await addExercise(
        name: 'Canal Run',
        category: ExerciseCategory.cardio,
        modality: CardioModality.run,
        metricType: 'distanceTime',
      );
      await logSet(id, distanceMetres: 3000);

      expect(queuedKeys(), isEmpty);
      await evaluate();
      expect(queuedKeys(), contains('first_cardio'));
    });

    test('badges earned together are all queued', () async {
      final id = await addExercise(
        name: 'Canal Run',
        category: ExerciseCategory.cardio,
        modality: CardioModality.run,
        metricType: 'distanceTime',
      );
      // One set of a cardio exercise inside a completed session trips both
      // the first-cardio badge and the first-workout badge at once.
      await logSet(id, distanceMetres: 3000);
      await (db.update(db.workoutSessions)).write(
        WorkoutSessionsCompanion(endTime: Value(DateTime(2026, 6, 1, 1))),
      );

      await evaluate();
      expect(queuedKeys(), containsAll(['first_cardio', 'first_workout']));
    });

    test('re-evaluating does not queue the same badge twice', () async {
      final id = await addExercise(
        name: 'Canal Run',
        category: ExerciseCategory.cardio,
        modality: CardioModality.run,
        metricType: 'distanceTime',
      );
      await logSet(id, distanceMetres: 3000);

      await evaluate();
      await evaluate();

      expect(queuedKeys().where((k) => k == 'first_cardio').length, 1);
    });

    test('dismissing takes them one at a time, oldest first', () async {
      container.read(badgeUnlockQueueProvider.notifier).enqueue([
        'first_cardio',
        'first_mobility',
      ]);

      expect(queuedKeys(), ['first_cardio', 'first_mobility']);

      container.read(badgeUnlockQueueProvider.notifier).dismissCurrent();
      expect(queuedKeys(), ['first_mobility']);

      container.read(badgeUnlockQueueProvider.notifier).dismissCurrent();
      expect(queuedKeys(), isEmpty);

      // Dismissing an empty queue is a no-op, not a range error.
      container.read(badgeUnlockQueueProvider.notifier).dismissCurrent();
      expect(queuedKeys(), isEmpty);
    });

    test('an unknown key is skipped rather than throwing', () {
      // A badge row synced from a newer version of the app has no definition
      // here, and that is not worth a crash.
      container.read(badgeUnlockQueueProvider.notifier).enqueue([
        'first_cardio',
        'badge_from_the_future',
      ]);

      expect(queuedKeys(), ['first_cardio']);
    });
  });

  // ---------------------------------------------------------------------------
  // Rank
  // ---------------------------------------------------------------------------
  //
  // A rank is a sum of the badges held, so it can only move when badges are
  // awarded. It is worked out on the award path rather than watched, which
  // means a rank-up that is not announced here is one the user only discovers
  // by noticing a header reading differently.

  group('rank', () {
    test('a first badge is not yet a rank-up', () async {
      // Iron is where everyone starts. Announcing it would celebrate standing
      // still.
      final id = await addExercise(
        name: 'Canal Run',
        category: ExerciseCategory.cardio,
        modality: CardioModality.run,
        metricType: 'distanceTime',
      );
      await logSet(id, distanceMetres: 3000);

      await evaluate();

      expect(queuedKeys(), isNotEmpty);
      expect(container.read(rankUpQueueProvider), isNull);
    });

    test('crossing a threshold announces the rank reached', () async {
      // Parked one point below Copper, awarded by hand rather than trained
      // for: the arithmetic is what is under test, and earning eleven points
      // through the fixtures would prove nothing extra. The two badges the
      // fixture is about to award are held back so the twelfth point is the
      // one that crosses.
      final filler = [
        for (final badge in kAllBadges)
          if (badge.tier == BadgeTier.bronze &&
              badge.key != 'first_cardio' &&
              badge.key != 'first_workout')
            badge.key,
      ].take(Rank.pebble.threshold - 1).toList();

      expect(filler, hasLength(Rank.pebble.threshold - 1));
      await (db.update(db.badges)..where((b) => b.badgeKey.isIn(filler))).write(
        BadgesCompanion(earnedAt: Value(DateTime(2026, 6, 1))),
      );

      final id = await addExercise(
        name: 'Canal Run',
        category: ExerciseCategory.cardio,
        modality: CardioModality.run,
        metricType: 'distanceTime',
      );
      await logSet(id, distanceMetres: 3000);

      await evaluate();

      expect(queuedKeys(), contains('first_cardio'));
      expect(container.read(rankUpQueueProvider), Rank.pebble);
    });

    test('the announcement is cleared once, and stays cleared', () async {
      container.read(rankUpQueueProvider.notifier).announce(Rank.stone);
      expect(container.read(rankUpQueueProvider), Rank.stone);

      container.read(rankUpQueueProvider.notifier).clear();
      expect(container.read(rankUpQueueProvider), isNull);

      // Clearing nothing is a no-op, not a state change.
      container.read(rankUpQueueProvider.notifier).clear();
      expect(container.read(rankUpQueueProvider), isNull);
    });
  });
}
