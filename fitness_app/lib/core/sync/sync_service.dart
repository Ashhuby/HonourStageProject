import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../database/local_database.dart';
import '../../features/workout/domain/muscle.dart';
import 'exercise_muscle_payload.dart';
import 'set_payload.dart';

/// Handles upload of dirty (unsynced) local records to Supabase.
/// Upload-only, last-write-wins. Download path is triggered on first login.
/// Designed to be instantiated without Flutter context for workmanager isolate.
class SyncService {
  final AppDatabase db;
  final SupabaseClient supabase;
  final _uuid = const Uuid();

  SyncService({required this.db, required this.supabase});

  String? get _userId => supabase.auth.currentUser?.id;

  /// Entry point — upload all dirty records across all syncable tables.
  /// FK-ordered: splits → routines → routineExercises → sessions → sets
  /// PersonalBests and Badges have no parent FK dependencies so they
  /// run last but could run in any order.
  /// Marks every syncable row dirty so the next sync re-uploads all of it.
  ///
  /// Sync only pushes rows whose `synced_at` is null, which assumes the server
  /// still holds everything it has ever acknowledged. When that stops being
  /// true — the remote was wiped, a project restored from an older backup, a
  /// row deleted by hand — the client has no way to notice: the parents are
  /// never re-sent, and every child that references one fails its foreign key
  /// for good. Sync then reports failure on every attempt and never recovers.
  ///
  /// This is the way out. The upserts are keyed on `remote_id`, so a full
  /// re-upload recreates what is missing and leaves what is not alone, and
  /// `uploadDirtyRecords` already sends parents before children.
  Future<void> markEverythingForReupload() async {
    await db.transaction(() async {
      for (final statement in const [
        'UPDATE workout_splits SET synced_at = NULL',
        'UPDATE workout_routines SET synced_at = NULL',
        'UPDATE routine_exercises SET synced_at = NULL',
        'UPDATE workout_sessions SET synced_at = NULL',
        'UPDATE workout_sets SET synced_at = NULL',
        'UPDATE personal_bests SET synced_at = NULL',
        'UPDATE badges SET synced_at = NULL WHERE earned_at IS NOT NULL',
        'UPDATE exercises SET synced_at = NULL WHERE is_custom = 1',
      ]) {
        await db.customStatement(statement);
      }
    });
  }

  Future<SyncResult> uploadDirtyRecords() async {
    final userId = _userId;
    if (userId == null) return SyncResult.unauthenticated();

    int uploaded = 0;
    final errors = <String>[];

    try {
      uploaded += await _syncSplits(userId);
    } catch (e) {
      errors.add('splits: $e');
    }

    try {
      uploaded += await _syncRoutines(userId);
    } catch (e) {
      errors.add('routines: $e');
    }

    try {
      uploaded += await _syncRoutineExercises(userId);
    } catch (e) {
      errors.add('routineExercises: $e');
    }

    try {
      uploaded += await _syncSessions(userId);
    } catch (e) {
      errors.add('sessions: $e');
    }

    try {
      uploaded += await _syncSets(userId);
    } catch (e) {
      errors.add('sets: $e');
    }

    try {
      // After the sets, never before — see the doc on the method.
      await _purgeSyncedSessionTombstones();
    } catch (e) {
      errors.add('sessionTombstones: $e');
    }

    try {
      uploaded += await _syncPersonalBests(userId);
    } catch (e) {
      errors.add('personalBests: $e');
    }

    try {
      uploaded += await _syncBadges(userId);
    } catch (e) {
      errors.add('badges: $e');
    }

    try {
      uploaded += await _syncCustomExercises(userId);
    } catch (e) {
      errors.add('customExercises: $e');
    }

    try {
      // Last, and in this order: a routine can only go once no session needs
      // it, and a split only once its routines have gone.
      await _purgeSyncedRoutineTombstones();
      await _purgeSyncedSplitTombstones();
    } catch (e) {
      errors.add('tombstones: $e');
    }

    return SyncResult(
      uploaded: uploaded,
      errors: errors,
      success: errors.isEmpty,
    );
  }

  // ---------------------------------------------------------------------------
  // Splits
  // ---------------------------------------------------------------------------

