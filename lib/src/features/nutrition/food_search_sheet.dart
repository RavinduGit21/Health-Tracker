import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_tracker/src/constants/app_colors.dart';
import 'package:health_tracker/src/features/dashboard/dashboard_repository.dart';
import 'package:health_tracker/src/features/goals/goals_repository.dart';
import 'package:health_tracker/src/features/nutrition/food_data.dart';
import 'package:health_tracker/src/features/nutrition/nutrition_repository.dart';

class FoodSearchSheet extends ConsumerStatefulWidget {
  const FoodSearchSheet({super.key});

  @override
  ConsumerState<FoodSearchSheet> createState() => _FoodSearchSheetState();
}

class _FoodSearchSheetState extends ConsumerState<FoodSearchSheet> {
  final _searchController = TextEditingController();
  List<FoodItem> _results = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _search(String query) async {
    setState(() => _isLoading = true);
    final results = await ref.read(nutritionRepositoryProvider).searchFood(query);
    if (mounted) {
      setState(() {
        _results = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Add Food", style: Theme.of(context).textTheme.headlineSmall),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: (val) {
               if (_debounce?.isActive ?? false) _debounce!.cancel();
               _debounce = Timer(const Duration(milliseconds: 500), () {
                 if (val.length > 2) _search(val);
               });
            },
            decoration: InputDecoration(
              hintText: "Search (e.g. Apple, Coke)",
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: AppColors.surfaceDark,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_results.isEmpty && _searchController.text.isNotEmpty)
            const Center(child: Text("No foods found"))
          else
            Expanded(
              child: ListView.separated(
                itemCount: _results.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final food = _results[index];
                  return _FoodTile(food: food);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _FoodTile extends ConsumerWidget {
  final FoodItem food;

  const _FoodTile({required this.food});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsState = ref.watch(goalsProvider);
    final isAddedMode = goalsState.sugarTrackingMode == 'added';
    final sugarAmount = isAddedMode ? food.addedSugar : food.totalSugar;

    return ListTile(
      tileColor: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(food.name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text("${food.servingSize} • ${food.calories} kcal"),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text("+${sugarAmount.toStringAsFixed(1)}g sugar", style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold)),
          Text(isAddedMode ? "(Added)" : "(Total)", style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
      onTap: () {
        ref.read(dailyLogRepositoryProvider).addSugar(sugarAmount.round(), description: food.name);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Added ${food.name}")));
        Navigator.pop(context);
      },
    );
  }
}
