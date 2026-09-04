/// Reading and writing a split's rotation.
///
/// Kept apart from `split_repository.dart`, which is already the largest file
/// in `data/`, and because everything here is about one question — what should
/// I train — rather than about editing the split itself.
library;

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:riverpod/riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/database/local_database.dart';
import '../domain/split_schedule.dart';

part 'split_schedule_repository.g.dart';

/// Everything the Today card needs, resolved together.
///
/// One record rather than four providers because the parts are only ever
/// meaningful as a set: a verdict without the schedule cannot be drawn, and a
/// schedule without the verdict cannot say what to do next.
class SplitPlan {
  const SplitPlan({
    required this.split,
    required this.schedule,
    required this.verdict,
    required this.lastTrainedOn,
    required this.trainedToday,
    required this.exerciseCounts,
  });

  final WorkoutSplit split;
  final SplitSchedule schedule;
  final ScheduleVerdict verdict;

  /// When this split was last trained, or null if it never has been.
  final DateTime? lastTrainedOn;

  /// Whether a session against this split has already been finished today.
  /// The Today card moves on to the next day when it has, rather than
  /// offering a workout that is already logged.
  final bool trainedToday;

  /// Exercises planned per routine, keyed by routine id. Shown on the card so
  /// the user knows what they are agreeing to before they start.
  final Map<int, int> exerciseCounts;

  /// The routine due, if there is one.
  ScheduledRoutine? get due => verdict.routine;

  /// Whether the due routine is due right now.
  bool get isToday => verdict.daysAway == 0 && !trainedToday;
}

/// The split the Splits tab opens on, or null when there is none.
///
/// At most one row is ever flagged — [SplitScheduleRepository.setDefaultSplit]
/// clears the others in the same transaction — but this takes the first of
/// whatever it finds rather than asserting, because a half-applied sync is not
/// worth a crash on the app's opening screen.
@riverpod
Stream<WorkoutSplit?> watchDefaultSplit(Ref ref) {
  final db = ref.watch(databaseProvider);

  return (db.select(db.workoutSplits)
        ..where((s) => s.deletedAt.isNull())
        ..where((s) => s.isDefault.equals(true))
        ..limit(1))
      .watch()
      .map((rows) => rows.isEmpty ? null : rows.first);
}

/// The rotation for one split.
///
/// Watches both tables the answer is built from. It used to be driven by the
/// split row alone, which is not where a rotation actually lives: putting a
/// routine on a day writes `schedule_slots` on **workout_routines**, so the
/// stream never fired. The write landed and the screen kept drawing the old
/// schedule — adding a day appeared to do nothing, and removing one appeared
/// to do nothing either.
///
/// The trivial query is here for its `readsFrom` set; drift re-emits when any
/// of those tables is written, which is exactly when this answer can change.
@riverpod
Stream<SplitSchedule> watchSplitSchedule(Ref ref, int splitId) {
  final db = ref.watch(databaseProvider);

  return db
      .customSelect(
        'SELECT 1 AS v',
        readsFrom: {db.workoutSplits, db.workoutRoutines},
      )
      .watch()
      .asyncMap((_) async {
        final split = await (db.select(
          db.workoutSplits,
        )..where((s) => s.id.equals(splitId))).getSingleOrNull();
        if (split == null) return SplitSchedule.none;

        final routines =
            await (db.select(db.workoutRoutines)
                  ..where((r) => r.splitId.equals(splitId))
                  ..where((r) => r.deletedAt.isNull())
                  ..orderBy([(r) => OrderingTerm.asc(r.orderIndex)]))
                .get();

        return _scheduleOf(split, routines);
      });
}

SplitSchedule _scheduleOf(WorkoutSplit split, List<WorkoutRoutine> routines) {
  final mode = ScheduleMode.byNameOrNone(split.scheduleMode);

  return SplitSchedule.of(
    mode: mode,
    length: split.cycleLength,
    routines: [
      for (final routine in routines)
        (
          routineId: routine.id,
          name: routine.name,
          slots: parseSlots(routine.scheduleSlots),
        ),
    ],
  );
}

/// The full picture for one split: its rotation, what is due, and when it was
/// last trained.
///
/// A stream rather than a future because the Splits tab stays mounted and the
/// answer changes the moment a session is finished — the whole point of the
/// card is that it is right when the user opens the app.
@riverpod
Stream<SplitPlan?> watchSplitPlan(Ref ref, int splitId) {
  final db = ref.watch(databaseProvider);

  // Re-runs on any write to the four tables the answer depends on. The trivial
  // query exists only for its `readsFrom` set.
  return db
      .customSelect(
        'SELECT 1 AS v',
        readsFrom: {
          db.workoutSplits,
          db.workoutRoutines,
          db.workoutSessions,
          db.routineExercises,
        },
      )
      .watch()
      .asyncMap((_) => _buildPlan(db, splitId));
}

