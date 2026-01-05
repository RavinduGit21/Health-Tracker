
class FoodItem {
  final String name;
  final double totalSugar; // in grams
  final double addedSugar; // in grams
  final String servingSize;
  final int calories;

  const FoodItem({
    required this.name,
    required this.totalSugar,
    required this.addedSugar,
    required this.servingSize,
    required this.calories,
  });
}

const List<FoodItem> commonFoods = [
  FoodItem(name: "Coca Cola (Can)", totalSugar: 39, addedSugar: 39, servingSize: "330ml", calories: 140),
  FoodItem(name: "Apple (Medium)", totalSugar: 19, addedSugar: 0, servingSize: "182g", calories: 95),
  FoodItem(name: "Banana", totalSugar: 14, addedSugar: 0, servingSize: "118g", calories: 105),
  FoodItem(name: "Orange Juice (Glass)", totalSugar: 21, addedSugar: 0, servingSize: "240ml", calories: 110),
  FoodItem(name: "Snickers Bar", totalSugar: 27, addedSugar: 25, servingSize: "52g", calories: 250),
  FoodItem(name: "Plain Yogurt", totalSugar: 9, addedSugar: 0, servingSize: "170g", calories: 100),
  FoodItem(name: "Fruit Yogurt (Strawberry)", totalSugar: 25, addedSugar: 16, servingSize: "170g", calories: 150),
  FoodItem(name: "Milk (Whole, 1 cup)", totalSugar: 12, addedSugar: 0, servingSize: "240ml", calories: 150),
  FoodItem(name: "Chocolate Chip Cookie", totalSugar: 11, addedSugar: 10, servingSize: "1 cookie", calories: 80),
  FoodItem(name: "Ice Cream (Vanilla, 1/2 cup)", totalSugar: 14, addedSugar: 14, servingSize: "66g", calories: 137),
  FoodItem(name: "Ketchup (1 tbsp)", totalSugar: 4, addedSugar: 4, servingSize: "15ml", calories: 20),
  FoodItem(name: "Granola Bar", totalSugar: 10, addedSugar: 8, servingSize: "1 bar", calories: 120),
  FoodItem(name: "Grapes (1 cup)", totalSugar: 23, addedSugar: 0, servingSize: "150g", calories: 104),
  FoodItem(name: "Energy Drink", totalSugar: 27, addedSugar: 27, servingSize: "250ml", calories: 110),
  FoodItem(name: "Iced Tea (Sweetened)", totalSugar: 22, addedSugar: 22, servingSize: "240ml", calories: 90),
];
