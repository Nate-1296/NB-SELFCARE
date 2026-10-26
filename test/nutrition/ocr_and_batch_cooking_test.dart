import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/database/daos/food_dao.dart';
import 'package:nb_selfcare/core/database/daos/recipe_dao.dart';
import 'package:nb_selfcare/core/services/nutrition_label_ocr_service.dart';
import 'package:nb_selfcare/core/services/open_food_facts_service.dart';

void main() {
  group('Fase 3: Nutrición de la Vida Real y Catálogo Masivo', () {
    test('NutritionLabelOcrService: extrae macronutrientes desde texto OCR en español', () {
      final NutritionLabelOcrService ocrService = NutritionLabelOcrService();

      const String sampleLabelEs = '''
      INFORMACIÓN NUTRICIONAL
      Porción: 100g
      Valor Energético: 420 kcal
      Proteínas: 24.5 g
      Grasas Totales: 14.2 g
      Carbohidratos: 48.0 g
      Azúcares: 3.5 g
      Fibra dietética: 6.8 g
      Sodio: 350 mg
      ''';

      final OcrNutritionData data = ocrService.parseText(sampleLabelEs);

      expect(data.hasAnyData, isTrue);
      expect(data.kcal, equals(420.0));
      expect(data.proteinG, equals(24.5));
      expect(data.fatG, equals(14.2));
      expect(data.carbsG, equals(48.0));
      expect(data.sugarG, equals(3.5));
      expect(data.fiberG, equals(6.8));
      expect(data.sodiumMg, equals(350.0));
      expect(data.servingGrams, equals(100.0));
    });

    test('NutritionLabelOcrService: extrae macronutrientes y convierte sal a sodio en inglés', () {
      final NutritionLabelOcrService ocrService = NutritionLabelOcrService();

      const String sampleLabelEn = '''
      Nutrition Facts
      Serving size: 50 g
      Calories: 210
      Total Fat: 8g
      Carbohydrate: 22g
      Proteins: 11g
      Fiber: 4g
      Salt: 1.5 g
      ''';

      final OcrNutritionData data = ocrService.parseText(sampleLabelEn);

      expect(data.hasAnyData, isTrue);
      expect(data.kcal, equals(210.0));
      expect(data.fatG, equals(8.0));
      expect(data.carbsG, equals(22.0));
      expect(data.proteinG, equals(11.0));
      expect(data.fiberG, equals(4.0));
      // 1.5g salt * 400 = 600mg sodium
      expect(data.sodiumMg, equals(600.0));
      expect(data.servingGrams, equals(50.0));
    });

    test('OpenFoodFactsService: searchProducts busca en API y persiste en SQLite local', () async {
      final AppDatabase db = AppDatabase(NativeDatabase.memory());
      final FoodDao foodDao = FoodDao(db);

      final MockClient mockHttpClient = MockClient((http.Request request) async {
        expect(request.url.queryParameters['search_terms'], equals('yogurt griego'));

        final Map<String, dynamic> mockResponse = <String, dynamic>{
          'count': 1,
          'page': 1,
          'page_size': 20,
          'products': <dynamic>[
            <String, dynamic>{
              'code': '8410000123456',
              'product_name_es': 'Yogurt Griego Natural',
              'brands': 'Lácteos Artesanales',
              'nutriscore_grade': 'a',
              'nova_group': 1,
              'nutriments': <String, dynamic>{
                'energy-kcal_100g': 115.0,
                'proteins_100g': 10.0,
                'carbohydrates_100g': 4.0,
                'fat_100g': 9.0,
                'fiber_100g': 0.0,
                'sugars_100g': 3.8,
                'sodium_100g': 0.045, // 0.045g -> 45mg
                'calcium_100g': 0.120, // 0.120g -> 120mg
              },
            },
          ],
        };

        return http.Response(
          jsonEncode(mockResponse),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });

      final OpenFoodFactsService service = OpenFoodFactsService(
        foodDao,
        httpClient: mockHttpClient,
      );

      final List<FoodItem> items =
          await service.searchProducts('yogurt griego');

      expect(items.length, equals(1));
      final FoodItem product = items.first;
      expect(product.name, equals('Yogurt Griego Natural'));
      expect(product.brand, equals('Lácteos Artesanales'));
      expect(product.nutriScore, equals('A'));
      expect(product.novaGroup, equals(1));
      expect(product.kcalPer100g, equals(115.0));
      expect(product.proteinPer100g, equals(10.0));
      expect(product.fatPer100g, equals(9.0));
      expect(product.carbsPer100g, equals(4.0));
      expect(product.sodiumMgPer100g, equals(45.0));
      expect(product.calciumMgPer100g, equals(120.0));

      // Verificar persistencia inmediata en SQLite local
      final FoodItem? localItem =
          await foodDao.getByBarcode('8410000123456');
      expect(localItem, isNotNull);
      expect(localItem!.id, equals(product.id));

      await db.close();
    });

    test('RecipeDao: guarda receta multiración (4 raciones) y calcula exactitud de macros', () async {
      final AppDatabase db = AppDatabase(NativeDatabase.memory());
      final RecipeDao recipeDao = RecipeDao(db);

      // Ingredientes
      final int arrozId = await db.into(db.foodItems).insert(
            FoodItemsCompanion.insert(
              name: 'Arroz Integral',
              source: 'test',
              kcalPer100g: 350.0,
              proteinPer100g: 7.5,
              carbsPer100g: 74.0,
              fatPer100g: 2.5,
            ),
          );

      final int polloId = await db.into(db.foodItems).insert(
            FoodItemsCompanion.insert(
              name: 'Pechuga de Pollo',
              source: 'test',
              kcalPer100g: 165.0,
              proteinPer100g: 31.0,
              carbsPer100g: 0.0,
              fatPer100g: 3.6,
            ),
          );

      // Receta para 4 platos: 400g arroz + 500g pollo
      // Totales:
      // Arroz: 400g -> 1400 kcal, 30g P, 296g C, 10g G
      // Pollo: 500g -> 825 kcal, 155g P, 0g C, 18g G
      // Total olla: 2225 kcal, 185g P, 296g C, 28g G
      // Porción (1/4): 556.25 kcal, 46.25g P, 74g C, 7g G
      final int recipeId = await recipeDao.createRecipe(
        name: 'Arroz con Pollo Meal Prep',
        defaultMealType: 'lunch',
        totalYieldServings: 4,
        ingredients: <RecipeIngredientDraft>[
          RecipeIngredientDraft(foodItemId: arrozId, rawGrams: 400.0),
          RecipeIngredientDraft(foodItemId: polloId, rawGrams: 500.0),
        ],
      );

      final Recipe? recipe = await recipeDao.getRecipeById(recipeId);
      expect(recipe, isNotNull);
      expect(recipe!.totalYieldServings, equals(4));
      expect(recipe.kcalPerServing, closeTo(556.25, 0.1));
      expect(recipe.proteinPerServing, closeTo(46.25, 0.1));
      expect(recipe.carbsPerServing, closeTo(74.0, 0.1));
      expect(recipe.fatPerServing, closeTo(7.0, 0.1));

      await db.close();
    });
  });
}
