import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:alarm/alarm.dart';
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

  static const int _bedtimeAlarmId = 3000;
  static const int _wakeAlarmId = 3001;

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    tz_data.initializeTimeZones();
    try {
      final String? localTz = await FlutterTimezone.getLocalTimezone();
      if (localTz != null) {
        tz.setLocalLocation(tz.getLocation(localTz));
      }
    } catch (e) {
      debugPrint("Timezone initialization failed: $e. Falling back to UTC.");
      tz.setLocalLocation(tz.UTC);
    }

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap
      },
    );

    await _requestPermissionsIfNeeded();

    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    try {
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'sleep_alarms',
          'Sleep Alarms',
          description: 'Daily bedtime and wake-up alarms',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'water_reminders',
          'Water Reminders',
          description: 'Reminders to drink water',
          importance: Importance.max,
          playSound: true,
        ),
      );
    } catch (_) {
      // Ignore channel creation failures.
    }
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

  Future<void> scheduleBedtimeAlarm({required int hour, required int minute}) async {
    await _scheduleDailyAlarm(
      id: _bedtimeAlarmId,
      hour: hour,
      minute: minute,
      title: 'Bedtime',
      body: 'Time to go to sleep.',
    );
    
    // Also set a proper ringing alarm if we have logic for it
    await _setRingingAlarm(
      id: _bedtimeAlarmId,
      hour: hour,
      minute: minute,
      title: 'Bedtime',
      body: 'Time to sleep!',
    );
  }

  Future<void> cancelBedtimeAlarm() async {
    await flutterLocalNotificationsPlugin.cancel(_bedtimeAlarmId);
    if (!kIsWeb) await Alarm.stop(_bedtimeAlarmId);
  }

  Future<void> scheduleWakeAlarm({required int hour, required int minute}) async {
    await _scheduleDailyAlarm(
      id: _wakeAlarmId,
      hour: hour,
      minute: minute,
      title: 'Wake up',
      body: 'Good morning! Time to wake up.',
    );

    await _setRingingAlarm(
      id: _wakeAlarmId,
      hour: hour,
      minute: minute,
      title: 'Wake up',
      body: 'Good morning!',
    );
  }

  Future<void> cancelWakeAlarm() async {
    await flutterLocalNotificationsPlugin.cancel(_wakeAlarmId);
    if (!kIsWeb) await Alarm.stop(_wakeAlarmId);
  }

  static const String _alarmPath = 'assets/alarm.mp3';

  Future<void> _setRingingAlarm({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    if (kIsWeb) return;

    final alarmSettings = AlarmSettings(
      id: id,
      dateTime: scheduled,
      assetAudioPath: _alarmPath,
      loopAudio: true,
      vibrate: true,
      volume: 0.8,
      fadeDuration: 3.0,
      notificationSettings: NotificationSettings(
        title: title,
        body: body,
        stopButton: 'Stop',
      ),
      androidFullScreenIntent: true,
    );

    try {
      await Alarm.set(alarmSettings: alarmSettings);
    } catch (e) {
      debugPrint("Alarm package failed (likely missing assets/alarm.mp3): $e");
      // If it fails, we still have the local notification as backup
    }
  }

  Future<void> _scheduleDailyAlarm({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'sleep_alarms',
      'Sleep Alarms',
      channelDescription: 'Daily bedtime and wake-up alarms',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      ongoing: true, // Makes it harder to dismiss accidentally
      audioAttributesUsage: AudioAttributesUsage.alarm,
      styleInformation: const BigTextStyleInformation(''),
    );
    const details = NotificationDetails(android: androidDetails);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    AndroidScheduleMode scheduleMode = AndroidScheduleMode.alarmClock;
    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    try {
      if (androidPlugin != null) {
        final canExact = await androidPlugin.canScheduleExactNotifications() ?? false;
        if (!canExact) {
          await androidPlugin.requestExactAlarmsPermission();
          // After requesting, we still might not have it until user returns,
          // so we check again or just accept it might be inexact this time.
          final nowCanExact = await androidPlugin.canScheduleExactNotifications() ?? false;
          if (!nowCanExact) scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
        }
      }
    } catch (e) {
      debugPrint("Error checking/requesting exact alarm: $e");
      scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
    }

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      details,
      androidScheduleMode: scheduleMode,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    try {
      final pending = await flutterLocalNotificationsPlugin.pendingNotificationRequests();
      // Intentionally log for debugging alarm scheduling.
      // ignore: avoid_print
      print('Pending notifications count: ${pending.length}');
    } catch (_) {
      // Ignore
    }
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
