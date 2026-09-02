import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:fitness_app/core/database/database_provider.dart';
import 'package:fitness_app/core/database/local_database.dart';
import 'package:fitness_app/features/workout/data/session_repository.dart';

/// Tests for finding a session that was started and never finished.
///
/// An in-progress session is skipped by history and by sync, so before this
/// existed an interrupted workout was unreachable — the sets logged in it
/// were stranded in the database with no way back.
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late int exerciseId;
  late int splitId;
  late int routineId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );

    exerciseId = await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            name: 'Bench Press',
            bodyPart: 'Chest',
            equipmentType: 'Barbell',
          ),
        );
    splitId = await db
        .into(db.workoutSplits)
        .insert(WorkoutSplitsCompanion.insert(name: 'PPL'));
    routineId = await db
        .into(db.workoutRoutines)
        .insert(
          WorkoutRoutinesCompanion.insert(
            splitId: splitId,
            name: 'Push Day',
            orderIndex: 0,
          ),
        );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<int> insertSession({
    required DateTime start,
    bool finished = false,
    bool deleted = false,
    int? routine,
  }) {
    return db
        .into(db.workoutSessions)
        .insert(
          WorkoutSessionsCompanion.insert(
            startTime: start,
            routineId: Value(routine),
            endTime: Value(
              finished ? start.add(const Duration(hours: 1)) : null,
            ),
            deletedAt: Value(deleted ? DateTime.now() : null),
          ),
        );
  }

  Future<void> insertSet(int sessionId, {bool deleted = false}) async {
    await db
        .into(db.workoutSets)
        .insert(
          WorkoutSetsCompanion.insert(
            sessionId: sessionId,
            exerciseId: exerciseId,
            weight: const Value(80),
            reps: const Value(8),
            deletedAt: Value(deleted ? DateTime.now() : null),
          ),
        );
  }

  /// Reads the first value emitted by a provider, keeping the auto-disposed
  /// subscription alive for the duration of the read.
  Future<T> firstValue<T>(ProviderListenable<AsyncValue<T>> provider) async {
    final sub = container.listen(provider, (_, _) {});
    try {
      var value = container.read(provider);
      while (!value.hasValue) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        value = container.read(provider);
      }
      return value.requireValue;
    } finally {
      sub.close();
    }
  }

  Future<ActiveSession?> activeSession() =>
      firstValue(watchActiveSessionProvider);

  group('watchActiveSession', () {
    test('is null when every session is finished', () async {
      await insertSession(start: DateTime(2026, 1, 8), finished: true);

      expect(await activeSession(), isNull);
    });

    test('finds a freestyle session left open', () async {
      final id = await insertSession(start: DateTime(2026, 1, 15, 18, 30));

      final active = await activeSession();

      expect(active, isNotNull);
      expect(active!.session.id, id);
      expect(active.title, freestyleSessionTitle);
      expect(active.routineId, isNull);
    });

    test('titles a routine session with the routine name', () async {
      await insertSession(start: DateTime(2026, 1, 15), routine: routineId);

      final active = await activeSession();

      expect(active!.title, 'Push Day');
      expect(active.routineId, routineId);
    });

    test('ignores a discarded session', () async {
      await insertSession(start: DateTime(2026, 1, 15), deleted: true);

      expect(await activeSession(), isNull);
    });

    test('picks the most recent of several left open', () async {
      await insertSession(start: DateTime(2026, 1, 1));
      final newest = await insertSession(start: DateTime(2026, 1, 15));
      await insertSession(start: DateTime(2026, 1, 8));

      expect((await activeSession())!.session.id, newest);
    });

    test('clears once the session is finished', () async {
      final id = await insertSession(start: DateTime(2026, 1, 15));
      expect(await activeSession(), isNotNull);

      await container.read(sessionRepositoryProvider.notifier).endSession(id);

      expect(await activeSession(), isNull);
    });

    test('clears once the session is discarded', () async {
      final id = await insertSession(start: DateTime(2026, 1, 15));
      await insertSet(id);

      await container
          .read(sessionRepositoryProvider.notifier)
          .deleteSession(id);

      expect(await activeSession(), isNull);
    });
  });

  group('watchSetCountForSession', () {
    test('counts the sets logged so far', () async {
      final id = await insertSession(start: DateTime(2026, 1, 15));
      await insertSet(id);
      await insertSet(id);

      expect(await firstValue(watchSetCountForSessionProvider(id)), 2);
    });

    test('is zero for a session with nothing logged', () async {
      final id = await insertSession(start: DateTime(2026, 1, 15));

      expect(await firstValue(watchSetCountForSessionProvider(id)), 0);
    });

    test('excludes deleted sets and other sessions', () async {
      final id = await insertSession(start: DateTime(2026, 1, 15));
      final other = await insertSession(start: DateTime(2026, 1, 14));
      await insertSet(id);
      await insertSet(id, deleted: true);
      await insertSet(other);

      expect(await firstValue(watchSetCountForSessionProvider(id)), 1);
    });
  });
}
