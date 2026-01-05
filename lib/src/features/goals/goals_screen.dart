import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_tracker/src/constants/app_colors.dart';
import 'package:health_tracker/src/features/goals/goals_repository.dart';
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
  
  @override
  void initState() {
    super.initState();
    // Initialize with current values
    final currentGoals = ref.read(goalsProvider);
    _waterController = TextEditingController(text: currentGoals.waterGoal.toString());
    _sugarController = TextEditingController(text: currentGoals.sugarLimit.toString());
    _weightController = TextEditingController(text: currentGoals.targetWeight.toString());
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
                   NotificationService().scheduleReminders();
                 } else {
                   NotificationService().cancelReminders();
                 }
              },
            ),
            if (goalsState.remindersEnabled) ...[
              const SizedBox(height: 16),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Start Time"),
                        DropdownButton<int>(
                          value: goalsState.reminderStartHour,
                          items: List.generate(24, (i) => DropdownMenuItem(value: i, child: Text("${i.toString().padLeft(2, '0')}:00"))),
                          onChanged: (val) {
                            if (val != null) {
                              ref.read(goalsProvider.notifier).updateReminderSettings(val, goalsState.reminderEndHour, goalsState.reminderInterval);
                              NotificationService().scheduleReminders();
                            }
                          },
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("End Time"),
                        DropdownButton<int>(
                          value: goalsState.reminderEndHour,
                          items: List.generate(24, (i) => DropdownMenuItem(value: i, child: Text("${i.toString().padLeft(2, '0')}:00"))),
                          onChanged: (val) {
                            if (val != null) {
                               ref.read(goalsProvider.notifier).updateReminderSettings(goalsState.reminderStartHour, val, goalsState.reminderInterval);
                               NotificationService().scheduleReminders();
                            }
                          },
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Interval"),
                        DropdownButton<int>(
                          value: goalsState.reminderInterval,
                          items: [1, 2, 3, 4, 6].map((i) => DropdownMenuItem(value: i, child: Text("Every $i hours"))).toList(),
                          onChanged: (val) {
                             if (val != null) {
                               ref.read(goalsProvider.notifier).updateReminderSettings(goalsState.reminderStartHour, goalsState.reminderEndHour, val);
                               NotificationService().scheduleReminders();
                             }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
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
          ],
        ),
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

    final notifier = ref.read(goalsProvider.notifier);
    await notifier.updateWaterGoal(water);
    await notifier.updateSugarLimit(sugar);
    await notifier.updateTargetWeight(weight);

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
