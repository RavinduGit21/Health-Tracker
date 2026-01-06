import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_tracker/src/constants/app_colors.dart';
import 'package:health_tracker/src/features/dashboard/dashboard_repository.dart';
import 'package:intl/intl.dart';

class DailyDetailScreen extends ConsumerWidget {
  final String date;

  const DailyDetailScreen({super.key, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logAsync = ref.watch(dailyLogByDateProvider(date));

    return Scaffold(
      appBar: AppBar(
        title: Text(date),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: "Delete Full Day Data",
            onPressed: () => _showDeleteDayConfirmation(context, ref),
          ),
        ],
      ),
      body: logAsync.when(
        data: (log) {
          final entries = log.entries.reversed.toList();
          if (entries.isEmpty) {
            return const Center(child: Text("No detailed entries for this day"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _buildDetailItem(context, ref, entry, log.date);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text("Error: $err")),
      ),
    );
  }

  Widget _buildDetailItem(BuildContext context, WidgetRef ref, LogEntry entry, String logDate) {
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
        repo.deleteLogEntry(logDate, entry.id);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${entry.description} deleted")));
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.white.withOpacity(0.05))),
        child: ListTile(
          onTap: () => _showEditEntryDialog(context, ref, logDate, entry),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isWater ? AppColors.primary : AppColors.secondary).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isWater ? Icons.water_drop : Icons.cookie,
              color: isWater ? AppColors.primary : AppColors.secondary,
              size: 20,
            ),
          ),
          title: Text(entry.description, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(entry.time),
          trailing: Text(
            "${entry.amount > 0 ? '+' : ''}${entry.amount} ${isWater ? 'mL' : 'g'}",
            style: TextStyle(
              color: isWater ? AppColors.primary : AppColors.secondary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  void _showEditEntryDialog(BuildContext context, WidgetRef ref, String logDate, LogEntry entry) {
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
          TextButton(
            onPressed: () {
              ref.read(dailyLogRepositoryProvider).deleteLogEntry(logDate, entry.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${entry.description} deleted")));
            }, 
            child: const Text("DELETE", style: TextStyle(color: Colors.redAccent))
          ),
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
                ref.read(dailyLogRepositoryProvider).editLogEntry(logDate, updated);
                Navigator.pop(context);
              }
            }, 
            child: const Text("SAVE")
          ),
        ],
      ),
    );
  }

  void _showDeleteDayConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Full Day Data?"),
        content: Text("Are you sure you want to delete all logs for $date? This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          TextButton(
            onPressed: () {
              ref.read(dailyLogRepositoryProvider).deleteLog(date);
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to history list
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Data for $date deleted")));
            }, 
            child: const Text("DELETE", style: TextStyle(color: Colors.redAccent))
          ),
        ],
      ),
    );
  }
}
