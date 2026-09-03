import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../features/workout/data/workout_tables.dart';
import '../../features/workout/domain/muscle.dart';
import 'exercise_seed.dart';

part 'local_database.g.dart';

@DriftDatabase(
  tables: [
    Exercises,
    ExerciseMuscles,
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
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await _createMuscleIndexes();
        await _guardExerciseUniqueness();
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
          // withMuscles: false — exercise_muscles does not exist until the
          // v9 branch below, which backfills these rows by name anyway.
          await _seedExercises(withMuscles: false);
        }
        if (from < 7) {
          await _rebuildPersonalBests();
        }
        if (from < 8) {
          await _refileChinUps();
        }
        if (from < 9) {
          await _migrateToMuscleTaxonomy(m);
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

  // ---------------------------------------------------------------------------
  // v9 — the muscle taxonomy
  // ---------------------------------------------------------------------------

  /// Constraints on `exercise_muscles` that SQLite cannot express in the table
  /// definition and drift cannot express as a `@TableIndex`.
  ///
  /// `IF NOT EXISTS` throughout so this is safe to call from both `onCreate`
  /// and the v9 upgrade, and so the migration tests can drop the table without
  /// having to track its indexes.
  Future<void> _createMuscleIndexes() async {
    // "Exactly one primary per exercise", as a constraint rather than a
    // convention the writing code is trusted to honour.
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_exercise_muscles_primary '
      'ON exercise_muscles (exercise_id) WHERE is_primary = 1',
    );
    // Reverse lookup — every exercise training a muscle, primaries first.
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_exercise_muscles_lookup '
      'ON exercise_muscles (muscle, is_primary)',
    );
  }

  /// Uniqueness guards that make the two duplication bugs unrepeatable: the
  /// seed re-run that inserted instead of updating, and the sync download that
  /// does the same thing keyed on `remote_id`.
  ///
  /// Deliberately best-effort. A statement that throws inside `onUpgrade`
  /// propagates out of the database open and bricks the app on launch, and
  /// these indexes are a safety net rather than a correctness requirement — if
  /// a library still holds duplicates the dedupe could not resolve, the app
  /// must still start. The next release tries again.
  Future<void> _guardExerciseUniqueness() async {
    try {
      await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_exercises_seed_name '
        'ON exercises (name) WHERE is_custom = 0',
      );
    } catch (_) {
      // Duplicates survive; the library shows them twice but still opens.
    }
    try {
      await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_exercises_remote_id '
        'ON exercises (remote_id) WHERE remote_id IS NOT NULL',
      );
    } catch (_) {
      // As above — a duplicated download is visible, not fatal.
    }
  }

  /// v8 to v9: replaces the single free-text `bodyPart` with a primary muscle
  /// and zero or more secondaries in `exercise_muscles`.
  ///
  /// Foreign keys are OFF for the whole of this method — `PRAGMA foreign_keys`
  /// is set in `beforeOpen`, which drift runs *after* `onUpgrade`. So
  /// `ON DELETE CASCADE` does not fire here and every child row is handled by
  /// hand; the upside is that re-pointing `exercise_id` is not FK-checked, so
  /// the order of the repairs below does not matter.
  ///
  /// Does NOT re-run [_seedExercises] to pick up the new data. Before v9 there
  /// was no unique constraint on `name`, so a re-run inserted 41 more rows
  /// rather than updating. The existing library is enriched in place, matched
  /// on name.
  Future<void> _migrateToMuscleTaxonomy(Migrator m) async {
    await m.createTable(exerciseMuscles);
    await _createMuscleIndexes();
    await _dedupeSeededExercises();
    await _backfillSeededMuscles();
    await _backfillRemainingMuscles();
    await _syncBodyPartToPrimaryGroup();
    await _guardExerciseUniqueness();
  }

  /// Collapses the duplicate seeded exercises left behind by the v6 upgrade.
  ///
  /// That branch called `_seedExercises()`, whose `insertOnConflictUpdate`
  /// conflicted on `id` rather than `name` and so inserted a second copy of
  /// every default exercise. The backfill below matches on name, and the
  /// uniqueness guard cannot be applied, until these are resolved.
  ///
  /// The survivor is the lowest `id` — the original, and the one existing sets
  /// and routines are most likely to reference already.
  Future<void> _dedupeSeededExercises() async {
    final groups = await customSelect(
      'SELECT name, MIN(id) AS winner FROM exercises '
      'WHERE is_custom = 0 GROUP BY name HAVING COUNT(*) > 1',
    ).get();

    for (final group in groups) {
      final winner = group.read<int>('winner');
      final losers = (await customSelect(
        'SELECT id FROM exercises '
        'WHERE is_custom = 0 AND name = ? AND id <> ?',
        variables: [
          Variable<String>(group.read<String>('name')),
          Variable<int>(winner),
        ],
      ).get()).map((row) => row.read<int>('id'));

      for (final loser in losers) {
        await customStatement(
          'UPDATE routine_exercises SET exercise_id = ? WHERE exercise_id = ?',
          [winner, loser],
        );
        await customStatement(
          'UPDATE workout_sets SET exercise_id = ? WHERE exercise_id = ?',
          [winner, loser],
        );
        await _mergePersonalBests(loser: loser, winner: winner);
        // Explicit — the FK cascade is inert during onUpgrade.
        await customStatement('DELETE FROM exercises WHERE id = ?', [loser]);
      }
    }
  }

  /// Moves the loser's personal bests onto the winner, keeping the better
  /// record wherever both hold one for the same key.
  ///
  /// A blind re-point would violate the v7 unique key
  /// (exercise_id, metric_type, distance_metres). Survivors are left dirty so
  /// the corrected record uploads on the next sync, matching what
  /// [_rebuildPersonalBests] does.
  Future<void> _mergePersonalBests({
    required int loser,
    required int winner,
  }) async {
    const columns =
        'id, exercise_id, reps, weight, duration_seconds, distance_metres, '
        'metric_type, achieved_at, remote_id, user_id, deleted_at';

    final incoming = await customSelect(
      'SELECT $columns FROM personal_bests WHERE exercise_id = ?',
      variables: [Variable<int>(loser)],
    ).get();

    for (final row in incoming) {
      // "IS" rather than "=" so a NULL distance matches a NULL distance,
      // which is how the v7 unique key treats it.
      final held = await customSelect(
        'SELECT $columns FROM personal_bests '
        'WHERE exercise_id = ? AND metric_type = ? AND distance_metres IS ?',
        variables: [
          Variable<int>(winner),
          Variable<String>(row.read<String>('metric_type')),
          Variable<double>(row.readNullable<double>('distance_metres')),
        ],
      ).getSingleOrNull();

      if (held == null) {
        await customStatement(
          'UPDATE personal_bests SET exercise_id = ?, synced_at = NULL '
          'WHERE id = ?',
          [winner, row.read<int>('id')],
        );
        continue;
      }

      if (_supersedes(row, held)) {
        // Drop the weaker record the winner held, then move the better one on.
        await customStatement('DELETE FROM personal_bests WHERE id = ?', [
          held.read<int>('id'),
        ]);
        await customStatement(
          'UPDATE personal_bests SET exercise_id = ?, synced_at = NULL '
          'WHERE id = ?',
          [winner, row.read<int>('id')],
        );
      } else {
        await customStatement('DELETE FROM personal_bests WHERE id = ?', [
          row.read<int>('id'),
        ]);
      }
    }
  }

  /// Gives the 41 default exercises their primary and secondary muscles.
  ///
  /// Matched on name, so it is indifferent to what `bodyPart` currently holds —
  /// which matters for a library that never ran the v8 Chin Ups refile — and a
  /// renamed or deleted default simply gets no rows here and falls through to
  /// [_backfillRemainingMuscles].
  Future<void> _backfillSeededMuscles() async {
    for (final seed in kSeedExercises) {
      final ids = (await customSelect(
        'SELECT id FROM exercises WHERE name = ? AND is_custom = 0',
        variables: [Variable<String>(seed.name)],
      ).get()).map((row) => row.read<int>('id'));

      for (final id in ids) {
        await _writeSeedMuscles(id, seed);
      }
    }
  }

  /// Gives every remaining exercise a primary muscle derived from its old
  /// `bodyPart` string — custom exercises, renamed defaults, and anything
  /// downloaded from a client that predates the taxonomy.
  ///
  /// After this every exercise has exactly one primary, which is the invariant
  /// the filtering and grouping code is written against.
  Future<void> _backfillRemainingMuscles() async {
    final orphans = await customSelect(
      'SELECT id, body_part FROM exercises '
      'WHERE id NOT IN (SELECT exercise_id FROM exercise_muscles)',
    ).get();

    for (final row in orphans) {
      final muscle = muscleForLegacyBodyPart(row.read<String>('body_part'));
      await customStatement(
        'INSERT OR IGNORE INTO exercise_muscles '
        '(exercise_id, muscle, is_primary) VALUES (?, ?, 1)',
        [row.read<int>('id'), muscle.name],
      );
    }
  }

  /// Rewrites `bodyPart` to the primary muscle's group label.
  ///
  /// The column survives v9 as a denormalised cache: it is what sync uploads
  /// and what the remote schema declares NOT NULL, so dropping it would mean
  /// synthesising a placeholder on every upload. Driving it from the primary
  /// muscle — rather than string-rewriting the old labels — makes it correct
  /// by construction, including for rows whose `bodyPart` was free text.
  ///
  /// The vocabulary changes here: `Biceps` and `Triceps` become `Arms`, and
  /// `Whole Body` becomes `Full Body`. An older client downloading such a row
  /// fails to parse the label and files the exercise under "Other" — it
  /// degrades rather than crashing, which is what the tolerant parser is for.
  Future<void> _syncBodyPartToPrimaryGroup() async {
    final rows = await customSelect(
      'SELECT e.id AS id, e.body_part AS body_part, em.muscle AS muscle '
      'FROM exercises e '
      'JOIN exercise_muscles em ON em.exercise_id = e.id AND em.is_primary = 1',
    ).get();

    for (final row in rows) {
      final muscle =
          Muscle.byNameOrNull(row.read<String>('muscle')) ?? Muscle.fullBody;
      final label = muscle.group.label;
      if (row.read<String>('body_part') == label) continue;

      // Custom rows go dirty so the corrected label uploads on the next sync.
      await customStatement(
        'UPDATE exercises SET body_part = ?, '
        'synced_at = CASE WHEN is_custom = 1 THEN NULL ELSE synced_at END '
        'WHERE id = ?',
        [label, row.read<int>('id')],
      );
    }
  }

  /// Writes the default library, inserting missing rows and refreshing ones
  /// that already exist.
  ///
  /// A real upsert keyed on name, unlike the `insertOnConflictUpdate` this
  /// replaces: `exercises` has no unique constraint on `name`, so that
  /// conflicted on `id` — which the companion never sets — and inserted a
  /// duplicate every time the seed ran. The v6 upgrade branch calls this, so
  /// libraries in the wild are already carrying duplicates; v9 collapses them.
  ///
  /// [withMuscles] is false when called from the v6 branch, which runs before
  /// `exercise_muscles` exists. Those rows are backfilled by name in v9.
  Future<void> _seedExercises({bool withMuscles = true}) async {
    for (final seed in kSeedExercises) {
      // limit(1) so this stays safe against pre-v9 duplicates.
      final existing =
          await (select(exercises)
                ..where(
                  (e) => e.name.equals(seed.name) & e.isCustom.equals(false),
                )
                ..limit(1))
              .getSingleOrNull();

      final int id;
      if (existing == null) {
        id = await into(exercises).insert(
          ExercisesCompanion.insert(
            name: seed.name,
            bodyPart: seed.primary.group.label,
            equipmentType: seed.equipment,
            metricType: Value(seed.metricType),
          ),
        );
      } else {
        id = existing.id;
        await (update(exercises)..where((e) => e.id.equals(id))).write(
          ExercisesCompanion(
            bodyPart: Value(seed.primary.group.label),
            equipmentType: Value(seed.equipment),
            metricType: Value(seed.metricType),
          ),
        );
      }

      if (withMuscles) {
        await _writeSeedMuscles(id, seed);
      }
    }
  }

  /// Writes one exercise's primary and secondary muscle rows.
  ///
  /// Raw SQL with `INSERT OR IGNORE` so it is re-runnable and usable from
  /// inside a migration, where the Dart table classes may be ahead of the
  /// database's actual shape.
  Future<void> _writeSeedMuscles(int exerciseId, SeedExercise seed) async {
    await customStatement(
      'INSERT OR IGNORE INTO exercise_muscles (exercise_id, muscle, is_primary) '
      'VALUES (?, ?, 1)',
      [exerciseId, seed.primary.name],
    );
    for (final muscle in seed.secondary) {
      await customStatement(
        'INSERT OR IGNORE INTO exercise_muscles (exercise_id, muscle, is_primary) '
        'VALUES (?, ?, 0)',
        [exerciseId, muscle.name],
      );
    }
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
