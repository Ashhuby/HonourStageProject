import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:fitness_app/core/database/database_provider.dart';
import 'package:fitness_app/core/database/local_database.dart';
import 'package:fitness_app/features/workout/data/split_schedule_repository.dart';
import 'package:fitness_app/features/workout/domain/split_schedule.dart';

/// Tests the reads and writes behind a split's rotation.
///
/// `split_schedule_test.dart` proves the arithmetic; this proves the wiring —
/// that a slot written is a slot read back, that only one split can be the one
/// the tab opens on, and that the plan handed to the Today card is assembled
/// from the right rows.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  SplitScheduleRepository repo() =>
      container.read(splitScheduleRepositoryProvider.notifier);

  Future<int> addSplit(String name) => db
      .into(db.workoutSplits)
      .insert(WorkoutSplitsCompanion.insert(name: name));

  var order = 0;
  Future<int> addRoutine(int splitId, String name) => db
      .into(db.workoutRoutines)
      .insert(
        WorkoutRoutinesCompanion.insert(
          splitId: splitId,
          name: name,
          orderIndex: order++,
        ),
      );

  Future<WorkoutRoutine> readRoutine(int id) => (db.select(
    db.workoutRoutines,
  )..where((r) => r.id.equals(id))).getSingle();

  Future<List<WorkoutSplit>> readSplits() => db.select(db.workoutSplits).get();

  // ---------------------------------------------------------------------------
  // Defaults
  // ---------------------------------------------------------------------------

  group('the default split', () {
    test('starts unset, so nothing opens on a split by accident', () async {
      await addSplit('PPL');
      expect((await readSplits()).every((s) => !s.isDefault), isTrue);
    });

    test('only one split can hold it', () async {
      final first = await addSplit('PPL');
      final second = await addSplit('Upper/Lower');

      await repo().setDefaultSplit(first);
      await repo().setDefaultSplit(second);

      final splits = await readSplits();
      expect(splits.where((s) => s.isDefault).map((s) => s.id), [second]);
    });

    test('can be cleared, putting the tab back on the list', () async {
      final id = await addSplit('PPL');
      await repo().setDefaultSplit(id);
      await repo().setDefaultSplit(null);

      expect((await readSplits()).every((s) => !s.isDefault), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Slots
  // ---------------------------------------------------------------------------

  group('slots', () {
    test('a routine starts on no day at all', () async {
      final split = await addSplit('PPL');
      final push = await addRoutine(split, 'Push');

      expect(parseSlots((await readRoutine(push)).scheduleSlots), isEmpty);
    });

    test('assigning adds a day without disturbing the others', () async {
      final split = await addSplit('PPL');
      final push = await addRoutine(split, 'Push');

      await repo().assignSlot(push, 0);
      await repo().assignSlot(push, 3);

      expect(parseSlots((await readRoutine(push)).scheduleSlots), [0, 3]);
    });

    test('assigning the same day twice is not two days', () async {
      final split = await addSplit('PPL');
      final push = await addRoutine(split, 'Push');

      await repo().assignSlot(push, 0);
      await repo().assignSlot(push, 0);

      expect(parseSlots((await readRoutine(push)).scheduleSlots), [0]);
    });

    test('clearing removes one day and leaves the rest', () async {
      final split = await addSplit('PPL');
      final push = await addRoutine(split, 'Push');
      await repo().setRoutineSlots(push, [0, 3]);

      await repo().clearSlot(push, 0);

      expect(parseSlots((await readRoutine(push)).scheduleSlots), [3]);
    });

    test('clearing the last day leaves null, not an empty string', () async {
      final split = await addSplit('PPL');
      final push = await addRoutine(split, 'Push');
      await repo().setRoutineSlots(push, [2]);

      await repo().clearSlot(push, 2);

      expect((await readRoutine(push)).scheduleSlots, isNull);
    });

    test('a write marks the routine for sync', () async {
      final split = await addSplit('PPL');
      final push = await addRoutine(split, 'Push');
      await (db.update(db.workoutRoutines)..where((r) => r.id.equals(push)))
          .write(WorkoutRoutinesCompanion(syncedAt: Value(DateTime.now())));

      await repo().assignSlot(push, 1);

      expect((await readRoutine(push)).syncedAt, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Mode
  // ---------------------------------------------------------------------------

  group('changing the rotation', () {
    test('weekly is always seven days, whatever it is handed', () async {
      final split = await addSplit('PPL');
      await repo().setScheduleMode(split, ScheduleMode.weekly, cycleLength: 3);

      final row = (await readSplits()).single;
      expect(row.scheduleMode, 'weekly');
      expect(row.cycleLength, kWeekLength);
    });

    test('a cycle is clamped to something usable', () async {
      final split = await addSplit('PPL');

      await repo().setScheduleMode(split, ScheduleMode.cycle, cycleLength: 99);
      expect((await readSplits()).single.cycleLength, kMaxCycleLength);

      await repo().setScheduleMode(split, ScheduleMode.cycle, cycleLength: 1);
      expect((await readSplits()).single.cycleLength, 2);
    });

    test('shortening a cycle releases the days that no longer exist', () async {
      // A routine pinned past the end is a day the user can neither train nor
      // remove, because the editor cannot draw it.
      final split = await addSplit('PPL');
      final push = await addRoutine(split, 'Push');
      await repo().setScheduleMode(split, ScheduleMode.cycle, cycleLength: 7);
      await repo().setRoutineSlots(push, [0, 5]);

      await repo().setScheduleMode(split, ScheduleMode.cycle, cycleLength: 3);

      expect(parseSlots((await readRoutine(push)).scheduleSlots), [0]);
    });

    test('shortening leaves untouched routines alone', () async {
      final split = await addSplit('PPL');
      final push = await addRoutine(split, 'Push');
      await repo().setScheduleMode(split, ScheduleMode.cycle, cycleLength: 7);
      await repo().setRoutineSlots(push, [1]);
      await (db.update(db.workoutRoutines)..where((r) => r.id.equals(push)))
          .write(WorkoutRoutinesCompanion(syncedAt: Value(DateTime(2026))));

      await repo().setScheduleMode(split, ScheduleMode.cycle, cycleLength: 3);

      // Nothing fell off, so nothing was rewritten and nothing was needlessly
      // marked dirty for sync.
      final row = await readRoutine(push);
      expect(parseSlots(row.scheduleSlots), [1]);
      expect(row.syncedAt, DateTime(2026));
    });
  });

  // ---------------------------------------------------------------------------
  // The plan
  // ---------------------------------------------------------------------------

  group('the plan handed to the Today card', () {
    Future<SplitPlan?> plan(int splitId) =>
        container.read(watchSplitPlanProvider(splitId).future);

    test('is null for a split that does not exist', () async {
      expect(await plan(999), isNull);
    });

    test('an unscheduled split offers nothing rather than guessing', () async {
      final split = await addSplit('PPL');
      await addRoutine(split, 'Push');

      final result = (await plan(split))!;
      expect(result.schedule.isActive, isFalse);
      expect(result.due, isNull);
    });

    test('offers the routine on today', () async {
      final split = await addSplit('PPL');
      final push = await addRoutine(split, 'Push');
      await repo().setScheduleMode(split, ScheduleMode.weekly);

      // Whatever today is, put Push on it.
      final todaySlot = (DateTime.now().weekday - DateTime.monday) % 7;
      await repo().setRoutineSlots(push, [todaySlot]);

      final result = (await plan(split))!;
      expect(result.due?.name, 'Push');
      expect(result.isToday, isTrue);
    });

    test('counts the exercises planned for each routine', () async {
      final split = await addSplit('PPL');
      final push = await addRoutine(split, 'Push');
      final exercise = await db
          .into(db.exercises)
          .insert(
            ExercisesCompanion.insert(
              name: 'Bench Press',
              bodyPart: 'Chest',
              equipmentType: 'Barbell',
            ),
          );
      await db
          .into(db.routineExercises)
          .insert(
            RoutineExercisesCompanion.insert(
              routineId: push,
              exerciseId: exercise,
              orderIndex: 0,
            ),
          );

      final result = (await plan(split))!;
      expect(result.exerciseCounts[push], 1);
    });

    test('a session finished today moves the card on', () async {
      // Otherwise the card offers a workout that is already logged.
      final split = await addSplit('PPL');
      final push = await addRoutine(split, 'Push');
      await repo().setScheduleMode(split, ScheduleMode.weekly);

      final todaySlot = (DateTime.now().weekday - DateTime.monday) % 7;
      await repo().setRoutineSlots(push, [todaySlot]);

      final now = DateTime.now();
      await db
          .into(db.workoutSessions)
          .insert(
            WorkoutSessionsCompanion.insert(
              routineId: Value(push),
              startTime: DateTime(now.year, now.month, now.day, 8),
              endTime: Value(DateTime(now.year, now.month, now.day, 9)),
            ),
          );

      final result = (await plan(split))!;
      expect(result.trainedToday, isTrue);
      expect(result.isToday, isFalse);
    });

    test('an unfinished session is not a session trained', () async {
      final split = await addSplit('PPL');
      final push = await addRoutine(split, 'Push');
      await repo().setScheduleMode(split, ScheduleMode.weekly);
      await repo().setRoutineSlots(push, [
        (DateTime.now().weekday - DateTime.monday) % 7,
      ]);

      await db
          .into(db.workoutSessions)
          .insert(
            WorkoutSessionsCompanion.insert(
              routineId: Value(push),
              startTime: DateTime.now(),
            ),
          );

      final result = (await plan(split))!;
      expect(result.trainedToday, isFalse);
      expect(result.isToday, isTrue);
    });

    test('a session from another split does not anchor this one', () async {
      final mine = await addSplit('PPL');
      final theirs = await addSplit('Upper/Lower');
      final push = await addRoutine(mine, 'Push');
      final upper = await addRoutine(theirs, 'Upper');

      await repo().setScheduleMode(mine, ScheduleMode.cycle, cycleLength: 3);
      await repo().setRoutineSlots(push, [0]);

      await db
          .into(db.workoutSessions)
          .insert(
            WorkoutSessionsCompanion.insert(
              routineId: Value(upper),
              startTime: DateTime.now(),
              endTime: Value(DateTime.now()),
            ),
          );

      final result = (await plan(mine))!;
      expect(result.lastTrainedOn, isNull);
      // Never trained on this split, so the ring starts today rather than
      // opening on a rest day.
      expect(result.isToday, isTrue);
    });
  });
}
