import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:health_tracker/src/features/sleep/sleep_repository.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:health_tracker/src/constants/supabase_config.dart';

class WidgetService {
  static const String appGroupId = 'group.health_tracker';
  static const String androidWidgetName = 'SleepWidgetProvider';
  static const String androidFullWidgetName = 'com.example.health_tracker.SleepWidgetProvider';

  static Future<void> updateSleepWidget({
    required bool isSleeping,
    DateTime? startTime,
  }) async {
    try {
      await HomeWidget.saveWidgetData<bool>('is_sleeping', isSleeping);

      // Calculate the 'base' for Android Chronometer
      // chronometer.base = SystemClock.elapsedRealtime() - (Now - StartTime)
      if (isSleeping && startTime != null) {
        final rawElapsedMillis = DateTime.now().difference(startTime).inMilliseconds;
        final elapsedMillis = rawElapsedMillis < 0 ? 0 : rawElapsedMillis;
        await HomeWidget.saveWidgetData<int>('elapsed_millis', elapsedMillis);
      } else {
        await HomeWidget.saveWidgetData<int>('elapsed_millis', 0);
      }

      final updated = await HomeWidget.updateWidget(
        name: androidWidgetName,
        androidName: androidWidgetName,
        qualifiedAndroidName: androidFullWidgetName,
      );
      debugPrint('updateSleepWidget: updateWidget result=$updated');
    } catch (e) {
      debugPrint('updateSleepWidget failed: $e');
    }
  }

  @pragma('vm:entry-point')
  static Future<void> backgroundCallback(Uri? uri) async {
    // Crucial for background isolates
    WidgetsFlutterBinding.ensureInitialized();
    debugPrint("--- Sleep Widget Clicked! URI: $uri ---");

    final isToggle = uri?.host == 'toggle' || uri?.pathSegments.contains('toggle') == true;

    if (isToggle) {
      try {
        await Hive.initFlutter();
        debugPrint("Hive Initialized in background");
        
        // Initialize Supabase in background
        try {
          await Supabase.initialize(
            url: SupabaseConfig.url,
            anonKey: SupabaseConfig.anonKey,
          );
          debugPrint("Supabase Initialized in background");
        } catch (_) {
          // Already initialized
        }
        
        final box = await Hive.openBox('sleep_logs');
        final repo = SleepRepository(box);
        
        final active = repo.getActiveSession();
        debugPrint("Current active session: ${active?.id}");
        
        if (active == null) {
          debugPrint("Starting Sleep...");
          await repo.startSleep();
        } else {
          debugPrint("Ending Sleep...");
          await repo.endSleep();
        }
        
        final newActive = repo.getActiveSession();
        debugPrint("New active session: ${newActive?.id}");
        
        await updateSleepWidget(
          isSleeping: newActive != null,
          startTime: newActive?.startTime,
        );
        debugPrint("Widget Update Triggered");
      } catch (e, stack) {
        debugPrint("Background callback error: $e");
        debugPrint(stack.toString());
      }
    } else {
      debugPrint("Unknown URI host: ${uri?.host}");
    }
  }
}

@pragma('vm:entry-point')
Future<void> homeWidgetBackgroundCallback(Uri? uri) async {
  await WidgetService.backgroundCallback(uri);
}
