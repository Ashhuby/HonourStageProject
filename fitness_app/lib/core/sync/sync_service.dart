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

      // Hard-delete locally if soft-deleted and now synced
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
      // Parent split must have a remoteId before we can sync child
      final split = await (db.select(db.workoutSplits)
            ..where((s) => s.id.equals(routine.splitId)))
          .getSingleOrNull();

      if (split == null || split.remoteId == null) {
        // Parent not synced yet — skip, will retry next sync
        continue;
      }

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
      // Only sync completed sessions — endTime must be set
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