  Future<int> _syncSplits(String userId) async {
    final dirty = await (db.select(
      db.workoutSplits,
    )..where((s) => s.syncedAt.isNull())).get();

    for (final split in dirty) {
      final remoteId = split.remoteId ?? _uuid.v4();

      await supabase.from('workout_splits').upsert({
        'id': remoteId,
        'user_id': userId,
        'local_id': split.id,
        'name': split.name,
        'created_at': split.createdAt.toIso8601String(),
        'deleted_at': split.deletedAt?.toIso8601String(),
        'synced_at': DateTime.now().toIso8601String(),
      });

      await (db.update(
        db.workoutSplits,
      )..where((s) => s.id.equals(split.id))).write(
        WorkoutSplitsCompanion(
          remoteId: Value(remoteId),
          userId: Value(userId),
          syncedAt: Value(DateTime.now()),
        ),
      );

      // Deliberately not deleted here — see _purgeSyncedSplitTombstones,
      // which runs once the routines below it are gone.
    }

    return dirty.length;
  }

  // ---------------------------------------------------------------------------
  // Routines
  // ---------------------------------------------------------------------------

  Future<int> _syncRoutines(String userId) async {
    final dirty = await (db.select(
      db.workoutRoutines,
    )..where((r) => r.syncedAt.isNull())).get();

    for (final routine in dirty) {
      final split = await (db.select(
        db.workoutSplits,
      )..where((s) => s.id.equals(routine.splitId))).getSingleOrNull();

      if (split == null || split.remoteId == null) continue;

      final remoteId = routine.remoteId ?? _uuid.v4();

      await supabase.from('workout_routines').upsert({
        'id': remoteId,
        'user_id': userId,
        'local_id': routine.id,
        'split_id': split.remoteId,
        'name': routine.name,
        'order_index': routine.orderIndex,
        'deleted_at': routine.deletedAt?.toIso8601String(),
        'synced_at': DateTime.now().toIso8601String(),
      });

      await (db.update(
        db.workoutRoutines,
      )..where((r) => r.id.equals(routine.id))).write(
        WorkoutRoutinesCompanion(
          remoteId: Value(remoteId),
          userId: Value(userId),
          syncedAt: Value(DateTime.now()),
        ),
      );

      // Deliberately not deleted here — see _purgeSyncedRoutineTombstones.
    }

    return dirty.length;
  }

  // ---------------------------------------------------------------------------
  // RoutineExercises
  // ---------------------------------------------------------------------------

  Future<int> _syncRoutineExercises(String userId) async {
    final dirty = await (db.select(
      db.routineExercises,
    )..where((re) => re.syncedAt.isNull())).get();

    for (final re in dirty) {
      final routine = await (db.select(
        db.workoutRoutines,
      )..where((r) => r.id.equals(re.routineId))).getSingleOrNull();

      if (routine == null || routine.remoteId == null) continue;

      final remoteId = re.remoteId ?? _uuid.v4();

      await supabase.from('routine_exercises').upsert({
        'id': remoteId,
        'user_id': userId,
        'local_id': re.id,
        'routine_id': routine.remoteId,
        'exercise_id': re.exerciseId,
        'order_index': re.orderIndex,
        'target_sets': re.targetSets,
        'target_reps': re.targetReps,
        'deleted_at': re.deletedAt?.toIso8601String(),
        'synced_at': DateTime.now().toIso8601String(),
      });

      await (db.update(
        db.routineExercises,
      )..where((r) => r.id.equals(re.id))).write(
        RoutineExercisesCompanion(
          remoteId: Value(remoteId),
          userId: Value(userId),
          syncedAt: Value(DateTime.now()),
        ),
      );

      if (re.deletedAt != null) {
        await (db.delete(
          db.routineExercises,
        )..where((r) => r.id.equals(re.id))).go();
      }
    }

    return dirty.length;
  }

  // ---------------------------------------------------------------------------
  // Sessions
  // ---------------------------------------------------------------------------

