import 'package:health_tracker/src/features/dashboard/dashboard_repository.dart';
import 'package:hive_flutter/hive_flutter.dart';

class DataImportService {
  static Future<void> importSpreadsheetData(DailyLogRepository repo) async {
    final List<Map<String, dynamic>> historicalData = [
      {'date': '2026-01-01', 'water': 2000, 'sugar': 0, 'workout': true, 'calories': 100, 'sugarCut': true},
      {'date': '2026-01-02', 'water': 2000, 'sugar': 0, 'workout': true, 'calories': 100, 'sugarCut': true},
      {'date': '2026-01-03', 'water': 2000, 'sugar': 0, 'workout': true, 'calories': 100, 'sugarCut': true},
      {'date': '2026-01-04', 'water': 2000, 'sugar': 0, 'workout': true, 'calories': 100, 'sugarCut': true},
      {'date': '2026-01-05', 'water': 2000, 'sugar': 0, 'workout': true, 'calories': 100, 'sugarCut': true},
      {'date': '2026-01-06', 'water': 2000, 'sugar': 0, 'workout': true, 'calories': 100, 'sugarCut': true},
    ];

    for (var data in historicalData) {
      final log = DailyLog(
        date: data['date'],
        waterIntake: data['water'],
        sugarIntake: data['sugar'],
        workoutDone: data['workout'],
        caloriesBurned: data['calories'],
        sugarCutCompleted: data['sugarCut'],
        entries: [
          LogEntry(
            id: 'import_w_${data['date']}',
            time: '09:00 AM',
            description: 'Imported Water',
            amount: data['water'],
            type: 'water',
          ),
        ],
      );
      await repo.updateLog(log);
    }
  }
}
