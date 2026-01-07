import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_tracker/src/features/sleep/sleep_repository.dart';
import 'package:health_tracker/src/features/goals/goals_repository.dart';
import 'package:health_tracker/src/utils/notification_service.dart';
import 'package:health_tracker/src/utils/widget_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

class SleepScreen extends ConsumerStatefulWidget {
  const SleepScreen({super.key});

  @override
  ConsumerState<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends ConsumerState<SleepScreen> {
  Timer? _ticker;
  DateTime _now = DateTime.now();
  ProviderSubscription<SleepLog?>? _activeSessionSub;

  static const String _bedEnabledKey = 'sleep_bed_alarm_enabled';
  static const String _bedTimeKey = 'sleep_bed_alarm_time';
  static const String _wakeEnabledKey = 'sleep_wake_alarm_enabled';
  static const String _wakeTimeKey = 'sleep_wake_alarm_time';

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(sleepRepositoryProvider).syncRemote());
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
      });
    });

    _activeSessionSub = ref.listenManual<SleepLog?>(activeSleepSessionProvider, (prev, next) async {
      await WidgetService.updateSleepWidget(
        isSleeping: next != null,
        startTime: next?.startTime,
      );
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _activeSessionSub?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeSession = ref.watch(activeSleepSessionProvider);
    final logs = ref.watch(sleepLogsProvider).value ?? [];
    final goals = ref.watch(goalsProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0F172A),
              const Color(0xFF1E1B4B),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                title: const Text('Sleep Tracking', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                centerTitle: true,
                floating: true,
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      _buildActiveSessionCard(activeSession, goals),
                      const SizedBox(height: 20),
                      _buildAlarmSection(),
                      const SizedBox(height: 30),
                      _buildHistorySection(logs),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveSessionCard(SleepLog? session, GoalsState goals) {
    final bool isSleeping = session != null;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            isSleeping ? Icons.nightlight_round : Icons.wb_sunny_rounded,
            size: 64,
            color: isSleeping ? Colors.indigoAccent : Colors.orangeAccent,
          ),
          const SizedBox(height: 16),
          Text(
            isSleeping ? "You're currently sleeping" : "You're awake",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          if (isSleeping)
            Text(
              "Started at ${DateFormat.jm().format(session.startTime)}",
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            )
          else
            Text(
              "Daily Goal: ${goals.sleepGoal} hours",
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
          if (isSleeping) ...[
            const SizedBox(height: 8),
            Text(
              _formatDuration(_now.difference(session.startTime)),
              style: const TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold, fontSize: 22),
            ),
          ],
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => isSleeping ? _showWakeUpDialog(session) : _refStartSleep(),
            style: ElevatedButton.styleFrom(
              backgroundColor: isSleeping ? Colors.indigo : Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: Text(
              isSleeping ? "WAKE UP" : "START SLEEP",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          if (!isSleeping)
            TextButton(
              onPressed: () => _showWakeUpDialog(null),
              child: Text(
                "Forgot to start? Log sleep manually",
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
            ),
        ],
      ),
    );
  }

  void _refStartSleep() async {
    final repo = ref.read(sleepRepositoryProvider);
    await repo.startSleep();
    final active = repo.getActiveSession();
    await WidgetService.updateSleepWidget(
      isSleeping: active != null,
      startTime: active?.startTime,
    );
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) {
      d = Duration.zero;
    }
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _showWakeUpDialog(SleepLog? session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _WakeUpSheet(session: session),
    );
  }

  Widget _buildAlarmSection() {
    final settings = Hive.box('settings');
    return ValueListenableBuilder(
      valueListenable: settings.listenable(keys: [_bedEnabledKey, _bedTimeKey, _wakeEnabledKey, _wakeTimeKey]),
      builder: (context, Box box, _) {
        final bedEnabled = (box.get(_bedEnabledKey, defaultValue: false) as bool?) ?? false;
        final wakeEnabled = (box.get(_wakeEnabledKey, defaultValue: false) as bool?) ?? false;
        final bedTime = _parseTimeOfDay(box.get(_bedTimeKey)) ?? const TimeOfDay(hour: 22, minute: 0);
        final wakeTime = _parseTimeOfDay(box.get(_wakeTimeKey)) ?? const TimeOfDay(hour: 6, minute: 0);

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Alarms',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildAlarmRow(
                title: 'Bedtime alarm',
                enabled: bedEnabled,
                time: bedTime,
                onToggle: (v) async {
                  await settings.put(_bedEnabledKey, v);
                  if (v) {
                    await NotificationService().scheduleBedtimeAlarm(hour: bedTime.hour, minute: bedTime.minute);
                    _showNextAlarmInfo('Bedtime alarm', bedTime);
                  } else {
                    await NotificationService().cancelBedtimeAlarm();
                  }
                },
                onPickTime: () async {
                  final picked = await showTimePicker(context: context, initialTime: bedTime);
                  if (picked == null) return;
                  await settings.put(_bedTimeKey, _formatTimeKey(picked));
                  if (bedEnabled) {
                    await NotificationService().scheduleBedtimeAlarm(hour: picked.hour, minute: picked.minute);
                    _showNextAlarmInfo('Bedtime alarm', picked);
                  }
                },
              ),
              const SizedBox(height: 8),
              _buildAlarmRow(
                title: 'Wake-up alarm',
                enabled: wakeEnabled,
                time: wakeTime,
                onToggle: (v) async {
                  await settings.put(_wakeEnabledKey, v);
                  if (v) {
                    await NotificationService().scheduleWakeAlarm(hour: wakeTime.hour, minute: wakeTime.minute);
                    _showNextAlarmInfo('Wake-up alarm', wakeTime);
                  } else {
                    await NotificationService().cancelWakeAlarm();
                  }
                },
                onPickTime: () async {
                  final picked = await showTimePicker(context: context, initialTime: wakeTime);
                  if (picked == null) return;
                  await settings.put(_wakeTimeKey, _formatTimeKey(picked));
                  if (wakeEnabled) {
                    await NotificationService().scheduleWakeAlarm(hour: picked.hour, minute: picked.minute);
                    _showNextAlarmInfo('Wake-up alarm', picked);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showNextAlarmInfo(String label, TimeOfDay time) {
    if (!mounted) return;
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    final when = DateFormat('EEE, MMM d • h:mm a').format(next);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label scheduled for $when')),
    );
  }

  Widget _buildAlarmRow({
    required String title,
    required bool enabled,
    required TimeOfDay time,
    required ValueChanged<bool> onToggle,
    required VoidCallback onPickTime,
  }) {
    final formatted = MaterialLocalizations.of(context).formatTimeOfDay(time);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                InkWell(
                  onTap: onPickTime,
                  child: Text(
                    formatted,
                    style: TextStyle(color: Colors.white.withOpacity(0.6)),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: onToggle,
            activeColor: Colors.indigoAccent,
          ),
        ],
      ),
    );
  }

  TimeOfDay? _parseTimeOfDay(dynamic raw) {
    if (raw is! String || raw.isEmpty) return null;
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _formatTimeKey(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildHistorySection(List<SleepLog> logs) {
    final finishedLogs = logs.where((e) => e.endTime != null).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Sleep Journey",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 16),
        if (finishedLogs.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Text("No sleep logs yet.", style: TextStyle(color: Colors.white.withOpacity(0.4))),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: finishedLogs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _buildSleepItem(finishedLogs[index]),
          ),
      ],
    );
  }

  Widget _buildSleepItem(SleepLog log) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.bedtime_outlined, color: Colors.blueAccent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEE, MMM d').format(log.startTime),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  "${DateFormat.jm().format(log.startTime)} - ${DateFormat.jm().format(log.endTime!)}",
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${log.durationHours.toStringAsFixed(1)}h",
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
              ),
              if (log.moodAfterWake != null)
                Text(
                  log.moodAfterWake!,
                  style: const TextStyle(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.bold),
                ),
            ],
          ),
          const SizedBox(width: 10),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.white.withOpacity(0.2), size: 20),
            onPressed: () => _confirmDelete(log.id),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete log?"),
        content: const Text("This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          TextButton(
            onPressed: () {
              ref.read(sleepRepositoryProvider).deleteLog(id);
              Navigator.pop(context);
            },
            child: const Text("DELETE", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _WakeUpSheet extends ConsumerStatefulWidget {
  final SleepLog? session;
  const _WakeUpSheet({this.session});

  @override
  ConsumerState<_WakeUpSheet> createState() => _WakeUpSheetState();
}

class _WakeUpSheetState extends ConsumerState<_WakeUpSheet> {
  int _quality = 3;
  String? _mood;
  final TextEditingController _notesController = TextEditingController();
  late DateTime _wakeTime;
  DateTime? _manualStart;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _wakeTime = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final goals = ref.watch(goalsProvider);

    return Container(
      padding: const EdgeInsets.all(24).copyWith(bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1B4B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.session == null ? "Log Sleep" : "Good Morning!",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              "How was your sleep?",
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
            const SizedBox(height: 32),
            if (widget.session == null) ...[
              _buildTimeSelector(
                label: "I went to bed at:",
                value: _manualStart ?? _suggestedStart(goals.usualBedtime),
                onTap: () => _pickTime(true),
              ),
              const SizedBox(height: 16),
            ],
            _buildTimeSelector(
              label: "I woke up at:",
              value: _wakeTime,
              onTap: () => _pickTime(false),
            ),
            const SizedBox(height: 32),
            const Text("Mood after waking:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildMoodSelector(),
            const SizedBox(height: 32),
            const Text("Sleep Quality:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Slider(
              value: _quality.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              activeColor: Colors.indigoAccent,
              onChanged: (v) => setState(() => _quality = v.toInt()),
            ),
            Center(
              child: Text(
                ["Poor", "Fair", "Good", "Great", "Excellent"][_quality - 1],
                style: const TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _notesController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Anything on your mind? (Dreams, thoughts...)",
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                fillColor: Colors.white.withOpacity(0.05),
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigoAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text("CONTINUE", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  DateTime _suggestedStart(String usualBedtime) {
    try {
      final parts = usualBedtime.split(':');
      final now = DateTime.now();
      var start = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
      if (start.isAfter(now)) {
        start = start.subtract(const Duration(days: 1));
      }
      return start;
    } catch (_) {
      return DateTime.now().subtract(const Duration(hours: 8));
    }
  }

  Widget _buildTimeSelector({required String label, required DateTime value, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7))),
            Text(
              DateFormat.jm().format(value),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodSelector() {
    final moods = {
      'Tired': Icons.sentiment_very_dissatisfied,
      'Anxious': Icons.energy_savings_leaf_outlined,
      'Neutral': Icons.sentiment_neutral,
      'Rested': Icons.sentiment_satisfied_alt,
      'Energized': Icons.sentiment_very_satisfied,
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: moods.entries.map((e) {
        final isSelected = _mood == e.key;
        return InkWell(
          onTap: () => setState(() => _mood = e.key),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.indigoAccent : Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(e.value, color: isSelected ? Colors.white : Colors.white.withOpacity(0.5)),
              ),
              const SizedBox(height: 4),
              Text(
                e.key,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? Colors.indigoAccent : Colors.white.withOpacity(0.3),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _pickTime(bool isStart) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(isStart ? (_manualStart ?? _suggestedStart(ref.read(goalsProvider).usualBedtime)) : _wakeTime),
    );
    if (time != null) {
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
      setState(() {
        if (dt.isAfter(now) && isStart) {
          // If picking a start time that's "later" than now, assume it was yesterday
          if (isStart) _manualStart = dt.subtract(const Duration(days: 1));
        } else {
          if (isStart) _manualStart = dt; else _wakeTime = dt;
        }
      });
    }
  }

  void _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(sleepRepositoryProvider);
      await repo.endSleep(
        qualityScore: _quality,
        mood: _mood,
        notes: _notesController.text,
        endTime: _wakeTime,
        manualStartTime: _manualStart,
      );
      final active = repo.getActiveSession();
      await WidgetService.updateSleepWidget(
        isSleeping: active != null,
        startTime: active?.startTime,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save sleep log: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
