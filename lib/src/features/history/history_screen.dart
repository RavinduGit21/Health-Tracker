import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_tracker/src/constants/app_colors.dart';
import 'package:health_tracker/src/features/dashboard/dashboard_repository.dart';
import 'package:health_tracker/src/features/history/daily_detail_screen.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allLogsAsync = ref.watch(allLogsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Tracking History"),
      ),
      body: allLogsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
        data: (logs) {
          if (logs.isEmpty) {
            return const Center(child: Text("No history yet. Start tracking!"));
          }
          
          final totalDays = logs.length;
          final sugarCutDays = logs.where((l) => l.sugarCutCompleted).length;
          final workoutDays = logs.where((l) => l.workoutDone).length;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSummaryStat("Days", totalDays.toString(), Icons.calendar_today, Colors.blue),
                        _buildSummaryStat("Sugar Cut", sugarCutDays.toString(), Icons.block, Colors.pink),
                        _buildSummaryStat("Workouts", workoutDays.toString(), Icons.fitness_center, Colors.green),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final log = logs[index];
                      return _HistoryItem(log: log);
                    },
                    childCount: logs.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _HistoryItem extends ConsumerWidget {
  final DailyLog log;

  const _HistoryItem({required this.log});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = DateTime.tryParse(log.date) ?? DateTime.now();
    final dateStr = DateFormat('EEE, MMM d').format(date);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderOverlay),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
           Navigator.push(context, MaterialPageRoute(builder: (_) => DailyDetailScreen(log: log)));
        },
        onLongPress: () => _showEditDialog(context, ref, log),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildMiniCheck(Icons.water_drop, "${log.waterIntake}ml", AppColors.primary, log.waterIntake > 0),
                        const SizedBox(width: 8),
                        _buildMiniCheck(Icons.cookie, "${log.sugarIntake}g", AppColors.secondary, log.sugarIntake > 0),
                        const SizedBox(width: 8),
                        if (log.workoutDone) const Icon(Icons.fitness_center, size: 14, color: Colors.greenAccent),
                        if (log.sugarCutCompleted) const SizedBox(width: 4),
                        if (log.sugarCutCompleted) const Icon(Icons.block, size: 14, color: Colors.pinkAccent),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniCheck(IconData icon, String label, Color color, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active ? color.withOpacity(0.1) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: active ? color : Colors.white24),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, color: active ? Colors.white : Colors.white38, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }


  void _showEditDialog(BuildContext context, WidgetRef ref, DailyLog log) {
    final waterCtrl = TextEditingController(text: log.waterIntake.toString());
    final sugarCtrl = TextEditingController(text: log.sugarIntake.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: Text("Edit Log: ${log.date}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: waterCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Water (mL)", icon: Icon(Icons.water_drop, color: AppColors.primary)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: sugarCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Sugar (g)", icon: Icon(Icons.cookie, color: AppColors.secondary)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () {
              final newWater = int.tryParse(waterCtrl.text) ?? log.waterIntake;
              final newSugar = int.tryParse(sugarCtrl.text) ?? log.sugarIntake;
              
              ref.read(dailyLogRepositoryProvider).updateLog(
                log.copyWith(waterIntake: newWater, sugarIntake: newSugar)
              );
              Navigator.pop(ctx);
            },
            child: const Text("SAVE"),
          ),
        ],
      ),
    );
  }
}
