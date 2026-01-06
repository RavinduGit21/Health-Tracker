import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_tracker/src/constants/app_colors.dart';
import 'package:health_tracker/src/features/goals/goals_repository.dart';
import 'package:health_tracker/src/features/dashboard/dashboard_repository.dart';
import 'package:health_tracker/src/features/weight/weight_repository.dart';
import 'package:health_tracker/src/utils/notification_service.dart';
import 'package:intl/intl.dart';

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  late TextEditingController _waterController;
  late TextEditingController _sugarController;
  late TextEditingController _weightController;
  late TextEditingController _sleepGoalController;
  late String _usualBedtime;
  
  @override
  void initState() {
    super.initState();
    // Initialize with current values
    final currentGoals = ref.read(goalsProvider);
    _waterController = TextEditingController(text: currentGoals.waterGoal.toString());
    _sugarController = TextEditingController(text: currentGoals.sugarLimit.toString());
    _weightController = TextEditingController(text: currentGoals.targetWeight.toString());
    _sleepGoalController = TextEditingController(text: currentGoals.sleepGoal.toString());
    _usualBedtime = currentGoals.usualBedtime;
  }

  @override
  Widget build(BuildContext context) {
    final goalsState = ref.watch(goalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Set Goals")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildGoalInput(
              context, 
              "Daily Water Goal (mL)", 
              _waterController, 
              Icons.water_drop, 
              AppColors.primary
            ),
            const SizedBox(height: 16),
            _buildGoalInput(
              context, 
              "Daily Sugar Limit (g)", 
              _sugarController, 
              Icons.cookie, 
              AppColors.secondary
            ),
            const SizedBox(height: 16),
            _buildGoalInput(
              context, 
              "Target Weight (${goalsState.weightUnit})", 
              _weightController, 
              Icons.monitor_weight, 
              Colors.orange
            ),
            const SizedBox(height: 16),
            _buildGoalInput(
              context, 
              "Sleep Goal (Hours)", 
              _sleepGoalController, 
              Icons.bedtime, 
              Colors.indigoAccent
            ),
            const SizedBox(height: 16),
            _buildTimePickerTile("Usual Bedtime", _usualBedtime),
            const SizedBox(height: 24),
            Text("Sugar Tracking Mode", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: const Text("Added Sugar Only"),
                    subtitle: const Text("Recommended: 38g limit"),
                    value: 'added', 
                    groupValue: goalsState.sugarTrackingMode, 
                    onChanged: (val) {
                      if (val != null) ref.read(goalsProvider.notifier).setSugarTrackingMode(val);
                    },
                    activeColor: AppColors.secondary,
                  ),
                  RadioListTile<String>(
                    title: const Text("Total Sugar"),
                    subtitle: const Text("Includes fruit & milk"),
                    value: 'total', 
                    groupValue: goalsState.sugarTrackingMode, 
                    onChanged: (val) {
                      if (val != null) ref.read(goalsProvider.notifier).setSugarTrackingMode(val);
                    },
                    activeColor: AppColors.secondary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              title: const Text("Daily Reminders"),
              subtitle: const Text("Receive notifications to log intake"),
              value: goalsState.remindersEnabled,
              onChanged: (val) {
                 ref.read(goalsProvider.notifier).setRemindersEnabled(val);
                 if (val) {
                   NotificationService().showNotification(title: "Reminders Enabled", body: "We will remind you to drink water!");
                   // Trigger schedule via goal update or direct call if needed, 
                   // but usually goal update handles it. 
                   // Let's force a refresh using current goal
                   final repo = ref.read(dailyLogRepositoryProvider); 
                   NotificationService().scheduleWaterReminders(
                      currentIntake: repo.getTodayLog().waterIntake,
                      goal: goalsState.waterGoal,
                      unit: 'mL'
                   );
                 } else {
                   NotificationService().cancelAll();
                 }
              },
            ),
            const SizedBox(height: 24),
            _buildChallengePicker(context, goalsState, ref),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () {
                NotificationService().showScheduledNotification(
                  title: "Hydration Check!", 
                  body: "Time to drink water and check your sugar intake.", 
                  seconds: 5
                );
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Notification coming in 5 seconds...")));
              }, 
              icon: const Icon(Icons.notifications_active), 
              label: const Text("Test Reminder (5s Delay)")
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveGoals,
                child: const Text("SAVE GOALS"),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showResetConfirmation,
                icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                label: const Text("RESET ALL DATA", style: TextStyle(color: Colors.redAccent)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reset All Data?"),
        content: const Text("This will permanently delete all your water, sugar, and weight logs from this device and the cloud. This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          TextButton(
            onPressed: () async {
              await ref.read(dailyLogRepositoryProvider).clearAllData();
              await ref.read(weightRepositoryProvider).clearAllData();
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All data has been reset.")));
              }
            }, 
            child: const Text("RESET", style: TextStyle(color: Colors.redAccent))
          ),
        ],
      ),
    );
  }

  Widget _buildTimePickerTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.access_time, color: Colors.indigoAccent),
              ),
              const SizedBox(width: 16),
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          TextButton(
            onPressed: () async {
              final parts = value.split(':');
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
              );
              if (time != null) {
                setState(() => _usualBedtime = "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}");
              }
            },
            child: Text(_usualBedtime, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigoAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengePicker(BuildContext context, GoalsState state, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Sugar Cut Challenge", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text("7-day challenge to avoid added sugar.", style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                    const Text("Start Date", style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    Text(state.challengeStartDate ?? "Not started", style: const TextStyle(fontWeight: FontWeight.bold)),
                 ],
               ),
               ElevatedButton(
                 onPressed: () async {
                   final d = await showDatePicker(
                     context: context, 
                     initialDate: DateTime.now(), 
                     firstDate: DateTime(2020), 
                     lastDate: DateTime(2030)
                   );
                   if (d != null) {
                      ref.read(goalsProvider.notifier).setChallengeStartDate(DateFormat('yyyy-MM-dd').format(d));
                   }
                 }, 
                 child: Text(state.challengeStartDate == null ? "START" : "CHANGE"),
               ),
            ],
          ),
          if (state.challengeStartDate != null) 
            TextButton(
              onPressed: () => ref.read(goalsProvider.notifier).setChallengeStartDate(null), 
              child: const Text("Reset Challenge", style: TextStyle(color: Colors.redAccent, fontSize: 12))
            ),
        ],
      ),
    );
  }

  void _saveGoals() async {
    final water = int.tryParse(_waterController.text) ?? 2000;
    final sugar = int.tryParse(_sugarController.text) ?? 38;
    final weight = double.tryParse(_weightController.text) ?? 70.0;
    final sleepGoal = int.tryParse(_sleepGoalController.text) ?? 8;

    final notifier = ref.read(goalsProvider.notifier);
    await notifier.updateWaterGoal(water);
    await notifier.updateSugarLimit(sugar);
    await notifier.updateTargetWeight(weight);
    await notifier.updateSleepGoal(sleepGoal);
    await notifier.updateUsualBedtime(_usualBedtime);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Goals saved!")));
      Navigator.pop(context);
    }
  }

  Widget _buildGoalInput(BuildContext context, String label, TextEditingController controller, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
