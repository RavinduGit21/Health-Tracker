import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:health_tracker/src/constants/app_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:health_tracker/src/features/dashboard/dashboard_repository.dart';
import 'package:health_tracker/src/features/goals/goals_repository.dart';
import 'package:health_tracker/src/features/history/daily_detail_screen.dart';
import 'package:health_tracker/src/features/nutrition/food_search_sheet.dart';
import 'package:health_tracker/src/features/weight/weight_repository.dart';
import 'package:health_tracker/src/features/weight/weight_screen.dart';

import 'package:health_tracker/src/features/authentication/auth_repository.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyLogAsync = ref.watch(todayLogProvider);
    final goalsState = ref.watch(goalsProvider);
    final latestWeight = ref.watch(latestWeightProvider);
    final authRepo = ref.watch(authRepositoryProvider);
    final user = authRepo.currentUser;
    final isAdmin = authRepo.isAdmin(user?.email);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text("Today's Health"),
            if (isAdmin) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text("ADMIN", style: TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () {
              ref.read(dailyLogRepositoryProvider).syncRemote();
              ref.read(weightRepositoryProvider).syncRemote();
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Syncing with cloud...")));
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/goals'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: dailyLogAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (dailyLog) {
          final waterProgress = (dailyLog.waterIntake / goalsState.waterGoal).clamp(0.0, 1.0);
          final sugarProgress = (dailyLog.sugarIntake / goalsState.sugarLimit).clamp(0.0, 1.0);

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildActivityCard(context, dailyLog, goalsState, ref),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildCompactStatCard(context, "Water", "${dailyLog.waterIntake} mL", waterProgress, Icons.water_drop, AppColors.primary)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildCompactStatCard(context, "Sugar", "${dailyLog.sugarIntake} g", sugarProgress, Icons.cookie, AppColors.secondary)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildWeightCard(context, latestWeight, goalsState),
                    const SizedBox(height: 24),
                    Text("Today's Timeline", style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                  ]),
                ),
              ),
              if (dailyLog.entries.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text("No entries yet today", style: TextStyle(color: AppColors.textSecondary))),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final entry = dailyLog.entries.reversed.toList()[index];
                        return _buildTimelineEntry(context, entry, dailyLog.date, ref);
                      },
                      childCount: dailyLog.entries.length,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          );
        }
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
            showModalBottomSheet(context: context, builder: (_) => const AddEntrySheet());
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Log", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildCompactStatCard(BuildContext context, String label, String value, double progress, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderOverlay),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withOpacity(0.05),
            color: color,
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineEntry(BuildContext context, LogEntry entry, String date, WidgetRef ref) {
    final isWater = entry.type == 'water';
    final repo = ref.read(dailyLogRepositoryProvider);

    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.redAccent,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        repo.deleteLogEntry(date, entry.id);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${entry.description} deleted")));
      },
      child: InkWell(
        onTap: () => _showEditEntryDialog(context, ref, date, entry),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isWater ? AppColors.primary : AppColors.secondary).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isWater ? Icons.water_drop : Icons.cookie,
                  color: isWater ? AppColors.primary : AppColors.secondary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.description, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(entry.time, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Text(
                "${entry.amount > 0 ? '+' : ''}${entry.amount} ${isWater ? 'mL' : 'g'}",
                style: TextStyle(
                  color: isWater ? AppColors.primary : AppColors.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditEntryDialog(BuildContext context, WidgetRef ref, String date, LogEntry entry) {
    final amountController = TextEditingController(text: entry.amount.toString());
    final descController = TextEditingController(text: entry.description);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Edit ${entry.type == 'water' ? 'Water' : 'Sugar'} Entry"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: "Description"),
            ),
            TextField(
              controller: amountController,
              decoration: InputDecoration(labelText: "Amount (${entry.type == 'water' ? 'mL' : 'g'})"),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () {
              final amount = int.tryParse(amountController.text);
              if (amount != null) {
                final updated = LogEntry(
                  id: entry.id,
                  time: entry.time,
                  description: descController.text,
                  amount: amount,
                  type: entry.type,
                );
                ref.read(dailyLogRepositoryProvider).editLogEntry(date, updated);
                Navigator.pop(context);
              }
            }, 
            child: const Text("SAVE")
          ),
        ],
      ),
    );
  }


  Widget _buildActivityCard(BuildContext context, DailyLog log, GoalsState goals, WidgetRef ref) {
    final repo = ref.read(dailyLogRepositoryProvider);
    final streak = repo.getSugarStreak();
    final challenge = repo.getChallengeProgress(goals.challengeStartDate);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               Text("Activity Checks", style: Theme.of(context).textTheme.titleMedium),
               if (challenge['active'] == true) 
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                   decoration: BoxDecoration(color: Colors.purple.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                   child: Text("Day ${challenge['dayIndex']}/7", style: const TextStyle(fontSize: 10, color: Colors.purpleAccent)),
                 ),
             ],
           ),
           const SizedBox(height: 16),
           Row(
             children: [
               Expanded(
                 child: _buildCheckItem(
                   context, 
                   "Sugar Cut", 
                   log.sugarCutCompleted, 
                   Icons.block, 
                   Colors.pinkAccent,
                   (val) => repo.toggleSugarCut(val ?? false)
                 ),
               ),
               const SizedBox(width: 12),
               Expanded(
                 child: _buildCheckItem(
                   context, 
                   "Workout", 
                   log.workoutDone, 
                   Icons.fitness_center, 
                   Colors.greenAccent,
                   (val) => _showWorkoutDialog(context, ref, log)
                 ),
               ),
             ],
           ),
           const Divider(height: 32, color: Colors.white10),
           Row(
             mainAxisAlignment: MainAxisAlignment.spaceAround,
             children: [
                _buildStatMini("Streak", "$streak days", Icons.local_fire_department, Colors.orange),
                _buildStatMini("Challenge", "${challenge['completed'] ?? 0}/${challenge['total'] ?? 7}", Icons.emoji_events, Colors.yellow),
             ],
           )
        ],
      ),
    );
  }

  Widget _buildCheckItem(BuildContext context, String label, bool checked, IconData icon, Color color, Function(bool?)? onChanged) {
    return InkWell(
      onTap: () => onChanged?.call(!checked),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: checked ? color.withOpacity(0.1) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: checked ? color.withOpacity(0.5) : Colors.transparent),
        ),
        child: Column(
          children: [
            Icon(icon, color: checked ? color : Colors.white24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: checked ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatMini(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        )
      ],
    );
  }

  void _showWorkoutDialog(BuildContext context, WidgetRef ref, DailyLog log) {
    final calorieController = TextEditingController(text: log.caloriesBurned.toString());
    final notesController = TextEditingController(text: log.workoutNotes);
    bool done = log.workoutDone;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Log Workout"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  title: const Text("Workout Completed"),
                  value: done, 
                  onChanged: (val) => setState(() => done = val ?? false)
                ),
                TextField(
                  controller: calorieController,
                  decoration: const InputDecoration(labelText: "Calories Burned"),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: "Workout Notes"),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
            ElevatedButton(
              onPressed: () {
                ref.read(dailyLogRepositoryProvider).updateWorkout(
                  done: done,
                  calories: int.tryParse(calorieController.text) ?? 0,
                  notes: notesController.text,
                );
                Navigator.pop(context);
              }, 
              child: const Text("SAVE")
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightCard(BuildContext context, WeightEntry? latest, GoalsState goals) {
    return InkWell(
      onTap: () => context.push('/weight'),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.monitor_weight, color: Colors.orange),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text("Body Weight", style: Theme.of(context).textTheme.titleMedium),
                   Text(
                     latest != null ? "${latest.weight} ${goals.weightUnit}" : "No data",
                     style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)
                   ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}

class AddEntrySheet extends ConsumerWidget {
  const AddEntrySheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(dailyLogRepositoryProvider);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Quick Add", style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildAddButton(context, "Water", "+250ml", Icons.water_drop, AppColors.primary, () {
                repo.addWater(250);
                // Refresh provider? The StreamProvider handles it automatically!
                Navigator.pop(context);
              }),
              _buildAddButton(context, "Sugar", "+5g", Icons.cookie, AppColors.secondary, () {
                repo.addSugar(5);
                Navigator.pop(context);
              }),
              _buildAddButton(context, "Weight", "Log", Icons.monitor_weight, Colors.orange, () {
                Navigator.pop(context);
                context.push('/weight');
              }),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox( // Make it full width
             width: double.infinity,
             child: OutlinedButton.icon(
                onPressed: () {
                   Navigator.pop(context); // Close this sheet
                   showModalBottomSheet(
                     context: context, 
                     isScrollControlled: true, // Allow full height
                     builder: (_) => const FoodSearchSheet()
                   );
                },
                icon: const Icon(Icons.search),
                label: const Text("Search Food Database"),
                style: OutlinedButton.styleFrom(
                   padding: const EdgeInsets.all(16),
                   side: const BorderSide(color: Colors.white24),
                ),
             ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(BuildContext context, String label, String value, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(value, style: TextStyle(color: color)),
          ],
        ),
      ),
    );
  }
}