  Future<int> _syncSessions(String userId) async {
    final dirty = await (db.select(
      db.workoutSessions,
    )..where((s) => s.syncedAt.isNull())).get();

    for (final session in dirty) {
      if (session.endTime == null) {
        // Discarded before it finished. Uploading requires an endTime, so
        // this row was never sent and has nothing to tombstone — but the
        // bare `continue` that used to be here skipped it on every run,
        // leaving it dirty forever and stranding its sets too, because
        // _syncSets bails on a set whose session has no remoteId.
        if (session.deletedAt != null) {
          await (db.delete(
            db.workoutSessions,
          )..where((s) => s.id.equals(session.id))).go();
        }
        continue;
      }

      String? routineRemoteId;
      if (session.routineId != null) {
        final routine = await (db.select(
          db.workoutRoutines,
        )..where((r) => r.id.equals(session.routineId!))).getSingleOrNull();
        routineRemoteId = routine?.remoteId;
      }

      final remoteId = session.remoteId ?? _uuid.v4();

      await supabase.from('workout_sessions').upsert({
        'id': remoteId,
        'user_id': userId,
        'local_id': session.id,
        'routine_id': routineRemoteId,
        'start_time': session.startTime.toIso8601String(),
        'end_time': session.endTime?.toIso8601String(),
        'session_note': session.sessionNote,
        'deleted_at': session.deletedAt?.toIso8601String(),
        'synced_at': DateTime.now().toIso8601String(),
      });

      await (db.update(
        db.workoutSessions,
      )..where((s) => s.id.equals(session.id))).write(
        WorkoutSessionsCompanion(
          remoteId: Value(remoteId),
          userId: Value(userId),
          syncedAt: Value(DateTime.now()),
        ),
      );

      // The local row is NOT deleted here even once its tombstone is up —
      // see _purgeSyncedSessionTombstones, which runs after the sets.
    }

    return dirty.length;
  }

  /// Removes session rows whose tombstone has reached the remote copy.
  ///
  /// Deliberately not part of [_syncSessions]. `workout_sets` cascades on
  /// `session_id` and foreign keys are on, so deleting the session there wiped
  /// its sets locally *before* [_syncSets] could upload their own tombstones —
  /// leaving the remote sets with `deleted_at` null forever.
  ///
  /// The FK ordering documented on [uploadDirtyRecords] is an *insert*
  /// ordering, parents first so a child can name its parent. Deletes have to
  /// unwind the other way.
  ///
  /// The `NOT EXISTS` guard means a session whose sets failed to upload keeps
  /// its children alive to be retried, rather than losing them. It is keyed on
  /// state rather than on this run's work, so it also clears rows already
  /// stranded by the previous behaviour.
  /// Removes routine rows whose tombstone has reached the remote copy, and
  /// which nothing local still points at.
  ///
  /// Sync used to delete these the moment it had pushed the tombstone, which
  /// failed outright: `workout_sessions.routine_id` references this table with
  /// no delete action, so removing a routine any session was logged against
  /// raises FOREIGN KEY constraint failed (787) and takes the whole sync step
  /// down with it. Deleting a split was worse — routines cascade from it, so
  /// the cascade hit the same wall one level down.
  ///
  /// A session has to keep the routine it was performed against; that is what
  /// gives the history its name. So the tombstone stays until the history
  /// does, which costs one hidden row and no correctness: every query already
  /// filters on `deleted_at IS NULL`.
  Future<void> _purgeSyncedRoutineTombstones() async {
    await db.customStatement('''
      DELETE FROM workout_routines
      WHERE deleted_at IS NOT NULL
        AND synced_at IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM workout_sessions
          WHERE workout_sessions.routine_id = workout_routines.id
        )
    ''');
  }

  /// Removes split rows whose tombstone has reached the remote copy, once the
  /// routines that cascade from them are gone.
  ///
  /// Runs after [_purgeSyncedRoutineTombstones], never before: deleting a
  /// split cascades into its routines, and a cascade cannot stop to check
  /// whether a session still needs one.
  Future<void> _purgeSyncedSplitTombstones() async {
    await db.customStatement('''
      DELETE FROM workout_splits
      WHERE deleted_at IS NOT NULL
        AND synced_at IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM workout_routines
          WHERE workout_routines.split_id = workout_splits.id
        )
    ''');
  }

  Future<void> _purgeSyncedSessionTombstones() async {
    await db.customStatement('''
      DELETE FROM workout_sessions
      WHERE deleted_at IS NOT NULL
        AND synced_at IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM workout_sets
          WHERE workout_sets.session_id = workout_sessions.id
            AND workout_sets.synced_at IS NULL
        )
    ''');
  }

