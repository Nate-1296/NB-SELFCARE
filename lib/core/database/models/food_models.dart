/// Modelos de lectura (resultados de JOIN) que la UI puede usar sin depender del DAO.
library;

import '../app_database.dart';

/// Registro de comida consumida combinado con los metadatos de su alimento (JOIN).
class FoodLogWithItem {
  const FoodLogWithItem({required this.log, this.foodItem});

  final FoodLog log;
  final FoodItem? foodItem;
}

/// Ingrediente resuelto dentro de una plantilla de combo casero.
class MealComboIngredientDetail {
  const MealComboIngredientDetail({required this.foodItem, required this.baseGrams});

  final FoodItem foodItem;
  final double baseGrams;
}

/// Plantilla de combo casero enriquecida con ingredientes y macronutrientes base (1.0x).
class MealComboWithDetails {
  const MealComboWithDetails({
    required this.combo,
    required this.ingredients,
    required this.baseKcal,
    required this.baseProteinG,
    required this.baseCarbsG,
    required this.baseFatG,
  });

  final MealCombo combo;
  final List<MealComboIngredientDetail> ingredients;
  final double baseKcal;
  final double baseProteinG;
  final double baseCarbsG;
  final double baseFatG;
}
