import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:health_tracker/src/features/goals/goals_repository.dart';
import 'package:health_tracker/src/utils/widget_service.dart';

class SleepLog {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final int qualityScore; // 1-5
  final String? moodAfterWake; // happy, neutral, tired, anxious
  final String? notes;

  SleepLog({
    required this.id,
    required this.startTime,
    this.endTime,
    this.qualityScore = 0,
    this.moodAfterWake,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'start_time': startTime.toIso8601String(),
    'end_time': endTime?.toIso8601String(),
    'quality_score': qualityScore,
    'mood_after_wake': moodAfterWake,
    'notes': notes,
  };

  factory SleepLog.fromMap(Map<dynamic, dynamic> map) => SleepLog(
    id: map['id'] ?? '',
    startTime: DateTime.parse(map['start_time']),
    endTime: map['end_time'] != null ? DateTime.parse(map['end_time']) : null,
    qualityScore: map['quality_score'] ?? 0,
    moodAfterWake: map['mood_after_wake'],
    notes: map['notes'],
  );

  Map<String, dynamic> toSupabase(String userId) => {
    'id': id,
    'user_id': userId,
    'start_time': startTime.toIso8601String(),
    'end_time': endTime?.toIso8601String(),
    'quality_score': qualityScore,
    'mood_after_wake': moodAfterWake,
    'notes': notes,
  };

  factory SleepLog.fromSupabase(Map<String, dynamic> map) => SleepLog(
    id: map['id'] ?? '',
    startTime: DateTime.parse(map['start_time']),
    endTime: map['end_time'] != null ? DateTime.parse(map['end_time']) : null,
    qualityScore: map['quality_score'] ?? 0,
    moodAfterWake: map['mood_after_wake'],
    notes: map['notes'],
  );

  double get durationHours {
    if (endTime == null) return 0;
    return endTime!.difference(startTime).inMinutes / 60.0;
  }
}

class SleepRepository {
  final Box _box;
  final _supabase = Supabase.instance.client;
  RealtimeChannel? _sleepChannel;
  StreamSubscription? _boxSubscription;
  SleepLog? _lastWidgetActive;

  static const Duration _maxUnfinishedSessionAge = Duration(hours: 20);
  static const Duration _maxFutureSkew = Duration(minutes: 2);

