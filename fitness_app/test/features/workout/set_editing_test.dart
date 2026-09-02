import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:fitness_app/core/database/database_provider.dart';
import 'package:fitness_app/core/database/local_database.dart';
import 'package:fitness_app/features/workout/data/personal_best_repository.dart';
import 'package:fitness_app/features/workout/data/session_repository.dart';

/// Tests for correcting a logged set and the records that depend on it.
///
/// A personal best is evidence of a set that was logged, so editing or
/// deleting that set has to withdraw it. Before this, a mistyped 800kg lift
/// left an 800kg record standing even after the set was deleted.
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late int exerciseId;
  late int sessionId;

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
    sessionId = await db
        .into(db.workoutSessions)
        .insert(
          WorkoutSessionsCompanion.insert(startTime: DateTime(2026, 1, 15)),
        );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  SessionRepository sessions() =>
      container.read(sessionRepositoryProvider.notifier);

  PersonalBestRepository records() =>
      container.read(personalBestRepositoryProvider.notifier);

  Future<int> insertSet({
    required double weight,
    required int reps,
    DateTime? at,
  }) {
    return db
        .into(db.workoutSets)
        .insert(
          WorkoutSetsCompanion.insert(
            sessionId: sessionId,
            exerciseId: exerciseId,
            weight: Value(weight),
            reps: Value(reps),
            timestamp: Value(at ?? DateTime(2026, 1, 15, 10)),
          ),
        );
  }

  Future<void> rebuild() => records().recalculateForExercise(
    exerciseId: exerciseId,
    metricType: 'weightReps',
  );

  Future<List<PersonalBest>> liveRecords() =>
      (db.select(db.personalBests)..where((pb) => pb.deletedAt.isNull())).get();

  // ---------------------------------------------------------------------------
  // Replay
  // ---------------------------------------------------------------------------

  group('computeRecords', () {
    WorkoutSet set({
      double weight = 0.0,
      int reps = 0,
      int? durationSeconds,
      double? distanceMetres,
      DateTime? at,
    }) {
      return WorkoutSet(
        id: 0,
        sessionId: 1,
        exerciseId: 1,
        weight: weight,
        reps: reps,
        durationSeconds: durationSeconds,
        distanceMetres: distanceMetres,
        isCompleted: false,
        timestamp: at ?? DateTime(2026, 1, 15),
      );
    }

    test('returns nothing when no sets survive', () {
      expect(computeRecords([], 'weightReps'), isEmpty);
    });

    test('weightReps keeps the heaviest, then the most reps', () {
      final result = computeRecords([
        set(weight: 80, reps: 8),
        set(weight: 100, reps: 3),
        set(weight: 100, reps: 5),
        set(weight: 90, reps: 10),
      ], 'weightReps');

      expect(result, hasLength(1));
      expect(result.single.weight, 100);
      expect(result.single.reps, 5);
    });

    test('carries the date of the set that earned it', () {
      final earned = DateTime(2025, 12, 20, 18, 30);
      final result = computeRecords([
        set(weight: 100, reps: 3, at: earned),
        set(weight: 80, reps: 8, at: DateTime(2026, 1, 15)),
      ], 'weightReps');

      expect(result.single.achievedAt, earned);
    });

    test('timeOnly keeps the longest hold', () {
      final result = computeRecords([
        set(durationSeconds: 60),
        set(durationSeconds: 95),
        set(durationSeconds: 80),
      ], 'timeOnly');

      expect(result.single.durationSeconds, 95);
    });

    test('distanceTime keeps the fastest time per distance', () {
      final result = computeRecords([
        set(distanceMetres: 400, durationSeconds: 90),
        set(distanceMetres: 5000, durationSeconds: 1500),
        set(distanceMetres: 400, durationSeconds: 82),
        set(distanceMetres: 5000, durationSeconds: 1600),
      ], 'distanceTime');

      expect(result, hasLength(2));
      expect(
        result.firstWhere((r) => r.distanceMetres == 400).durationSeconds,
        82,
      );
      expect(
        result.firstWhere((r) => r.distanceMetres == 5000).durationSeconds,
        1500,
      );
    });

    test('bodyweightReps judges unweighted sets on reps', () {
      final result = computeRecords([
        set(reps: 10),
        set(reps: 15),
        set(reps: 12),
      ], 'bodyweightReps');

      expect(result.single.reps, 15);
    });

    test('bodyweightReps judges a weighted set on weight', () {
      final result = computeRecords([
        set(reps: 15),
        set(weight: 10, reps: 5),
      ], 'bodyweightReps');

      expect(result.single.weight, 10);
      expect(result.single.reps, 5);
    });
  });

  // ---------------------------------------------------------------------------
  // Deleting
  // ---------------------------------------------------------------------------

  group('deleteSet', () {
    test('withdraws a record the deleted set earned', () async {
      await insertSet(weight: 100, reps: 3);
      final mistake = await insertSet(weight: 800, reps: 1);
      await rebuild();
      expect((await liveRecords()).single.weight, 800);

      await sessions().deleteSet(mistake);

      final remaining = await liveRecords();
      expect(remaining, hasLength(1));
      expect(remaining.single.weight, 100, reason: 'falls back to a real set');
    });

    test('leaves no record when the last set goes', () async {
      final only = await insertSet(weight: 100, reps: 3);
      await rebuild();

      await sessions().deleteSet(only);

      expect(await liveRecords(), isEmpty);
    });

    test('a withdrawn record is marked for removal upstream', () async {
      final only = await insertSet(weight: 100, reps: 3);
      await rebuild();

      await sessions().deleteSet(only);

      final row = (await db.select(db.personalBests).get()).single;
      expect(row.deletedAt, isNotNull);
      expect(row.syncedAt, isNull);
    });

    test('earning the record again revives it', () async {
      final only = await insertSet(weight: 100, reps: 3);
      await rebuild();
      await sessions().deleteSet(only);

      final pr = await records().checkAndSavePr(
        exerciseId: exerciseId,
        exerciseName: 'Bench Press',
        metricType: 'weightReps',
        weight: 90,
        reps: 5,
      );

      expect(pr, isNotNull);
      final live = await liveRecords();
      expect(live, hasLength(1));
      expect(live.single.weight, 90);
    });

    test('keeps the record when a lesser set is deleted', () async {
      await insertSet(weight: 100, reps: 3);
      final lesser = await insertSet(weight: 60, reps: 12);
      await rebuild();

      await sessions().deleteSet(lesser);

      expect((await liveRecords()).single.weight, 100);
    });
  });

  // ---------------------------------------------------------------------------
  // Editing
  // ---------------------------------------------------------------------------

  group('updateSet', () {
    test('corrects the set and the record it earned', () async {
      final typo = await insertSet(weight: 800, reps: 5);
      await rebuild();

      await sessions().updateSet(setId: typo, weight: 80, reps: 5);

      final set = (await db.select(db.workoutSets).get()).single;
      expect(set.weight, 80);
      expect((await liveRecords()).single.weight, 80);
    });

    test('an edit that beats the record takes it', () async {
      await insertSet(weight: 100, reps: 3);
      final light = await insertSet(weight: 60, reps: 12);
      await rebuild();

      await sessions().updateSet(setId: light, weight: 120, reps: 2);

      expect((await liveRecords()).single.weight, 120);
    });

    test('marks the set dirty for sync', () async {
      final id = await insertSet(weight: 100, reps: 3);
      await (db.update(db.workoutSets)..where((s) => s.id.equals(id))).write(
        WorkoutSetsCompanion(syncedAt: Value(DateTime(2026))),
      );

      await sessions().updateSet(setId: id, weight: 105, reps: 3);

      expect((await db.select(db.workoutSets).get()).single.syncedAt, isNull);
    });

    test('keeps the date the record was actually earned', () async {
      final earned = DateTime(2025, 12, 20, 18, 30);
      await insertSet(weight: 100, reps: 3, at: earned);
      final other = await insertSet(
        weight: 60,
        reps: 12,
        at: DateTime(2026, 1, 15, 11),
      );

      await sessions().updateSet(setId: other, weight: 65, reps: 12);

      expect((await liveRecords()).single.achievedAt, earned);
    });
  });
}
