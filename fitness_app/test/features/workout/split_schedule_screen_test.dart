import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_app/core/database/database_provider.dart';
import 'package:fitness_app/core/database/local_database.dart';
import 'package:fitness_app/features/workout/data/split_schedule_repository.dart';
import 'package:fitness_app/features/workout/domain/split_schedule.dart';
import 'package:fitness_app/features/workout/presentation/split_schedule_screen.dart';

/// Drives the schedule editor as a screen.
///
/// The repository tests prove the write lands and the stream fires. Neither
/// says whether the screen redraws, which is the only thing the user ever
/// sees — "it is working, the presentation is just not updating" was the
/// report, and every test in the suite passed while it was true.
///
/// Everything here runs inside [WidgetTester.runAsync]. `testWidgets` replaces
/// the clock with a fake one, and drift's query streams need real timers to
/// deliver — without it the screen sits on its loading spinner forever and the
/// test proves nothing about the widget at all.
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late WorkoutSplit split;
  late int pushId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );

    final splitId = await db
        .into(db.workoutSplits)
        .insert(WorkoutSplitsCompanion.insert(name: 'PPL'));
    pushId = await db
        .into(db.workoutRoutines)
        .insert(
          WorkoutRoutinesCompanion.insert(
            splitId: splitId,
            name: 'Push',
            orderIndex: 0,
          ),
        );

    await container
        .read(splitScheduleRepositoryProvider.notifier)
        .setScheduleMode(splitId, ScheduleMode.weekly);

    split = await (db.select(
      db.workoutSplits,
    )..where((s) => s.id.equals(splitId))).getSingle();
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// Pumps until the real async work behind the screen has landed.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump();
    }
  }

  Future<void> pumpEditor(WidgetTester tester) async {
    // Tall enough for all seven days at once. A ListView does not build what
    // is off-screen, so on the default 800px surface the later days simply do
    // not exist and the counts below would be measuring the viewport.
    await tester.binding.setSurfaceSize(const Size(900, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: SplitScheduleScreen(split: split)),
      ),
    );
    await settle(tester);
  }

  testWidgets('the week and the routine tray are drawn', (tester) async {
    await pumpEditor(tester);

    expect(find.text('Mon'), findsOneWidget);
    expect(find.text('Sun'), findsOneWidget);
    expect(find.text('ROUTINES'), findsOneWidget);
    // Nothing scheduled yet, so every day reads as rest.
    expect(find.text('Rest'), findsNWidgets(kWeekLength));
  });

  testWidgets('adding a routine to a day shows up without leaving', (
    tester,
  ) async {
    await pumpEditor(tester);
    expect(find.text('Rest'), findsNWidgets(kWeekLength));

    await tester.runAsync(
      () => container
          .read(splitScheduleRepositoryProvider.notifier)
          .assignSlot(pushId, 0),
    );
    await settle(tester);

    // Monday is no longer rest, and Push is on it.
    expect(
      find.text('Rest'),
      findsNWidgets(kWeekLength - 1),
      reason: 'the screen did not redraw after the routine was assigned',
    );
  });

  testWidgets('removing a routine from a day shows up without leaving', (
    tester,
  ) async {
    await tester.runAsync(
      () => container
          .read(splitScheduleRepositoryProvider.notifier)
          .assignSlot(pushId, 0),
    );
    await pumpEditor(tester);
    expect(find.text('Rest'), findsNWidgets(kWeekLength - 1));

    await tester.runAsync(
      () => container
          .read(splitScheduleRepositoryProvider.notifier)
          .clearSlot(pushId, 0),
    );
    await settle(tester);

    expect(
      find.text('Rest'),
      findsNWidgets(kWeekLength),
      reason: 'the screen did not redraw after the routine was removed',
    );
  });
}
