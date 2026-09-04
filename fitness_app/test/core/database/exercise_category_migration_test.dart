import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/core/database/exercise_seed.dart';
import 'package:fitness_app/core/database/local_database.dart';

import 'schema_fixture.dart';

/// Tests the v9 → v10 move to activity categories.
///
/// Two things here are only observable through a real migration over a real
/// file. The first is the retirement of the `Full Body` muscle: an install
/// that ran v9 holds `exercise_muscles` rows whose muscle is `'fullBody'`, and
/// deleting the enum value without purging them would leave the catalogue
/// silently skipping those rows — Running rendering as Unassigned with nothing
/// anywhere to say why. The second is the seed insert, which is the one narrow
/// case where a migration may add default exercises, and only because `since`
/// restricts it to names that have never shipped.
void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('onerep_categories');
    dbFile = File('${tempDir.path}/app.sqlite');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  /// Builds a database file in its v9 shape.
  ///
  /// v9 is the current schema minus `category`, `modality` and the trigger
  /// that ties them together. Triggers are dropped first — SQLite refuses to
  /// drop a column a trigger references.
  Future<void> buildV9Database(
    Future<void> Function(AppDatabase db) seed,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    await db.customStatement('SELECT 1'); // force onCreate
    await db.customStatement(
      'DROP TRIGGER IF EXISTS trg_exercises_modality_insert',
    );
    await db.customStatement(
      'DROP TRIGGER IF EXISTS trg_exercises_modality_update',
    );
    await db.customStatement('ALTER TABLE exercises DROP COLUMN modality');
    await db.customStatement('ALTER TABLE exercises DROP COLUMN category');
    // The v11 target columns did not exist yet either.
    await db.customStatement(
      'ALTER TABLE routine_exercises DROP COLUMN target_distance_metres',
    );
    await db.customStatement(
      'ALTER TABLE routine_exercises DROP COLUMN target_duration_seconds',
    );
    await seed(db);
    await makeLookLikeVersion(db, 9);
    await db.close();
  }

  Future<AppDatabase> migrate() async {
    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    await db.customStatement('SELECT 1');
    return db;
  }

  /// Inserts an exercise in its v9 shape, optionally with muscle rows.
  Future<int> insertExercise(
    AppDatabase db, {
    required String name,
    required String bodyPart,
    String metricType = 'weightReps',
    bool isCustom = false,
    String? primaryMuscle,
    DateTime? syncedAt,
  }) async {
    await db.customStatement(
      'INSERT INTO exercises (name, body_part, equipment_type, is_custom, '
      'metric_type, user_id, synced_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [
        name,
        bodyPart,
        'Barbell',
        isCustom ? 1 : 0,
        metricType,
        isCustom ? 'user-1' : null,
        syncedAt?.millisecondsSinceEpoch == null
            ? null
            : syncedAt!.millisecondsSinceEpoch ~/ 1000,
      ],
    );
    final row = await db
        .customSelect('SELECT last_insert_rowid() AS id')
        .getSingle();
    final id = row.read<int>('id');

    if (primaryMuscle != null) {
      await db.customStatement(
        'INSERT INTO exercise_muscles (exercise_id, muscle, is_primary) '
        'VALUES (?, ?, 1)',
        [id, primaryMuscle],
      );
    }
    return id;
  }

  Future<({String category, String? modality})> filingOf(
    AppDatabase db,
    String name,
  ) async {
    final row = await db
        .customSelect(
          'SELECT category, modality FROM exercises WHERE name = ?',
          variables: [Variable<String>(name)],
        )
        .getSingle();
    return (
      category: row.read<String>('category'),
      modality: row.readNullable<String>('modality'),
    );
  }

  // ---------------------------------------------------------------------------
  // Refiling the defaults
  // ---------------------------------------------------------------------------

  test('the seeded cardio exercises gain a category and a modality', () async {
    await buildV9Database((db) async {
      await insertExercise(
        db,
        name: 'Running',
        bodyPart: 'Full Body',
        metricType: 'distanceTime',
        primaryMuscle: 'fullBody',
      );
      await insertExercise(
        db,
        name: 'Rowing Machine',
        bodyPart: 'Full Body',
        metricType: 'distanceTime',
        primaryMuscle: 'fullBody',
      );
    });

    final db = await migrate();
    addTearDown(db.close);

    expect(await filingOf(db, 'Running'), (
      category: 'cardio',
      modality: 'run',
    ));
    expect(await filingOf(db, 'Rowing Machine'), (
      category: 'cardio',
      modality: 'row',
    ));
  });

  test('a strength default is left alone', () async {
    await buildV9Database((db) async {
      await insertExercise(
        db,
        name: 'Bench Press',
        bodyPart: 'Chest',
        primaryMuscle: 'chest',
      );
    });

    final db = await migrate();
    addTearDown(db.close);

    expect(await filingOf(db, 'Bench Press'), (
      category: 'strength',
      modality: null,
    ));
  });

  // ---------------------------------------------------------------------------
  // Retiring Full Body
  // ---------------------------------------------------------------------------

  test('no fullBody muscle row survives the migration', () async {
    await buildV9Database((db) async {
      await insertExercise(
        db,
        name: 'Running',
        bodyPart: 'Full Body',
        metricType: 'distanceTime',
        primaryMuscle: 'fullBody',
      );
      await insertExercise(
        db,
        name: 'Circuit Blast',
        bodyPart: 'Full Body',
        isCustom: true,
        primaryMuscle: 'fullBody',
      );
    });

    final db = await migrate();
    addTearDown(db.close);

    final left = await db
        .customSelect(
          "SELECT COUNT(*) AS n FROM exercise_muscles WHERE muscle = 'fullBody'",
        )
        .getSingle();
    expect(
      left.read<int>('n'),
      0,
      reason: 'a row the enum can no longer parse is invisible, not an error',
    );
  });

  test('a seeded cardio exercise gets the muscles it really works', () async {
    await buildV9Database((db) async {
      await insertExercise(
        db,
        name: 'Running',
        bodyPart: 'Full Body',
        metricType: 'distanceTime',
        primaryMuscle: 'fullBody',
      );
    });

    final db = await migrate();
    addTearDown(db.close);

    final rows = await db
        .customSelect(
          'SELECT em.muscle AS muscle, em.is_primary AS is_primary '
          'FROM exercise_muscles em JOIN exercises e ON e.id = em.exercise_id '
          "WHERE e.name = 'Running'",
        )
        .get();

    final primary = rows.firstWhere((r) => r.read<int>('is_primary') == 1);
    expect(primary.read<String>('muscle'), 'quads');
    expect(
      rows.map((r) => r.read<String>('muscle')),
      containsAll(['hamstrings', 'glutes', 'calves']),
    );
  });

  test('a custom exercise filed under Full Body becomes unassigned', () async {
    // Losing the primary is the point: any replacement would be a claim about
    // anatomy the app cannot support, and "Unassigned" is visible.
    await buildV9Database((db) async {
      await insertExercise(
        db,
        name: 'Circuit Blast',
        bodyPart: 'Full Body',
        isCustom: true,
        primaryMuscle: 'fullBody',
      );
    });

    final db = await migrate();
    addTearDown(db.close);

    final row = await db
        .customSelect(
          'SELECT e.body_part AS body_part, e.synced_at AS synced_at, '
          '  (SELECT COUNT(*) FROM exercise_muscles em '
          '    WHERE em.exercise_id = e.id) AS muscles '
          "FROM exercises e WHERE e.name = 'Circuit Blast'",
        )
        .getSingle();

    expect(row.read<int>('muscles'), 0);
    expect(row.read<String>('body_part'), 'Unassigned');
    expect(row.readNullable<int>('synced_at'), isNull);
  });

  // ---------------------------------------------------------------------------
  // The new seed rows
  // ---------------------------------------------------------------------------

  test('the exercises added at v10 are inserted', () async {
    await buildV9Database((db) async {
      await insertExercise(
        db,
        name: 'Bench Press',
        bodyPart: 'Chest',
        primaryMuscle: 'chest',
      );
    });

    final db = await migrate();
    addTearDown(db.close);

    expect(await filingOf(db, 'Treadmill Run'), (
      category: 'cardio',
      modality: 'run',
    ));
    expect(await filingOf(db, 'Hamstring Stretch'), (
      category: 'mobility',
      modality: null,
    ));
  });

  test('a deleted default is not resurrected', () async {
    // The v10 insert is restricted by `since` for exactly this reason: it only
    // adds names that have never shipped, so it cannot undo a deletion.
    await buildV9Database((db) async {
      await insertExercise(
        db,
        name: 'Bench Press',
        bodyPart: 'Chest',
        primaryMuscle: 'chest',
      );
      // 'Running' shipped at v9 and the user deleted it.
    });

    final db = await migrate();
    addTearDown(db.close);

    final running = await db
        .customSelect(
          "SELECT COUNT(*) AS n FROM exercises WHERE name = 'Running'",
        )
        .getSingle();
    expect(running.read<int>('n'), 0);
  });

  test('a custom exercise does not gain a seeded twin', () async {
    await buildV9Database((db) async {
      await insertExercise(
        db,
        name: 'Jump Rope',
        bodyPart: 'Legs',
        metricType: 'timeOnly',
        isCustom: true,
        primaryMuscle: 'calves',
      );
    });

    final db = await migrate();
    addTearDown(db.close);

    final rows = await db
        .customSelect(
          "SELECT is_custom FROM exercises WHERE name = 'Jump Rope'",
        )
        .get();
    expect(rows, hasLength(1));
    expect(rows.single.read<int>('is_custom'), 1);
  });

  // ---------------------------------------------------------------------------
  // Categorising custom exercises
  // ---------------------------------------------------------------------------

  test('a custom distanceTime exercise is filed as cardio', () async {
    await buildV9Database((db) async {
      await insertExercise(
        db,
        name: 'Canal Run',
        bodyPart: 'Legs',
        metricType: 'distanceTime',
        isCustom: true,
        primaryMuscle: 'quads',
        syncedAt: DateTime(2026, 5, 1),
      );
    });

    final db = await migrate();
    addTearDown(db.close);

    expect(await filingOf(db, 'Canal Run'), (
      category: 'cardio',
      modality: 'other',
    ));

    final synced = await db
        .customSelect(
          "SELECT synced_at FROM exercises WHERE name = 'Canal Run'",
        )
        .getSingle();
    expect(
      synced.readNullable<int>('synced_at'),
      isNull,
      reason: 'the corrected category has to upload',
    );
  });

  test('a custom timeOnly exercise deliberately stays strength', () async {
    // timeOnly covers Plank and Dead Hang as well as every stretch, so
    // guessing Mobility would misfile the holds instead. Leaving it put means
    // the exercise stays where the user last saw it.
    await buildV9Database((db) async {
      await insertExercise(
        db,
        name: 'Wall Sit',
        bodyPart: 'Legs',
        metricType: 'timeOnly',
        isCustom: true,
        primaryMuscle: 'quads',
      );
    });

    final db = await migrate();
    addTearDown(db.close);

    expect(await filingOf(db, 'Wall Sit'), (
      category: 'strength',
      modality: null,
    ));
  });

  // ---------------------------------------------------------------------------
  // The constraint, and re-entrancy
  // ---------------------------------------------------------------------------

  test('modality is required for cardio and forbidden otherwise', () async {
    await buildV9Database((db) async {
      await insertExercise(db, name: 'Bench Press', bodyPart: 'Chest');
    });

    final db = await migrate();
    addTearDown(db.close);

    await expectLater(
      db.customStatement(
        'INSERT INTO exercises (name, body_part, equipment_type, is_custom, '
        "metric_type, category) VALUES ('Bad Cardio', 'Legs', 'Other', 1, "
        "'distanceTime', 'cardio')",
      ),
      throwsA(isA<SqliteException>()),
      reason: 'cardio without a modality',
    );

    await expectLater(
      db.customStatement(
        'INSERT INTO exercises (name, body_part, equipment_type, is_custom, '
        "metric_type, category, modality) VALUES ('Bad Lift', 'Chest', "
        "'Barbell', 1, 'weightReps', 'strength', 'run')",
      ),
      throwsA(isA<SqliteException>()),
      reason: 'a modality on something that is not cardio',
    );
  });

  test('reopening the migrated file changes nothing', () async {
    await buildV9Database((db) async {
      await insertExercise(
        db,
        name: 'Running',
        bodyPart: 'Full Body',
        metricType: 'distanceTime',
        primaryMuscle: 'fullBody',
      );
    });

    final first = await migrate();
    final before = await first
        .customSelect('SELECT COUNT(*) AS n FROM exercises')
        .getSingle();
    await first.close();

    final second = await migrate();
    addTearDown(second.close);
    final after = await second
        .customSelect('SELECT COUNT(*) AS n FROM exercises')
        .getSingle();

    expect(after.read<int>('n'), before.read<int>('n'));
  });

  test('the seed and a fresh install agree on every category', () async {
    // A fresh install runs onCreate; an upgrade runs the migration. If the two
    // disagreed, the same exercise would be filed differently depending on
    // when the user installed.
    await buildV9Database((db) async {
      for (final seed in kSeedExercises.where((s) => s.since <= 9)) {
        await insertExercise(
          db,
          name: seed.name,
          bodyPart: seed.primary?.group.label ?? 'Unassigned',
          metricType: seed.metricType,
          primaryMuscle: seed.primary?.name,
        );
      }
    });

    final db = await migrate();
    addTearDown(db.close);

    for (final seed in kSeedExercises) {
      expect(await filingOf(db, seed.name), (
        category: seed.category.name,
        modality: seed.modality?.name,
      ), reason: seed.name);
    }
  });
}
