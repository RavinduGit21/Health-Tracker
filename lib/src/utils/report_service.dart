import 'package:flutter/services.dart';
import 'package:health_tracker/src/features/dashboard/dashboard_repository.dart';
import 'package:health_tracker/src/features/sleep/sleep_repository.dart';
import 'package:health_tracker/src/features/weight/weight_repository.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportService {
  static Future<void> generateAndShareReport({
    required List<DailyLog> dailyLogs,
    required List<SleepLog> sleepLogs,
    required List<WeightEntry> weightLogs,
  }) async {
    final pdf = pw.Document();

    // Sort logs correctly for tables and charts
    dailyLogs.sort((a, b) => b.date.compareTo(a.date));
    sleepLogs.sort((a, b) => b.startTime.compareTo(a.startTime));
    weightLogs.sort((a, b) => b.date.compareTo(a.date)); // Descending for table

    final weightForChart = List<WeightEntry>.from(weightLogs).reversed.toList(); // Ascending for chart

    final now = DateTime.now();
    final dateRange = dailyLogs.isEmpty 
        ? "No data" 
        : "${dailyLogs.last.date} to ${dailyLogs.first.date}";

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader(now, dateRange),
            pw.SizedBox(height: 20),
            _buildSummaryTable(dailyLogs, sleepLogs, weightLogs),
            pw.SizedBox(height: 30),
            
            _buildSectionTitle("Weight Loss Trend"),
            _buildWeightChart(weightForChart),
            pw.SizedBox(height: 30),

            _buildSectionTitle("Daily Activity (Last 30 Days)"),
            _buildDailyTable(dailyLogs.take(30).toList()),
            pw.SizedBox(height: 30),

            _buildSectionTitle("Sleep Patterns"),
            _buildSleepTable(sleepLogs.take(20).toList()),
            pw.SizedBox(height: 30),

            _buildSectionTitle("Weight History"),
            _buildWeightTable(weightLogs.take(20).toList()),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'health_report_${DateFormat('yyyyMMdd').format(now)}.pdf',
    );
  }

  static pw.Widget _buildHeader(DateTime now, String dateRange) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text("Health Tracking Report", 
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text("Generated on: ${DateFormat('MMM d, yyyy').format(now)}"),
            pw.Text("Period: $dateRange"),
          ],
        ),
        pw.Divider(thickness: 2, color: PdfColors.blue900),
      ],
    );
  }

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
        pw.SizedBox(height: 8),
      ],
    );
  }

  static pw.Widget _buildWeightChart(List<WeightEntry> entries) {
    if (entries.length < 2) {
      return pw.Container(
        height: 150,
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        child: pw.Text("Not enough weight data to display chart (need at least 2 entries)"),
      );
    }

    // Limit to last 15 entries for clarity
    final recentEntries = entries.length > 15 ? entries.sublist(entries.length - 15) : entries;

    // Calculate dynamic range for Y axis
    final weights = recentEntries.map((e) => e.weight).toList();
    final minW = weights.reduce((a, b) => a < b ? a : b);
    final maxW = weights.reduce((a, b) => a > b ? a : b);
    final rangePadding = (maxW - minW) * 0.2;
    final yMin = (minW - rangePadding).floorToDouble();
    final yMax = (maxW + rangePadding).ceilToDouble();

    return pw.Container(
      height: 200,
      padding: const pw.EdgeInsets.only(top: 10, bottom: 10, right: 10),
      child: pw.Chart(
        grid: pw.CartesianGrid(
          xAxis: pw.FixedAxis(
            List.generate(recentEntries.length, (i) => i.toDouble()),
            format: (v) => DateFormat('MM/dd').format(DateTime.parse(recentEntries[v.toInt()].date)),
            textStyle: const pw.TextStyle(fontSize: 8),
          ),
          yAxis: pw.FixedAxis(
            [yMin, yMax],
            format: (v) => v.toStringAsFixed(1),
            textStyle: const pw.TextStyle(fontSize: 8),
            divisions: true,
          ),
        ),
        datasets: [
          pw.LineDataSet(
            legend: 'Weight',
            drawPoints: true,
            pointSize: 3,
            drawLine: true,
            lineWidth: 2,
            lineColor: PdfColors.orange700,
            color: PdfColors.orange700,
            data: List.generate(recentEntries.length, (i) {
              return pw.PointChartValue(i.toDouble(), recentEntries[i].weight);
            }),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryTable(List<DailyLog> daily, List<SleepLog> sleep, List<WeightEntry> weight) {
    final totalWater = daily.fold(0, (sum, item) => sum + item.waterIntake);
    final avgWater = daily.isEmpty ? 0 : (totalWater / daily.length).round();
    
    final totalSleep = sleep.where((s) => s.endTime != null).fold(0.0, (sum, item) => sum + item.durationHours);
    final avgSleep = sleep.isEmpty ? 0.0 : totalSleep / sleep.length;

    final startWeight = weight.isEmpty ? 0.0 : weight.last.weight;
    final currentWeight = weight.isEmpty ? 0.0 : weight.first.weight;
    final weightDiff = currentWeight - startWeight;

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem("Avg Water", "$avgWater mL"),
              _buildSummaryItem("Avg Sleep", "${avgSleep.toStringAsFixed(1)} hrs"),
              _buildSummaryItem("Weight Progress", "${weightDiff >= 0 ? '+' : ''}${weightDiff.toStringAsFixed(1)} kg"),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.SizedBox(height: 4),
        pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
      ],
    );
  }

  static pw.Widget _buildDailyTable(List<DailyLog> logs) {
    return pw.TableHelper.fromTextArray(
      context: null,
      headers: ['Date', 'Water (mL)', 'Sugar (g)', 'Workout', 'Sugar Cut'],
      data: logs.map((l) => [
        l.date,
        l.waterIntake.toString(),
        l.sugarIntake.toString(),
        l.workoutDone ? 'Yes' : 'No',
        l.sugarCutCompleted ? 'Done' : '-',
      ]).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
      cellAlignment: pw.Alignment.center,
      rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
    );
  }

  static pw.Widget _buildSleepTable(List<SleepLog> logs) {
    return pw.TableHelper.fromTextArray(
      context: null,
      headers: ['Date', 'Start', 'End', 'Duration', 'Mood'],
      data: logs.map((l) {
        final date = DateFormat('MMM d').format(l.startTime);
        final start = DateFormat.jm().format(l.startTime);
        final end = l.endTime != null ? DateFormat.jm().format(l.endTime!) : '-';
        return [
          date,
          start,
          end,
          "${l.durationHours.toStringAsFixed(1)} h",
          l.moodAfterWake ?? '-',
        ];
      }).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo700),
      cellAlignment: pw.Alignment.center,
      rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
    );
  }

  static pw.Widget _buildWeightTable(List<WeightEntry> logs) {
    return pw.TableHelper.fromTextArray(
      context: null,
      headers: ['Date', 'Weight (kg)', 'Change'],
      data: List.generate(logs.length, (i) {
        final l = logs[i];
        double diff = 0;
        if (i < logs.length - 1) {
          diff = l.weight - logs[i+1].weight;
        }
        return [
          l.date,
          l.weight.toStringAsFixed(1),
          diff == 0 ? '-' : "${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)}",
        ];
      }),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.orange700),
      cellAlignment: pw.Alignment.center,
      rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
    );
  }
}
