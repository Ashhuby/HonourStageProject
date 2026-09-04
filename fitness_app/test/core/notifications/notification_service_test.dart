import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/core/notifications/notification_service.dart';

/// Tests that notifications cannot take anything down with them.
///
/// The bug these exist for: `cancelAll()` throws `UnimplementedError` on any
/// platform the plugin does not ship — Windows and the web among them — and
/// both the Finish and the Cancel Workout buttons awaited it immediately
/// before popping the route. The session was ended or deleted in the database
/// and then the navigation never ran, so the buttons did nothing at all and
/// there was no way off the session screen.
///
/// Every method is checked rather than only the one that caused it. The next
/// call added to a button will be whichever one is untested.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = NotificationService();

  /// Every call the app makes, so a new one has to be added here to be
  /// forgotten anywhere else.
  final calls = <String, Future<void> Function()>{
    'init': service.init,
    'scheduleRestCompleteNotification': () =>
        service.scheduleRestCompleteNotification(
          DateTime.now().add(const Duration(minutes: 2)),
        ),
    'cancelRestNotification': service.cancelRestNotification,
    'cancelAll': service.cancelAll,
  };

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  group('on a platform the plugin does not implement', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.windows);

    for (final entry in calls.entries) {
      test('${entry.key} completes instead of throwing', () async {
        await expectLater(entry.value(), completes);
      });
    }
  });

  group('on a supported platform with no plugin behind the channel', () {
    // What a test binding looks like, and what a device with the plugin
    // missing or a permission revoked looks like too: the call reaches the
    // channel and fails there.
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);

    for (final entry in calls.entries) {
      test('${entry.key} swallows the channel failure', () async {
        await expectLater(entry.value(), completes);
      });
    }
  });
}
