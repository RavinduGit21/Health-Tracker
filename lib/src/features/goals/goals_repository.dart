import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:health_tracker/src/features/dashboard/dashboard_repository.dart';
import 'package:health_tracker/src/utils/notification_service.dart';

class GoalsRepository {
  final Box _box;

  GoalsRepository(this._box);

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
  Future<void> setWaterGoal(int value) => _box.put(waterGoalKey, value);

  int getSugarLimit() => _box.get(sugarLimitKey, defaultValue: 38);
  Future<void> setSugarLimit(int value) => _box.put(sugarLimitKey, value);

  bool getRemindersEnabled() => _box.get(remindersKey, defaultValue: true);
  Future<void> setRemindersEnabled(bool value) => _box.put(remindersKey, value);

  String getSugarTrackingMode() => _box.get(sugarModeKey, defaultValue: 'added');
  Future<void> setSugarTrackingMode(String value) => _box.put(sugarModeKey, value);

  int getReminderStartHour() => _box.get(reminderStartKey, defaultValue: 9);
  Future<void> setReminderStartHour(int value) => _box.put(reminderStartKey, value);

  int getReminderEndHour() => _box.get(reminderEndKey, defaultValue: 20); // 8 PM
  Future<void> setReminderEndHour(int value) => _box.put(reminderEndKey, value);

  int getReminderInterval() => _box.get(reminderIntervalKey, defaultValue: 2);
  Future<void> setReminderInterval(int value) => _box.put(reminderIntervalKey, value);

  double getTargetWeight() => _box.get(targetWeightKey, defaultValue: 70.0);
  Future<void> setTargetWeight(double value) => _box.put(targetWeightKey, value);

  String getWeightUnit() => _box.get(weightUnitKey, defaultValue: 'kg');
  Future<void> setWeightUnit(String value) => _box.put(weightUnitKey, value);

  String? getChallengeStartDate() => _box.get(challengeStartKey);
  Future<void> setChallengeStartDate(String? value) => _box.put(challengeStartKey, value);
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
