import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'food_data.dart';

class NutritionRepository {
  Future<List<FoodItem>> searchFood(String query) async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (query.isEmpty) return [];

    final lowercaseQuery = query.toLowerCase();
    return commonFoods.where((food) {
      return food.name.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }
}

final nutritionRepositoryProvider = Provider<NutritionRepository>((ref) {
  return NutritionRepository();
});
