import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../features/workout/data/workout_tables.dart';

part 'local_database.g.dart';

@DriftDatabase(tables: [
  Exercises,
  WorkoutSplits,
  WorkoutRoutines,
  RoutineExercises,
  WorkoutSessions,
  WorkoutSets,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : _isTesting = false, super(_openConnection());
  AppDatabase.forTesting(super.executor) : _isTesting = true;

  final bool _isTesting;

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        if (!_isTesting) {
          await batch((batch) {
            batch.insertAll(exercises, [
              ExercisesCompanion.insert(
                name: 'Bench Press',
                bodyPart: 'Chest',
                equipmentType: 'Barbell',
              ),
              ExercisesCompanion.insert(
                name: 'Squat',
                bodyPart: 'Legs',
                equipmentType: 'Barbell',
              ),
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
        }
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.createTable(routineExercises);
        }
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'fitness_db.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}