  // ---------------------------------------------------------------------------
  // Sets
  // ---------------------------------------------------------------------------

  Future<int> _syncSets(String userId) async {
    final dirty = await (db.select(
      db.workoutSets,
    )..where((s) => s.syncedAt.isNull())).get();

    for (final set in dirty) {
      final session = await (db.select(
        db.workoutSessions,
      )..where((s) => s.id.equals(set.sessionId))).getSingleOrNull();

      if (session == null || session.remoteId == null) continue;

      final remoteId = set.remoteId ?? _uuid.v4();

      await supabase.from('workout_sets').upsert({
        'id': remoteId,
        'user_id': userId,
        'local_id': set.id,
        'session_id': session.remoteId,
        'exercise_id': set.exerciseId,
        'weight': set.weight,
        'reps': set.reps,
        'is_completed': set.isCompleted,
        'timestamp': set.timestamp.toIso8601String(),
        'deleted_at': set.deletedAt?.toIso8601String(),
        'synced_at': DateTime.now().toIso8601String(),
        // Without these a run uploaded as 0 kg x 0 reps.
        ...setMetricColumns(
          durationSeconds: set.durationSeconds,
          distanceMetres: set.distanceMetres,
        ),
      });

      await (db.update(
        db.workoutSets,
      )..where((s) => s.id.equals(set.id))).write(
        WorkoutSetsCompanion(
          remoteId: Value(remoteId),
          userId: Value(userId),
          syncedAt: Value(DateTime.now()),
        ),
      );

      if (set.deletedAt != null) {
        await (db.delete(
          db.workoutSets,
        )..where((s) => s.id.equals(set.id))).go();
      }
    }

    return dirty.length;
  }

  // ---------------------------------------------------------------------------
  // Personal Bests
  // ---------------------------------------------------------------------------
  // No parent FK dependency — exercise rows are seeded globally and not synced.
  // exercise_id is stored as a plain integer reference, not a remote UUID.
  //
  // A record's identity is (exercise, metric type, distance) — the v7 local
  // key. The remote key must match it; see the SQL in set_payload.dart. The
  // old remote key was (user_id, exercise_id, reps), which cannot tell a 5 km
  // record from a 10 km one because both carry reps = 0.

  Future<int> _syncPersonalBests(String userId) async {
    final dirty = await (db.select(
      db.personalBests,
    )..where((pb) => pb.syncedAt.isNull())).get();

    for (final pr in dirty) {
      final remoteId = pr.remoteId ?? _uuid.v4();

      await supabase.from('personal_bests').upsert({
        'id': remoteId,
        'user_id': userId,
        'local_id': pr.id,
        'exercise_id': pr.exerciseId,
        'reps': pr.reps,
        'weight': pr.weight,
        'achieved_at': pr.achievedAt.toIso8601String(),
        'deleted_at': pr.deletedAt?.toIso8601String(),
        'synced_at': DateTime.now().toIso8601String(),
        ...personalBestMetricColumns(
          metricType: pr.metricType,
          durationSeconds: pr.durationSeconds,
          distanceMetres: pr.distanceMetres,
        ),
      });

      await (db.update(
        db.personalBests,
      )..where((pb) => pb.id.equals(pr.id))).write(
        PersonalBestsCompanion(
          remoteId: Value(remoteId),
          userId: Value(userId),
          syncedAt: Value(DateTime.now()),
        ),
      );

      // Hard-delete locally once soft-delete has been synced upstream.
      if (pr.deletedAt != null) {
        await (db.delete(
          db.personalBests,
        )..where((pb) => pb.id.equals(pr.id))).go();
      }
    }

    return dirty.length;
  }

  // ---------------------------------------------------------------------------
  // Badges
  // ---------------------------------------------------------------------------
  // No parent FK dependency — badge rows are standalone.
  // Only earned badges (earnedAt != null) are worth syncing — unearned badges
  // are local UI state seeded on install. Syncing unearned rows would just
  // add noise to Supabase with no value.
  // The UNIQUE (user_id, badge_key) constraint handles conflict resolution.

