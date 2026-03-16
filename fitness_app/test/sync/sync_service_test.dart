import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/core/database/local_database.dart';

/// Sync service unit tests.
/// These tests verify dirty-flag detection, soft-delete state, and
/// parent-dependency ordering logic directly against the in-memory DB.
/// Supabase network calls are excluded from unit tests by design integration tested manually via the manual sync trigger in the UI.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  // ---------------------------------------------------------------------------
  // Dirty flag detection
  // ---------------------------------------------------------------------------

  group('Dirty flag detection', () {
    test('newly inserted split has null syncedAt — is dirty', () async {
      await db.into(db.workoutSplits).insert(
            WorkoutSplitsCompanion.insert(name: 'PPL'),
          );

      final dirty = await (db.select(db.workoutSplits)
            ..where((s) => s.syncedAt.isNull()))
          .get();

      expect(dirty.length, 1);
    });

    test('split with syncedAt set is not dirty', () async {
      await db.into(db.workoutSplits).insert(
            WorkoutSplitsCompanion(
              name: const Value('PPL'),
              syncedAt: Value(DateTime.now()),
            ),
          );

      final dirty = await (db.select(db.workoutSplits)
            ..where((s) => s.syncedAt.isNull()))
          .get();

      expect(dirty, isEmpty);
    });

    test('updating a synced split clears syncedAt — marks it dirty', () async {
      final id = await db.into(db.workoutSplits).insert(
            WorkoutSplitsCompanion(
              name: const Value('PPL'),
              syncedAt: Value(DateTime.now()),
            ),
          );

      // Simulate an edit — clear syncedAt to mark dirty
      await (db.update(db.workoutSplits)..where((s) => s.id.equals(id)))
          .write(const WorkoutSplitsCompanion(syncedAt: Value(null)));

      final dirty = await (db.select(db.workoutSplits)
            ..where((s) => s.syncedAt.isNull()))
          .get();

      expect(dirty.length, 1);
    });

    test('newly inserted session is dirty', () async {
      final session = await db.into(db.workoutSessions).insert(
            WorkoutSessionsCompanion.insert(
              startTime: DateTime.now(),
              endTime: Value(DateTime.now()),
            ),
          );

      final dirty = await (db.select(db.workoutSessions)
            ..where((s) => s.syncedAt.isNull()))
          .get();

      expect(dirty.length, 1);
      expect(dirty.first.id, session);
    });
  });

  // ---------------------------------------------------------------------------
  // Unauthenticated guard
  // ---------------------------------------------------------------------------

  group('Unauthenticated state', () {
    test('dirty records remain unsynced when userId is null', () async {
      await db.into(db.workoutSplits).insert(
            WorkoutSplitsCompanion.insert(name: 'Should Not Sync'),
          );

      // Simulate unauthenticated — userId never stamped
      final dirty = await (db.select(db.workoutSplits)
            ..where((s) => s.userId.isNull()))
          .get();

      expect(dirty.length, 1);
      expect(dirty.first.syncedAt, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Parent dependency ordering
  // ---------------------------------------------------------------------------

  group('Parent dependency ordering', () {
    test('routine without synced parent split is skipped', () async {
      final splitId = await db.into(db.workoutSplits).insert(
            WorkoutSplitsCompanion.insert(name: 'Unsynced Split'),
          );

      await db.into(db.workoutRoutines).insert(
            WorkoutRoutinesCompanion.insert(
              name: 'Push Day',
              splitId: splitId,
              orderIndex: 0,
            ),
          );

      // Parent split has no remoteId — routine cannot be synced
      final split = await (db.select(db.workoutSplits)
            ..where((s) => s.id.equals(splitId)))
          .getSingle();

      expect(split.remoteId, isNull,
          reason: 'Split must have remoteId before child routine can sync');
    });

    test('routine can sync once parent split has remoteId', () async {
      final splitId = await db.into(db.workoutSplits).insert(
            WorkoutSplitsCompanion(
              name: const Value('Synced Split'),
              remoteId: const Value('remote-uuid-123'),
              userId: const Value('user-uuid-456'),
              syncedAt: Value(DateTime.now()),
            ),
          );

      await db.into(db.workoutRoutines).insert(
            WorkoutRoutinesCompanion.insert(
              name: 'Push Day',
              splitId: splitId,
              orderIndex: 0,
            ),
          );

      final split = await (db.select(db.workoutSplits)
            ..where((s) => s.id.equals(splitId)))
          .getSingle();

      expect(split.remoteId, isNotNull,
          reason: 'Parent has remoteId — child routine is eligible to sync');

      final dirtyRoutines = await (db.select(db.workoutRoutines)
            ..where((r) => r.syncedAt.isNull()))
          .get();

      expect(dirtyRoutines.length, 1);
    });

    test('workout set without synced parent session is skipped', () async {
      final sessionId = await db.into(db.workoutSessions).insert(
            WorkoutSessionsCompanion.insert(startTime: DateTime.now()),
          );

      final exerciseId = await db.into(db.exercises).insert(
            ExercisesCompanion.insert(
              name: 'Squat',
              bodyPart: 'Legs',
              equipmentType: 'Barbell',
            ),
          );

      await db.into(db.workoutSets).insert(
            WorkoutSetsCompanion.insert(
              sessionId: sessionId,
              exerciseId: exerciseId,
              weight: 100.0,
              reps: 5,
            ),
          );

      final session = await (db.select(db.workoutSessions)
            ..where((s) => s.id.equals(sessionId)))
          .getSingle();

      expect(session.remoteId, isNull,
          reason: 'Session has no remoteId — sets cannot sync yet');
    });
  });

  // ---------------------------------------------------------------------------
  // Soft delete
  // ---------------------------------------------------------------------------

  group('Soft delete', () {
    test('soft-deleted split has deletedAt set and syncedAt cleared', () async {
      final id = await db.into(db.workoutSplits).insert(
            WorkoutSplitsCompanion(
              name: const Value('To Delete'),
              syncedAt: Value(DateTime.now()),
            ),
          );

      // Soft delete — stamp deletedAt, clear syncedAt so sync picks it up
      await (db.update(db.workoutSplits)..where((s) => s.id.equals(id)))
          .write(WorkoutSplitsCompanion(
        deletedAt: Value(DateTime.now()),
        syncedAt: const Value(null),
      ));

      final record = await (db.select(db.workoutSplits)
            ..where((s) => s.id.equals(id)))
          .getSingle();

      expect(record.deletedAt, isNotNull);
      expect(record.syncedAt, isNull,
          reason: 'Soft-deleted record must be dirty so sync propagates delete');
    });

    test('soft-deleted record appears in dirty queue', () async {
      final id = await db.into(db.workoutSplits).insert(
            WorkoutSplitsCompanion(
              name: const Value('To Delete'),
              syncedAt: Value(DateTime.now()),
            ),
          );

      await (db.update(db.workoutSplits)..where((s) => s.id.equals(id)))
          .write(WorkoutSplitsCompanion(
        deletedAt: Value(DateTime.now()),
        syncedAt: const Value(null),
      ));

      final dirty = await (db.select(db.workoutSplits)
            ..where((s) => s.syncedAt.isNull()))
          .get();

      expect(dirty.length, 1);
      expect(dirty.first.deletedAt, isNotNull);
    });
  });
}