Future<SplitPlan?> _buildPlan(AppDatabase db, int splitId) async {
  final split = await (db.select(
    db.workoutSplits,
  )..where((s) => s.id.equals(splitId))).getSingleOrNull();
  if (split == null) return null;

  final routines =
      await (db.select(db.workoutRoutines)
            ..where((r) => r.splitId.equals(splitId))
            ..where((r) => r.deletedAt.isNull())
            ..orderBy([(r) => OrderingTerm.asc(r.orderIndex)]))
          .get();

  final schedule = _scheduleOf(split, routines);
  final routineIds = [for (final routine in routines) routine.id];

  // The most recent finished session belonging to this split. This is the
  // anchor a cycle turns from, so it has to be the session that actually
  // happened rather than a date the user was asked to keep up to date.
  final lastSession = routineIds.isEmpty
      ? null
      : await (db.select(db.workoutSessions)
              ..where((s) => s.routineId.isIn(routineIds))
              ..where((s) => s.endTime.isNotNull())
              ..where((s) => s.deletedAt.isNull())
              ..orderBy([(s) => OrderingTerm.desc(s.startTime)])
              ..limit(1))
            .getSingleOrNull();

  final now = DateTime.now();
  final lastTrainedOn = lastSession?.startTime;

  final trainedToday =
      lastTrainedOn != null &&
      DateTime(lastTrainedOn.year, lastTrainedOn.month, lastTrainedOn.day) ==
          DateTime(now.year, now.month, now.day);

  // Which slot that session sat in. A routine can hold several, so the one
  // closest to the session's own weekday is the honest reading for a weekly
  // split; for a cycle any of them turns the ring the same way.
  final lastSlots = lastSession?.routineId == null
      ? const <int>[]
      : parseSlots(
          routines
              .firstWhere((r) => r.id == lastSession!.routineId)
              .scheduleSlots,
        );

  final verdict = nextUp(
    schedule,
    now,
    lastTrainedSlot: lastSlots.isEmpty ? null : lastSlots.first,
    lastTrainedOn: lastTrainedOn,
    skipToday: trainedToday,
  );

  final counts = <int, int>{};
  for (final routine in routines) {
    counts[routine.id] = await _exerciseCount(db, routine.id);
  }

  return SplitPlan(
    split: split,
    schedule: schedule,
    verdict: verdict,
    lastTrainedOn: lastTrainedOn,
    trainedToday: trainedToday,
    exerciseCounts: counts,
  );
}

Future<int> _exerciseCount(AppDatabase db, int routineId) async {
  final row = await db
      .customSelect(
        'SELECT COUNT(*) AS v FROM routine_exercises '
        'WHERE routine_id = ? AND deleted_at IS NULL',
        variables: [Variable.withInt(routineId)],
      )
      .getSingle();

  final value = row.data['v'];
  return value is int ? value : 0;
}

// ---------------------------------------------------------------------------
// Writes
// ---------------------------------------------------------------------------

@riverpod
class SplitScheduleRepository extends _$SplitScheduleRepository {
  @override
  void build() {}

  /// Makes [splitId] the split the Splits tab opens on, clearing whichever
  /// held it before.
  ///
  /// One statement each way inside a transaction, so there is never a moment
  /// where two splits are default or none is.
  Future<void> setDefaultSplit(int? splitId) async {
    final db = ref.read(databaseProvider);

    await db.transaction(() async {
      await db
          .update(db.workoutSplits)
          .write(const WorkoutSplitsCompanion(isDefault: Value(false)));

      if (splitId == null) return;
      await (db.update(db.workoutSplits)..where((s) => s.id.equals(splitId)))
          .write(const WorkoutSplitsCompanion(isDefault: Value(true)));
    });
  }

  /// Sets how a split repeats.
  ///
  /// Shortening a cycle strands any routine pinned past the new end, so those
  /// are cleared here rather than left to be filtered out on every read — a
  /// routine that looks scheduled on a day the editor cannot show is a day the
  /// user can neither train nor remove.
  Future<void> setScheduleMode(
    int splitId,
    ScheduleMode mode, {
    int? cycleLength,
  }) async {
    final db = ref.read(databaseProvider);
    final length = mode == ScheduleMode.weekly
        ? kWeekLength
        : (cycleLength ?? kWeekLength).clamp(2, kMaxCycleLength);

    await db.transaction(() async {
      await (db.update(
        db.workoutSplits,
      )..where((s) => s.id.equals(splitId))).write(
        WorkoutSplitsCompanion(
          scheduleMode: Value(mode.name),
          cycleLength: Value(length),
          syncedAt: const Value(null),
        ),
      );

      final routines = await (db.select(
        db.workoutRoutines,
      )..where((r) => r.splitId.equals(splitId))).get();

      for (final routine in routines) {
        final kept = parseSlots(routine.scheduleSlots, length: length);
        if (kept.length == parseSlots(routine.scheduleSlots).length) continue;

        await (db.update(
          db.workoutRoutines,
        )..where((r) => r.id.equals(routine.id))).write(
          WorkoutRoutinesCompanion(
            scheduleSlots: Value(formatSlots(kept)),
            syncedAt: const Value(null),
          ),
        );
      }
    });
  }

  /// Puts [routineId] on exactly [slots].
  Future<void> setRoutineSlots(int routineId, Iterable<int> slots) async {
    final db = ref.read(databaseProvider);

    await (db.update(
      db.workoutRoutines,
    )..where((r) => r.id.equals(routineId))).write(
      WorkoutRoutinesCompanion(
        scheduleSlots: Value(formatSlots(slots)),
        syncedAt: const Value(null),
      ),
    );
  }

  /// Puts [routineId] on [slot], leaving its other days alone.
  Future<void> assignSlot(int routineId, int slot) async {
    final current = await _slotsOf(routineId);
    if (current.contains(slot)) return;
    await setRoutineSlots(routineId, [...current, slot]);
  }

  /// Takes [routineId] off [slot].
  Future<void> clearSlot(int routineId, int slot) async {
    final current = await _slotsOf(routineId);
    if (!current.contains(slot)) return;
    await setRoutineSlots(routineId, current.where((s) => s != slot));
  }

  Future<List<int>> _slotsOf(int routineId) async {
    final db = ref.read(databaseProvider);
    final routine = await (db.select(
      db.workoutRoutines,
    )..where((r) => r.id.equals(routineId))).getSingleOrNull();

    return parseSlots(routine?.scheduleSlots);
  }
}
