import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/core/database/local_database.dart';

/// Tests the local half of deleting a session upstream.
///
/// The Supabase calls are not testable here — the client is not injectable —
/// so these pin the database behaviour the sync service depends on, which is
/// where both bugs actually lived.
void main() {
  late AppDatabase db;
  late int exerciseId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
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

  tearDown(() async => db.close());

  Future<int> insertSession({
    DateTime? endTime,
    DateTime? deletedAt,
    DateTime? syncedAt,
  }) => db
      .into(db.workoutSessions)
      .insert(
        WorkoutSessionsCompanion.insert(
          startTime: DateTime(2026, 3, 1, 9),
          endTime: Value(endTime),
          deletedAt: Value(deletedAt),
          syncedAt: Value(syncedAt),
        ),
      );

  Future<void> insertSet(int sessionId, {DateTime? syncedAt}) => db
      .into(db.workoutSets)
      .insert(
        WorkoutSetsCompanion.insert(
          sessionId: sessionId,
          exerciseId: exerciseId,
          weight: const Value(100),
          reps: const Value(5),
          syncedAt: Value(syncedAt),
        ),
      );

  /// The purge the sync service runs after uploading set tombstones.
  Future<void> purge() => db.customStatement('''
    DELETE FROM workout_sessions
    WHERE deleted_at IS NOT NULL
      AND synced_at IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM workout_sets
        WHERE workout_sets.session_id = workout_sessions.id
          AND workout_sets.synced_at IS NULL
      )
  ''');

  Future<int> countSets() async =>
      (await db.select(db.workoutSets).get()).length;
  Future<int> countSessions() async =>
      (await db.select(db.workoutSessions).get()).length;

  // ---------------------------------------------------------------------------
  // The cascade that caused the bug
  // ---------------------------------------------------------------------------

  test('deleting a session row takes its sets with it', () async {
    // This is the whole mechanism. The sync service used to hard-delete the
    // session as soon as its own tombstone was uploaded — which happens before
    // the sets are synced — so the cascade wiped the sets locally and their
    // tombstones never reached the remote copy at all.
    final id = await insertSession(endTime: DateTime(2026, 3, 1, 10));
    await insertSet(id);
    expect(await countSets(), 1);

    await (db.delete(db.workoutSessions)..where((s) => s.id.equals(id))).go();

    expect(await countSets(), 0);
  });

  // ---------------------------------------------------------------------------
  // The purge
  // ---------------------------------------------------------------------------

  test('a synced tombstone with all its sets synced is removed', () async {
    final id = await insertSession(
      endTime: DateTime(2026, 3, 1, 10),
      deletedAt: DateTime(2026, 3, 2),
      syncedAt: DateTime(2026, 3, 2),
    );
    await insertSet(id, syncedAt: DateTime(2026, 3, 2));

    await purge();

    expect(await countSessions(), 0);
  });

  test('a session with a set still to upload is kept', () async {
    // Otherwise the cascade would destroy the very row that still had to be
    // sent, and the remote set would stay undeleted forever.
    final id = await insertSession(
      endTime: DateTime(2026, 3, 1, 10),
      deletedAt: DateTime(2026, 3, 2),
      syncedAt: DateTime(2026, 3, 2),
    );
    await insertSet(id, syncedAt: DateTime(2026, 3, 2));
    await insertSet(id); // dirty

    await purge();

    expect(await countSessions(), 1);
    expect(await countSets(), 2);
  });

  test('a live session is never touched', () async {
    final id = await insertSession(
      endTime: DateTime(2026, 3, 1, 10),
      syncedAt: DateTime(2026, 3, 2),
    );
    await insertSet(id, syncedAt: DateTime(2026, 3, 2));

    await purge();

    expect(await countSessions(), 1);
  });

  test('a deleted session whose tombstone has not gone up is kept', () async {
    await insertSession(
      endTime: DateTime(2026, 3, 1, 10),
      deletedAt: DateTime(2026, 3, 2),
    );

    await purge();

    expect(await countSessions(), 1);
  });

  test('it clears rows already stranded by the old behaviour', () async {
    // Keyed on state rather than on this run's work, so a session left in
    // this shape by a previous build is healed rather than ignored.
    await insertSession(
      endTime: DateTime(2026, 3, 1, 10),
      deletedAt: DateTime(2025, 12, 1),
      syncedAt: DateTime(2025, 12, 1),
    );

    await purge();

    expect(await countSessions(), 0);
  });
}
