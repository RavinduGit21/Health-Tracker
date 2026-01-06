import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:health_tracker/src/utils/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LogEntry {
  final String id;
  final String time;
  final String description;
  final int amount; // mL for water, g for sugar
  final String type; // 'water' or 'sugar'

  LogEntry({
    required this.id,
    required this.time, 
    required this.description, 
    required this.amount, 
    required this.type
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'time': time, 
    'description': description, 
    'amount': amount, 
    'type': type
  };

  factory LogEntry.fromMap(Map<dynamic, dynamic> map) => LogEntry(
    id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
    time: map['time'] ?? '',
    description: map['description'] ?? '',
    amount: map['amount'] ?? 0,
    type: map['type'] ?? 'water',
  );
}

class DailyLog {
  final String date;
  final int waterIntake;
  final int sugarIntake;
  final bool workoutDone;
  final int caloriesBurned;
  final String workoutNotes;
  final String notes;
  final bool sugarCutCompleted;
  final List<LogEntry> entries;

  DailyLog({
    required this.date, 
    required this.waterIntake, 
    required this.sugarIntake,
    this.workoutDone = false,
    this.caloriesBurned = 0,
    this.workoutNotes = '',
    this.notes = '',
    this.sugarCutCompleted = false,
    this.entries = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'waterIntake': waterIntake,
      'sugarIntake': sugarIntake,
      'workoutDone': workoutDone,
      'caloriesBurned': caloriesBurned,
      'workoutNotes': workoutNotes,
      'notes': notes,
      'sugarCutCompleted': sugarCutCompleted,
      'entries': entries.map((e) => e.toMap()).toList(),
    };
  }

  factory DailyLog.fromMap(Map<dynamic, dynamic> map) {
    return DailyLog(
      date: map['date'] ?? '',
      waterIntake: map['waterIntake'] ?? 0,
      sugarIntake: map['sugarIntake'] ?? 0,
      workoutDone: map['workoutDone'] ?? false,
      caloriesBurned: map['caloriesBurned'] ?? 0,
      workoutNotes: map['workoutNotes'] ?? '',
      notes: map['notes'] ?? '',
      sugarCutCompleted: map['sugarCutCompleted'] ?? false,
      entries: (map['entries'] as List?)?.map((e) => LogEntry.fromMap(e)).toList() ?? [],
    );
  }
  
  Map<String, dynamic> toSupabase(String userId) {
    return {
      'user_id': userId,
      'date': date,
      'water_intake': waterIntake,
      'sugar_intake': sugarIntake,
      'workout_done': workoutDone,
      'calories_burned': caloriesBurned,
      'workout_notes': workoutNotes,
      'notes': notes,
      'sugar_cut_completed': sugarCutCompleted,
      'entries': entries.map((e) => e.toMap()).toList(),
    };
  }

  factory DailyLog.fromSupabase(Map<String, dynamic> map) {
    return DailyLog(
      date: map['date'] ?? '',
      waterIntake: map['water_intake'] ?? 0,
      sugarIntake: map['sugar_intake'] ?? 0,
      workoutDone: map['workout_done'] ?? false,
      caloriesBurned: map['calories_burned'] ?? 0,
      workoutNotes: map['workout_notes'] ?? '',
      notes: map['notes'] ?? '',
      sugarCutCompleted: map['sugar_cut_completed'] ?? false,
      entries: (map['entries'] as List?)?.map((e) => LogEntry.fromMap(e)).toList() ?? [],
    );
  }

  DailyLog copyWith({
    int? waterIntake, 
    int? sugarIntake, 
    bool? workoutDone,
    int? caloriesBurned,
    String? workoutNotes,
    String? notes,
    bool? sugarCutCompleted,
    List<LogEntry>? entries,
  }) {
    return DailyLog(
      date: date,
      waterIntake: waterIntake ?? this.waterIntake,
      sugarIntake: sugarIntake ?? this.sugarIntake,
      workoutDone: workoutDone ?? this.workoutDone,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      workoutNotes: workoutNotes ?? this.workoutNotes,
      notes: notes ?? this.notes,
      sugarCutCompleted: sugarCutCompleted ?? this.sugarCutCompleted,
      entries: entries ?? this.entries,
    );
  }
}

class DailyLogRepository {
  final Box _box;
  final _supabase = Supabase.instance.client;

  RealtimeChannel? _dailyLogChannel;

  DailyLogRepository(this._box) {
    _initRealtime();
    // Re-init when auth state changes (e.g. login)
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn || data.event == AuthChangeEvent.tokenRefreshed) {
        _initRealtime();
      } else if (data.event == AuthChangeEvent.signedOut) {
        _dailyLogChannel?.unsubscribe();
        _dailyLogChannel = null;
      }
    });
  }

  void _initRealtime() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    _dailyLogChannel?.unsubscribe();
    _dailyLogChannel = _supabase
        .channel('public:daily_logs')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'daily_logs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
            if (payload.eventType == PostgresChangeEvent.delete) {
              final oldId = payload.oldRecord['date'];
              if (oldId != null) _box.delete(oldId);
            } else if (payload.newRecord != null) {
              final log = DailyLog.fromSupabase(payload.newRecord);
              _box.put(log.date, log.toMap());
            }
          },
        );
    _dailyLogChannel?.subscribe();
  }

  String _getTodayKey() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  DailyLog getTodayLog() {
    final key = _getTodayKey();
    final data = _box.get(key);
    if (data == null) {
      return DailyLog(date: key, waterIntake: 0, sugarIntake: 0);
    }
    return DailyLog.fromMap(data);
  }

  Future<void> addWater(int amount, {String description = "Water"}) async {
    final currentLog = getTodayLog();
    final newEntry = LogEntry(
      id: "w_${DateTime.now().millisecondsSinceEpoch}",
      time: DateFormat.jm().format(DateTime.now()),
      description: description,
      amount: amount,
      type: 'water',
    );
    final newLog = currentLog.copyWith(
      waterIntake: currentLog.waterIntake + amount,
      entries: [...currentLog.entries, newEntry],
    );
    
    // Check if goal was reached with this sip
    final settings = Hive.box('settings');
    final goal = settings.get('water_goal', defaultValue: 2000);
    final previouslyReached = currentLog.waterIntake >= goal;
    final nowReached = newLog.waterIntake >= goal;

    await _saveLog(newLog);
    _updateWidget(newLog);
    
    // Type 4: Goal Completed Notification (Instant)
    if (!previouslyReached && nowReached) {
      await NotificationService().showNotification(
        title: 'Goal Completed! 🥳',
        body: 'Great job! You reached your water goal today 🎉',
      );
    }

    // Update all other schedules (1, 2, 3, 5)
    await NotificationService().scheduleWaterReminders(
      currentIntake: newLog.waterIntake,
      goal: goal,
      unit: 'mL',
    );
  }

  Future<void> addSugar(int amount, {String description = "Sugar"}) async {
    final currentLog = getTodayLog();
    final newEntry = LogEntry(
      id: "s_${DateTime.now().millisecondsSinceEpoch}",
      time: DateFormat.jm().format(DateTime.now()),
      description: description,
      amount: amount,
      type: 'sugar',
    );
    final newLog = currentLog.copyWith(
      sugarIntake: currentLog.sugarIntake + amount,
      entries: [...currentLog.entries, newEntry],
    );
    await _saveLog(newLog);
    _updateWidget(newLog);
  }

  Future<void> deleteLogEntry(String date, String entryId) async {
    final data = _box.get(date);
    if (data == null) return;
    
    final log = DailyLog.fromMap(data);
    final entry = log.entries.firstWhere((e) => e.id == entryId);
    
    final updatedEntries = log.entries.where((e) => e.id != entryId).toList();
    final updatedLog = log.copyWith(
      waterIntake: entry.type == 'water' ? (log.waterIntake - entry.amount) : log.waterIntake,
      sugarIntake: entry.type == 'sugar' ? (log.sugarIntake - entry.amount) : log.sugarIntake,
      entries: updatedEntries,
    );
    
    await _saveLog(updatedLog);
    if (date == _getTodayKey()) {
      _updateWidget(updatedLog);
      final goal = Hive.box('settings').get('water_goal', defaultValue: 2000);
      await NotificationService().scheduleWaterReminders(
        currentIntake: updatedLog.waterIntake,
        goal: goal,
        unit: 'mL',
      );
    }
  }

  Future<void> editLogEntry(String date, LogEntry updatedEntry) async {
    final data = _box.get(date);
    if (data == null) return;
    
    final log = DailyLog.fromMap(data);
    final index = log.entries.indexWhere((e) => e.id == updatedEntry.id);
    if (index == -1) return;
    
    final oldEntry = log.entries[index];
    final updatedEntries = List<LogEntry>.from(log.entries);
    updatedEntries[index] = updatedEntry;
    
    final updatedLog = log.copyWith(
      waterIntake: log.waterIntake - (oldEntry.type == 'water' ? oldEntry.amount : 0) + (updatedEntry.type == 'water' ? updatedEntry.amount : 0),
      sugarIntake: log.sugarIntake - (oldEntry.type == 'sugar' ? oldEntry.amount : 0) + (updatedEntry.type == 'sugar' ? updatedEntry.amount : 0),
      entries: updatedEntries,
    );
    
    await _saveLog(updatedLog);
    if (date == _getTodayKey()) {
      _updateWidget(updatedLog);
      final goal = Hive.box('settings').get('water_goal', defaultValue: 2000);
      await NotificationService().scheduleWaterReminders(
        currentIntake: updatedLog.waterIntake,
        goal: goal,
        unit: 'mL',
      );
    }
  }

  Future<void> _saveLog(DailyLog log) async {
    // Save to Hive locally first
    await _box.put(log.date, log.toMap());
    
    // Sync to Supabase if logged in
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        await _supabase.from('daily_logs').upsert(
          log.toSupabase(user.id),
          onConflict: 'user_id, date',
        );
      } catch (e) {
        print("Supabase sync failed: $e");
        // We could flag this log for retry later
      }
    }
  }

  Future<void> syncRemote() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final response = await _supabase
          .from('daily_logs')
          .select()
          .eq('user_id', user.id);
      
      final remoteLogs = (response as List).map((row) => DailyLog.fromSupabase(row)).toList();
      final remoteDates = remoteLogs.map((l) => l.date).toSet();

      // Update local with remote
      for (var log in remoteLogs) {
        await _box.put(log.date, log.toMap());
      }

      // Delete local that is NOT in remote (Mirroring)
      final localKeys = _box.keys.whereType<String>().toList();
      for (var key in localKeys) {
        if (!remoteDates.contains(key)) {
           await _box.delete(key);
        }
      }
    } catch (e) {
      print("Supabase pull failed: $e");
    }
  }

  Future<void> updateWorkout({bool? done, int? calories, String? notes}) async {
    final currentLog = getTodayLog();
    final newLog = currentLog.copyWith(
      workoutDone: done ?? currentLog.workoutDone,
      caloriesBurned: calories ?? currentLog.caloriesBurned,
      workoutNotes: notes ?? currentLog.workoutNotes,
    );
    await _saveLog(newLog);
  }

  Future<void> updateNotes(String notes) async {
    final currentLog = getTodayLog();
    final newLog = currentLog.copyWith(notes: notes);
    await _saveLog(newLog);
  }

  Future<void> toggleSugarCut(bool value) async {
    final currentLog = getTodayLog();
    final newLog = currentLog.copyWith(sugarCutCompleted: value);
    await _saveLog(newLog);
  }
  
  // Rest of the methods updated to use _saveLog where applicable...
  
  int getSugarStreak() {
    int streak = 0;
    final now = DateTime.now();
    for (int i = 0; i < 365; i++) {
      final date = now.subtract(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(date);
      final data = _box.get(key);
      if (data == null) break;
      final log = DailyLog.fromMap(data);
      if (!log.sugarCutCompleted) break;
      streak++;
    }
    return streak;
  }

  Map<String, dynamic> getChallengeProgress(String? startDate) {
    if (startDate == null || startDate.isEmpty) {
      return {'active': false};
    }

    final start = DateFormat('yyyy-MM-dd').parse(startDate);
    final now = DateTime.now();
    final diffDays = now.difference(start).inDays;
    final dayIndex = diffDays + 1;

    int completed = 0;
    for (int i = 0; i < 7; i++) {
       final d = start.add(Duration(days: i));
       final key = DateFormat('yyyy-MM-dd').format(d);
       final data = _box.get(key);
       if (data != null) {
         final log = DailyLog.fromMap(data);
         if (log.sugarCutCompleted) completed++;
       }
    }

    return {
      'active': true,
      'dayIndex': dayIndex,
      'completed': completed,
      'total': 7,
    };
  }

  Future<void> updateWidgetWithCurrentData() async {
    final currentLog = getTodayLog();
    await _updateWidget(currentLog);
  }

  Future<void> _updateWidget(DailyLog log) async {}
  
  List<DailyLog> getLast7Days() {
    final List<DailyLog> logs = [];
    final now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(date);
      final data = _box.get(key);
      if (data != null) {
        logs.add(DailyLog.fromMap(data));
      } else {
        logs.add(DailyLog(date: key, waterIntake: 0, sugarIntake: 0));
      }
    }
    return logs;
  }

  List<DailyLog> getAllLogs() {
    final List<DailyLog> logs = [];
    for (var key in _box.keys) {
       final data = _box.get(key);
       if (data != null && data is Map) {
         logs.add(DailyLog.fromMap(data));
       }
    }
    logs.sort((a, b) => b.date.compareTo(a.date));
    return logs;
  }

  Future<void> updateLog(DailyLog log) async {
    await _saveLog(log);
    if (log.date == _getTodayKey()) {
      _updateWidget(log);
    }
  }

  Future<void> deleteLog(String date) async {
    await _box.delete(date);
    final user = _supabase.auth.currentUser;
    if (user != null) {
      await _supabase.from('daily_logs').delete().eq('user_id', user.id).eq('date', date);
    }
    if (date == _getTodayKey()) {
      _updateWidget(DailyLog(date: date, waterIntake: 0, sugarIntake: 0));
    }
  }

  Future<void> clearAllData() async {
    await _box.clear();
    final user = _supabase.auth.currentUser;
    if (user != null) {
      await _supabase.from('daily_logs').delete().eq('user_id', user.id);
    }
    _updateWidget(DailyLog(date: _getTodayKey(), waterIntake: 0, sugarIntake: 0));
  }
}

