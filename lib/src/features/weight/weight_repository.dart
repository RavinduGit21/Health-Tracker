import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

class WeightEntry {
  final String date;
  final double weight;
  final String? note;

  WeightEntry({required this.date, required this.weight, this.note});

  Map<String, dynamic> toMap() => {
    'date': date,
    'weight': weight,
    'note': note,
  };

  factory WeightEntry.fromMap(Map<dynamic, dynamic> map) => WeightEntry(
    date: map['date'] ?? '',
    weight: (map['weight'] as num?)?.toDouble() ?? 0.0,
    note: map['note'],
  );
}

class WeightRepository {
  final Box _box;

  WeightRepository(this._box);

  Future<void> addWeight(double weight, {String? note}) async {
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final entry = WeightEntry(date: date, weight: weight, note: note);
    await _box.put(date, entry.toMap());
  }

  List<WeightEntry> getAllEntries() {
    final entries = _box.values.map((e) => WeightEntry.fromMap(e)).toList();
    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  WeightEntry? getLatestEntry() {
    final entries = getAllEntries();
    return entries.isEmpty ? null : entries.first;
  }

  Future<void> deleteEntry(String date) async {
    await _box.delete(date);
  }
}

final weightRepositoryProvider = Provider<WeightRepository>((ref) {
  final box = Hive.box('weight_logs');
  return WeightRepository(box);
});

final weightEntriesProvider = StreamProvider.autoDispose<List<WeightEntry>>((ref) async* {
  final repo = ref.watch(weightRepositoryProvider);
  final box = Hive.box('weight_logs');
  
  yield repo.getAllEntries();
  
  await for (final _ in box.watch()) {
    yield repo.getAllEntries();
  }
});

final latestWeightProvider = Provider.autoDispose<WeightEntry?>((ref) {
  final entries = ref.watch(weightEntriesProvider).value ?? [];
  return entries.isEmpty ? null : entries.first;
});
