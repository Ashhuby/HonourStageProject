import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../features/workout/data/workout_tables.dart';

part 'local_database.g.dart';

@DriftDatabase(
  tables: [
    Exercises,
    WorkoutSplits,
    WorkoutRoutines,
    RoutineExercises,
    WorkoutSessions,
    WorkoutSets,
    PersonalBests,
    Badges,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : _isTesting = false, super(_openConnection());
  AppDatabase.forTesting(super.executor) : _isTesting = true;

  final bool _isTesting;

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        if (!_isTesting) {
          await _seedExercises();
          await _seedBadges();
        }
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.createTable(routineExercises);
        }
        if (from < 3) {
          await m.addColumn(workoutSplits, workoutSplits.remoteId);
          await m.addColumn(workoutSplits, workoutSplits.userId);
          await m.addColumn(workoutSplits, workoutSplits.syncedAt);
          await m.addColumn(workoutSplits, workoutSplits.deletedAt);
          await m.addColumn(workoutRoutines, workoutRoutines.remoteId);
          await m.addColumn(workoutRoutines, workoutRoutines.userId);
          await m.addColumn(workoutRoutines, workoutRoutines.syncedAt);
          await m.addColumn(workoutRoutines, workoutRoutines.deletedAt);
          await m.addColumn(routineExercises, routineExercises.remoteId);
          await m.addColumn(routineExercises, routineExercises.userId);
          await m.addColumn(routineExercises, routineExercises.syncedAt);
          await m.addColumn(routineExercises, routineExercises.deletedAt);
          await m.addColumn(workoutSessions, workoutSessions.remoteId);
          await m.addColumn(workoutSessions, workoutSessions.userId);
          await m.addColumn(workoutSessions, workoutSessions.syncedAt);
          await m.addColumn(workoutSessions, workoutSessions.deletedAt);
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
          await customStatement(
            'ALTER TABLE exercises ADD COLUMN remote_id TEXT',
          );
          await customStatement(
            'ALTER TABLE exercises ADD COLUMN user_id TEXT',
          );
          await customStatement(
            'ALTER TABLE exercises ADD COLUMN synced_at INTEGER',
          );
          await customStatement(
            'ALTER TABLE exercises ADD COLUMN deleted_at INTEGER',
          );
        }
        if (from < 6) {
          // Add metricType to exercises — default weightReps for all existing rows
          await customStatement(
            "ALTER TABLE exercises ADD COLUMN metric_type TEXT NOT NULL DEFAULT 'weightReps'",
          );
          // Add duration and distance to workout_sets
          await customStatement(
            'ALTER TABLE workout_sets ADD COLUMN duration_seconds INTEGER',
          );
          await customStatement(
            'ALTER TABLE workout_sets ADD COLUMN distance_metres REAL',
          );
          // Make weight and reps nullable-friendly with defaults
          // (SQLite ALTER TABLE cannot change column constraints, but new rows
          // will use the Drift defaults. Existing rows already have values.)
          // Add new fields to personal_bests
          await customStatement(
            'ALTER TABLE personal_bests ADD COLUMN duration_seconds INTEGER',
          );
          await customStatement(
            'ALTER TABLE personal_bests ADD COLUMN distance_metres REAL',
          );
          await customStatement(
            "ALTER TABLE personal_bests ADD COLUMN metric_type TEXT NOT NULL DEFAULT 'weightReps'",
          );
          // Seed the expanded exercise library.
          // NOTE: `name` carries no unique constraint, so insertOnConflictUpdate
          // conflicts on `id` — which this companion never sets. Re-running the
          // seed therefore inserts rather than updates. Left as-is because
          // changing it now would alter an upgrade path already shipped; new
          // corrections must not re-run the seed (see _refileChinUps).
          await _seedExercises();
        }
        if (from < 7) {
          await _rebuildPersonalBests();
        }
        if (from < 8) {
          await _refileChinUps();
        }
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  /// Rebuilds personal_bests on the v7 unique key.
  ///
  /// Before v7 the table was keyed on (exercise_id, reps). Because reps varies
  /// per record, the upserts that were meant to replace a personal best
  /// inserted a new row instead, leaving several rows per exercise. That broke
  /// every read: bodyweight lookups threw once a third row appeared, and a
  /// distanceTime record was written over the wrong distance.
  ///
  /// The key becomes (exercise_id, metric_type, distance_metres), so surviving
  /// duplicates must be collapsed to the single best record per key before the
  /// constraint can be applied. Survivors are marked dirty so the corrected
  /// record uploads on the next sync.
  Future<void> _rebuildPersonalBests() async {
    final rows = await customSelect(
      'SELECT id, exercise_id, reps, weight, duration_seconds, '
      'distance_metres, metric_type, achieved_at, remote_id, user_id, '
      'deleted_at FROM personal_bests',
    ).get();

    // Collapse to the best row per (exercise, metric type, distance).
    final best = <String, QueryRow>{};
    for (final row in rows) {
      final key =
          '${row.read<int>('exercise_id')}|${row.read<String>('metric_type')}'
          '|${row.readNullable<double>('distance_metres') ?? 0.0}';
      final current = best[key];
      if (current == null || _supersedes(row, current)) best[key] = row;
    }

    await customStatement('DROP TABLE personal_bests');
    await createMigrator().createTable(personalBests);

    for (final row in best.values) {
      await into(personalBests).insert(
        PersonalBestsCompanion.insert(
          exerciseId: row.read<int>('exercise_id'),
          reps: Value(row.read<int>('reps')),
          weight: Value(row.read<double>('weight')),
          durationSeconds: Value(row.readNullable<int>('duration_seconds')),
          distanceMetres: Value(
            row.readNullable<double>('distance_metres') ?? 0.0,
          ),
          metricType: Value(row.read<String>('metric_type')),
          achievedAt: DateTime.fromMillisecondsSinceEpoch(
            row.read<int>('achieved_at') * 1000,
          ),
          remoteId: Value(row.readNullable<String>('remote_id')),
          userId: Value(row.readNullable<String>('user_id')),
          // Left dirty on purpose — the surviving record is re-uploaded.
          syncedAt: const Value(null),
          deletedAt: Value(
            row.readNullable<int>('deleted_at') == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(
                    row.read<int>('deleted_at') * 1000,
                  ),
          ),
        ),
      );
    }
  }

  /// Whether [candidate] is the better record of the two, by the comparator
  /// for its metric type. Used only to collapse pre-v7 duplicates.
  bool _supersedes(QueryRow candidate, QueryRow current) {
    switch (candidate.read<String>('metric_type')) {
      case 'timeOnly':
        return (candidate.readNullable<int>('duration_seconds') ?? 0) >
            (current.readNullable<int>('duration_seconds') ?? 0);
      case 'distanceTime':
        // Same distance by construction — the faster time wins.
        const noTime = 1 << 30;
        return (candidate.readNullable<int>('duration_seconds') ?? noTime) <
            (current.readNullable<int>('duration_seconds') ?? noTime);
      default:
        // weightReps and bodyweightReps: heaviest, then most reps.
        final candidateWeight = candidate.read<double>('weight');
        final currentWeight = current.read<double>('weight');
        if (candidateWeight != currentWeight) {
          return candidateWeight > currentWeight;
        }
        return candidate.read<int>('reps') > current.read<int>('reps');
    }
  }

  /// Re-files Chin Ups from Biceps to Back (v8).
  ///
  /// The original seed filed a lat-dominant pull under its secondary mover,
  /// which was invisible while the library was a flat list but is not now that
  /// tapping the Back region on the body map is how the exercise is found.
  ///
  /// A targeted UPDATE rather than a re-run of [_seedExercises]: `exercises`
  /// has no unique constraint on `name`, so insertOnConflictUpdate conflicts on
  /// `id` and would insert a second Chin Ups rather than correct the first.
  /// Raw SQL, like the other migration helpers, so it stays valid against the
  /// v8 schema regardless of how the table is later shaped.
  ///
  /// Guarded on the old value so a user who has already re-filed it — or who
  /// added their own Chin Ups row — is left alone.
  Future<void> _refileChinUps() async {
    await customStatement(
      "UPDATE exercises SET body_part = 'Back' "
      "WHERE name = 'Chin Ups' AND body_part = 'Biceps' AND is_custom = 0",
    );
  }

  Future<void> _seedExercises() async {
    // Helper — insert or update by name
    Future<void> seed(
      String name,
      String bodyPart,
      String equipment,
      String metricType,
    ) async {
      await into(exercises).insertOnConflictUpdate(
        ExercisesCompanion.insert(
          name: name,
          bodyPart: bodyPart,
          equipmentType: equipment,
          metricType: Value(metricType),
        ),
      );
    }

    // Chest
    await seed('Bench Press', 'Chest', 'Barbell', 'weightReps');
    await seed('Incline Bench Press', 'Chest', 'Barbell', 'weightReps');
    await seed('Chest Fly', 'Chest', 'Dumbbell', 'weightReps');
    await seed('Dips', 'Chest', 'Body Weight', 'bodyweightReps');
    await seed('Cable Fly', 'Chest', 'Cable', 'weightReps');

    // Back
    await seed('Deadlift', 'Back', 'Barbell', 'weightReps');
    await seed('Barbell Row', 'Back', 'Barbell', 'weightReps');
    await seed('Pull Ups', 'Back', 'Body Weight', 'bodyweightReps');
    await seed('Chin Ups', 'Back', 'Body Weight', 'bodyweightReps');
    await seed('Lat Pulldown', 'Back', 'Cable', 'weightReps');
    await seed('Seated Cable Row', 'Back', 'Cable', 'weightReps');
    await seed('T-Bar Row', 'Back', 'Machine', 'weightReps');
    await seed('Dead Hang', 'Back', 'Body Weight', 'timeOnly');

    // Legs
    await seed('Squat', 'Legs', 'Barbell', 'weightReps');
    await seed('Romanian Deadlift', 'Legs', 'Barbell', 'weightReps');
    await seed('Leg Press', 'Legs', 'Machine', 'weightReps');
    await seed('Lunges', 'Legs', 'Dumbbell', 'weightReps');
    await seed('Leg Curl', 'Legs', 'Machine', 'weightReps');
    await seed('Leg Extension', 'Legs', 'Machine', 'weightReps');
    await seed('Calf Raise', 'Legs', 'Machine', 'weightReps');

    // Shoulders
    await seed('Shoulder Press', 'Shoulders', 'Dumbbell', 'weightReps');
    await seed('Overhead Press', 'Shoulders', 'Barbell', 'weightReps');
    await seed('Lateral Raise', 'Shoulders', 'Dumbbell', 'weightReps');
    await seed('Front Raise', 'Shoulders', 'Dumbbell', 'weightReps');
    await seed('Face Pull', 'Shoulders', 'Cable', 'weightReps');
    await seed('Shrugs', 'Shoulders', 'Barbell', 'weightReps');

    // Arms
    await seed('Barbell Curl', 'Biceps', 'Barbell', 'weightReps');
    await seed('Dumbbell Curl', 'Biceps', 'Dumbbell', 'weightReps');
    await seed('Hammer Curl', 'Biceps', 'Dumbbell', 'weightReps');
    await seed('Tricep Pushdown', 'Triceps', 'Cable', 'weightReps');
    await seed('Skull Crushers', 'Triceps', 'Barbell', 'weightReps');
    await seed('Close Grip Bench', 'Triceps', 'Barbell', 'weightReps');

    // Core
    await seed('Plank', 'Core', 'Body Weight', 'timeOnly');
    await seed('Crunches', 'Core', 'Body Weight', 'bodyweightReps');
    await seed('Russian Twist', 'Core', 'Body Weight', 'bodyweightReps');
    await seed('Leg Raise', 'Core', 'Body Weight', 'bodyweightReps');
    await seed('Ab Wheel', 'Core', 'Body Weight', 'bodyweightReps');
    await seed('Cable Crunch', 'Core', 'Cable', 'weightReps');

    // Cardio
    await seed('Running', 'Whole Body', 'Body Weight', 'distanceTime');
    await seed('Cycling', 'Whole Body', 'Machine', 'distanceTime');
    await seed('Rowing Machine', 'Whole Body', 'Machine', 'distanceTime');
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
