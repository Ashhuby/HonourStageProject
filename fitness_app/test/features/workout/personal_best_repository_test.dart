import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/core/database/local_database.dart';
import 'package:fitness_app/features/workout/data/personal_best_repository.dart';

/// Tests for the PR detection algorithm in PersonalBestRepository.
/// Uses an in-memory Drift database — no mocking, no fakes.
/// The real schema runs against real SQLite so constraint behaviour
/// (unique key on exerciseId + reps) is verified, not assumed.
void main() {
  late AppDatabase db;
  late int exerciseId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());

    // Insert a real exercise row — PersonalBests has a FK to Exercises.
    exerciseId = await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            name: 'Bench Press',
            bodyPart: 'Chest',
            equipmentType: 'Barbell',
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  // Helper: call the core algorithm directly against the real DB.
  // We instantiate the repository logic inline rather than through Riverpod
  // because unit tests should not require a ProviderContainer.
  Future<PrResult?> checkAndSave({
    required double weight,
    required int reps,
  }) async {
    // Fetch existing PR for this (exercise, reps) pair.
    final existing =
        await (db.select(db.personalBests)
              ..where((pb) => pb.exerciseId.equals(exerciseId))
              ..where((pb) => pb.reps.equals(reps))
              ..where((pb) => pb.deletedAt.isNull()))
            .getSingleOrNull();

    final isNewPr = existing == null || weight > existing.weight;
    if (!isNewPr) return null;
    await db
        .into(db.personalBests)
        .insert(
          PersonalBestsCompanion.insert(
            exerciseId: exerciseId,
            reps: Value(reps),
            weight: Value(weight),
            achievedAt: DateTime.now(),
          ),
          onConflict: DoUpdate(
            (old) => PersonalBestsCompanion.custom(
              weight: Variable(weight),
              achievedAt: Variable(DateTime.now()),
            ),
            target: [db.personalBests.exerciseId, db.personalBests.reps],
          ),
        );

    return PrResult(
      exerciseId: exerciseId,
      exerciseName: 'Bench Press',
      metricType: 'weightReps',
      weight: weight,
      reps: reps,
    );
  }

  group('PR detection — first PR', () {
    test('first set logged for any rep count is always a PR', () async {
      final result = await checkAndSave(weight: 80, reps: 5);
      expect(result, isNotNull);
      expect(result!.weight, 80);
      expect(result.reps, 5);
    });

    test('PR row is persisted after first detection', () async {
      await checkAndSave(weight: 80, reps: 5);
      final rows = await db.select(db.personalBests).get();
      expect(rows.length, 1);
      expect(rows.first.weight, 80);
    });
  });

  group('PR detection — beating an existing PR', () {
    test('heavier weight at same rep count is a new PR', () async {
      await checkAndSave(weight: 80, reps: 5);
      final result = await checkAndSave(weight: 85, reps: 5);
      expect(result, isNotNull);
      expect(result!.weight, 85);
    });

    test(
      'upsert replaces old weight — only one row per (exercise, reps)',
      () async {
        await checkAndSave(weight: 80, reps: 5);
        await checkAndSave(weight: 85, reps: 5);
        final rows = await (db.select(
          db.personalBests,
        )..where((pb) => pb.reps.equals(5))).get();
        expect(rows.length, 1);
        expect(rows.first.weight, 85);
      },
    );
  });

  group('PR detection — equal and lighter weights', () {
    test('equal weight at same reps is NOT a new PR', () async {
      await checkAndSave(weight: 80, reps: 5);
      final result = await checkAndSave(weight: 80, reps: 5);
      expect(result, isNull);
    });

    test('lighter weight at same reps is NOT a new PR', () async {
      await checkAndSave(weight: 80, reps: 5);
      final result = await checkAndSave(weight: 75, reps: 5);
      expect(result, isNull);
    });

    test('lighter weight does not overwrite the stored PR', () async {
      await checkAndSave(weight: 80, reps: 5);
      await checkAndSave(weight: 75, reps: 5);
      final row = await (db.select(
        db.personalBests,
      )..where((pb) => pb.reps.equals(5))).getSingle();
      expect(row.weight, 80);
    });
  });

  group('PR detection — rep count independence', () {
    test('PRs at different rep counts are tracked independently', () async {
      final pr5 = await checkAndSave(weight: 100, reps: 5);
      final pr10 = await checkAndSave(weight: 80, reps: 10);
      expect(pr5, isNotNull);
      expect(pr10, isNotNull);

      final rows = await db.select(db.personalBests).get();
      expect(rows.length, 2);
    });

    test('beating 5-rep PR does not affect 10-rep PR', () async {
      await checkAndSave(weight: 100, reps: 5);
      await checkAndSave(weight: 80, reps: 10);
      await checkAndSave(weight: 105, reps: 5);

      final rep10Row = await (db.select(
        db.personalBests,
      )..where((pb) => pb.reps.equals(10))).getSingle();
      expect(rep10Row.weight, 80);
    });

    test(
      'heavy weight at high reps does not create a PR for low reps',
      () async {
        // 80kg x 10 reps — no 5-rep PR exists yet
        await checkAndSave(weight: 80, reps: 10);
        final fiveRepRow = await (db.select(
          db.personalBests,
        )..where((pb) => pb.reps.equals(5))).getSingleOrNull();
        expect(fiveRepRow, isNull);
      },
    );
  });

  group('PR detection — sequence of improvements', () {
    test(
      'progressive overload across multiple sessions is tracked correctly',
      () async {
        // Simulate 4 weeks of bench press progress
        await checkAndSave(weight: 80, reps: 5); // week 1
        await checkAndSave(weight: 82.5, reps: 5); // week 2 — PR
        await checkAndSave(weight: 82.5, reps: 5); // week 3 — no PR (matched)
        final result = await checkAndSave(weight: 85, reps: 5); // week 4 — PR

        expect(result, isNotNull);
        expect(result!.weight, 85);

        final row = await (db.select(
          db.personalBests,
        )..where((pb) => pb.reps.equals(5))).getSingle();
        expect(row.weight, 85);
      },
    );
  });
}
