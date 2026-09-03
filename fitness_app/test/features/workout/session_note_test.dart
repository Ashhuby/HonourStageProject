import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:fitness_app/core/database/database_provider.dart';
import 'package:fitness_app/core/database/local_database.dart';
import 'package:fitness_app/features/workout/data/session_repository.dart';

/// Tests notes on a session.
///
/// `sessionNote` has been a column since sync existed and travels to Supabase
/// and back, but nothing in the app ever wrote one — so it had only ever held
/// null. These pin the write path, and in particular the rule that blank input
/// clears rather than storing an empty string.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  SessionRepository sessions() =>
      container.read(sessionRepositoryProvider.notifier);

  Future<int> insertSession({DateTime? syncedAt}) => db
      .into(db.workoutSessions)
      .insert(
        WorkoutSessionsCompanion.insert(
          startTime: DateTime(2026, 3, 1, 9),
          endTime: Value(DateTime(2026, 3, 1, 10)),
          syncedAt: Value(syncedAt),
        ),
      );

  Future<WorkoutSession> read(int id) => (db.select(
    db.workoutSessions,
  )..where((s) => s.id.equals(id))).getSingle();

  test('a note is stored against the session', () async {
    final id = await insertSession();

    await sessions().setSessionNote(id, 'Felt strong. Shoulder twinged.');

    expect((await read(id)).sessionNote, 'Felt strong. Shoulder twinged.');
  });

  test('surrounding whitespace is trimmed', () async {
    final id = await insertSession();

    await sessions().setSessionNote(id, '   easy session   ');

    expect((await read(id)).sessionNote, 'easy session');
  });

  test('blank input clears the note rather than storing empty', () async {
    // Otherwise there would be two ways of saying "no note", and the row
    // marker would light up for a session carrying nothing.
    final id = await insertSession();
    await sessions().setSessionNote(id, 'something');

    await sessions().setSessionNote(id, '   ');

    expect((await read(id)).sessionNote, isNull);
  });

  test('null clears the note', () async {
    final id = await insertSession();
    await sessions().setSessionNote(id, 'something');

    await sessions().setSessionNote(id, null);

    expect((await read(id)).sessionNote, isNull);
  });

  test('writing a note marks the session dirty', () async {
    // The column already syncs both ways, so the note has to be queued for
    // upload like every other edit.
    final id = await insertSession(syncedAt: DateTime(2026, 3, 2));

    await sessions().setSessionNote(id, 'note');

    expect((await read(id)).syncedAt, isNull);
  });

  test('clearing a note also marks it dirty', () async {
    final id = await insertSession();
    await sessions().setSessionNote(id, 'note');
    await (db.update(db.workoutSessions)..where((s) => s.id.equals(id))).write(
      WorkoutSessionsCompanion(syncedAt: Value(DateTime(2026, 3, 2))),
    );

    await sessions().setSessionNote(id, null);

    final row = await read(id);
    expect(row.sessionNote, isNull);
    expect(row.syncedAt, isNull, reason: 'the removal has to reach the server');
  });

  test('the note reaches the history view model', () async {
    final id = await insertSession();
    await sessions().setSessionNote(id, 'tough one');

    final sub = container.listen(
      watchCompletedSessionDetailsProvider,
      (_, _) {},
    );
    addTearDown(sub.close);

    var value = container.read(watchCompletedSessionDetailsProvider);
    while (!value.hasValue) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      value = container.read(watchCompletedSessionDetailsProvider);
    }

    expect(value.requireValue.single.note, 'tough one');
  });

  test('a note on one session does not touch another', () async {
    final first = await insertSession();
    final second = await insertSession();

    await sessions().setSessionNote(first, 'only this one');

    expect((await read(first)).sessionNote, 'only this one');
    expect((await read(second)).sessionNote, isNull);
  });
}
