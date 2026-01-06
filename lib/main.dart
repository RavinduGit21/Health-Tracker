import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:health_tracker/src/features/dashboard/dashboard_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:health_tracker/src/constants/app_theme.dart';
import 'package:health_tracker/src/routing/app_router.dart';
import 'package:health_tracker/src/features/onboarding/onboarding_repository.dart';
import 'package:health_tracker/src/utils/notification_service.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:health_tracker/src/constants/supabase_config.dart';
import 'package:home_widget/home_widget.dart';
import 'package:health_tracker/src/utils/widget_service.dart';
import 'package:health_tracker/src/features/sleep/sleep_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  
  // Initialize Hive
  await Hive.initFlutter();
  await Hive.openBox('settings');
  await Hive.openBox('daily_logs');
  await Hive.openBox('weight_logs');
  await Hive.openBox('sleep_logs');

  // Initialize Services
  final sharedPreferences = await SharedPreferences.getInstance();
  await NotificationService().init();

  // Sync Data to Widget & Schedule Reminders
  final dailyLogRepo = DailyLogRepository(Hive.box('daily_logs'));
  await dailyLogRepo.updateWidgetWithCurrentData();
  
  final settingsBox = Hive.box('settings');
  final todayLog = dailyLogRepo.getTodayLog();
  await NotificationService().scheduleWaterReminders(
    currentIntake: todayLog.waterIntake,
    goal: settingsBox.get('water_goal', defaultValue: 2000),
    unit: 'mL',
  );

  // Home Widget Setup
  HomeWidget.registerBackgroundCallback(WidgetService.backgroundCallback);
  final activeSleep = SleepRepository(Hive.box('sleep_logs')).getActiveSession();
  await WidgetService.updateSleepWidget(
    isSleeping: activeSleep != null,
    startTime: activeSleep?.startTime,
  );

  runApp(
    ProviderScope(
      overrides: [
        onboardingRepositoryProvider.overrideWithValue(
          OnboardingRepository(sharedPreferences),
        ),
      ],
      child: const HealthTrackerApp(),
    ),
  );
}

class HealthTrackerApp extends ConsumerWidget {
  const HealthTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Health Tracker',
      theme: AppTheme.darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
