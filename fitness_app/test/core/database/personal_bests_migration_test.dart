import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/core/database/local_database.dart';

/// Tests the v6 → v7 rebuild of personal_bests.
///
/// The unique key moves from (exercise_id, reps) to
/// (exercise_id, metric_type, distance_metres), so the duplicate rows the old
/// key allowed have to be collapsed to the single best record per key. This
/// runs the real migration over a real v6 database file.
void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('onerep_migration');
    dbFile = File('${tempDir.path}/app.sqlite');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  /// Seconds since the epoch — how drift stores a DateTime by default.
  int stamp(DateTime dt) => dt.millisecondsSinceEpoch ~/ 1000;

  /// Builds a database file in its v6 shape, seeded by [seed], and returns it
  /// closed and ready to be reopened by the migrating [AppDatabase].
  Future<void> buildV6Database(
    Future<void> Function(AppDatabase db) seed,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase(dbFile));

    // Create the tables at the current schema, then restore personal_bests to
    // its v6 definition and rewind the version drift reads on open.
    await db.customStatement('SELECT 1');
    // The v10 columns and their trigger did not exist yet. Dropping them is
    // what makes this file genuinely look like the older schema — without it
    // the v10 branch tries to add a column that is already there. Triggers go
    // first: SQLite refuses to drop a column a trigger references.
    await db.customStatement(
      'DROP TRIGGER IF EXISTS trg_exercises_modality_insert',
    );
    await db.customStatement(
      'DROP TRIGGER IF EXISTS trg_exercises_modality_update',
    );
    await db.customStatement('ALTER TABLE exercises DROP COLUMN modality');
    await db.customStatement('ALTER TABLE exercises DROP COLUMN category');
    await db.customStatement('DROP TABLE personal_bests');
    await db.customStatement('''
      CREATE TABLE personal_bests (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        exercise_id INTEGER NOT NULL REFERENCES exercises (id),
        reps INTEGER NOT NULL DEFAULT 0,
        weight REAL NOT NULL DEFAULT 0.0,
        duration_seconds INTEGER NULL,
        distance_metres REAL NULL,
        metric_type TEXT NOT NULL DEFAULT 'weightReps',
        achieved_at INTEGER NOT NULL,
        remote_id TEXT NULL,
        user_id TEXT NULL,
        synced_at INTEGER NULL,
        deleted_at INTEGER NULL,
        UNIQUE (exercise_id, reps)
      )
    ''');
    await seed(db);
    await db.customStatement('PRAGMA user_version = 6');
    await db.close();
  }

  Future<int> insertExercise(AppDatabase db, String name) {
    return db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            name: name,
            bodyPart: 'Chest',
            equipmentType: 'Barbell',
          ),
        );
  }

  Future<void> insertLegacyPr(
    AppDatabase db, {
    required int exerciseId,
    required int reps,
    double weight = 0.0,
    int? durationSeconds,
    double? distanceMetres,
    String metricType = 'weightReps',
    DateTime? achievedAt,
    String? remoteId,
  }) {
    return db.customStatement(
      'INSERT INTO personal_bests (exercise_id, reps, weight, '
      'duration_seconds, distance_metres, metric_type, achieved_at, '
      'remote_id, user_id, synced_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        exerciseId,
        reps,
        weight,
        durationSeconds,
        distanceMetres,
        metricType,
        stamp(achievedAt ?? DateTime(2026, 1, 5)),
        remoteId,
        'user-1',
        stamp(DateTime(2026, 1, 6)),
      ],
    );
  }

  test('collapses duplicates to the best record per key', () async {
    late int bench;
    late int pullUp;
    late int run;
    late int plank;

    await buildV6Database((db) async {
      bench = await insertExercise(db, 'Bench Press');
      pullUp = await insertExercise(db, 'Pull Up');
      run = await insertExercise(db, 'Run');
      plank = await insertExercise(db, 'Plank');

      // weightReps — a row per rep count, only the heaviest is the record.
      await insertLegacyPr(db, exerciseId: bench, reps: 8, weight: 80);
      await insertLegacyPr(db, exerciseId: bench, reps: 5, weight: 85);
      await insertLegacyPr(
        db,
        exerciseId: bench,
        reps: 3,
        weight: 100,
        remoteId: 'remote-bench',
        achievedAt: DateTime(2025, 12, 20),
      );

      // bodyweightReps — the state that used to throw on the next log.
      for (final reps in [10, 12, 15]) {
        await insertLegacyPr(
          db,
          exerciseId: pullUp,
          reps: reps,
          metricType: 'bodyweightReps',
        );
      }

      // distanceTime — two rows for one distance, plus a second distance.
      await insertLegacyPr(
        db,
        exerciseId: run,
        reps: 0,
        metricType: 'distanceTime',
        distanceMetres: 5000,
        durationSeconds: 1500,
      );
      await insertLegacyPr(
        db,
        exerciseId: run,
        reps: 1,
        metricType: 'distanceTime',
        distanceMetres: 5000,
        durationSeconds: 1440,
      );
      await insertLegacyPr(
        db,
        exerciseId: run,
        reps: 2,
        metricType: 'distanceTime',
        distanceMetres: 400,
        durationSeconds: 90,
      );

      // timeOnly — longest hold wins.
      await insertLegacyPr(
        db,
        exerciseId: plank,
        reps: 0,
        metricType: 'timeOnly',
        durationSeconds: 95,
      );
      await insertLegacyPr(
        db,
        exerciseId: plank,
        reps: 1,
        metricType: 'timeOnly',
        durationSeconds: 60,
      );
    });

    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    final rows = await db.select(db.personalBests).get();

    // 1 bench + 1 pull up + 2 run distances + 1 plank
    expect(rows, hasLength(5));

    final benchPr = rows.firstWhere((r) => r.exerciseId == bench);
    expect(benchPr.weight, 100);
    expect(benchPr.reps, 3);
    expect(benchPr.remoteId, 'remote-bench');
    expect(benchPr.achievedAt, DateTime(2025, 12, 20));
    expect(
      benchPr.syncedAt,
      isNull,
      reason: 'the surviving record must re-upload',
    );
    expect(benchPr.distanceMetres, 0.0, reason: 'null distance becomes 0');

    final pullUpPr = rows.firstWhere((r) => r.exerciseId == pullUp);
    expect(pullUpPr.reps, 15);

    final runPrs = rows.where((r) => r.exerciseId == run).toList();
    expect(runPrs, hasLength(2));
    expect(
      runPrs.firstWhere((r) => r.distanceMetres == 5000).durationSeconds,
      1440,
      reason: 'the faster time over the same distance survives',
    );
    expect(
      runPrs.firstWhere((r) => r.distanceMetres == 400).durationSeconds,
      90,
      reason: 'a separate distance is a separate record',
    );

    final plankPr = rows.firstWhere((r) => r.exerciseId == plank);
    expect(plankPr.durationSeconds, 95);
  });

  test('the new unique key is enforced after migrating', () async {
    late int bench;

    await buildV6Database((db) async {
      bench = await insertExercise(db, 'Bench Press');
      await insertLegacyPr(db, exerciseId: bench, reps: 3, weight: 100);
    });

    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    // Force the migration to run before probing the constraint.
    await db.select(db.personalBests).get();

    await expectLater(
      db
          .into(db.personalBests)
          .insert(
            PersonalBestsCompanion.insert(
              exerciseId: bench,
              reps: const Value(5),
              weight: const Value(90),
              achievedAt: DateTime(2026),
            ),
          ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('an empty personal_bests table migrates cleanly', () async {
    await buildV6Database((db) async {
      await insertExercise(db, 'Bench Press');
    });

    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    expect(await db.select(db.personalBests).get(), isEmpty);
  });
}