  // ---------------------------------------------------------------------------
  // Custom Exercises
  // ---------------------------------------------------------------------------
  // Only syncs exercises where isCustom == true — seeded exercises are
  // identical for all users and do not need to be synced per-user, and their
  // muscle rows are written by the migration on every install.

  Future<int> _syncCustomExercises(String userId) async {
    final dirty =
        await (db.select(db.exercises)
              ..where((e) => e.isCustom.equals(true))
              ..where((e) => e.syncedAt.isNull()))
            .get();

    for (final exercise in dirty) {
      final remoteId = exercise.remoteId ?? _uuid.v4();
      final muscles = await _musclesFor(exercise.id);

      await supabase.from('exercises').upsert({
        'id': remoteId,
        'user_id': userId,
        'local_id': exercise.id,
        'name': exercise.name,
        // Still sent, and still the primary muscle's group label. Remote
        // declares it NOT NULL and older clients read nothing else.
        'body_part': exercise.bodyPart,
        'equipment_type': exercise.equipmentType,
        // Absent before, so a custom cardio exercise round-tripped as a lift.
        'metric_type': exercise.metricType,
        'notes': exercise.notes,
        'deleted_at': exercise.deletedAt?.toIso8601String(),
        'synced_at': DateTime.now().toIso8601String(),
        ...muscleColumnsFor(
          primary: muscles.primary,
          secondary: muscles.secondary,
        ),
      });

      await (db.update(
        db.exercises,
      )..where((e) => e.id.equals(exercise.id))).write(
        ExercisesCompanion(
          remoteId: Value(remoteId),
          userId: Value(userId),
          syncedAt: Value(DateTime.now()),
        ),
      );

      if (exercise.deletedAt != null) {
        await (db.delete(
          db.exercises,
        )..where((e) => e.id.equals(exercise.id))).go();
      }
    }

    return dirty.length;
  }

  Future<int> _syncBadges(String userId) async {
    final dirty =
        await (db.select(db.badges)
              ..where((b) => b.syncedAt.isNull())
              ..where((b) => b.earnedAt.isNotNull()))
            .get();

    for (final badge in dirty) {
      final remoteId = badge.remoteId ?? _uuid.v4();

      await supabase.from('badges').upsert({
        'id': remoteId,
        'user_id': userId,
        'local_id': badge.id,
        'badge_key': badge.badgeKey,
        'earned_at': badge.earnedAt!.toIso8601String(),
        'deleted_at': badge.deletedAt?.toIso8601String(),
        'synced_at': DateTime.now().toIso8601String(),
      });

      await (db.update(db.badges)..where((b) => b.id.equals(badge.id))).write(
        BadgesCompanion(
          remoteId: Value(remoteId),
          userId: Value(userId),
          syncedAt: Value(DateTime.now()),
        ),
      );

      if (badge.deletedAt != null) {
        await (db.delete(db.badges)..where((b) => b.id.equals(badge.id))).go();
      }
    }

    return dirty.length;
  }

  // ---------------------------------------------------------------------------
  // Clear local data — call on sign out
  // ---------------------------------------------------------------------------

  Future<void> clearLocalData() async {
    await db.transaction(() async {
      await db.delete(db.workoutSets).go();
      await db.delete(db.workoutSessions).go();
      await db.delete(db.routineExercises).go();
      await db.delete(db.workoutRoutines).go();
      await db.delete(db.workoutSplits).go();
      await db.delete(db.personalBests).go();

      // Delete custom exercises — seeded exercises (isCustom == false) stay.
      await (db.delete(
        db.exercises,
      )..where((e) => e.isCustom.equals(true))).go();

      await db
          .update(db.badges)
          .write(
            const BadgesCompanion(
              earnedAt: Value(null),
              remoteId: Value(null),
              userId: Value(null),
              syncedAt: Value(null),
            ),
          );
    });
  }

  // ---------------------------------------------------------------------------
  // Download user data — call on sign in
  // ---------------------------------------------------------------------------

  Future<void> downloadUserData() async {
    final userId = _userId;
    if (userId == null) return;

    await _downloadSplits(userId);
    await _downloadRoutines(userId);
    await _downloadRoutineExercises(userId);
    await _downloadSessions(userId);
    await _downloadSets(userId);
    await _downloadPersonalBests(userId);
    await _downloadBadges(userId);
    await _downloadCustomExercises(userId);
  }

