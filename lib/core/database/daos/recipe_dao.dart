import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_database.dart';

/// Modelo ligero para definir un ingrediente crudo al crear o editar una receta.
class RecipeIngredientDraft {
  const RecipeIngredientDraft({
    required this.foodItemId,
    required this.rawGrams,
  });

  final int foodItemId;
  final double rawGrams;
}

/// Agregado que combina una receta con sus ingredientes completos resueltos.
class RecipeWithIngredients {
  const RecipeWithIngredients({
    required this.recipe,
    required this.ingredients,
  });

  final Recipe recipe;
  final List<ResolvedRecipeIngredient> ingredients;
}

class ResolvedRecipeIngredient {
  const ResolvedRecipeIngredient({
    required this.ingredient,
    required this.foodItem,
  });

  final RecipeIngredient ingredient;
  final FoodItem foodItem;
}

/// DAO para gestión de recetas caseras multiración (Batch Cooking & Meal Prep).
class RecipeDao {
  RecipeDao(this._db);

  final AppDatabase _db;

  /// Emite la lista completa de recetas caseras ordenadas por última fecha de uso.
  Stream<List<Recipe>> watchAllRecipes() {
    return (_db.select(_db.recipes)
          ..orderBy([
            (tbl) => OrderingTerm(expression: tbl.lastUsedAt, mode: OrderingMode.desc),
            (tbl) => OrderingTerm(expression: tbl.name, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  /// Obtiene una receta por su identificador único.
  Future<Recipe?> getRecipeById(int id) {
    return (_db.select(_db.recipes)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  /// Obtiene una receta junto a todos sus ingredientes desglosados y resueltos.
  Future<RecipeWithIngredients?> getRecipeWithIngredients(int recipeId) async {
    final Recipe? recipe = await getRecipeById(recipeId);
    if (recipe == null) return null;

    final query = _db.select(_db.recipeIngredients).join([
      innerJoin(
        _db.foodItems,
        _db.foodItems.id.equalsExp(_db.recipeIngredients.foodItemId),
      ),
    ])..where(_db.recipeIngredients.recipeId.equals(recipeId));

    final rows = await query.get();
    final List<ResolvedRecipeIngredient> resolvedList = rows.map((row) {
      return ResolvedRecipeIngredient(
        ingredient: row.readTable(_db.recipeIngredients),
        foodItem: row.readTable(_db.foodItems),
      );
    }).toList();

    return RecipeWithIngredients(recipe: recipe, ingredients: resolvedList);
  }

  /// Crea una receta calculando atómicamente los macros consolidados por ración.
  Future<int> createRecipe({
    required String name,
    String? description,
    String defaultMealType = 'lunch',
    required int totalYieldServings,
    double? cookedTotalWeightGrams,
    required List<RecipeIngredientDraft> ingredients,
  }) async {
    if (totalYieldServings <= 0) {
      throw ArgumentError('totalYieldServings debe ser mayor a 0');
    }
    if (ingredients.isEmpty) {
      throw ArgumentError('Una receta requiere al menos 1 ingrediente');
    }

    // 1. Obtener los alimentos base para calcular los totales crudos
    double totalKcal = 0;
    double totalP = 0;
    double totalC = 0;
    double totalF = 0;
    double totalFib = 0;
    double totalSod = 0;
    double totalPot = 0;
    double totalMag = 0;

    for (final draft in ingredients) {
      final FoodItem? food = await (_db.select(_db.foodItems)
            ..where((tbl) => tbl.id.equals(draft.foodItemId)))
          .getSingleOrNull();

      if (food != null) {
        final double factor = draft.rawGrams / 100.0;
        totalKcal += food.kcalPer100g * factor;
        totalP += food.proteinPer100g * factor;
        totalC += food.carbsPer100g * factor;
        totalF += food.fatPer100g * factor;
        totalFib += food.fiberPer100g * factor;
        totalSod += food.sodiumMgPer100g * factor;
        totalPot += food.potassiumMgPer100g * factor;
        totalMag += food.magnesiumMgPer100g * factor;
      }
    }

    // 2. Normalizar por ración (1 serving)
    final double yieldD = totalYieldServings.toDouble();
    final companion = RecipesCompanion(
      name: Value(name),
      description: Value(description),
      defaultMealType: Value(defaultMealType),
      totalYieldServings: Value(totalYieldServings),
      cookedTotalWeightGrams: Value(cookedTotalWeightGrams),
      kcalPerServing: Value(double.parse((totalKcal / yieldD).toStringAsFixed(1))),
      proteinPerServing: Value(double.parse((totalP / yieldD).toStringAsFixed(1))),
      carbsPerServing: Value(double.parse((totalC / yieldD).toStringAsFixed(1))),
      fatPerServing: Value(double.parse((totalF / yieldD).toStringAsFixed(1))),
      fiberPerServing: Value(double.parse((totalFib / yieldD).toStringAsFixed(1))),
      sodiumMgPerServing: Value(double.parse((totalSod / yieldD).toStringAsFixed(1))),
      potassiumMgPerServing: Value(double.parse((totalPot / yieldD).toStringAsFixed(1))),
      magnesiumMgPerServing: Value(double.parse((totalMag / yieldD).toStringAsFixed(1))),
      lastUsedAt: Value(DateTime.now()),
    );

    return _db.transaction(() async {
      final int recipeId = await _db.into(_db.recipes).insert(companion);
      for (final draft in ingredients) {
        await _db.into(_db.recipeIngredients).insert(
              RecipeIngredientsCompanion(
                recipeId: Value(recipeId),
                foodItemId: Value(draft.foodItemId),
                rawGrams: Value(draft.rawGrams),
              ),
            );
      }
      return recipeId;
    });
  }

  /// Elimina una receta y sus ingredientes asociados (en cascada).
  Future<int> deleteRecipe(int id) {
    return (_db.delete(_db.recipes)..where((tbl) => tbl.id.equals(id))).go();
  }

  /// Actualiza la fecha de último uso de una receta.
  Future<void> touchRecipe(int id) async {
    final query = _db.update(_db.recipes)..where((tbl) => tbl.id.equals(id));
    await query.write(RecipesCompanion(lastUsedAt: Value(DateTime.now())));
  }
}

/// Provider de Riverpod para inyectar RecipeDao.
final recipeDaoProvider = Provider<RecipeDao>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return RecipeDao(db);
});

/// StreamProvider reactivo que expone todas las recetas caseras ordenadas por uso reciente.
final allRecipesStreamProvider = StreamProvider<List<Recipe>>((ref) {
  final RecipeDao dao = ref.watch(recipeDaoProvider);
  return dao.watchAllRecipes();
});

