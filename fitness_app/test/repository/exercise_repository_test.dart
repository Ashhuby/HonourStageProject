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

  group('Exercise Repository', () {
    test('inserts an exercise and retrieves it', () async {
      await db.into(db.exercises).insert(
            ExercisesCompanion.insert(
              name: 'Bench Press',
              bodyPart: 'Chest',
              equipmentType: 'Barbell',
            ),
          );

      final results = await db.select(db.exercises).get();
      expect(results.length, 1);
      expect(results.first.name, 'Bench Press');
      expect(results.first.bodyPart, 'Chest');
    });

    test('deletes an exercise', () async {
      final id = await db.into(db.exercises).insert(
            ExercisesCompanion.insert(
              name: 'Squat',
              bodyPart: 'Legs',
              equipmentType: 'Barbell',
            ),
          );

      await (db.delete(db.exercises)..where((e) => e.id.equals(id))).go();

      final results = await db.select(db.exercises).get();
      expect(results, isEmpty);
    });

    test('inserts multiple exercises and retrieves all', () async {
      await db.batch((batch) {
        batch.insertAll(db.exercises, [
          ExercisesCompanion.insert(
            name: 'Deadlift',
            bodyPart: 'Back',
            equipmentType: 'Barbell',
          ),
          ExercisesCompanion.insert(
            name: 'Shoulder Press',
            bodyPart: 'Shoulders',
            equipmentType: 'Dumbbell',
          ),
        ]);
      });

      final results = await db.select(db.exercises).get();
      expect(results.length, 2);
    });
  });
}