  SleepRepository(this._box) {
    _initRealtime();
    _initWidgetSync();
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn || data.event == AuthChangeEvent.tokenRefreshed) {
        _initRealtime();
      } else if (data.event == AuthChangeEvent.signedOut) {
        _sleepChannel?.unsubscribe();
        _sleepChannel = null;
      }
    });
  }

  void _initWidgetSync() {
    _boxSubscription?.cancel();
    _lastWidgetActive = getActiveSession();
    _boxSubscription = _box.watch().listen((_) async {
      final active = getActiveSession();
      final didChange = (_lastWidgetActive?.id != active?.id) ||
          (_lastWidgetActive?.startTime != active?.startTime) ||
          (_lastWidgetActive?.endTime != active?.endTime);
      if (!didChange) return;
      _lastWidgetActive = active;
      await WidgetService.updateSleepWidget(
        isSleeping: active != null,
        startTime: active?.startTime,
      );
    });
  }

  void _initRealtime() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    _sleepChannel?.unsubscribe();
    _sleepChannel = _supabase
        .channel('public:sleep_logs')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'sleep_logs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
            if (payload.eventType == PostgresChangeEvent.delete) {
              final oldId = payload.oldRecord['id'];
              if (oldId != null) _box.delete(oldId);
            } else if (payload.newRecord != null) {
              final log = SleepLog.fromSupabase(payload.newRecord);
              _box.put(log.id, log.toMap());
            }
          },
        )
        .subscribe();
  }

  Future<void> syncRemote() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final response = await _supabase.from('sleep_logs').select().eq('user_id', user.id);
      final remoteLogs = (response as List).map((row) => SleepLog.fromSupabase(row)).toList();
      
      final remoteIds = remoteLogs.map((e) => e.id).toSet();
      for (var log in remoteLogs) {
        await _box.put(log.id, log.toMap());
      }

      final localKeys = _box.keys.whereType<String>().toList();
      for (var key in localKeys) {
        if (!remoteIds.contains(key)) {
          await _box.delete(key);
        }
      }

      await _sanitizeStaleSessions();
      final active = getActiveSession();
      await WidgetService.updateSleepWidget(
        isSleeping: active != null,
        startTime: active?.startTime,
      );
    } catch (e) {
      print("Sleep sync failed: $e");
    }
  }

  List<SleepLog> getAllLogs() {
    final logs = _box.values.map((e) => SleepLog.fromMap(e)).toList();
    logs.sort((a, b) => b.startTime.compareTo(a.startTime));
    return logs;
  }

  SleepLog? getActiveSession() {
    try {
      final now = DateTime.now();
      return getAllLogs().firstWhere((e) {
        if (e.endTime != null) return false;
        if (e.startTime.isAfter(now.add(_maxFutureSkew))) return false;
        if (now.difference(e.startTime) > _maxUnfinishedSessionAge) return false;
        return true;
      });
    } catch (_) {
      return null;
    }
  }

  Future<void> _sanitizeStaleSessions() async {
    final now = DateTime.now();
    final all = getAllLogs();
    final stale = all.where((e) {
      if (e.endTime != null) return false;
      if (e.startTime.isAfter(now.add(_maxFutureSkew))) return true;
      return now.difference(e.startTime) > _maxUnfinishedSessionAge;
    }).toList();

    for (final s in stale) {
      final finished = SleepLog(
        id: s.id,
        startTime: s.startTime,
        endTime: now,
        qualityScore: 0,
        moodAfterWake: s.moodAfterWake,
        notes: s.notes,
      );
      await _saveLog(finished);
    }
  }

  Future<void> startSleep() async {
    final existing = getActiveSession();
    if (existing != null) return;

    final log = SleepLog(
      id: "sleep_${DateTime.now().millisecondsSinceEpoch}",
      startTime: DateTime.now(),
    );
    await _saveLog(log);
    await WidgetService.updateSleepWidget(isSleeping: true, startTime: log.startTime);
  }

  Future<void> endSleep({
    int qualityScore = 3,
    String? mood,
    String? notes,
    DateTime? endTime,
    DateTime? manualStartTime,
  }) async {
    SleepLog? session = getActiveSession();
    final now = endTime ?? DateTime.now();

    if (session == null) {
      // Smart Logic: User forgot to start. Use manualStartTime or suggest based on usual Bedtime.
      final start = manualStartTime ?? _suggestStartTime(now);
      session = SleepLog(
        id: "sleep_${DateTime.now().millisecondsSinceEpoch}",
        startTime: start,
      );
    }

    final finishedLog = SleepLog(
      id: session.id,
      startTime: session.startTime,
      endTime: now,
      qualityScore: qualityScore,
      moodAfterWake: mood,
      notes: notes,
    );

    await _saveLog(finishedLog);
    await WidgetService.updateSleepWidget(isSleeping: false);
  }

  DateTime _suggestStartTime(DateTime wakeTime) {
    // Basic smart suggestion: 8 hours ago
    return wakeTime.subtract(const Duration(hours: 8));
  }

  Future<void> _saveLog(SleepLog log) async {
    await _box.put(log.id, log.toMap());
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        await _supabase.from('sleep_logs').upsert(log.toSupabase(user.id));
      } catch (e) {
        // Keep local save as source of truth when offline.
        print("Sleep sync failed: $e");
      }
    }
  }

  Future<void> deleteLog(String id) async {
    await _box.delete(id);
    final user = _supabase.auth.currentUser;
    if (user != null) {
      await _supabase.from('sleep_logs').delete().eq('user_id', user.id).eq('id', id);
    }
  }
}

final sleepRepositoryProvider = Provider<SleepRepository>((ref) {
  final box = Hive.box('sleep_logs');
  return SleepRepository(box);
});

final sleepLogsProvider = StreamProvider.autoDispose<List<SleepLog>>((ref) {
  final repo = ref.watch(sleepRepositoryProvider);
  final box = Hive.box('sleep_logs');

  final controller = StreamController<List<SleepLog>>();

  void emit() {
    if (controller.isClosed) return;
    controller.add(repo.getAllLogs());
  }

  emit();

  final boxSub = box.watch().listen((_) => emit());
  // Fallback: widget background runs in a different isolate/engine;
  // box.watch() may not fire across isolates on some devices.
  final pollSub = Stream.periodic(const Duration(seconds: 2)).listen((_) => emit());

  ref.onDispose(() {
    boxSub.cancel();
    pollSub.cancel();
    controller.close();
  });

  return controller.stream;
});

final activeSleepSessionProvider = Provider.autoDispose<SleepLog?>((ref) {
  final logs = ref.watch(sleepLogsProvider).value ?? [];
  try {
    return logs.firstWhere((e) => e.endTime == null);
  } catch (_) {
    return null;
  }
});
