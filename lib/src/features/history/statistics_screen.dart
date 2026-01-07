import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_tracker/src/constants/app_colors.dart';
import 'package:health_tracker/src/features/dashboard/dashboard_repository.dart';
import 'package:health_tracker/src/features/goals/goals_repository.dart';
import 'package:health_tracker/src/utils/report_service.dart';
import 'package:health_tracker/src/features/weight/weight_repository.dart';
import 'package:health_tracker/src/features/sleep/sleep_repository.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allLogsAsync = ref.watch(allLogsProvider);
    final goalsState = ref.watch(goalsProvider);
    final weightEntries = ref.watch(weightEntriesProvider).value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Statistics & Trends"),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () {
              final logs = ref.read(allLogsProvider).value ?? [];
              final sleepLogs = ref.read(sleepRepositoryProvider).getAllLogs();
              ReportService.generateAndShareReport(
                dailyLogs: logs,
                sleepLogs: sleepLogs,
                weightLogs: weightEntries,
              );
            },
          )
        ],
      ),
      body: allLogsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
        data: (logs) {
          if (logs.isEmpty) return const Center(child: Text("Not enough data yet"));

          // Calculations
          final totalDays = logs.length;
          final totalWater = logs.fold(0, (sum, log) => sum + log.waterIntake);
          final totalSugar = logs.fold(0, (sum, log) => sum + log.sugarIntake);
          
          final avgWater = (totalWater / totalDays).round();
          final avgSugar = (totalSugar / totalDays).round();

          int waterStreak = 0;
          int currentWaterStreak = 0;
          // Logs are sorted descending (newest first). Iterate reversed for streak?
          // Actually, let's just iterate ascending by date.
          final sortedLogs = List<DailyLog>.from(logs)..sort((a, b) => a.date.compareTo(b.date));
          
          for (var log in sortedLogs) {
             if (log.waterIntake >= goalsState.waterGoal) {
               currentWaterStreak++;
             } else {
               if (currentWaterStreak > waterStreak) waterStreak = currentWaterStreak;
               currentWaterStreak = 0;
             }
          }
          if (currentWaterStreak > waterStreak) waterStreak = currentWaterStreak;

          int daysOverSugar = logs.where((l) => l.sugarIntake > goalsState.sugarLimit).length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildStatCard(context, "Average Water Intake", "$avgWater mL", Icons.water_drop, AppColors.primary),
              const SizedBox(height: 16),
              _buildStatCard(context, "Average Sugar Intake", "$avgSugar g", Icons.cookie, AppColors.secondary),
              const SizedBox(height: 16),
              _buildStatCard(context, "Best Water Streak", "$waterStreak Days", Icons.local_fire_department, Colors.orange),
              const SizedBox(height: 16),
              _buildStatCard(context, "Days Over Sugar Limit", "$daysOverSugar Days", Icons.warning, Colors.redAccent),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
