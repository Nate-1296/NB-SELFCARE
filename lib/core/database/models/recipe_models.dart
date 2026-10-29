/// Modelos de lectura (resultados de JOIN) que la UI puede usar sin depender del DAO.
library;

import '../app_database.dart';

/// Modelo ligero para definir un ingrediente crudo al crear o editar una receta.
class RecipeIngredientDraft {
  const RecipeIngredientDraft({required this.foodItemId, required this.rawGrams});

  final int foodItemId;
  final double rawGrams;
}

/// Agregado que combina una receta con sus ingredientes completos resueltos.
class RecipeWithIngredients {
  const RecipeWithIngredients({required this.recipe, required this.ingredients});

  final Recipe recipe;
  final List<ResolvedRecipeIngredient> ingredients;
}

class ResolvedRecipeIngredient {
  const ResolvedRecipeIngredient({required this.ingredient, required this.foodItem});

  final RecipeIngredient ingredient;
  final FoodItem foodItem;
}
