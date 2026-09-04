import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/core/database/local_database.dart';

/// Tests that deleting a split or a routine cannot break sync.
///
/// The bug: sync hard-deleted a routine as soon as it had pushed the
/// tombstone. `workout_sessions.routine_id` references that table with no
/// delete action, so removing a routine any session was logged against raised
/// FOREIGN KEY constraint failed (787) — and every sync from then on failed at
/// the same row, because nothing had changed to stop it trying again.
///
/// Deleting a split was worse. Routines cascade from it, so the cascade hit
/// the same wall one level down and the error surfaced against splits instead.
///
/// The queries are asserted directly rather than through SyncService, which
/// needs a live Supabase client — the local delete is the part that was wrong.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  /// The purge as sync runs it.
  Future<void> purgeRoutines() => db.customStatement('''
      DELETE FROM workout_routines
      WHERE deleted_at IS NOT NULL
        AND synced_at IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM workout_sessions
          WHERE workout_sessions.routine_id = workout_routines.id
        )
    ''');

  Future<void> purgeSplits() => db.customStatement('''
      DELETE FROM workout_splits
      WHERE deleted_at IS NOT NULL
        AND synced_at IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM workout_routines
          WHERE workout_routines.split_id = workout_splits.id
        )
    ''');

  Future<int> addSplit({bool deleted = false}) => db
      .into(db.workoutSplits)
      .insert(
        WorkoutSplitsCompanion.insert(
          name: 'PPL',
          deletedAt: Value(deleted ? DateTime(2026, 5, 1) : null),
          syncedAt: Value(DateTime(2026, 5, 1)),
        ),
      );

  Future<int> addRoutine(int splitId, {bool deleted = false}) => db
      .into(db.workoutRoutines)
      .insert(
        WorkoutRoutinesCompanion.insert(
          splitId: splitId,
          name: 'Push',
          orderIndex: 0,
          deletedAt: Value(deleted ? DateTime(2026, 5, 1) : null),
          syncedAt: Value(DateTime(2026, 5, 1)),
        ),
      );

  Future<int> addSession(int routineId) => db
      .into(db.workoutSessions)
      .insert(
        WorkoutSessionsCompanion.insert(
          routineId: Value(routineId),
          startTime: DateTime(2026, 5, 1),
        ),
      );

  Future<int> countRoutines() async =>
      (await db.select(db.workoutRoutines).get()).length;

  Future<int> countSplits() async =>
      (await db.select(db.workoutSplits).get()).length;

  test('the local foreign key really does block the delete', () async {
    // Proves the constraint this is all about is actually enforced — without
    // it the rest of these tests would pass for the wrong reason.
    final split = await addSplit();
    final routine = await addRoutine(split);
    await addSession(routine);

    await expectLater(
      (db.delete(db.workoutRoutines)..where((r) => r.id.equals(routine))).go(),
      throwsA(anything),
    );
  });

  test('a deleted routine with history is kept, not purged', () async {
    final split = await addSplit();
    final routine = await addRoutine(split, deleted: true);
    await addSession(routine);

    await purgeRoutines();

    // Kept, and harmlessly: every query filters on deleted_at IS NULL, and the
    // session needs the row to know what it was.
    expect(await countRoutines(), 1);
  });

  test('a deleted routine with no history is purged', () async {
    final split = await addSplit();
    await addRoutine(split, deleted: true);

    await purgeRoutines();

    expect(await countRoutines(), 0);
  });

  test('a live routine is never purged', () async {
    final split = await addSplit();
    await addRoutine(split);

    await purgeRoutines();

    expect(await countRoutines(), 1);
  });

  test('a deleted split waits for its routines', () async {
    final split = await addSplit(deleted: true);
    final routine = await addRoutine(split, deleted: true);
    await addSession(routine);

    await purgeRoutines();
    await purgeSplits();

    // The routine is pinned by a session, so the split stays too — deleting it
    // would cascade into the routine and hit the same constraint.
    expect(await countRoutines(), 1);
    expect(await countSplits(), 1);
  });

  test('a deleted split with nothing left goes', () async {
    final split = await addSplit(deleted: true);
    await addRoutine(split, deleted: true);

    await purgeRoutines();
    await purgeSplits();

    expect(await countRoutines(), 0);
    expect(await countSplits(), 0);
  });

  test('purging twice is a no-op, not an error', () async {
    final split = await addSplit(deleted: true);
    await addRoutine(split, deleted: true);

    await purgeRoutines();
    await purgeSplits();
    await purgeRoutines();
    await purgeSplits();

    expect(await countSplits(), 0);
  });
}
