import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/core/database/exercise_seed.dart';
import 'package:fitness_app/core/database/local_database.dart';
import 'package:fitness_app/features/workout/domain/muscle.dart';

/// Tests the v8 → v9 move from a single `body_part` string to a primary muscle
/// plus secondaries in `exercise_muscles`.
///
/// This runs the real migration over a real database file, following
/// `personal_bests_migration_test.dart`. That matters more here than usual:
/// the migration also repairs two pre-existing data defects — the duplicate
/// exercises the v6 upgrade inserted, and the missing uniqueness constraint
/// that let it — and neither repair is observable any other way.
void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('onerep_muscles');
    dbFile = File('${tempDir.path}/app.sqlite');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  int stamp(DateTime dt) => dt.millisecondsSinceEpoch ~/ 1000;

  /// Builds a database file in its v8 shape, seeded by [seed], closed and
  /// ready for the migrating [AppDatabase] to reopen.
  ///
  /// The v8 shape is the current one minus `exercise_muscles`, so dropping
  /// that table is enough. Its indexes go with it, which is why every
  /// `CREATE INDEX` in the migration says `IF NOT EXISTS`.
  Future<void> buildV8Database(
    Future<void> Function(AppDatabase db) seed,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    await db.customStatement('SELECT 1'); // force onCreate
    await db.customStatement('DROP TABLE exercise_muscles');
    // The uniqueness guards did not exist at v8 either, and the duplicate
    // fixtures below could not be inserted while they do.
    await db.customStatement('DROP INDEX IF EXISTS idx_exercises_seed_name');
    await db.customStatement('DROP INDEX IF EXISTS idx_exercises_remote_id');
    await seed(db);
    await db.customStatement('PRAGMA user_version = 8');
    await db.close();
  }

  /// Reopens the file, running the v9 migration, and hands back the database.
  Future<AppDatabase> migrate() async {
    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    await db.customStatement('SELECT 1');
    return db;
  }

  Future<int> insertExercise(
    AppDatabase db, {
    required String name,
    required String bodyPart,
    bool isCustom = false,
    String? remoteId,
    DateTime? syncedAt,
  }) async {
    await db.customStatement(
      'INSERT INTO exercises (name, body_part, equipment_type, is_custom, '
      'metric_type, remote_id, user_id, synced_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [
        name,
        bodyPart,
        'Barbell',
        isCustom ? 1 : 0,
        'weightReps',
        remoteId,
        isCustom ? 'user-1' : null,
        syncedAt == null ? null : stamp(syncedAt),
      ],
    );
    final row = await db
        .customSelect('SELECT last_insert_rowid() AS id')
        .getSingle();
    return row.read<int>('id');
  }

  /// The muscles recorded for one exercise, primary first.
  Future<({Muscle? primary, List<Muscle> secondary})> musclesOf(
    AppDatabase db,
    int exerciseId,
  ) async {
    final rows = await db
        .customSelect(
          'SELECT muscle, is_primary FROM exercise_muscles WHERE exercise_id = ?',
          variables: [Variable<int>(exerciseId)],
        )
        .get();

    Muscle? primary;
    final secondary = <Muscle>[];
    for (final row in rows) {
      final muscle = Muscle.byNameOrNull(row.read<String>('muscle'));
      if (muscle == null) continue;
      if (row.read<int>('is_primary') == 1) {
        primary = muscle;
      } else {
        secondary.add(muscle);
      }
    }
    return (primary: primary, secondary: secondary);
  }

  Future<String> bodyPartOf(AppDatabase db, int id) async {
    final row = await db
        .customSelect(
          'SELECT body_part FROM exercises WHERE id = ?',
          variables: [Variable<int>(id)],
        )
        .getSingle();
    return row.read<String>('body_part');
  }

  // ---------------------------------------------------------------------------
  // Seeded exercises
  // ---------------------------------------------------------------------------

  test('a seeded exercise gains its primary and secondary muscles', () async {
    late int dips;
    await buildV8Database((db) async {
      dips = await insertExercise(db, name: 'Dips', bodyPart: 'Chest');
    });

    final db = await migrate();
    addTearDown(db.close);

    final muscles = await musclesOf(db, dips);
    expect(muscles.primary, Muscle.chest);
    expect(muscles.secondary, containsAll([Muscle.triceps, Muscle.frontDelts]));
    expect(muscles.secondary, hasLength(2));
  });

  test('an exercise with no secondaries gets exactly one row', () async {
    late int calfRaise;
    await buildV8Database((db) async {
      calfRaise = await insertExercise(
        db,
        name: 'Calf Raise',
        bodyPart: 'Legs',
      );
    });

    final db = await migrate();
    addTearDown(db.close);

    final muscles = await musclesOf(db, calfRaise);
    expect(muscles.primary, Muscle.calves);
    expect(muscles.secondary, isEmpty);
  });

  test('seeded rows are matched on name, not on body_part', () async {
    // A library that never ran the v8 refile still has Chin Ups under Biceps.
    // The name match must win, or it would be backfilled as an arm exercise.
    late int chinUps;
    await buildV8Database((db) async {
      chinUps = await insertExercise(db, name: 'Chin Ups', bodyPart: 'Biceps');
    });

    final db = await migrate();
    addTearDown(db.close);

    final muscles = await musclesOf(db, chinUps);
    expect(muscles.primary, Muscle.lats);
    expect(muscles.secondary, contains(Muscle.biceps));
    expect(await bodyPartOf(db, chinUps), 'Back');
  });

  test('every exercise ends with exactly one primary', () async {
    await buildV8Database((db) async {
      await insertExercise(db, name: 'Squat', bodyPart: 'Legs');
      await insertExercise(db, name: 'Plank', bodyPart: 'Core');
      await insertExercise(
        db,
        name: 'Zercher Squat',
        bodyPart: 'Legs',
        isCustom: true,
      );
    });

    final db = await migrate();
    addTearDown(db.close);

    final rows = await db
        .customSelect(
          'SELECT e.id AS id, COUNT(em.muscle) AS primaries FROM exercises e '
          'LEFT JOIN exercise_muscles em '
          '  ON em.exercise_id = e.id AND em.is_primary = 1 '
          'GROUP BY e.id',
        )
        .get();

    expect(rows, isNotEmpty);
    for (final row in rows) {
      expect(
        row.read<int>('primaries'),
        1,
        reason: 'id ${row.read<int>('id')}',
      );
    }
  });

  // ---------------------------------------------------------------------------
  // Everything that is not a pristine seeded row
  // ---------------------------------------------------------------------------

  test('a custom exercise migrates from its old label', () async {
    late int custom;
    await buildV8Database((db) async {
      custom = await insertExercise(
        db,
        name: 'Preacher Curl',
        bodyPart: 'Biceps',
        isCustom: true,
        remoteId: 'remote-1',
        syncedAt: DateTime(2026, 2, 1),
      );
    });

    final db = await migrate();
    addTearDown(db.close);

    final muscles = await musclesOf(db, custom);
    expect(muscles.primary, Muscle.biceps);
    expect(muscles.secondary, isEmpty);
    // Biceps is no longer a group — the label becomes its group, Arms.
    expect(await bodyPartOf(db, custom), 'Arms');

    // And the corrected label must upload, so the row goes dirty.
    final synced = await db
        .customSelect(
          'SELECT synced_at FROM exercises WHERE id = ?',
          variables: [Variable<int>(custom)],
        )
        .getSingle();
    expect(synced.readNullable<int>('synced_at'), isNull);
  });

  test('an unrecognised body_part does not throw', () async {
    // body_part is free TEXT, so a row can carry anything at all.
    late int odd;
    await buildV8Database((db) async {
      odd = await insertExercise(
        db,
        name: 'Wrist Roller',
        bodyPart: 'Nonsense',
        isCustom: true,
      );
    });

    final db = await migrate();
    addTearDown(db.close);

    final muscles = await musclesOf(db, odd);
    expect(muscles.primary, Muscle.fullBody);
    expect(await bodyPartOf(db, odd), 'Full Body');
  });

  test('a renamed default falls through to the label path', () async {
    late int renamed;
    await buildV8Database((db) async {
      renamed = await insertExercise(
        db,
        name: 'Bench Press (Comp)',
        bodyPart: 'Chest',
      );
    });

    final db = await migrate();
    addTearDown(db.close);

    final muscles = await musclesOf(db, renamed);
    expect(muscles.primary, Muscle.chest);
    expect(
      muscles.secondary,
      isEmpty,
      reason: 'no name match, so no seed data',
    );

    // It must not have been deleted along the way.
    final still = await db
        .customSelect(
          'SELECT COUNT(*) AS n FROM exercises WHERE id = ?',
          variables: [Variable<int>(renamed)],
        )
        .getSingle();
    expect(still.read<int>('n'), 1);
  });

  test('a deleted default is a no-op, leaving no orphan rows', () async {
    await buildV8Database((db) async {
      await insertExercise(db, name: 'Dips', bodyPart: 'Chest');
      // Squat is simply absent.
    });

    final db = await migrate();
    addTearDown(db.close);

    final orphans = await db
        .customSelect(
          'SELECT COUNT(*) AS n FROM exercise_muscles em '
          'WHERE em.exercise_id NOT IN (SELECT id FROM exercises)',
        )
        .getSingle();
    expect(orphans.read<int>('n'), 0);
  });

  // ---------------------------------------------------------------------------
  // The v6 duplicate repair
  // ---------------------------------------------------------------------------

  test('duplicate seeded exercises collapse, carrying their history', () async {
    late int keep;
    late int drop;

    await buildV8Database((db) async {
      keep = await insertExercise(db, name: 'Bench Press', bodyPart: 'Chest');
      drop = await insertExercise(db, name: 'Bench Press', bodyPart: 'Chest');

      final splitId = await db
          .customSelect(
            "INSERT INTO workout_splits (name) VALUES ('PPL') RETURNING id",
          )
          .getSingle();
      final routineId = await db
          .customSelect(
            'INSERT INTO workout_routines (split_id, name, order_index) '
            "VALUES (?, 'Push', 0) RETURNING id",
            variables: [Variable<int>(splitId.read<int>('id'))],
          )
          .getSingle();

      // A routine references the survivor; a logged set references the loser.
      await db.customStatement(
        'INSERT INTO routine_exercises '
        '(routine_id, exercise_id, target_sets, target_reps, order_index) '
        'VALUES (?, ?, 3, 5, 0)',
        [routineId.read<int>('id'), keep],
      );
      final sessionId = await db
          .customSelect(
            'INSERT INTO workout_sessions (start_time) VALUES (?) RETURNING id',
            variables: [Variable<int>(stamp(DateTime(2026, 3, 1)))],
          )
          .getSingle();
      await db.customStatement(
        'INSERT INTO workout_sets (session_id, exercise_id, weight, reps, '
        'timestamp) VALUES (?, ?, 100.0, 5, ?)',
        [sessionId.read<int>('id'), drop, stamp(DateTime(2026, 3, 1, 10))],
      );

      // Both carry a personal best for the same key; the loser's is heavier.
      for (final (id, weight) in [(keep, 100.0), (drop, 120.0)]) {
        await db.customStatement(
          'INSERT INTO personal_bests (exercise_id, reps, weight, metric_type, '
          'achieved_at, synced_at) VALUES (?, 5, ?, ?, ?, ?)',
          [
            id,
            weight,
            'weightReps',
            stamp(DateTime(2026, 3, 1)),
            stamp(DateTime(2026, 3, 2)),
          ],
        );
      }
    });

    final db = await migrate();
    addTearDown(db.close);

    // One Bench Press left, and it is the lower id.
    final remaining = await db
        .customSelect("SELECT id FROM exercises WHERE name = 'Bench Press'")
        .get();
    expect(remaining, hasLength(1));
    expect(remaining.single.read<int>('id'), keep);

    // The logged set followed the survivor rather than dangling.
    final sets = await db
        .customSelect('SELECT exercise_id FROM workout_sets')
        .get();
    expect(sets.single.read<int>('exercise_id'), keep);

    // One personal best survives, and it is the heavier of the two.
    final prs = await db
        .customSelect(
          'SELECT exercise_id, weight, synced_at FROM personal_bests',
        )
        .get();
    expect(prs, hasLength(1));
    expect(prs.single.read<int>('exercise_id'), keep);
    expect(prs.single.read<double>('weight'), 120.0);
    expect(
      prs.single.readNullable<int>('synced_at'),
      isNull,
      reason: 'the corrected record must re-upload',
    );
  });

  test('a second seeded exercise of the same name is now rejected', () async {
    await buildV8Database((db) async {
      await insertExercise(db, name: 'Bench Press', bodyPart: 'Chest');
    });

    final db = await migrate();
    addTearDown(db.close);

    await expectLater(
      db.customStatement(
        'INSERT INTO exercises (name, body_part, equipment_type, is_custom, '
        "metric_type) VALUES ('Bench Press', 'Chest', 'Barbell', 0, "
        "'weightReps')",
      ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('an exercise cannot hold two primary muscles', () async {
    late int squat;
    await buildV8Database((db) async {
      squat = await insertExercise(db, name: 'Squat', bodyPart: 'Legs');
    });

    final db = await migrate();
    addTearDown(db.close);

    await expectLater(
      db.customStatement(
        'INSERT INTO exercise_muscles (exercise_id, muscle, is_primary) '
        'VALUES (?, ?, 1)',
        [squat, Muscle.glutes.name],
      ),
      throwsA(isA<SqliteException>()),
    );
  });

  // ---------------------------------------------------------------------------
  // Re-entrancy
  // ---------------------------------------------------------------------------

  test('reopening the migrated file changes nothing', () async {
    await buildV8Database((db) async {
      await insertExercise(db, name: 'Deadlift', bodyPart: 'Back');
      await insertExercise(
        db,
        name: 'Zercher Squat',
        bodyPart: 'Legs',
        isCustom: true,
      );
    });

    final first = await migrate();
    final before = await first
        .customSelect('SELECT COUNT(*) AS n FROM exercise_muscles')
        .getSingle();
    await first.close();

    final second = await migrate();
    addTearDown(second.close);
    final after = await second
        .customSelect('SELECT COUNT(*) AS n FROM exercise_muscles')
        .getSingle();

    expect(after.read<int>('n'), before.read<int>('n'));
  });

  // ---------------------------------------------------------------------------
  // The seed list itself
  // ---------------------------------------------------------------------------

  group('kSeedExercises', () {
    test('holds 41 uniquely named exercises', () {
      expect(kSeedExercises, hasLength(41));
      final names = kSeedExercises.map((s) => s.name).toSet();
      expect(names, hasLength(kSeedExercises.length));
    });

    test('no exercise lists its primary among its secondaries', () {
      for (final seed in kSeedExercises) {
        expect(
          seed.secondary,
          isNot(contains(seed.primary)),
          reason: seed.name,
        );
        expect(
          seed.secondary.toSet(),
          hasLength(seed.secondary.length),
          reason: '${seed.name} repeats a secondary',
        );
      }
    });

    test('every metric type is one the set logger understands', () {
      const known = {
        'weightReps',
        'bodyweightReps',
        'timeOnly',
        'distanceTime',
      };
      for (final seed in kSeedExercises) {
        expect(known, contains(seed.metricType), reason: seed.name);
      }
    });
  });
}
