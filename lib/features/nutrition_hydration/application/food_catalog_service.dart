import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/food_dao.dart';
import '../../../core/database/daos/recipe_dao.dart';
import '../../../core/domain/enums.dart';
import '../../../core/services/smart_meal_suggester.dart';

/// Catálogo de alimentos, combos y recetas: búsquedas y ediciones que no son
/// registros de comida (esos pasan por `FoodLoggingService`).
class FoodCatalogService {
  FoodCatalogService(this._ref);

  final Ref _ref;

  FoodDao get _foods => _ref.read(foodDaoProvider);

  Future<List<FoodItem>> search({
    String query = '',
    bool onlyFavorites = false,
    bool onlyCustom = false,
    int limit = 40,
  }) {
    return _foods.filterCatalog(
      query: query,
      onlyFavorites: onlyFavorites,
      onlyCustom: onlyCustom,
      limit: limit,
    );
  }

  Future<void> setFavorite(FoodItem food, {required bool favorite}) =>
      _foods.toggleFavorite(food.id, favorite);

  /// Crea un alimento propio y lo devuelve ya persistido.
  Future<FoodItem?> createFood(FoodItemsCompanion food) async {
    final int id = await _foods.insertFood(food);
    return _foods.getById(id);
  }

  /// Cambia la cantidad o el bloque de un registro existente.
  Future<void> updateLogEntry({
    required FoodLog log,
    FoodItem? food,
    required double grams,
    MealType? mealType,
  }) {
    return _foods.updateFoodLogEntry(existingLog: log, food: food, newGrams: grams, mealType: mealType);
  }

  Future<void> deleteCombo(int comboId) => _foods.deleteCombo(comboId);

  Future<Recipe?> createRecipe({
    required String name,
    String? description,
    required MealType defaultMealType,
    required int servings,
    double? cookedTotalWeightGrams,
    required List<RecipeIngredientDraft> ingredients,
  }) async {
    final RecipeDao recipes = _ref.read(recipeDaoProvider);
    final int id = await recipes.createRecipe(
      name: name,
      description: description,
      defaultMealType: defaultMealType,
      totalYieldServings: servings,
      cookedTotalWeightGrams: cookedTotalWeightGrams,
      ingredients: ingredients,
    );
    return recipes.getRecipeById(id);
  }

  Future<SuggestedDailyMenu> suggestMenu(UserProfile profile) =>
      _ref.read(smartMealSuggesterProvider).generateMenu(profile: profile, foodDao: _foods);

  Future<List<SuggestedMealItem>> closeGap({
    required double remainingKcal,
    required double remainingProteinG,
    required double remainingCarbsG,
    required double remainingFatG,
  }) {
    return _ref.read(nutrientOracleProvider).recommendToCloseGap(
          remainingKcal: remainingKcal,
          remainingProteinG: remainingProteinG,
          remainingCarbsG: remainingCarbsG,
          remainingFatG: remainingFatG,
          foodDao: _foods,
        );
  }
}

final foodCatalogServiceProvider = Provider<FoodCatalogService>(FoodCatalogService.new);

/// Combos guardados con sus ingredientes.
final mealCombosProvider = StreamProvider<List<MealComboWithDetails>>((Ref ref) {
  return ref.watch(foodDaoProvider).watchMealCombosWithDetails();
});
