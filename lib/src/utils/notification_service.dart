import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static const String _settingsBoxName = 'settings';
  static const String _lastWaterLogAtKey = 'last_water_log_at';

  static const int _waterReminderBaseId = 2000;
  static const int _waterReminderCount = 12;

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    tz_data.initializeTimeZones();
    try {
      final localTz = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTz));
    } catch (_) {
      // Fall back to default timezone database location.
    }

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap
      },
    );

    await _requestPermissionsIfNeeded();
  }

  Future<void> _requestPermissionsIfNeeded() async {
    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    try {
      await androidPlugin?.requestNotificationsPermission();
    } catch (_) {
      // Ignore if not supported on this device/SDK.
    }

    final iosPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    try {
      await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (_) {
      // Ignore if not supported.
    }
  }

  Future<void> showNotification({required String title, required String body, int id = 99}) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
            'immediate_channel', 'Immediate Notifications',
            channelDescription: 'Notifications sent immediately',
            importance: Importance.max,
            priority: Priority.high);
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
        id, title, body, platformChannelSpecifics);
  }

  Future<void> showScheduledNotification({required String title, required String body, required int seconds}) async {
    await Future.delayed(Duration(seconds: seconds));
    await showNotification(title: title, body: body);
  }

  Future<void> scheduleWaterReminders({
    required int currentIntake,
    required int goal,
    required String unit,
  }) async {
    await _cancelWaterReminders();

    if (currentIntake >= goal) {
      return;
    }

    final now = DateTime.now();
    final settings = Hive.box(_settingsBoxName);

    DateTime? lastLoggedAt;
    final lastLoggedRaw = settings.get(_lastWaterLogAtKey);
    if (lastLoggedRaw is String && lastLoggedRaw.isNotEmpty) {
      lastLoggedAt = DateTime.tryParse(lastLoggedRaw);
    }

    // If we don't have a timestamp (or it's from a different day), start from now.
    if (lastLoggedAt == null || !_isSameDay(lastLoggedAt, now)) {
      lastLoggedAt = now;
      await settings.put(_lastWaterLogAtKey, lastLoggedAt.toIso8601String());
    }

    // Schedule a chain: every 2 hours after the last logged time.
    // We schedule up to _waterReminderCount reminders ahead.
    final first = lastLoggedAt.add(const Duration(hours: 2));
    final firstScheduled = first.isAfter(now)
        ? first
        : now.add(const Duration(hours: 2));

    for (int i = 0; i < _waterReminderCount; i++) {
      final scheduledAt = firstScheduled.add(Duration(hours: 2 * i));

      // Don't schedule past the end of the day (keeps schedule clean).
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
      if (scheduledAt.isAfter(endOfDay)) break;

      await _scheduleWaterReminder(
        id: _waterReminderBaseId + i,
        scheduledAt: scheduledAt,
        currentIntake: currentIntake,
        goal: goal,
        unit: unit,
      );
    }
  }

  Future<void> recordWaterLoggedNow() async {
    final settings = Hive.box(_settingsBoxName);
    await settings.put(_lastWaterLogAtKey, DateTime.now().toIso8601String());
  }

  Future<void> _cancelWaterReminders() async {
    for (int i = 0; i < _waterReminderCount; i++) {
      await flutterLocalNotificationsPlugin.cancel(_waterReminderBaseId + i);
    }
  }

  Future<void> _scheduleWaterReminder({
    required int id,
    required DateTime scheduledAt,
    required int currentIntake,
    required int goal,
    required String unit,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'water_reminders',
      'Water Reminders',
      channelDescription: 'Reminders to drink water',
      importance: Importance.max,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    final remaining = (goal - currentIntake).clamp(0, goal);
    final title = 'Time to drink water';
    final body = remaining > 0
        ? 'You are $remaining $unit away from your goal. Log your water now.'
        : 'Log your water now.';

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledAt, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> cancelAll() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}
