import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:fitness_app/core/database/database_provider.dart';
import 'package:fitness_app/core/database/local_database.dart';
import 'package:fitness_app/features/workout/data/personal_best_repository.dart';

/// Regression tests for personal best records.
///
/// Before schema v7 the table was keyed on (exerciseId, reps), so the upserts
/// meant to replace a record inserted a new row per rep count instead. Three
/// failures followed, one per metric type, all covered here:
///   - bodyweight lookups threw "Bad state: Too many elements" on the third PR
///   - a distanceTime record was written over the wrong distance
///   - weightReps accumulated superseded rows
///
/// These drive the real repository against an in-memory database.
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late int exerciseId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    exerciseId = await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            name: 'Pull Up',
            bodyPart: 'Back',
            equipmentType: 'Bodyweight',
          ),
        );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  PersonalBestRepository repo() =>
      container.read(personalBestRepositoryProvider.notifier);

  Future<PrResult?> log({
    required String metricType,
    double weight = 0.0,
    int reps = 0,
    int? durationSeconds,
    double? distanceMetres,
  }) {
    return repo().checkAndSavePr(
      exerciseId: exerciseId,
      exerciseName: 'Pull Up',
      metricType: metricType,
      weight: weight,
      reps: reps,
      durationSeconds: durationSeconds,
      distanceMetres: distanceMetres,
    );
  }

  Future<List<PersonalBest>> records() => db.select(db.personalBests).get();

  // ---------------------------------------------------------------------------
  // bodyweightReps
  // ---------------------------------------------------------------------------

  group('bodyweightReps', () {
    test('keeps a single record across repeated PRs', () async {
      for (final reps in [10, 12, 15, 20]) {
        await log(metricType: 'bodyweightReps', reps: reps);
      }

      final rows = await records();
      expect(rows, hasLength(1));
      expect(rows.single.reps, 20);
    });

    test('logging after two PRs does not throw', () async {
      await log(metricType: 'bodyweightReps', reps: 10);
      await log(metricType: 'bodyweightReps', reps: 12);

      // The third call is what used to hit "Bad state: Too many elements".
      await expectLater(
        log(metricType: 'bodyweightReps', reps: 8),
        completion(isNull),
      );
    });

    test('fewer reps than the record is not a PR', () async {
      await log(metricType: 'bodyweightReps', reps: 15);

      expect(await log(metricType: 'bodyweightReps', reps: 12), isNull);
      expect((await records()).single.reps, 15);
    });

    test('added weight is compared as a weighted set', () async {
      await log(metricType: 'bodyweightReps', reps: 12);
      final pr = await log(metricType: 'bodyweightReps', weight: 10, reps: 5);

      expect(pr, isNotNull);
      final rows = await records();
      expect(rows, hasLength(1));
      expect(rows.single.weight, 10);
      expect(rows.single.reps, 5);
    });
  });

  // ---------------------------------------------------------------------------
  // distanceTime
  // ---------------------------------------------------------------------------

  group('distanceTime', () {
    test('keeps one record per distance', () async {
      await log(
        metricType: 'distanceTime',
        distanceMetres: 400,
        durationSeconds: 90,
      );
      await log(
        metricType: 'distanceTime',
        distanceMetres: 5000,
        durationSeconds: 1500,
      );

      final rows = await records();
      expect(rows, hasLength(2));

      final quarterMile = rows.firstWhere((r) => r.distanceMetres == 400);
      final fiveK = rows.firstWhere((r) => r.distanceMetres == 5000);
      expect(
        quarterMile.durationSeconds,
        90,
        reason: 'a 5k must not overwrite the 400m record',
      );
      expect(fiveK.durationSeconds, 1500);
    });

    test('a run of slightly different distances mints one record', () async {
      // The regression. Records key on a standard distance, so 5000 m then
      // 5040 m then 5080 m is the same 5 km three times — not three PRs.
      // Keyed on the raw distance, every run was a personal best, the table
      // grew without bound and `pr_10` fired after ten runs having beaten
      // nothing at all.
      for (var i = 0; i < 10; i++) {
        await log(
          metricType: 'distanceTime',
          distanceMetres: 5000 + i * 40.0,
          durationSeconds: 1500 + i * 10,
        );
      }

      final rows = await records();
      expect(rows, hasLength(1));
      expect(rows.single.distanceMetres, 5000);
      expect(
        rows.single.durationSeconds,
        1500,
        reason: 'the first run was the fastest, and nothing since beat it',
      );
    });

    test('a longer distance still earns its own record', () async {
      await log(
        metricType: 'distanceTime',
        distanceMetres: 5200,
        durationSeconds: 1500,
      );
      await log(
        metricType: 'distanceTime',
        distanceMetres: 10400,
        durationSeconds: 3200,
      );

      final rows = await records();
      expect(rows.map((r) => r.distanceMetres).toSet(), {5000.0, 10000.0});
    });

    test('an effort shorter than any standard distance earns none', () async {
      final pr = await log(
        metricType: 'distanceTime',
        distanceMetres: 60,
        durationSeconds: 12,
      );

      expect(pr, isNull);
      expect(await records(), isEmpty);
    });

    test('a faster time over the same distance replaces the record', () async {
      await log(
        metricType: 'distanceTime',
        distanceMetres: 5000,
        durationSeconds: 1500,
      );
      final pr = await log(
        metricType: 'distanceTime',
        distanceMetres: 5000,
        durationSeconds: 1440,
      );

      expect(pr, isNotNull);
      final rows = await records();
      expect(rows, hasLength(1));
      expect(rows.single.durationSeconds, 1440);
    });

    test('a slower time over the same distance is not a PR', () async {
      await log(
        metricType: 'distanceTime',
        distanceMetres: 5000,
        durationSeconds: 1440,
      );

      expect(
        await log(
          metricType: 'distanceTime',
          distanceMetres: 5000,
          durationSeconds: 1600,
        ),
        isNull,
      );
      expect((await records()).single.durationSeconds, 1440);
    });
  });

  // ---------------------------------------------------------------------------
  // weightReps and timeOnly
  // ---------------------------------------------------------------------------

  group('weightReps', () {
    test('the first set logged is always a PR', () async {
      final pr = await log(metricType: 'weightReps', weight: 60, reps: 10);

      expect(pr, isNotNull);
      expect(pr!.weight, 60);
      expect((await records()).single.weight, 60);
    });

    test('repeating the record set is not a PR', () async {
      await log(metricType: 'weightReps', weight: 100, reps: 3);

      expect(await log(metricType: 'weightReps', weight: 100, reps: 3), isNull);
      expect(await records(), hasLength(1));
    });

    test('a run of improvements leaves only the last', () async {
      for (final weight in [60.0, 70.0, 80.0, 90.0]) {
        expect(
          await log(metricType: 'weightReps', weight: weight, reps: 5),
          isNotNull,
          reason: '$weight kg beats the record before it',
        );
      }

      final rows = await records();
      expect(rows, hasLength(1));
      expect(rows.single.weight, 90);
    });

    test('keeps a single record as the weight climbs', () async {
      await log(metricType: 'weightReps', weight: 80, reps: 8);
      await log(metricType: 'weightReps', weight: 85, reps: 5);
      await log(metricType: 'weightReps', weight: 100, reps: 3);

      final rows = await records();
      expect(rows, hasLength(1));
      expect(rows.single.weight, 100);
      expect(rows.single.reps, 3);
    });

    test('more reps at the same weight is a PR', () async {
      await log(metricType: 'weightReps', weight: 100, reps: 3);
      final pr = await log(metricType: 'weightReps', weight: 100, reps: 5);

      expect(pr, isNotNull);
      expect((await records()).single.reps, 5);
    });

    test('a lighter set is not a PR', () async {
      await log(metricType: 'weightReps', weight: 100, reps: 3);

      expect(await log(metricType: 'weightReps', weight: 90, reps: 8), isNull);
      expect((await records()).single.weight, 100);
    });
  });

  group('timeOnly', () {
    test('keeps the longest hold in a single record', () async {
      await log(metricType: 'timeOnly', durationSeconds: 60);
      await log(metricType: 'timeOnly', durationSeconds: 95);

      expect(await log(metricType: 'timeOnly', durationSeconds: 80), isNull);

      final rows = await records();
      expect(rows, hasLength(1));
      expect(rows.single.durationSeconds, 95);
    });
  });

  // ---------------------------------------------------------------------------
  // Cross-cutting
  // ---------------------------------------------------------------------------

  test('records of different metric types coexist for one exercise', () async {
    await log(metricType: 'weightReps', weight: 100, reps: 3);
    await log(metricType: 'bodyweightReps', reps: 15);
    await log(metricType: 'timeOnly', durationSeconds: 90);
    await log(
      metricType: 'distanceTime',
      distanceMetres: 400,
      durationSeconds: 80,
    );

    expect(await records(), hasLength(4));
  });

  test('a new record is left dirty so it uploads on the next sync', () async {
    await log(metricType: 'weightReps', weight: 100, reps: 3);
    await (db.update(db.personalBests)..where((pb) => pb.id.isNotNull())).write(
      PersonalBestsCompanion(syncedAt: Value(DateTime(2026))),
    );

    await log(metricType: 'weightReps', weight: 105, reps: 3);

    expect((await records()).single.syncedAt, isNull);
  });
}
