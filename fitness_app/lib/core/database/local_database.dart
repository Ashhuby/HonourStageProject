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
  PersonalBests,
  Badges,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : _isTesting = false, super(_openConnection());
  AppDatabase.forTesting(super.executor) : _isTesting = true;

  final bool _isTesting;

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        if (!_isTesting) {
          await batch((b) {
            b.insertAll(exercises, [
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
              ExercisesCompanion.insert(
                name: 'Overhead Press',
                bodyPart: 'Shoulders',
                equipmentType: 'Barbell',
              ),
              ExercisesCompanion.insert(
                name: 'Barbell Row',
                bodyPart: 'Back',
                equipmentType: 'Barbell',
              ),
            ]);
          });
          await _seedBadges();
        }
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.createTable(routineExercises);
        }
        if (from < 3) {
          // WorkoutSplits
          await m.addColumn(workoutSplits, workoutSplits.remoteId);
          await m.addColumn(workoutSplits, workoutSplits.userId);
          await m.addColumn(workoutSplits, workoutSplits.syncedAt);
          await m.addColumn(workoutSplits, workoutSplits.deletedAt);
          // WorkoutRoutines
          await m.addColumn(workoutRoutines, workoutRoutines.remoteId);
          await m.addColumn(workoutRoutines, workoutRoutines.userId);
          await m.addColumn(workoutRoutines, workoutRoutines.syncedAt);
          await m.addColumn(workoutRoutines, workoutRoutines.deletedAt);
          // RoutineExercises
          await m.addColumn(routineExercises, routineExercises.remoteId);
          await m.addColumn(routineExercises, routineExercises.userId);
          await m.addColumn(routineExercises, routineExercises.syncedAt);
          await m.addColumn(routineExercises, routineExercises.deletedAt);
          // WorkoutSessions
          await m.addColumn(workoutSessions, workoutSessions.remoteId);
          await m.addColumn(workoutSessions, workoutSessions.userId);
          await m.addColumn(workoutSessions, workoutSessions.syncedAt);
          await m.addColumn(workoutSessions, workoutSessions.deletedAt);
          // WorkoutSets
          await m.addColumn(workoutSets, workoutSets.remoteId);
          await m.addColumn(workoutSets, workoutSets.userId);
          await m.addColumn(workoutSets, workoutSets.syncedAt);
          await m.addColumn(workoutSets, workoutSets.deletedAt);
        }
        if (from < 4) {
          await m.createTable(personalBests);
          await m.createTable(badges);
          await _seedBadges();
        }
        if (from < 5) {
          // Add sync columns to Exercises for custom exercise sync support.
          // Seeded default exercises get null values for all sync columns —
          // they are never synced since they are identical for all users.
          await m.addColumn(exercises, exercises.remoteId);
          await m.addColumn(exercises, exercises.userId);
          await m.addColumn(exercises, exercises.syncedAt);
          await m.addColumn(exercises, exercises.deletedAt);
        }
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _seedBadges() async {
    const badgeKeys = [
      'first_workout',
      'streak_7_day',
      'streak_30_day',
      'first_pr',
      'pr_10',
      'sets_50',
      'sets_500',
      'first_custom_exercise',
    ];
    await batch((b) {
      for (final key in badgeKeys) {
        b.insert(
          badges,
          BadgesCompanion.insert(badgeKey: key),
          onConflict: DoUpdate(
            (_) => BadgesCompanion.insert(badgeKey: key),
            target: [badges.badgeKey],
          ),
        );
      }
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'fitness_db.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}