  Future<void> _downloadSplits(String userId) async {
    final rows = await supabase
        .from('workout_splits')
        .select()
        .eq('user_id', userId)
        .isFilter('deleted_at', null);

    for (final row in rows) {
      await db
          .into(db.workoutSplits)
          .insertOnConflictUpdate(
            WorkoutSplitsCompanion.insert(
              name: row['name'] as String,
              createdAt: Value(_parseLocal(row['created_at'] as String)),
              remoteId: Value(row['id'] as String),
              userId: Value(userId),
              syncedAt: Value(DateTime.now()),
            ),
          );
    }
  }

  Future<void> _downloadRoutines(String userId) async {
    final rows = await supabase
        .from('workout_routines')
        .select()
        .eq('user_id', userId)
        .isFilter('deleted_at', null);

    for (final row in rows) {
      final split =
          await (db.select(db.workoutSplits)
                ..where((s) => s.remoteId.equals(row['split_id'] as String)))
              .getSingleOrNull();
      if (split == null) continue;

      await db
          .into(db.workoutRoutines)
          .insertOnConflictUpdate(
            WorkoutRoutinesCompanion.insert(
              name: row['name'] as String,
              splitId: split.id,
              orderIndex: row['order_index'] as int,
              remoteId: Value(row['id'] as String),
              userId: Value(userId),
              syncedAt: Value(DateTime.now()),
            ),
          );
    }
  }

  Future<void> _downloadRoutineExercises(String userId) async {
    final rows = await supabase
        .from('routine_exercises')
        .select()
        .eq('user_id', userId)
        .isFilter('deleted_at', null);

    for (final row in rows) {
      final routine =
          await (db.select(db.workoutRoutines)
                ..where((r) => r.remoteId.equals(row['routine_id'] as String)))
              .getSingleOrNull();
      if (routine == null) continue;

      await db
          .into(db.routineExercises)
          .insertOnConflictUpdate(
            RoutineExercisesCompanion.insert(
              routineId: routine.id,
              exerciseId: row['exercise_id'] as int,
              orderIndex: row['order_index'] as int,
              targetSets: Value(row['target_sets'] as int? ?? 3),
              targetReps: Value(row['target_reps'] as int? ?? 10),
              remoteId: Value(row['id'] as String),
              userId: Value(userId),
              syncedAt: Value(DateTime.now()),
            ),
          );
    }
  }

  Future<void> _downloadSessions(String userId) async {
    final rows = await supabase
        .from('workout_sessions')
        .select()
        .eq('user_id', userId)
        .isFilter('deleted_at', null);

    for (final row in rows) {
      int? localRoutineId;
      if (row['routine_id'] != null) {
        final routine =
            await (db.select(
                  db.workoutRoutines,
                )..where((r) => r.remoteId.equals(row['routine_id'] as String)))
                .getSingleOrNull();
        localRoutineId = routine?.id;
      }

      await db
          .into(db.workoutSessions)
          .insertOnConflictUpdate(
            WorkoutSessionsCompanion.insert(
              startTime: _parseLocal(row['start_time'] as String),
              endTime: Value(
                row['end_time'] != null
                    ? _parseLocal(row['end_time'] as String)
                    : null,
              ),
              routineId: Value(localRoutineId),
              sessionNote: Value(row['session_note'] as String?),
              remoteId: Value(row['id'] as String),
              userId: Value(userId),
              syncedAt: Value(DateTime.now()),
            ),
          );
    }
  }

