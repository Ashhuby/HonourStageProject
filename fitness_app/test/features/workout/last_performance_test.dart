import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:fitness_app/core/database/database_provider.dart';
import 'package:fitness_app/core/database/local_database.dart';
import 'package:fitness_app/core/utils/set_formatter.dart';
import 'package:fitness_app/features/workout/data/personal_best_repository.dart';
import 'package:fitness_app/features/workout/data/session_repository.dart';

/// Tests for the "last time" and "personal best" lookups shown on the active
/// session screen.
///
/// These run the real providers against an in-memory Drift database with
/// [databaseProvider] overridden, so the actual SQL is exercised rather than
/// an inline reimplementation of it.
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late int exerciseId;
  late int otherExerciseId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );

    exerciseId = await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            name: 'Bench Press',
            bodyPart: 'Chest',
            equipmentType: 'Barbell',
          ),
        );
    otherExerciseId = await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            name: 'Squat',
            bodyPart: 'Legs',
            equipmentType: 'Barbell',
          ),
        );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<int> insertSession({
    required DateTime start,
    bool finished = true,
    bool deleted = false,
  }) {
    return db
        .into(db.workoutSessions)
        .insert(
          WorkoutSessionsCompanion.insert(
            startTime: start,
            endTime: Value(
              finished ? start.add(const Duration(hours: 1)) : null,
            ),
            deletedAt: Value(deleted ? DateTime.now() : null),
          ),
        );
  }

  Future<void> insertSet({
    required int sessionId,
    required DateTime at,
    int? forExercise,
    double weight = 0,
    int reps = 0,
    int? durationSeconds,
    double? distanceMetres,
    bool deleted = false,
  }) async {
    await db
        .into(db.workoutSets)
        .insert(
          WorkoutSetsCompanion.insert(
            sessionId: sessionId,
            exerciseId: forExercise ?? exerciseId,
            weight: Value(weight),
            reps: Value(reps),
            durationSeconds: Value(durationSeconds),
            distanceMetres: Value(distanceMetres),
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

  Future<LastSessionPerformance?> lastPerformance(int currentSessionId) =>
      firstValue(
        watchLastPerformanceForExerciseProvider(exerciseId, currentSessionId),
      );

  // ---------------------------------------------------------------------------
  // Last session lookup
  // ---------------------------------------------------------------------------

  group('watchLastPerformanceForExercise', () {
    test('returns null when the exercise has never been logged', () async {
      final current = await insertSession(
        start: DateTime(2026, 1, 10),
        finished: false,
      );

      expect(await lastPerformance(current), isNull);
    });

    test('returns the most recent session only, in logged order', () async {
      final older = await insertSession(start: DateTime(2026, 1, 1));
      await insertSet(
        sessionId: older,
        at: DateTime(2026, 1, 1, 10),
        weight: 60,
        reps: 10,
      );

      final recent = await insertSession(start: DateTime(2026, 1, 8));
      await insertSet(
        sessionId: recent,
        at: DateTime(2026, 1, 8, 10),
        weight: 80,
        reps: 8,
      );
      await insertSet(
        sessionId: recent,
        at: DateTime(2026, 1, 8, 10, 5),
        weight: 80,
        reps: 6,
      );

      final current = await insertSession(
        start: DateTime(2026, 1, 15),
        finished: false,
      );

      final result = await lastPerformance(current);

      expect(result, isNotNull);
      expect(result!.date, DateTime(2026, 1, 8));
      expect(result.sets.map((s) => s.reps).toList(), [8, 6]);
      expect(result.sets.every((s) => s.weight == 80), isTrue);
    });

    test('ignores sets logged in the session in progress', () async {
      final current = await insertSession(
        start: DateTime(2026, 1, 15),
        finished: false,
      );
      await insertSet(
        sessionId: current,
        at: DateTime(2026, 1, 15, 10),
        weight: 100,
        reps: 5,
      );

      expect(await lastPerformance(current), isNull);
    });

    test(
      'ignores other exercises, deleted sets and unfinished sessions',
      () async {
        final deletedSession = await insertSession(
          start: DateTime(2026, 1, 9),
          deleted: true,
        );
        await insertSet(
          sessionId: deletedSession,
          at: DateTime(2026, 1, 9, 10),
          weight: 999,
          reps: 1,
        );

        final unfinished = await insertSession(
          start: DateTime(2026, 1, 7),
          finished: false,
        );
        await insertSet(
          sessionId: unfinished,
          at: DateTime(2026, 1, 7, 10),
          weight: 888,
          reps: 1,
        );

        final kept = await insertSession(start: DateTime(2026, 1, 5));
        await insertSet(
          sessionId: kept,
          at: DateTime(2026, 1, 5, 10),
          weight: 70,
          reps: 12,
        );
        await insertSet(
          sessionId: kept,
          at: DateTime(2026, 1, 5, 10, 5),
          weight: 75,
          reps: 1,
          deleted: true,
        );
        await insertSet(
          sessionId: kept,
          at: DateTime(2026, 1, 5, 10, 10),
          forExercise: otherExerciseId,
          weight: 120,
          reps: 5,
        );

        final current = await insertSession(
          start: DateTime(2026, 1, 15),
          finished: false,
        );

        final result = await lastPerformance(current);

        expect(result!.date, DateTime(2026, 1, 5));
        expect(result.sets.length, 1);
        expect(result.sets.single.weight, 70);
        expect(result.sets.single.reps, 12);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Personal best lookup
  // ---------------------------------------------------------------------------

  group('watchBestPrForExercise', () {
    Future<void> insertPr({
      required double weight,
      required int reps,
      String metricType = 'weightReps',
      int? durationSeconds,
      double distanceMetres = 0.0,
    }) async {
      await db
          .into(db.personalBests)
          .insert(
            PersonalBestsCompanion.insert(
              exerciseId: exerciseId,
              weight: Value(weight),
              reps: Value(reps),
              metricType: Value(metricType),
              durationSeconds: Value(durationSeconds),
              distanceMetres: Value(distanceMetres),
              achievedAt: DateTime(2026, 1, 5),
            ),
          );
    }

    test('returns null when no PR exists', () async {
      expect(
        await firstValue(watchBestPrForExerciseProvider(exerciseId)),
        isNull,
      );
    });

    test('returns the record held for the exercise', () async {
      await insertPr(weight: 100, reps: 3);

      final pb = await firstValue(watchBestPrForExerciseProvider(exerciseId));

      expect(pb!.weight, 100);
      expect(pb.reps, 3);
    });

    test('returns the longest distance for distanceTime records', () async {
      await insertPr(
        weight: 0,
        reps: 1,
        metricType: 'distanceTime',
        distanceMetres: 400,
        durationSeconds: 80,
      );
      await insertPr(
        weight: 0,
        reps: 2,
        metricType: 'distanceTime',
        distanceMetres: 5000,
        durationSeconds: 1500,
      );

      final pb = await firstValue(watchBestPrForExerciseProvider(exerciseId));

      expect(pb!.distanceMetres, 5000);
      expect(pb.durationSeconds, 1500);
    });
  });

  // ---------------------------------------------------------------------------
  // Formatting
  // ---------------------------------------------------------------------------

  group('formatTargetProgress', () {
    test('counts up to the planned sets', () {
      expect(
        formatTargetProgress(
          logged: 0,
          targetSets: 3,
          targetReps: 10,
          tracksReps: true,
        ),
        'SET 1 OF 3 · TARGET 10 REPS',
      );
      expect(
        formatTargetProgress(
          logged: 2,
          targetSets: 3,
          targetReps: 10,
          tracksReps: true,
        ),
        'SET 3 OF 3 · TARGET 10 REPS',
      );
    });

    test('drops the rep target for time and distance exercises', () {
      expect(
        formatTargetProgress(
          logged: 1,
          targetSets: 3,
          targetReps: 10,
          tracksReps: false,
        ),
        'SET 2 OF 3',
      );
    });

    test('reports the target as met, and counts sets beyond it', () {
      expect(
        formatTargetProgress(
          logged: 3,
          targetSets: 3,
          targetReps: 10,
          tracksReps: true,
        ),
        'TARGET MET · 3 OF 3 SETS',
      );
      expect(
        formatTargetProgress(
          logged: 5,
          targetSets: 3,
          targetReps: 10,
          tracksReps: true,
        ),
        'TARGET MET · 5 OF 3 SETS',
      );
    });
  });

  group('formatSetSummary', () {
    test('formats weight and reps without a trailing zero', () {
      expect(formatSetSummary(weight: 80, reps: 8), '80kg × 8 reps');
      expect(formatSetSummary(weight: 82.5, reps: 5), '82.5kg × 5 reps');
    });

    test('formats bodyweight sets as reps only', () {
      expect(formatSetSummary(reps: 12), '12 reps');
    });

    test('formats durations and distances', () {
      expect(formatSetSummary(durationSeconds: 45), '45s');
      expect(formatSetSummary(durationSeconds: 65), '1m 05s');
      expect(
        formatSetSummary(durationSeconds: 80, distanceMetres: 400),
        '400m in 1m 20s',
      );
      expect(
        formatSetSummary(durationSeconds: 1500, distanceMetres: 5000),
        '5.0km in 25m 00s',
      );
    });
  });
}
