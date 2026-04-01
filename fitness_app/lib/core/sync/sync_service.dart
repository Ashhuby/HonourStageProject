import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../database/local_database.dart';

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
      uploaded += await _syncPersonalBests(userId);
    } catch (e) {
      errors.add('personalBests: $e');
    }

    try {
      uploaded += await _syncBadges(userId);
    } catch (e) {
      errors.add('badges: $e');
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
    final dirty = await (db.select(db.workoutSplits)
          ..where((s) => s.syncedAt.isNull()))
        .get();

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

      await (db.update(db.workoutSplits)..where((s) => s.id.equals(split.id)))
          .write(WorkoutSplitsCompanion(
        remoteId: Value(remoteId),
        userId: Value(userId),
        syncedAt: Value(DateTime.now()),
      ));

      if (split.deletedAt != null) {
        await (db.delete(db.workoutSplits)
              ..where((s) => s.id.equals(split.id)))
            .go();
      }
    }

    return dirty.length;
  }

  // ---------------------------------------------------------------------------
  // Routines
  // ---------------------------------------------------------------------------

  Future<int> _syncRoutines(String userId) async {
    final dirty = await (db.select(db.workoutRoutines)
          ..where((r) => r.syncedAt.isNull()))
        .get();

    for (final routine in dirty) {
      final split = await (db.select(db.workoutSplits)
            ..where((s) => s.id.equals(routine.splitId)))
          .getSingleOrNull();

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

      await (db.update(db.workoutRoutines)
            ..where((r) => r.id.equals(routine.id)))
          .write(WorkoutRoutinesCompanion(
        remoteId: Value(remoteId),
        userId: Value(userId),
        syncedAt: Value(DateTime.now()),
      ));

      if (routine.deletedAt != null) {
        await (db.delete(db.workoutRoutines)
              ..where((r) => r.id.equals(routine.id)))
            .go();
      }
    }

    return dirty.length;
  }

  // ---------------------------------------------------------------------------
  // RoutineExercises
  // ---------------------------------------------------------------------------

  Future<int> _syncRoutineExercises(String userId) async {
    final dirty = await (db.select(db.routineExercises)
          ..where((re) => re.syncedAt.isNull()))
        .get();

    for (final re in dirty) {
      final routine = await (db.select(db.workoutRoutines)
            ..where((r) => r.id.equals(re.routineId)))
          .getSingleOrNull();

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

      await (db.update(db.routineExercises)
            ..where((r) => r.id.equals(re.id)))
          .write(RoutineExercisesCompanion(
        remoteId: Value(remoteId),
        userId: Value(userId),
        syncedAt: Value(DateTime.now()),
      ));

      if (re.deletedAt != null) {
        await (db.delete(db.routineExercises)
              ..where((r) => r.id.equals(re.id)))
            .go();
      }
    }

    return dirty.length;
  }

  // ---------------------------------------------------------------------------
  // Sessions
  // ---------------------------------------------------------------------------

  Future<int> _syncSessions(String userId) async {
    final dirty = await (db.select(db.workoutSessions)
          ..where((s) => s.syncedAt.isNull()))
        .get();

    for (final session in dirty) {
      if (session.endTime == null) continue;

      String? routineRemoteId;
      if (session.routineId != null) {
        final routine = await (db.select(db.workoutRoutines)
              ..where((r) => r.id.equals(session.routineId!)))
            .getSingleOrNull();
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

      await (db.update(db.workoutSessions)
            ..where((s) => s.id.equals(session.id)))
          .write(WorkoutSessionsCompanion(
        remoteId: Value(remoteId),
        userId: Value(userId),
        syncedAt: Value(DateTime.now()),
      ));

      if (session.deletedAt != null) {
        await (db.delete(db.workoutSessions)
              ..where((s) => s.id.equals(session.id)))
            .go();
      }
    }

    return dirty.length;
  }

  // ---------------------------------------------------------------------------
  // Sets
  // ---------------------------------------------------------------------------

  Future<int> _syncSets(String userId) async {
    final dirty = await (db.select(db.workoutSets)
          ..where((s) => s.syncedAt.isNull()))
        .get();

    for (final set in dirty) {
      final session = await (db.select(db.workoutSessions)
            ..where((s) => s.id.equals(set.sessionId)))
          .getSingleOrNull();

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
      });

      await (db.update(db.workoutSets)..where((s) => s.id.equals(set.id)))
          .write(WorkoutSetsCompanion(
        remoteId: Value(remoteId),
        userId: Value(userId),
        syncedAt: Value(DateTime.now()),
      ));

      if (set.deletedAt != null) {
        await (db.delete(db.workoutSets)..where((s) => s.id.equals(set.id)))
            .go();
      }
    }

    return dirty.length;
  }

  // ---------------------------------------------------------------------------
  // Personal Bests
  // ---------------------------------------------------------------------------
  // No parent FK dependency — exercise rows are seeded globally and not synced.
  // exercise_id is stored as a plain integer reference, not a remote UUID.
  // The UNIQUE (user_id, exercise_id, reps) constraint in Supabase handles
  // conflict resolution — upsert will update weight + achieved_at if beaten.

  Future<int> _syncPersonalBests(String userId) async {
    final dirty = await (db.select(db.personalBests)
          ..where((pb) => pb.syncedAt.isNull()))
        .get();

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
      });

      await (db.update(db.personalBests)
            ..where((pb) => pb.id.equals(pr.id)))
          .write(PersonalBestsCompanion(
        remoteId: Value(remoteId),
        userId: Value(userId),
        syncedAt: Value(DateTime.now()),
      ));

      // Hard-delete locally once soft-delete has been synced upstream.
      if (pr.deletedAt != null) {
        await (db.delete(db.personalBests)
              ..where((pb) => pb.id.equals(pr.id)))
            .go();
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

  Future<int> _syncBadges(String userId) async {
    final dirty = await (db.select(db.badges)
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

      await (db.update(db.badges)..where((b) => b.id.equals(badge.id)))
          .write(BadgesCompanion(
        remoteId: Value(remoteId),
        userId: Value(userId),
        syncedAt: Value(DateTime.now()),
      ));

      if (badge.deletedAt != null) {
        await (db.delete(db.badges)..where((b) => b.id.equals(badge.id)))
            .go();
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

      await db.update(db.badges).write(const BadgesCompanion(
        earnedAt: Value(null),
        remoteId: Value(null),
        userId: Value(null),
        syncedAt: Value(null),
      ));
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
  }

  Future<void> _downloadSplits(String userId) async {
    final rows = await supabase
        .from('workout_splits')
        .select()
        .eq('user_id', userId)
        .isFilter('deleted_at', null);

    for (final row in rows) {
      await db.into(db.workoutSplits).insertOnConflictUpdate(
            WorkoutSplitsCompanion.insert(
              name: row['name'] as String,
              createdAt: Value(DateTime.parse(row['created_at'] as String)),
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
      final split = await (db.select(db.workoutSplits)
            ..where((s) => s.remoteId.equals(row['split_id'] as String)))
          .getSingleOrNull();
      if (split == null) continue;

      await db.into(db.workoutRoutines).insertOnConflictUpdate(
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
      final routine = await (db.select(db.workoutRoutines)
            ..where((r) => r.remoteId.equals(row['routine_id'] as String)))
          .getSingleOrNull();
      if (routine == null) continue;

      await db.into(db.routineExercises).insertOnConflictUpdate(
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
        final routine = await (db.select(db.workoutRoutines)
              ..where((r) => r.remoteId.equals(row['routine_id'] as String)))
            .getSingleOrNull();
        localRoutineId = routine?.id;
      }

      await db.into(db.workoutSessions).insertOnConflictUpdate(
            WorkoutSessionsCompanion.insert(
              startTime: DateTime.parse(row['start_time'] as String),
              endTime: Value(row['end_time'] != null
                  ? DateTime.parse(row['end_time'] as String)
                  : null),
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
      final session = await (db.select(db.workoutSessions)
            ..where((s) => s.remoteId.equals(row['session_id'] as String)))
          .getSingleOrNull();
      if (session == null) continue;

      await db.into(db.workoutSets).insertOnConflictUpdate(
            WorkoutSetsCompanion.insert(
              sessionId: session.id,
              exerciseId: row['exercise_id'] as int,
              weight: (row['weight'] as num).toDouble(),
              reps: row['reps'] as int,
              isCompleted: Value(row['is_completed'] as bool? ?? false),
              timestamp: Value(row['timestamp'] != null
                  ? DateTime.parse(row['timestamp'] as String)
                  : DateTime.now()),
              remoteId: Value(row['id'] as String),
              userId: Value(userId),
              syncedAt: Value(DateTime.now()),
            ),
          );
    }
  }

  Future<void> _downloadPersonalBests(String userId) async {
    final rows = await supabase
        .from('personal_bests')
        .select()
        .eq('user_id', userId)
        .isFilter('deleted_at', null);

    for (final row in rows) {
      await db.into(db.personalBests).insertOnConflictUpdate(
            PersonalBestsCompanion.insert(
              exerciseId: row['exercise_id'] as int,
              reps: row['reps'] as int,
              weight: (row['weight'] as num).toDouble(),
              achievedAt: DateTime.parse(row['achieved_at'] as String),
              remoteId: Value(row['id'] as String),
              userId: Value(userId),
              syncedAt: Value(DateTime.now()),
            ),
          );
    }
  }

  Future<void> _downloadBadges(String userId) async {
    final rows = await supabase
        .from('badges')
        .select()
        .eq('user_id', userId);

    for (final row in rows) {
      await (db.update(db.badges)
            ..where((b) => b.badgeKey.equals(row['badge_key'] as String)))
          .write(BadgesCompanion(
        earnedAt: Value(row['earned_at'] != null
            ? DateTime.parse(row['earned_at'] as String)
            : null),
        remoteId: Value(row['id'] as String),
        userId: Value(userId),
        syncedAt: Value(DateTime.now()),
      ));
    }
  }
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