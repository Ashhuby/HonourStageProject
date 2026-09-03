import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:fitness_app/core/database/database_provider.dart';
import 'package:fitness_app/core/database/local_database.dart';
import 'package:fitness_app/features/workout/data/session_repository.dart';

/// Tests deleting a session from history.
///
/// The point of these is the rebuild. A personal best is evidence of a set
/// that was logged, so removing the session holding it has to withdraw it —
/// the contract `deleteSet` and `updateSet` already honour and `deleteSession`
/// did not. Asserting the surviving record's `achievedAt` is what proves the
/// records were genuinely replayed rather than merely reduced.
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late int benchId;
  late int squatId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );

    Future<int> addExercise(String name, String metricType) => db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            name: name,
            bodyPart: 'Chest',
            equipmentType: 'Barbell',
            metricType: Value(metricType),
          ),
        );

    benchId = await addExercise('Bench Press', 'weightReps');
    squatId = await addExercise('Squat', 'weightReps');
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  SessionRepository sessions() =>
      container.read(sessionRepositoryProvider.notifier);

  /// Logs a finished session through the live path, so records are written the
  /// way they are in the app rather than by the test.
  Future<int> loggedSession({
    required DateTime at,
    required List<({int exerciseId, double weight, int reps})> sets,
  }) async {
    final id = await db
        .into(db.workoutSessions)
        .insert(WorkoutSessionsCompanion.insert(startTime: at));

    for (final set in sets) {
      await sessions().logSet(
        sessionId: id,
        exerciseId: set.exerciseId,
        exerciseName: 'x',
        metricType: 'weightReps',
        weight: set.weight,
        reps: set.reps,
      );
    }

    await (db.update(db.workoutSessions)..where((s) => s.id.equals(id))).write(
      WorkoutSessionsCompanion(
        endTime: Value(at.add(const Duration(hours: 1))),
      ),
    );
    return id;
  }

  Future<List<PersonalBest>> records(int exerciseId) => (db.select(
    db.personalBests,
  )..where((pb) => pb.exerciseId.equals(exerciseId))).get();

  Future<PersonalBest?> liveRecord(int exerciseId) async {
    final rows =
        await (db.select(db.personalBests)
              ..where((pb) => pb.exerciseId.equals(exerciseId))
              ..where((pb) => pb.deletedAt.isNull()))
            .get();
    return rows.isEmpty ? null : rows.single;
  }

  // ---------------------------------------------------------------------------
  // Records follow the sets
  // ---------------------------------------------------------------------------

  test(
    'deleting the session holding a record falls back to the next',
    () async {
      await loggedSession(
        at: DateTime(2026, 3, 1, 9),
        sets: [(exerciseId: benchId, weight: 100, reps: 5)],
      );
      final heavier = await loggedSession(
        at: DateTime(2026, 3, 8, 9),
        sets: [(exerciseId: benchId, weight: 120, reps: 5)],
      );

      expect((await liveRecord(benchId))!.weight, 120);

      await sessions().deleteSession(heavier);

      final surviving = await liveRecord(benchId);
      expect(surviving!.weight, 100);

      // The record carries the surviving set's own timestamp, which is what
      // proves it was replayed from the sets rather than stamped afresh.
      final survivingSet = (await (db.select(
        db.workoutSets,
      )..where((s) => s.deletedAt.isNull())).get()).single;
      expect(surviving.achievedAt, survivingSet.timestamp);
    },
  );

  test('deleting the only session retires the record entirely', () async {
    final only = await loggedSession(
      at: DateTime(2026, 3, 1, 9),
      sets: [(exerciseId: benchId, weight: 100, reps: 5)],
    );

    await sessions().deleteSession(only);

    expect(await liveRecord(benchId), isNull);

    // Soft-deleted and dirty, so the withdrawal reaches the remote copy.
    final row = (await records(benchId)).single;
    expect(row.deletedAt, isNotNull);
    expect(row.syncedAt, isNull);
  });

  test('every exercise the session touched is rebuilt', () async {
    await loggedSession(
      at: DateTime(2026, 3, 1, 9),
      sets: [
        (exerciseId: benchId, weight: 100, reps: 5),
        (exerciseId: squatId, weight: 140, reps: 5),
      ],
    );
    final best = await loggedSession(
      at: DateTime(2026, 3, 8, 9),
      sets: [
        (exerciseId: benchId, weight: 120, reps: 5),
        (exerciseId: squatId, weight: 160, reps: 5),
      ],
    );

    await sessions().deleteSession(best);

    expect((await liveRecord(benchId))!.weight, 100);
    expect((await liveRecord(squatId))!.weight, 140);
  });

  test('a session holding no records leaves them alone', () async {
    await loggedSession(
      at: DateTime(2026, 3, 1, 9),
      sets: [(exerciseId: benchId, weight: 120, reps: 5)],
    );
    final lighter = await loggedSession(
      at: DateTime(2026, 3, 8, 9),
      sets: [(exerciseId: benchId, weight: 90, reps: 5)],
    );

    await sessions().deleteSession(lighter);

    final surviving = await liveRecord(benchId);
    expect(surviving!.weight, 120);
    expect(surviving.deletedAt, isNull);
  });

  // ---------------------------------------------------------------------------
  // The rows themselves
  // ---------------------------------------------------------------------------

  test('the session and its sets are soft-deleted and left dirty', () async {
    final id = await loggedSession(
      at: DateTime(2026, 3, 1, 9),
      sets: [(exerciseId: benchId, weight: 100, reps: 5)],
    );

    await sessions().deleteSession(id);

    final session = await (db.select(
      db.workoutSessions,
    )..where((s) => s.id.equals(id))).getSingle();
    expect(session.deletedAt, isNotNull);
    expect(session.syncedAt, isNull);

    final sets = await (db.select(
      db.workoutSets,
    )..where((s) => s.sessionId.equals(id))).get();
    expect(sets, isNotEmpty);
    expect(sets.every((s) => s.deletedAt != null), isTrue);
    expect(sets.every((s) => s.syncedAt == null), isTrue);
  });

  test('it drops out of the completed-session list', () async {
    final id = await loggedSession(
      at: DateTime(2026, 3, 1, 9),
      sets: [(exerciseId: benchId, weight: 100, reps: 5)],
    );

    await sessions().deleteSession(id);

    final remaining = await (db.select(
      db.workoutSessions,
    )..where((s) => s.deletedAt.isNull())).get();
    expect(remaining, isEmpty);
  });

  test('deleting a session with no sets does not throw', () async {
    final empty = await db
        .into(db.workoutSessions)
        .insert(
          WorkoutSessionsCompanion.insert(startTime: DateTime(2026, 3, 1, 9)),
        );

    await expectLater(sessions().deleteSession(empty), completes);
  });
}
