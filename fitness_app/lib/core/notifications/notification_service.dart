import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Local notifications, and nothing that depends on them.
///
/// Every method here absorbs its own failures. Notifications are housekeeping
/// — a rest alert that does not fire is a worse workout, not a broken one —
/// and the alternative was demonstrated the hard way: `cancelAll()` throws
/// `UnimplementedError` on any platform the plugin does not implement, which
/// includes Windows and the web. Both the Finish and the Cancel Workout
/// buttons awaited it immediately before popping the route, so on those
/// platforms the session was ended or deleted in the database and then the
/// navigation never ran. The buttons did nothing, silently, and there was no
/// way out of the screen.
///
/// Absorbing here rather than at the four call sites because a fifth would
/// have to remember, and forgetting is invisible until someone is trapped.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Notification id for the rest timer. A single id means a newly scheduled
  /// rest replaces any earlier one rather than stacking alerts.
  static const int _restNotificationId = 0;

  /// Whether the plugin has an implementation on this platform at all.
  ///
  /// The plugin's own `initialize` returns true everywhere and only the
  /// scheduling calls throw, so there is nothing to ask it — the list of
  /// platforms it ships is the answer.
  static bool get _supported {
    if (kIsWeb) return false;
    return const {
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
      TargetPlatform.linux,
    }.contains(defaultTargetPlatform);
  }

  static const AndroidNotificationDetails _restChannel =
      AndroidNotificationDetails(
        'rest_timer_channel',
        'Rest Timer',
        channelDescription: 'Notifies when rest period is complete',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
      );

  static const NotificationDetails _restDetails = NotificationDetails(
    android: _restChannel,
  );

  /// Runs [work], swallowing anything the notification layer throws.
  ///
  /// Catches broadly on purpose. The platform interface throws
  /// [UnimplementedError] where there is no implementation, the channel throws
  /// [MissingPluginException] where the plugin is not registered, and the OS
  /// throws [PlatformException] for a permission it has since revoked — none
  /// of which the caller can do anything about, and none of which is worth
  /// failing the thing the user actually asked for.
  Future<void> _attempt(String action, Future<void> Function() work) async {
    if (!_supported) return;
    try {
      await work();
    } catch (error) {
      debugPrint(
        'Notifications: $action failed, continuing without it: '
        '$error',
      );
    }
  }

  Future<void> init() async {
    await _attempt('initialisation', () async {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings settings = InitializationSettings(
        android: androidSettings,
      );

      await _plugin.initialize(settings);

      // Required before anything can be scheduled. The local zone is left as
      // UTC on purpose: rest is scheduled as an absolute instant a few minutes
      // out, so the zone name never affects when the alarm fires, and
      // resolving the device zone would cost another dependency.
      tz.initializeTimeZones();

      final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.requestNotificationsPermission();
      // Android 14 denies exact alarms until granted. Scheduling falls back to
      // an inexact alarm if this is refused, so the request is best-effort.
      await androidPlugin?.requestExactAlarmsPermission();
    });
  }

  /// Schedules the rest-complete alert for [endsAt].
  ///
  /// Scheduled rather than fired from a Dart timer so it still arrives when
  /// the phone is locked or the app has been evicted mid-set — the case the
  /// timer exists for.
  Future<void> scheduleRestCompleteNotification(DateTime endsAt) async {
    await _attempt('scheduling the rest alert', () async {
      await _plugin.cancel(_restNotificationId);

      final when = tz.TZDateTime.from(endsAt, tz.local);
      if (!when.isAfter(tz.TZDateTime.now(tz.local))) return;

      try {
        await _schedule(when, AndroidScheduleMode.exactAllowWhileIdle);
      } on PlatformException {
        // Exact alarms not permitted — an approximate alert beats none.
        await _schedule(when, AndroidScheduleMode.inexactAllowWhileIdle);
      }
    });
  }

  Future<void> _schedule(tz.TZDateTime when, AndroidScheduleMode mode) {
    return _plugin.zonedSchedule(
      _restNotificationId,
      'Rest Complete',
      'Time to get back to it!',
      when,
      _restDetails,
      androidScheduleMode: mode,
      // The instant is absolute, so it must not be reinterpreted per zone.
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancels a pending rest alert — rest skipped, restarted, or the set logged
  /// before it fired.
  Future<void> cancelRestNotification() => _attempt(
    'cancelling the rest alert',
    () => _plugin.cancel(_restNotificationId),
  );

  Future<void> cancelAll() =>
      _attempt('cancelling notifications', () => _plugin.cancelAll());
}
