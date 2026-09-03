import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:fitness_app/core/database/database_provider.dart';
import 'package:fitness_app/core/database/local_database.dart';
import 'package:fitness_app/features/workout/data/split_repository.dart';

/// Tests editing a plan after it has been built.
///
/// Splits and routines could only be created and deleted, so correcting a
/// typo meant destroying the thing — and deleting a split takes every routine
/// and every planned exercise with it. `orderIndex` had the same shape: it was
/// set when an exercise was added and never changed again.
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late int splitId;
  late int routineId;
  late int benchId;
  late int squatId;
  late int rowId;

  SplitRepository splits() => container.read(splitRepositoryProvider.notifier);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );

    splitId = await splits().createSplit('PPL');
    routineId = await splits().addRoutineToSplit('Push Day', splitId);

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
    rowId = await addExercise('Running', 'distanceTime');
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<WorkoutSplit> readSplit() => (db.select(
    db.workoutSplits,
  )..where((s) => s.id.equals(splitId))).getSingle();

  Future<WorkoutRoutine> readRoutine() => (db.select(
    db.workoutRoutines,
  )..where((r) => r.id.equals(routineId))).getSingle();

  Future<List<RoutineExercise>> planned() =>
      (db.select(db.routineExercises)
            ..where((re) => re.routineId.equals(routineId))
            ..where((re) => re.deletedAt.isNull())
            ..orderBy([(re) => OrderingTerm.asc(re.orderIndex)]))
          .get();

  // ---------------------------------------------------------------------------
  // Renaming
  // ---------------------------------------------------------------------------

  group('renaming', () {
    test('a split keeps its routines', () async {
      // The point of renaming: the alternative was deleting the split, which
      // takes everything under it.
      await splits().addExerciseToRoutine(
        routineId: routineId,
        exerciseId: benchId,
      );

      await splits().renameSplit(splitId, 'Push Pull Legs');

      expect((await readSplit()).name, 'Push Pull Legs');
      expect(await planned(), hasLength(1));
    });

    test('a routine can be renamed', () async {
      await splits().renameRoutine(routineId, 'Push A');
      expect((await readRoutine()).name, 'Push A');
    });

    test('renaming marks the row dirty', () async {
      await (db.update(db.workoutSplits)..where((s) => s.id.equals(splitId)))
          .write(WorkoutSplitsCompanion(syncedAt: Value(DateTime(2026, 3, 1))));

      await splits().renameSplit(splitId, 'Upper Lower');

      expect((await readSplit()).syncedAt, isNull);
    });

    test('whitespace is trimmed', () async {
      await splits().renameSplit(splitId, '  Full Body  ');
      expect((await readSplit()).name, 'Full Body');
    });

    test('a blank name is ignored rather than stored', () async {
      // A split with no name is unfindable, and the list would have to invent
      // a placeholder to render it.
      await splits().renameSplit(splitId, '   ');
      expect((await readSplit()).name, 'PPL');

      await splits().renameRoutine(routineId, '');
      expect((await readRoutine()).name, 'Push Day');
    });
  });

  // ---------------------------------------------------------------------------
  // Targets
  // ---------------------------------------------------------------------------

  group('targets', () {
    test('a plan can be corrected after it is set', () async {
      await splits().addExerciseToRoutine(
        routineId: routineId,
        exerciseId: benchId,
        targetSets: 3,
        targetReps: 10,
      );
      final entry = (await planned()).single;

      await splits().updateRoutineExerciseTarget(
        entry.id,
        targetSets: 5,
        targetReps: 5,
      );

      final updated = (await planned()).single;
      expect(updated.targetSets, 5);
      expect(updated.targetReps, 5);
      expect(updated.syncedAt, isNull);
    });

    test('a cardio target replaces a rep target', () async {
      await splits().addExerciseToRoutine(
        routineId: routineId,
        exerciseId: rowId,
      );
      final entry = (await planned()).single;

      await splits().updateRoutineExerciseTarget(
        entry.id,
        targetSets: 1,
        targetReps: 10,
        targetDistanceMetres: 5000,
      );

      final updated = (await planned()).single;
      expect(updated.targetDistanceMetres, 5000);
      expect(updated.targetDurationSeconds, isNull);
    });

    test('clearing a distance target is possible', () async {
      await splits().addExerciseToRoutine(
        routineId: routineId,
        exerciseId: rowId,
        targetDistanceMetres: 5000,
      );
      final entry = (await planned()).single;

      await splits().updateRoutineExerciseTarget(
        entry.id,
        targetSets: 3,
        targetReps: 10,
      );

      expect((await planned()).single.targetDistanceMetres, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Ordering
  // ---------------------------------------------------------------------------

  group('reordering', () {
    Future<List<int>> addThree() async {
      for (final id in [benchId, squatId, rowId]) {
        await splits().addExerciseToRoutine(
          routineId: routineId,
          exerciseId: id,
        );
      }
      return [for (final e in await planned()) e.id];
    }

    test('exercises come back in the order they were added', () async {
      await addThree();
      expect((await planned()).map((e) => e.orderIndex), [0, 1, 2]);
    });

    test('moving the last to the front rewrites every index', () async {
      final ids = await addThree();

      await splits().reorderRoutineExercises([ids[2], ids[0], ids[1]]);

      final after = await planned();
      expect(after.map((e) => e.id), [ids[2], ids[0], ids[1]]);
      expect(after.map((e) => e.orderIndex), [0, 1, 2]);
    });

    test('reordering marks every moved row dirty', () async {
      final ids = await addThree();
      await db
          .update(db.routineExercises)
          .write(
            RoutineExercisesCompanion(syncedAt: Value(DateTime(2026, 3, 1))),
          );

      await splits().reorderRoutineExercises([ids[1], ids[0], ids[2]]);

      expect((await planned()).every((e) => e.syncedAt == null), isTrue);
    });

    test('it compacts the gap a removal leaves behind', () async {
      // removeExerciseFromRoutine soft-deletes without re-indexing, so the
      // survivors keep indices 0 and 2. Rewriting from position closes it.
      final ids = await addThree();
      await splits().removeExerciseFromRoutine(ids[1]);

      expect((await planned()).map((e) => e.orderIndex), [0, 2]);

      await splits().reorderRoutineExercises([ids[0], ids[2]]);

      expect((await planned()).map((e) => e.orderIndex), [0, 1]);
    });

    test('an empty list is a no-op', () async {
      await expectLater(splits().reorderRoutineExercises([]), completes);
    });
  });
}
