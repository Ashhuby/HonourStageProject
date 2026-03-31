// lib/core/database/local_database.dart
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
  int get schemaVersion => 4;

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
          // Seed all badge definitions as unearned (earnedAt = null).
          // This guarantees the badges screen always has a full list to render
          // regardless of whether the user has triggered any badge yet.
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
          // Feature: Personal Best (PR) tracking
          await m.createTable(personalBests);
          // Feature: Badges and Achievements
          await m.createTable(badges);
          // Seed badge definitions for existing installs.
          // New installs hit onCreate above; upgrades hit this path.
          await _seedBadges();
        }
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  /// Inserts all known badge keys with earnedAt = null (unearned).
  /// Uses insertOnConflictUpdate so it is safe to call on both
  /// onCreate and onUpgrade — re-running it will never duplicate or
  /// overwrite an already-earned badge.
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
            // On conflict (key already exists) do nothing — preserve
            // any earnedAt that has already been set.
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