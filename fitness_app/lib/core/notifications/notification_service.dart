import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Notification id for the rest timer. A single id means a newly scheduled
  /// rest replaces any earlier one rather than stacking alerts.
  static const int _restNotificationId = 0;

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

  Future<void> init() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(settings);

    // Required before anything can be scheduled. The local zone is left as
    // UTC on purpose: rest is scheduled as an absolute instant a few minutes
    // out, so the zone name never affects when the alarm fires, and resolving
    // the device zone would cost another dependency.
    tz.initializeTimeZones();

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();
    // Android 14 denies exact alarms until granted. Scheduling falls back to
    // an inexact alarm if this is refused, so the request is best-effort.
    await androidPlugin?.requestExactAlarmsPermission();
  }

  /// Schedules the rest-complete alert for [endsAt].
  ///
  /// Scheduled rather than fired from a Dart timer so it still arrives when
  /// the phone is locked or the app has been evicted mid-set — the case the
  /// timer exists for.
  Future<void> scheduleRestCompleteNotification(DateTime endsAt) async {
    await cancelRestNotification();

    final when = tz.TZDateTime.from(endsAt, tz.local);
    if (!when.isAfter(tz.TZDateTime.now(tz.local))) return;

    try {
      await _schedule(when, AndroidScheduleMode.exactAllowWhileIdle);
    } on PlatformException {
      // Exact alarms not permitted — an approximate alert beats none.
      await _schedule(when, AndroidScheduleMode.inexactAllowWhileIdle);
    }
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
  Future<void> cancelRestNotification() async {
    await _plugin.cancel(_restNotificationId);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
