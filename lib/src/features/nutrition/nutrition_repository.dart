import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'food_data.dart';

class NutritionRepository {
  Future<List<FoodItem>> searchFood(String query) async {
    if (query.isEmpty) return [];

    final lowercaseQuery = query.toLowerCase();
    
    // 1. Get local results (Fast)
    final localResults = commonFoods.where((food) {
      return food.name.toLowerCase().contains(lowercaseQuery);
    }).toList();

    // 2. Get API results from Open Food Facts
    try {
      final url = Uri.parse(
        'https://world.openfoodfacts.org/cgi/search.pl?search_terms=$query&search_simple=1&action=process&json=1&page_size=20'
      );
      
      final response = await http.get(url, headers: {'User-Agent': 'HealthTrackerApp - Android - Version 1.0'});
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List products = data['products'] ?? [];
        
        final apiResults = products.map((p) {
          final nutriments = p['nutriments'] ?? {};
          final totalSugar = (nutriments['sugars_100g'] ?? 0).toDouble();
          final calories = (nutriments['energy-kcal_100g'] ?? 0).toInt();
          
          // Heuristic for added sugar
          double addedSugar = (nutriments['added-sugars_100g'] ?? -1.0).toDouble();
          
          if (addedSugar < 0) {
            // If API doesn't provide it, check categories
            final categories = (p['categories_tags'] as List?)?.cast<String>() ?? [];
            final isNatural = categories.any((c) => 
               c.contains('fruit') || 
               c.contains('vegetable') || 
               c.contains('nuts') || 
               c.contains('water') ||
               c.contains('egg') ||
               c.contains('meat') ||
               c.contains('fish') ||
               c.contains('legume') ||
               c.contains('grain') ||
               c.contains('seed')
            );
            
            if (isNatural) {
              addedSugar = 0;
            } else {
              // Assume 80% of sugar in processed food is added if not specified
              addedSugar = totalSugar * 0.8;
            }
          }

          return FoodItem(
            name: p['product_name'] ?? 'Unknown Product',
            totalSugar: totalSugar,
            addedSugar: addedSugar,
            servingSize: p['quantity'] ?? '100g',
            calories: calories,
          );
        }).toList();

        // Combine and return
        return [...localResults, ...apiResults];
      }
    } catch (e) {
      print('Food API error: $e');
    }

    return localResults;
  }
}

final nutritionRepositoryProvider = Provider<NutritionRepository>((ref) {
  return NutritionRepository();
});
