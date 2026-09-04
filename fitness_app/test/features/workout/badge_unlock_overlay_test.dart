import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_app/features/workout/data/badge_unlock_queue.dart';
import 'package:fitness_app/features/workout/presentation/widgets/badge_unlock_overlay.dart';

/// Tests the unlock celebration.
///
/// The only widget test in the suite, and deliberately so: everywhere else the
/// logic worth testing has been pushed into pure functions under `domain/`.
/// This cannot be — what is being tested is that the host adopts the queue,
/// shows one badge at a time and advances on dismissal, which is state living
/// in an element's lifecycle rather than in a value.
void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() => container.dispose());

  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: BadgeUnlockHost(child: Scaffold(body: Text('the app'))),
        ),
      ),
    );
  }

  void enqueue(List<String> keys) =>
      container.read(badgeUnlockQueueProvider.notifier).enqueue(keys);

  /// Runs the reveal to completion. The host adopts the queue in a
  /// post-frame callback, so an extra pump is needed before the animation.
  Future<void> settleReveal(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
  }

  /// Waits out the auto-dismiss and the fade that follows it.
  ///
  /// Also what keeps these tests honest about the hold timer: a celebration
  /// left on screen at the end of a test fails it with a pending timer, which
  /// is exactly the state the app was getting stuck in.
  Future<void> waitOutHold(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  }

  testWidgets('nothing is shown while the queue is empty', (tester) async {
    await pumpHost(tester);
    await tester.pump();

    expect(find.text('the app'), findsOneWidget);
    expect(find.text('BADGE UNLOCKED'), findsNothing);
  });

  testWidgets('an earned badge is celebrated', (tester) async {
    await pumpHost(tester);
    enqueue(['first_workout']);
    await settleReveal(tester);

    expect(find.text('BADGE UNLOCKED'), findsOneWidget);
    expect(find.text('First Rep'), findsOneWidget);
    expect(find.text('BRONZE'), findsOneWidget);
    // The app underneath is still mounted, not replaced.
    expect(find.text('the app'), findsOneWidget);

    await waitOutHold(tester);
  });

  testWidgets('a celebration takes itself down', (tester) async {
    // Nothing in the app may depend on the user tapping to get their screen
    // back. The overlay is a full-screen modal barrier, so for as long as it
    // is up every tap in the app goes to it — including the one on Finish.
    await pumpHost(tester);
    enqueue(['first_workout']);
    await settleReveal(tester);
    expect(find.text('BADGE UNLOCKED'), findsOneWidget);

    await waitOutHold(tester);

    expect(find.text('BADGE UNLOCKED'), findsNothing);
    expect(container.read(badgeUnlockQueueProvider), isEmpty);
  });

  testWidgets('tapping NICE dismisses and empties the queue', (tester) async {
    await pumpHost(tester);
    enqueue(['first_workout']);
    await settleReveal(tester);

    await tester.tap(find.text('NICE'));
    await tester.pumpAndSettle();

    expect(find.text('BADGE UNLOCKED'), findsNothing);
    expect(container.read(badgeUnlockQueueProvider), isEmpty);
  });

  testWidgets('badges are celebrated one at a time, in order', (tester) async {
    await pumpHost(tester);
    enqueue(['first_workout', 'first_cardio']);
    await settleReveal(tester);

    // The second badge must not be drawn on top of the first.
    expect(find.text('First Rep'), findsOneWidget);
    expect(find.text('Off the Rack'), findsNothing);
    expect(find.text('1 more to go'), findsOneWidget);

    await tester.tap(find.text('NICE'));
    await tester.pumpAndSettle();

    expect(find.text('First Rep'), findsNothing);
    expect(find.text('Off the Rack'), findsOneWidget);
    // Nothing behind this one, so no count.
    expect(find.textContaining('more to go'), findsNothing);

    await tester.tap(find.text('NICE'));
    await tester.pumpAndSettle();

    expect(find.text('BADGE UNLOCKED'), findsNothing);
    expect(container.read(badgeUnlockQueueProvider), isEmpty);
  });

  testWidgets('a badge queued mid-celebration waits its turn', (tester) async {
    await pumpHost(tester);
    enqueue(['first_workout']);
    await settleReveal(tester);

    // An award landing while the first is on screen must not swap it out.
    enqueue(['first_cardio']);
    await tester.pump();
    expect(find.text('First Rep'), findsOneWidget);
    expect(find.text('Off the Rack'), findsNothing);

    await tester.tap(find.text('NICE'));
    await tester.pumpAndSettle();
    expect(find.text('Off the Rack'), findsOneWidget);

    await waitOutHold(tester);
  });

  group('a pile landing at once', () {
    /// More badges than anyone wants to tap through one at a time. This is
    /// what an upgrade looks like from the app's side: badges added to the
    /// catalogue are earned retroactively, all on the first set logged after
    /// the update.
    const pile = [
      'first_workout',
      'sessions_10',
      'sets_50',
      'streak_3_day',
      'volume_10t',
      'pr_10',
    ];

    testWidgets('is one celebration, not six', (tester) async {
      await pumpHost(tester);
      enqueue(pile);
      await settleReveal(tester);

      expect(find.text('6 BADGES UNLOCKED'), findsOneWidget);
      expect(find.text('BADGE UNLOCKED'), findsNothing);
      // Nothing is held back, so there is no queue to trail.
      expect(find.textContaining('more to go'), findsNothing);

      await waitOutHold(tester);
    });

    testWidgets('names the badges it covers', (tester) async {
      await pumpHost(tester);
      enqueue(pile);
      await settleReveal(tester);

      // The headline is the best of them; the rest are listed rather than
      // reduced to a number.
      expect(find.text('PR Machine'), findsOneWidget);
      expect(find.textContaining('First Rep'), findsOneWidget);

      await waitOutHold(tester);
    });

    testWidgets('one dismissal clears the whole pile', (tester) async {
      await pumpHost(tester);
      enqueue(pile);
      await settleReveal(tester);

      await tester.tap(find.text('NICE'));
      await tester.pumpAndSettle();

      expect(container.read(badgeUnlockQueueProvider), isEmpty);
      expect(find.textContaining('UNLOCKED'), findsNothing);
    });
  });

  testWidgets('tapping the backdrop dismisses too', (tester) async {
    await pumpHost(tester);
    enqueue(['first_workout']);
    await settleReveal(tester);

    // Anywhere outside the button — the whole scrim is the dismiss target.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.text('BADGE UNLOCKED'), findsNothing);
  });

  testWidgets('the app is usable again on its own', (tester) async {
    // The bug this guards: badges land while the Finish dialog is open, the
    // celebration goes up over it — it is mounted above the navigator — and
    // every tap on Finish is eaten by the scrim instead. With a badge per tap
    // and a pile of them queued, the workout could not be ended at all.
    var finished = false;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (context, child) => BadgeUnlockHost(child: child!),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => AlertDialog(
                      actions: [
                        TextButton(
                          onPressed: () => finished = true,
                          child: const Text('Finish'),
                        ),
                      ],
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    enqueue(const [
      'first_workout',
      'sessions_10',
      'sets_50',
      'streak_3_day',
      'volume_10t',
      'pr_10',
    ]);
    await settleReveal(tester);

    // Without touching anything, the celebration clears itself.
    await waitOutHold(tester);

    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();
    expect(finished, isTrue);
  });

  testWidgets('the app underneath is not tappable through the scrim', (
    tester,
  ) async {
    var tapsUnderneath = 0;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: BadgeUnlockHost(
            child: Scaffold(
              body: GestureDetector(
                onTap: () => tapsUnderneath++,
                child: const SizedBox.expand(child: Text('the app')),
              ),
            ),
          ),
        ),
      ),
    );

    enqueue(['first_workout']);
    await settleReveal(tester);

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(tapsUnderneath, 0);
  });
}