  Future<void> _downloadSets(String userId) async {
    final rows = await supabase
        .from('workout_sets')
        .select()
        .eq('user_id', userId)
        .isFilter('deleted_at', null);

    for (final row in rows) {
      final session =
          await (db.select(db.workoutSessions)
                ..where((s) => s.remoteId.equals(row['session_id'] as String)))
              .getSingleOrNull();
      if (session == null) continue;

      final remoteId = row['id'] as String;
      final metrics = setMetricsFromRemoteRow(row);

      final companion = WorkoutSetsCompanion(
        sessionId: Value(session.id),
        exerciseId: Value(row['exercise_id'] as int),
        weight: Value(weightFromRemoteRow(row)),
        reps: Value(repsFromRemoteRow(row)),
        durationSeconds: Value(metrics.durationSeconds),
        distanceMetres: Value(metrics.distanceMetres),
        isCompleted: Value(row['is_completed'] as bool? ?? false),
        timestamp: Value(
          row['timestamp'] != null
              ? _parseLocal(row['timestamp'] as String)
              : DateTime.now(),
        ),
        remoteId: Value(remoteId),
        userId: Value(userId),
        syncedAt: Value(DateTime.now()),
      );

      // Keyed on remote_id, not on the primary key. insertOnConflictUpdate
      // conflicts on `id`, which the companion never sets, so it inserted a
      // fresh row every time — duplicating every set on each full download.
      // Same bug, and same fix, as _downloadCustomExercises.
      await _upsertByRemoteId(
        findLocalId: () async =>
            (await (db.select(db.workoutSets)
                      ..where((s) => s.remoteId.equals(remoteId))
                      ..limit(1))
                    .getSingleOrNull())
                ?.id,
        insert: () => db.into(db.workoutSets).insert(companion),
        update: (localId) => (db.update(
          db.workoutSets,
        )..where((s) => s.id.equals(localId))).write(companion),
      );
    }
  }

  /// Insert-or-update keyed on the row's remote id.
  ///
  /// Drift's `insertOnConflictUpdate` conflicts on the primary key, and every
  /// download companion here leaves `id` unset — so it can only ever insert.
  /// Factored out because three download paths need the same shape.
  Future<void> _upsertByRemoteId({
    required Future<int?> Function() findLocalId,
    required Future<void> Function() insert,
    required Future<void> Function(int localId) update,
  }) async {
    final localId = await findLocalId();
    if (localId == null) {
      await insert();
    } else {
      await update(localId);
    }
  }

  Future<void> _downloadPersonalBests(String userId) async {
    final rows = await supabase
        .from('personal_bests')
        .select()
        .eq('user_id', userId)
        .isFilter('deleted_at', null);

    for (final row in rows) {
      final remoteId = row['id'] as String;
      final metrics = personalBestMetricsFromRemoteRow(row);

      final companion = PersonalBestsCompanion(
        exerciseId: Value(row['exercise_id'] as int),
        reps: Value(repsFromRemoteRow(row)),
        weight: Value(weightFromRemoteRow(row)),
        durationSeconds: Value(metrics.durationSeconds),
        distanceMetres: Value(metrics.distanceMetres),
        metricType: Value(metrics.metricType),
        achievedAt: Value(_parseLocal(row['achieved_at'] as String)),
        remoteId: Value(remoteId),
        userId: Value(userId),
        syncedAt: Value(DateTime.now()),
      );

      // As in _downloadSets — and here the v7 unique key means a repeat
      // insert throws rather than merely duplicating.
      await _upsertByRemoteId(
        findLocalId: () async =>
            (await (db.select(db.personalBests)
                      ..where((pb) => pb.remoteId.equals(remoteId))
                      ..limit(1))
                    .getSingleOrNull())
                ?.id,
        insert: () => db.into(db.personalBests).insert(companion),
        update: (localId) => (db.update(
          db.personalBests,
        )..where((pb) => pb.id.equals(localId))).write(companion),
      );
    }
  }

  Future<void> _downloadCustomExercises(String userId) async {
    final rows = await supabase
        .from('exercises')
        .select()
        .eq('user_id', userId)
        .isFilter('deleted_at', null);

    for (final row in rows) {
      final remoteId = row['id'] as String;

      // Keyed on remote_id, not on the primary key. The companion below never
      // sets `id`, so insertOnConflictUpdate would conflict on a column that
      // is absent and insert a fresh row — duplicating every custom exercise
      // on every full download. A partial unique index on remote_id backs
      // this up at the schema level (see _guardExerciseUniqueness).
      final existing =
          await (db.select(db.exercises)
                ..where((e) => e.remoteId.equals(remoteId))
                ..limit(1))
              .getSingleOrNull();

      final companion = ExercisesCompanion(
        name: Value(row['name'] as String),
        bodyPart: Value(bodyPartFromRemoteRow(row)),
        equipmentType: Value(row['equipment_type'] as String),
        metricType: Value((row['metric_type'] as String?) ?? 'weightReps'),
        isCustom: const Value(true),
        notes: Value(row['notes'] as String?),
        remoteId: Value(remoteId),
        userId: Value(userId),
        syncedAt: Value(DateTime.now()),
      );

      final int localId;
      if (existing == null) {
        localId = await db.into(db.exercises).insert(companion);
      } else {
        localId = existing.id;
        await (db.update(
          db.exercises,
        )..where((e) => e.id.equals(localId))).write(companion);
      }

      final muscles = musclesFromRemoteRow(row);
      await _writeDownloadedMuscles(
        localId,
        primary: muscles.primary,
        secondary: muscles.secondary,
      );
    }
  }

