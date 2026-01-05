import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_tracker/src/constants/app_colors.dart';
import 'package:health_tracker/src/features/dashboard/dashboard_repository.dart';
import 'package:intl/intl.dart';

class DailyDetailScreen extends StatelessWidget {
  final DailyLog log;

  const DailyDetailScreen({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    // Sort entries by time (reversed) if we had parsing, but they are strings.
    // Assuming appended in order, so reverse to show newest first.
    final entries = log.entries.reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(log.date),
      ),
      body: entries.isEmpty 
        ? const Center(child: Text("No detailed entries for this day"))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return ListTile(
                leading: Icon(
                  entry.type == 'water' ? Icons.water_drop : Icons.cookie,
                  color: entry.type == 'water' ? AppColors.primary : AppColors.secondary,
                ),
                title: Text(entry.description, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(entry.time),
                trailing: Text(
                  "${entry.amount > 0 ? '+' : ''}${entry.amount} ${entry.type == 'water' ? 'mL' : 'g'}",
                  style: TextStyle(
                    color: entry.type == 'water' ? AppColors.primary : AppColors.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              );
            },
          ),
    );
  }
}
