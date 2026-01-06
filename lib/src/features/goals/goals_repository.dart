import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:health_tracker/src/features/dashboard/dashboard_repository.dart';
import 'package:health_tracker/src/utils/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GoalsRepository {
  final Box _box;
  final _supabase = Supabase.instance.client;

  RealtimeChannel? _settingsChannel;

  GoalsRepository(this._box) {
    _initRealtime();
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn || data.event == AuthChangeEvent.tokenRefreshed) {
        _initRealtime();
      } else if (data.event == AuthChangeEvent.signedOut) {
        _settingsChannel?.unsubscribe();
        _settingsChannel = null;
      }
    });
  }

  void _initRealtime() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    _settingsChannel?.unsubscribe();
    _settingsChannel = _supabase
        .channel('public:user_settings')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_settings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
             if (payload.newRecord != null) {
               final rec = payload.newRecord;
               _box.put(waterGoalKey, rec['water_goal']);
               _box.put(sugarLimitKey, rec['sugar_limit']);
               _box.put(remindersKey, rec['reminders_enabled']);
               _box.put(sugarModeKey, rec['sugar_tracking_mode']);
               _box.put(reminderStartKey, rec['reminder_start_hour']);
               _box.put(reminderEndKey, rec['reminder_end_hour']);
               _box.put(reminderIntervalKey, rec['reminder_interval']);
               _box.put(targetWeightKey, (rec['target_weight'] as num?)?.toDouble());
               _box.put(weightUnitKey, rec['weight_unit']);
               _box.put(challengeStartKey, rec['challenge_start_date']);
             }
          },
        );
    _settingsChannel?.subscribe();
  }

  Future<void> _saveSettings() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase.from('user_settings').upsert({
        'user_id': user.id,
        'water_goal': getWaterGoal(),
        'sugar_limit': getSugarLimit(),
        'reminders_enabled': getRemindersEnabled(),
        'sugar_tracking_mode': getSugarTrackingMode(),
        'reminder_start_hour': getReminderStartHour(),
        'reminder_end_hour': getReminderEndHour(),
        'reminder_interval': getReminderInterval(),
        'target_weight': getTargetWeight(),
        'weight_unit': getWeightUnit(),
        'challenge_start_date': getChallengeStartDate(),
      });
    } catch (e) {
      print("Settings sync failed: $e");
    }
  }

  Future<void> syncRemote() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final response = await _supabase.from('user_settings').select().eq('user_id', user.id).maybeSingle();
      if (response != null) {
        await _box.put(waterGoalKey, response['water_goal']);
        await _box.put(sugarLimitKey, response['sugar_limit']);
        await _box.put(remindersKey, response['reminders_enabled']);
        await _box.put(sugarModeKey, response['sugar_tracking_mode']);
        await _box.put(reminderStartKey, response['reminder_start_hour']);
        await _box.put(reminderEndKey, response['reminder_end_hour']);
        await _box.put(reminderIntervalKey, response['reminder_interval']);
        await _box.put(targetWeightKey, (response['target_weight'] as num?)?.toDouble());
        await _box.put(weightUnitKey, response['weight_unit']);
        await _box.put(challengeStartKey, response['challenge_start_date']);
      }
    } catch (e) {
      print("Settings pull failed: $e");
    }
  }

  static const String waterGoalKey = 'water_goal';
  static const String sugarLimitKey = 'sugar_limit';
  static const String remindersKey = 'reminders_enabled';
  static const String sugarModeKey = 'sugar_tracking_mode'; 
  
  static const String reminderStartKey = 'reminder_start_hour';
  static const String reminderEndKey = 'reminder_end_hour';
  static const String reminderIntervalKey = 'reminder_interval';
  static const String targetWeightKey = 'target_weight';
  static const String weightUnitKey = 'weight_unit';
  static const String challengeStartKey = 'challenge_start_date';

  int getWaterGoal() => _box.get(waterGoalKey, defaultValue: 2000);
  Future<void> setWaterGoal(int value) async {
    await _box.put(waterGoalKey, value);
    await _saveSettings();
  }

  int getSugarLimit() => _box.get(sugarLimitKey, defaultValue: 38);
  Future<void> setSugarLimit(int value) async {
    await _box.put(sugarLimitKey, value);
    await _saveSettings();
  }

  bool getRemindersEnabled() => _box.get(remindersKey, defaultValue: true);
  Future<void> setRemindersEnabled(bool value) async {
    await _box.put(remindersKey, value);
    await _saveSettings();
  }

  String getSugarTrackingMode() => _box.get(sugarModeKey, defaultValue: 'added');
  Future<void> setSugarTrackingMode(String value) async {
    await _box.put(sugarModeKey, value);
    await _saveSettings();
  }

  int getReminderStartHour() => _box.get(reminderStartKey, defaultValue: 9);
  Future<void> setReminderStartHour(int value) async {
    await _box.put(reminderStartKey, value);
    await _saveSettings();
  }

  int getReminderEndHour() => _box.get(reminderEndKey, defaultValue: 20); // 8 PM
  Future<void> setReminderEndHour(int value) async {
    await _box.put(reminderEndKey, value);
    await _saveSettings();
  }

  int getReminderInterval() => _box.get(reminderIntervalKey, defaultValue: 2);
  Future<void> setReminderInterval(int value) async {
    await _box.put(reminderIntervalKey, value);
    await _saveSettings();
  }

  double getTargetWeight() => _box.get(targetWeightKey, defaultValue: 70.0);
  Future<void> setTargetWeight(double value) async {
    await _box.put(targetWeightKey, value);
    await _saveSettings();
  }

  String getWeightUnit() => _box.get(weightUnitKey, defaultValue: 'kg');
  Future<void> setWeightUnit(String value) async {
    await _box.put(weightUnitKey, value);
    await _saveSettings();
  }

  String? getChallengeStartDate() => _box.get(challengeStartKey);
  Future<void> setChallengeStartDate(String? value) async {
    await _box.put(challengeStartKey, value);
    await _saveSettings();
  }
}

