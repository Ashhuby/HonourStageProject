import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/core/database/local_database.dart';

import 'schema_fixture.dart';

/// Tests the v13 → v14 removal of `workout_sets.is_completed`.
///
/// The column was dead from the day it was added. Nothing ever set it — a set
/// row is written when the set is done, so the row's existence is the
/// completion — and no query filtered on it. Every row read `false`, including
/// sets that had plainly been completed, so the column contradicted the data
/// sitting beside it.
///
/// Dropping a column is the one migration that can lose data, so this runs the
/// real thing over a real file and checks the sets survive it.
void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('onerep_dead_column');
    dbFile = File('${tempDir.path}/app.sqlite');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  /// A v13 database with a session and two sets in it.
  Future<void> buildV13Database() async {
    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    await db.customStatement('SELECT 1');

    final sessionId = await db
        .into(db.workoutSessions)
        .insert(
          WorkoutSessionsCompanion.insert(startTime: DateTime(2026, 5, 1, 9)),
        );
    final exerciseId = await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            name: 'Bench Press',
            bodyPart: 'Chest',
            equipmentType: 'Barbell',
          ),
        );

    for (var i = 0; i < 2; i++) {
      await db
          .into(db.workoutSets)
          .insert(
            WorkoutSetsCompanion.insert(
              sessionId: sessionId,
              exerciseId: exerciseId,
              weight: Value(60.0 + i),
              reps: const Value(10),
            ),
          );
    }

    await makeLookLikeVersion(db, 13);
    await db.close();
  }

  test('the column is gone after upgrading', () async {
    await buildV13Database();

    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    final columns = await db
        .customSelect('PRAGMA table_info(workout_sets)')
        .get();
    final names = [for (final row in columns) row.data['name'] as String];
    await db.close();

    expect(names, isNot(contains('is_completed')));
    // The columns that carry actual measurements are untouched.
    expect(names, containsAll(['weight', 'reps', 'duration_seconds']));
  });

  test('the sets themselves survive', () async {
    await buildV13Database();

    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    final sets = await db.select(db.workoutSets).get();
    await db.close();

    expect(sets, hasLength(2));
    expect(sets.map((s) => s.weight), containsAll([60.0, 61.0]));
    expect(sets.every((s) => s.reps == 10), isTrue);
  });

  test('reopening the migrated file changes nothing', () async {
    await buildV13Database();

    for (var i = 0; i < 2; i++) {
      final db = AppDatabase.forTesting(NativeDatabase(dbFile));
      expect(await db.select(db.workoutSets).get(), hasLength(2));
      await db.close();
    }
  });
}