  /// The muscles recorded locally for one exercise, for upload.
  Future<({Muscle? primary, List<Muscle> secondary})> _musclesFor(
    int exerciseId,
  ) async {
    final rows = await (db.select(
      db.exerciseMuscles,
    )..where((m) => m.exerciseId.equals(exerciseId))).get();

    Muscle? primary;
    final secondary = <Muscle>[];
    for (final row in rows) {
      final muscle = Muscle.byNameOrNull(row.muscle);
      if (muscle == null) continue;
      if (row.isPrimary) {
        primary = muscle;
      } else {
        secondary.add(muscle);
      }
    }
    secondary.sort((a, b) => a.index.compareTo(b.index));
    return (primary: primary, secondary: secondary);
  }

  /// Replaces a downloaded exercise's muscle rows with what the remote holds.
  ///
  /// The remote row is authoritative for a custom exercise: it is the same
  /// user's own edit arriving from another device.
  Future<void> _writeDownloadedMuscles(
    int exerciseId, {
    required Muscle? primary,
    required List<Muscle> secondary,
  }) async {
    await db.transaction(() async {
      await (db.delete(
        db.exerciseMuscles,
      )..where((m) => m.exerciseId.equals(exerciseId))).go();

      // Null when the remote row named no muscle we recognise. The exercise
      // renders under "Unassigned" rather than being given a fabricated one.
      if (primary != null) {
        await db
            .into(db.exerciseMuscles)
            .insert(
              ExerciseMusclesCompanion.insert(
                exerciseId: exerciseId,
                muscle: primary.name,
                isPrimary: const Value(true),
              ),
            );
      }
      for (final muscle in secondary) {
        if (muscle == primary) continue;
        await db
            .into(db.exerciseMuscles)
            .insert(
              ExerciseMusclesCompanion.insert(
                exerciseId: exerciseId,
                muscle: muscle.name,
              ),
            );
      }
    });
  }

  Future<void> _downloadBadges(String userId) async {
    final rows = await supabase.from('badges').select().eq('user_id', userId);

    for (final row in rows) {
      await (db.update(
        db.badges,
      )..where((b) => b.badgeKey.equals(row['badge_key'] as String))).write(
        BadgesCompanion(
          earnedAt: Value(
            row['earned_at'] != null
                ? _parseLocal(row['earned_at'] as String)
                : null,
          ),
          remoteId: Value(row['id'] as String),
          userId: Value(userId),
          syncedAt: Value(DateTime.now()),
        ),
      );
    }
  }
}

// Parses a Supabase ISO8601 timestamp as LOCAL time regardless of the UTC
// offset suffix. Supabase stores timestamps in UTC but the seeder inserted
// times as local DateTime — stripping the offset preserves the intended date.
DateTime _parseLocal(String iso) {
  // Remove timezone suffix (+00:00, Z, etc.) then parse as local
  final stripped = iso
      .replaceAll(RegExp(r'[+-]\d{2}:\d{2}$'), '')
      .replaceAll('Z', '');
  return DateTime.parse(stripped);
}

// ---------------------------------------------------------------------------
// Result type
// ---------------------------------------------------------------------------

class SyncResult {
  final bool success;
  final bool unauthenticated;
  final int uploaded;
  final List<String> errors;

  const SyncResult({
    required this.success,
    required this.uploaded,
    required this.errors,
    this.unauthenticated = false,
  });

  factory SyncResult.unauthenticated() => const SyncResult(
    success: false,
    unauthenticated: true,
    uploaded: 0,
    errors: [],
  );

  @override
  String toString() =>
      'SyncResult(success: $success, uploaded: $uploaded, errors: $errors)';
}
