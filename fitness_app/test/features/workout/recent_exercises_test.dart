import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:fitness_app/core/database/database_provider.dart';
import 'package:fitness_app/core/database/local_database.dart';
import 'package:fitness_app/features/workout/data/session_repository.dart';

/// Tests for the "recently used" row at the top of the exercise picker.
///
/// The recency order is derived from logged sets rather than a `lastUsedAt`
/// column, so this guards the de-duplication and ordering that stand in for
/// schema support — a regression here would silently reorder the row the user
/// reaches for first mid-workout.
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late int benchId;
  late int squatId;
  late int rowId;
  late int sessionId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );

    Future<int> addExercise(String name, String bodyPart) => db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            name: name,
            bodyPart: bodyPart,
            equipmentType: 'Barbell',
          ),
        );

    benchId = await addExercise('Bench Press', 'Chest');
    squatId = await addExercise('Squat', 'Legs');
    rowId = await addExercise('Barbell Row', 'Back');

    sessionId = await db
        .into(db.workoutSessions)
        .insert(
          WorkoutSessionsCompanion.insert(startTime: DateTime(2026, 1, 1, 9)),
        );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> insertSet({
    required int forExercise,
    required DateTime at,
    bool deleted = false,
  }) async {
    await db
        .into(db.workoutSets)
        .insert(
          WorkoutSetsCompanion.insert(
            sessionId: sessionId,
            exerciseId: forExercise,
            weight: const Value(60),
            reps: const Value(5),
            timestamp: Value(at),
            deletedAt: Value(deleted ? DateTime.now() : null),
          ),
        );
  }

  /// Reads the first value emitted by a provider, keeping the auto-disposed
  /// subscription alive for the duration of the read.
  Future<T> firstValue<T>(ProviderListenable<AsyncValue<T>> provider) async {
    final sub = container.listen(provider, (_, _) {});
    try {
      var value = container.read(provider);
      while (!value.hasValue) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        value = container.read(provider);
      }
      return value.requireValue;
    } finally {
      sub.close();
    }
  }

  Future<List<int>> recent({int limit = 6}) =>
      firstValue(watchRecentExerciseIdsProvider(limit: limit));

  test('no logged sets yields an empty list', () async {
    expect(await recent(), isEmpty);
  });

  test('orders exercises most recently logged first', () async {
    await insertSet(forExercise: benchId, at: DateTime(2026, 1, 1, 9));
    await insertSet(forExercise: squatId, at: DateTime(2026, 1, 1, 10));
    await insertSet(forExercise: rowId, at: DateTime(2026, 1, 1, 11));

    expect(await recent(), [rowId, squatId, benchId]);
  });

  test('an exercise appears once, at its most recent position', () async {
    // Bench was logged first and last; it must lead, and only once.
    await insertSet(forExercise: benchId, at: DateTime(2026, 1, 1, 9));
    await insertSet(forExercise: squatId, at: DateTime(2026, 1, 1, 10));
    await insertSet(forExercise: benchId, at: DateTime(2026, 1, 1, 11));

    expect(await recent(), [benchId, squatId]);
  });

  test('respects the limit', () async {
    await insertSet(forExercise: benchId, at: DateTime(2026, 1, 1, 9));
    await insertSet(forExercise: squatId, at: DateTime(2026, 1, 1, 10));
    await insertSet(forExercise: rowId, at: DateTime(2026, 1, 1, 11));

    expect(await recent(limit: 2), [rowId, squatId]);
  });

  test('soft-deleted sets do not count as recent use', () async {
    await insertSet(forExercise: benchId, at: DateTime(2026, 1, 1, 9));
    await insertSet(
      forExercise: squatId,
      at: DateTime(2026, 1, 1, 10),
      deleted: true,
    );

    expect(await recent(), [benchId]);
  });

  test(
    'an unfinished session still counts — recency is not completion',
    () async {
      // The picker is used mid-workout, so sets from the session in progress are
      // exactly the ones worth surfacing.
      final openSession = await db
          .into(db.workoutSessions)
          .insert(
            WorkoutSessionsCompanion.insert(startTime: DateTime(2026, 1, 2, 9)),
          );
      await db
          .into(db.workoutSets)
          .insert(
            WorkoutSetsCompanion.insert(
              sessionId: openSession,
              exerciseId: rowId,
              weight: const Value(60),
              reps: const Value(5),
              timestamp: Value(DateTime(2026, 1, 2, 9, 30)),
            ),
          );

      expect(await recent(), [rowId]);
    },
  );
}
