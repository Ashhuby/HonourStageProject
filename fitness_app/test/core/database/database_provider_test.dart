import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:fitness_app/core/database/database_provider.dart';

/// Guards the lifetime of the database.
///
/// This provider was auto-disposing, which closed the database whenever
/// nothing happened to be listening and opened a fresh one on the next read.
/// Drift's update notifications are per-instance, so a screen subscribed to
/// the old instance never heard about writes made through the new one: rows
/// changed and the UI kept drawing the previous answer.
///
/// It is the kind of fault that hides. Nothing throws, nothing is logged, and
/// every repository test passes — they read and write through one container
/// that holds the provider open for the length of the test, which is the one
/// condition the running app does not meet.
void main() {
  test('the same database instance is handed out every time', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final first = container.read(databaseProvider);
    final second = container.read(databaseProvider);

    expect(identical(first, second), isTrue);
  });

  test('it survives having no listeners', () async {
    // The condition that used to close it: a read that retains nothing, then
    // a turn of the event loop for the auto-dispose scheduler to run.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final before = container.read(databaseProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final after = container.read(databaseProvider);

    expect(
      identical(before, after),
      isTrue,
      reason:
          'the database was disposed and rebuilt, which silently breaks '
          'every query stream already subscribed to it',
    );
  });

  test('a subscription outlives an unrelated read', () async {
    // What the app actually does: a screen subscribes, the user navigates, a
    // repository reads the provider to write. All three must be the same
    // database or the screen goes deaf.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final watched = container.read(databaseProvider);
    final subscription = container.listen(databaseProvider, (_, _) {});
    subscription.close();

    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(identical(container.read(databaseProvider), watched), isTrue);
  });
}
