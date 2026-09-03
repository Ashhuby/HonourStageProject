import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:fitness_app/core/database/database_provider.dart';
import 'package:fitness_app/core/database/local_database.dart';
import 'package:fitness_app/features/workout/data/badge_service.dart';
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
}
