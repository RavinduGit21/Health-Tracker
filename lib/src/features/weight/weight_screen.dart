import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:health_tracker/src/constants/app_colors.dart';
import 'package:health_tracker/src/features/weight/weight_repository.dart';
import 'package:health_tracker/src/features/goals/goals_repository.dart';
import 'package:intl/intl.dart';

class WeightScreen extends ConsumerWidget {
  const WeightScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weightEntriesAsync = ref.watch(weightEntriesProvider);
    final goals = ref.watch(goalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Weight Tracker")),
      body: weightEntriesAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(child: Text("No weight entries yet. Start tracking today!"));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryCard(context, entries, goals),
                const SizedBox(height: 24),
                Text("Progress Chart", style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                _buildWeightChart(context, entries, goals),
                const SizedBox(height: 24),
                Text("Recent History", style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return _buildWeightItem(context, entry, goals, ref);
                  },
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text("Error: $err")),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddWeightDialog(context, ref),
        backgroundColor: Colors.orangeAccent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Log Weight", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, List<WeightEntry> entries, GoalsState goals) {
    final latestWeight = entries.first.weight;
    final firstWeight = entries.last.weight;
    final totalChange = latestWeight - firstWeight;
    final isLoss = totalChange < 0;
    
    final isTargetReached = latestWeight <= goals.targetWeight;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderOverlay),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Current Weight", style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    "${latestWeight.toStringAsFixed(1)} ${goals.weightUnit}",
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: (isTargetReached ? AppColors.success : Colors.orange).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: (isTargetReached ? AppColors.success : Colors.orange).withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Text(isTargetReached ? "GOAL" : "TARGET", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isTargetReached ? AppColors.success : Colors.orange)),
                    Text("${goals.targetWeight}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildStatDetail(context, "Start", "${firstWeight.toStringAsFixed(1)}", "")),
              Container(height: 30, width: 1, color: Colors.white10),
              Expanded(child: _buildStatDetail(context, "Progress", "${isLoss ? '' : '+'}${totalChange.toStringAsFixed(1)}", goals.weightUnit)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatDetail(BuildContext context, String label, String value, String unit) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            if (unit.isNotEmpty) Text(" $unit", style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ],
    );
  }

  Widget _buildWeightChart(BuildContext context, List<WeightEntry> entries, GoalsState goals) {
    final reversedEntries = entries.reversed.toList();
    if (reversedEntries.length < 2) {
       return const Card(child: Padding(padding: EdgeInsets.all(32), child: Center(child: Text("Track more days to see progress chart"))));
    }
    
    return Container(
      height: 220,
      padding: const EdgeInsets.only(right: 24, top: 24, bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderOverlay),
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < reversedEntries.length && (reversedEntries.length < 5 || index % (reversedEntries.length ~/ 4 + 1) == 0)) {
                    final date = DateTime.parse(reversedEntries[index].date);
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(DateFormat('Md').format(date), style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: reversedEntries.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.weight)).toList(),
              isCurved: true,
              color: Colors.orangeAccent,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [Colors.orangeAccent.withOpacity(0.2), Colors.orangeAccent.withOpacity(0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightItem(BuildContext context, WeightEntry entry, GoalsState goals, WidgetRef ref) {
    final date = DateTime.tryParse(entry.date) ?? DateTime.now();
    final repo = ref.read(weightRepositoryProvider);

    return Dismissible(
      key: Key(entry.date),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.redAccent,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        repo.deleteEntry(entry.date);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Entry for ${DateFormat('MMM d').format(date)} deleted")));
      },
      child: InkWell(
        onTap: () => _showEditWeightDialog(context, ref, entry),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.monitor_weight_outlined, color: Colors.orangeAccent, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateFormat('MMM d, yyyy').format(date), style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (entry.note != null && entry.note!.isNotEmpty)
                      Text(entry.note!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Text(
                "${entry.weight} ${goals.weightUnit}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditWeightDialog(BuildContext context, WidgetRef ref, WeightEntry entry) {
    final weightController = TextEditingController(text: entry.weight.toString());
    final noteController = TextEditingController(text: entry.note);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Edit Weight (${entry.date})"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: weightController,
              decoration: InputDecoration(labelText: "Weight (${ref.read(goalsProvider).weightUnit})"),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: "Note (optional)"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () {
              final weight = double.tryParse(weightController.text);
              if (weight != null) {
                ref.read(weightRepositoryProvider).updateWeight(
                  entry.date, 
                  weight, 
                  note: noteController.text.isEmpty ? null : noteController.text
                );
                Navigator.pop(context);
              }
            }, 
            child: const Text("SAVE")
          ),
        ],
      ),
    );
  }

  void _showAddWeightDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    final latest = ref.read(latestWeightProvider);
    if (latest != null) controller.text = latest.weight.toString();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Log Today's Weight"),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: "Enter weight",
            suffixText: ref.read(goalsProvider).weightUnit,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () {
              final weight = double.tryParse(controller.text);
              if (weight != null) {
                ref.read(weightRepositoryProvider).addWeight(weight);
                Navigator.pop(context);
              }
            }, 
            child: const Text("SAVE")
          ),
        ],
      ),
    );
  }
}