final dailyLogRepositoryProvider = Provider<DailyLogRepository>((ref) {
  final box = Hive.box('daily_logs');
  return DailyLogRepository(box);
});

final todayLogProvider = StreamProvider.autoDispose<DailyLog>((ref) async* {
  final repo = ref.watch(dailyLogRepositoryProvider);
  final box = Hive.box('daily_logs');
  
  yield repo.getTodayLog();
  
  final stream = box.watch(key: repo._getTodayKey());
  await for (final _ in stream) {
    yield repo.getTodayLog();
  }
});

final last7DaysLogsProvider = FutureProvider.autoDispose<List<DailyLog>>((ref) async {
  final repo = ref.watch(dailyLogRepositoryProvider);
  return repo.getLast7Days();
});

final allLogsProvider = StreamProvider.autoDispose<List<DailyLog>>((ref) async* {
  final repo = ref.watch(dailyLogRepositoryProvider);
  final box = Hive.box('daily_logs');
  
  yield repo.getAllLogs();
  await for (final _ in box.watch()) {
    yield repo.getAllLogs();
  }
});

final dailyLogByDateProvider = StreamProvider.autoDispose.family<DailyLog, String>((ref, date) async* {
  final repo = ref.watch(dailyLogRepositoryProvider);
  final box = Hive.box('daily_logs');
  
  final getLog = () {
    final data = box.get(date);
    if (data == null) return DailyLog(date: date, waterIntake: 0, sugarIntake: 0);
    return DailyLog.fromMap(data);
  };

  yield getLog();
  
  await for (final event in box.watch(key: date)) {
    yield getLog();
  }
});

