import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  
  Map<String, dynamic> toSupabase(String userId) => {
    'user_id': userId,
    'date': date,
    'weight': weight,
    'note': note,
  };
  
  factory WeightEntry.fromSupabase(Map<String, dynamic> map) => WeightEntry(
    date: map['date'] ?? '',
    weight: (map['weight'] as num?)?.toDouble() ?? 0.0,
    note: map['note'],
  );
}

class WeightRepository {
  final Box _box;
  final _supabase = Supabase.instance.client;

  RealtimeChannel? _weightChannel;

  WeightRepository(this._box) {
    _initRealtime();
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn || data.event == AuthChangeEvent.tokenRefreshed) {
        _initRealtime();
      } else if (data.event == AuthChangeEvent.signedOut) {
        _weightChannel?.unsubscribe();
        _weightChannel = null;
      }
    });
  }

  void _initRealtime() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    _weightChannel?.unsubscribe();
    _weightChannel = _supabase
        .channel('public:weight_logs')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'weight_logs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
            if (payload.newRecord != null) {
              final entry = WeightEntry.fromSupabase(payload.newRecord);
              _box.put(entry.date, entry.toMap());
            }
          },
        );
    _weightChannel?.subscribe();
  }

  Future<void> addWeight(double weight, {String? note}) async {
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final entry = WeightEntry(date: date, weight: weight, note: note);
    await _saveEntry(entry);
  }

  Future<void> _saveEntry(WeightEntry entry) async {
    await _box.put(entry.date, entry.toMap());
    
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        await _supabase.from('weight_logs').upsert(
          entry.toSupabase(user.id),
          onConflict: 'user_id, date',
        );
      } catch (e) {
        print("Weight sync failed: $e");
      }
    }
  }

  Future<void> syncRemote() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final data = await _supabase.from('weight_logs').select().eq('user_id', user.id);
      for (var row in data) {
        final entry = WeightEntry.fromSupabase(row);
        await _box.put(entry.date, entry.toMap());
      }
    } catch (e) {
      print("Weight pull failed: $e");
    }
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
    final user = _supabase.auth.currentUser;
    if (user != null) {
      await _supabase.from('weight_logs').delete().eq('user_id', user.id).eq('date', date);
    }
  }

  Future<void> updateWeight(String date, double weight, {String? note}) async {
    final entry = WeightEntry(date: date, weight: weight, note: note);
    await _saveEntry(entry);
  }

  Future<void> clearAllData() async {
    await _box.clear();
    final user = _supabase.auth.currentUser;
    if (user != null) {
      await _supabase.from('weight_logs').delete().eq('user_id', user.id);
    }
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
