import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/core/database/local_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Split Repository', () {
    test('creates a split and retrieves it', () async {
      await db
          .into(db.workoutSplits)
          .insert(WorkoutSplitsCompanion.insert(name: '6-Day PPL'));

      final results = await db.select(db.workoutSplits).get();
      expect(results.length, 1);
      expect(results.first.name, '6-Day PPL');
    });

    test('deletes a split', () async {
      final id = await db
          .into(db.workoutSplits)
          .insert(WorkoutSplitsCompanion.insert(name: 'Push Pull Legs'));

      await (db.delete(db.workoutSplits)..where((s) => s.id.equals(id))).go();

      final results = await db.select(db.workoutSplits).get();
      expect(results, isEmpty);
    });

    test('adds a routine to a split', () async {
      final splitId = await db
          .into(db.workoutSplits)
          .insert(WorkoutSplitsCompanion.insert(name: 'My Split'));

      await db
          .into(db.workoutRoutines)
          .insert(
            WorkoutRoutinesCompanion.insert(
              name: 'Push Day',
              splitId: splitId,
              orderIndex: 0,
            ),
          );

      final routines = await (db.select(
        db.workoutRoutines,
      )..where((r) => r.splitId.equals(splitId))).get();

      expect(routines.length, 1);
      expect(routines.first.name, 'Push Day');
    });

    test('adds an exercise to a routine', () async {
      final splitId = await db
          .into(db.workoutSplits)
          .insert(WorkoutSplitsCompanion.insert(name: 'My Split'));

      final routineId = await db
          .into(db.workoutRoutines)
          .insert(
            WorkoutRoutinesCompanion.insert(
              name: 'Push Day',
              splitId: splitId,
              orderIndex: 0,
            ),
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

      await db
          .into(db.routineExercises)
          .insert(
            RoutineExercisesCompanion.insert(
              routineId: routineId,
              exerciseId: exerciseId,
              orderIndex: 0,
            ),
          );

      final routineExercises = await (db.select(
        db.routineExercises,
      )..where((re) => re.routineId.equals(routineId))).get();

      expect(routineExercises.length, 1);
      expect(routineExercises.first.exerciseId, exerciseId);
    });

    test('deleting a split cascades to routines', () async {
      final splitId = await db
          .into(db.workoutSplits)
          .insert(WorkoutSplitsCompanion.insert(name: 'Cascade Test'));

      await db
          .into(db.workoutRoutines)
          .insert(
            WorkoutRoutinesCompanion.insert(
              name: 'Day 1',
              splitId: splitId,
              orderIndex: 0,
            ),
          );

      await (db.delete(
        db.workoutSplits,
      )..where((s) => s.id.equals(splitId))).go();

      final routines = await db.select(db.workoutRoutines).get();
      expect(routines, isEmpty);
    });
  });
}
