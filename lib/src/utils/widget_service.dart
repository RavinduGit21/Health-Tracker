import 'dart:async';
import 'dart:ui';
import 'package:home_widget/home_widget.dart';
import 'package:health_tracker/src/features/sleep/sleep_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

class WidgetService {
  static const String appGroupId = 'group.health_tracker'; // Mostly for iOS, but good practice
  static const String androidWidgetName = 'SleepWidgetProvider';

  static Future<void> updateSleepWidget({
    required bool isSleeping,
    DateTime? startTime,
  }) async {
    await HomeWidget.saveWidgetData<bool>('is_sleeping', isSleeping);
    
    // Calculate the 'base' for Android Chronometer
    // chronometer.base = SystemClock.elapsedRealtime() - (Now - StartTime)
    if (isSleeping && startTime != null) {
      final elapsedMillis = DateTime.now().difference(startTime).inMilliseconds;
      await HomeWidget.saveWidgetData<int>('elapsed_millis', elapsedMillis);
    } else {
      await HomeWidget.saveWidgetData<int>('elapsed_millis', 0);
    }

    await HomeWidget.updateWidget(
      name: androidWidgetName,
      androidName: androidWidgetName,
    );
  }

  @pragma('vm:entry-point')
  static Future<void> backgroundCallback(Uri? uri) async {
    if (uri?.host == 'toggle') {
      await Hive.initFlutter();
      final box = await Hive.openBox('sleep_logs');
      final repo = SleepRepository(box);
      
      final active = repo.getActiveSession();
      if (active == null) {
        await repo.startSleep();
      } else {
        await repo.endSleep();
      }
      
      final newActive = repo.getActiveSession();
      await updateSleepWidget(
        isSleeping: newActive != null,
        startTime: newActive?.startTime,
      );
    }
  }
}