final goalsRepositoryProvider = Provider<GoalsRepository>((ref) {
  final box = Hive.box('settings');
  return GoalsRepository(box);
});

class GoalsState {
  final int waterGoal;
  final int sugarLimit;
  final bool remindersEnabled;
  final String sugarTrackingMode;
  final int reminderStartHour;
  final int reminderEndHour;
  final int reminderInterval;
  final double targetWeight;
  final String weightUnit;
  final String? challengeStartDate;

  GoalsState({
    required this.waterGoal, 
    required this.sugarLimit,
    required this.remindersEnabled,
    required this.sugarTrackingMode,
    required this.reminderStartHour,
    required this.reminderEndHour,
    required this.reminderInterval,
    required this.targetWeight,
    required this.weightUnit,
    this.challengeStartDate,
  });
}

class GoalsNotifier extends Notifier<GoalsState> {
  @override
  GoalsState build() {
    final repository = ref.read(goalsRepositoryProvider);
    
    // Auto-sync on load
    repository.syncRemote().then((_) => ref.invalidateSelf());

    return GoalsState(
      waterGoal: repository.getWaterGoal(),
      sugarLimit: repository.getSugarLimit(),
      remindersEnabled: repository.getRemindersEnabled(),
      sugarTrackingMode: repository.getSugarTrackingMode(),
      reminderStartHour: repository.getReminderStartHour(),
      reminderEndHour: repository.getReminderEndHour(),
      reminderInterval: repository.getReminderInterval(),
      targetWeight: repository.getTargetWeight(),
      weightUnit: repository.getWeightUnit(),
      challengeStartDate: repository.getChallengeStartDate(),
    );
  }

  // ... existing methods ...

  Future<void> updateReminderSettings(int start, int end, int interval) async {
    final repo = ref.read(goalsRepositoryProvider);
    await repo.setReminderStartHour(start);
    await repo.setReminderEndHour(end);
    await repo.setReminderInterval(interval);
    
    // Refresh state
    state = GoalsState(
      waterGoal: state.waterGoal,
      sugarLimit: state.sugarLimit,
      remindersEnabled: state.remindersEnabled,
      sugarTrackingMode: state.sugarTrackingMode,
      reminderStartHour: start,
      reminderEndHour: end,
      reminderInterval: interval,
      targetWeight: state.targetWeight,
      weightUnit: state.weightUnit,
      challengeStartDate: state.challengeStartDate,
    );
  }

  // Helper method to copy state more easily if I was rewriting all, but keeping it minimal for diff.
  // Actually, I need to update all previous `state =` calls to include the new fields.
  // Let's use `copyWith` pattern usually, but here I'll just re-construct.
  
  Future<void> updateWaterGoal(int value) async {
    await ref.read(goalsRepositoryProvider).setWaterGoal(value);
    state = _textStateWith(waterGoal: value);
    
    // Update notifications with new goal
    final todayLog = ref.read(dailyLogRepositoryProvider).getTodayLog();
    await NotificationService().scheduleWaterReminders(
      currentIntake: todayLog.waterIntake,
      goal: value,
      unit: 'mL',
    );
  }

  Future<void> updateSugarLimit(int value) async {
    await ref.read(goalsRepositoryProvider).setSugarLimit(value);
    state = _textStateWith(sugarLimit: value);
  }

  Future<void> setRemindersEnabled(bool value) async {
    await ref.read(goalsRepositoryProvider).setRemindersEnabled(value);
    state = _textStateWith(remindersEnabled: value);
  }

  Future<void> setSugarTrackingMode(String value) async {
    await ref.read(goalsRepositoryProvider).setSugarTrackingMode(value);
    state = _textStateWith(sugarTrackingMode: value);
  }

  Future<void> updateTargetWeight(double value) async {
    await ref.read(goalsRepositoryProvider).setTargetWeight(value);
    state = _textStateWith(targetWeight: value);
  }

  Future<void> setWeightUnit(String value) async {
    await ref.read(goalsRepositoryProvider).setWeightUnit(value);
    state = _textStateWith(weightUnit: value);
  }

  Future<void> setChallengeStartDate(String? value) async {
    await ref.read(goalsRepositoryProvider).setChallengeStartDate(value);
    state = _textStateWith(challengeStartDate: value);
  }

  GoalsState _textStateWith({
    int? waterGoal, 
    int? sugarLimit, 
    bool? remindersEnabled, 
    String? sugarTrackingMode,
    int? reminderStartHour,
    int? reminderEndHour,
    int? reminderInterval,
    double? targetWeight,
    String? weightUnit,
    String? challengeStartDate,
  }) {
    return GoalsState(
      waterGoal: waterGoal ?? state.waterGoal,
      sugarLimit: sugarLimit ?? state.sugarLimit,
      remindersEnabled: remindersEnabled ?? state.remindersEnabled,
      sugarTrackingMode: sugarTrackingMode ?? state.sugarTrackingMode,
      reminderStartHour: reminderStartHour ?? state.reminderStartHour,
      reminderEndHour: reminderEndHour ?? state.reminderEndHour,
      reminderInterval: reminderInterval ?? state.reminderInterval,
      targetWeight: targetWeight ?? state.targetWeight,
      weightUnit: weightUnit ?? state.weightUnit,
      challengeStartDate: challengeStartDate ?? state.challengeStartDate,
    );
  }
}

final goalsProvider = NotifierProvider<GoalsNotifier, GoalsState>(GoalsNotifier.new);
