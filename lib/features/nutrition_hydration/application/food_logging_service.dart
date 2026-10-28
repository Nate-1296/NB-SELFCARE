import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock/clock.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/food_dao.dart';
import '../../../core/database/daos/recipe_dao.dart';
import '../../../core/domain/enums.dart';
import '../../../core/services/text_assistant.dart';
import '../../../shared/utils/date_time_extensions.dart';
import '../../pet_gamification/application/reward_service.dart';
import '../../pet_gamification/domain/reward_policy.dart';

/// Resultado de un registro de comida: filas creadas y monedas otorgadas.
class FoodLogResult {
  const FoodLogResult({required this.logIds, required this.coins});

  final List<int> logIds;

  /// Monedas ganadas con este registro (0 si la comida ya había sumado hoy).
  final int coins;

  bool get isEmpty => logIds.isEmpty;
}

/// Casos de uso de registro nutricional (docs/05): porción, combo, receta,
/// "repetir ayer" y edición/borrado con Deshacer. Cada registro de desayuno,
/// almuerzo o cena otorga sus monedas una vez al día (`RewardPolicy`).
class FoodLoggingService {
  FoodLoggingService(this._db, this._foodDao, this._recipeDao, this._rewards, this._clock);

  final AppDatabase _db;
  final FoodDao _foodDao;
  final RecipeDao _recipeDao;
  final RewardService _rewards;
  final Clock _clock;

  Future<FoodLogResult> logPortion({
    required FoodItem food,
    required double grams,
    required MealType mealType,
    required String dateKey,
  }) {
    return _logAndReward(mealType, dateKey, () async {
      final int id = await _foodDao.logFoodItemPortion(
        food: food,
        grams: grams,
        dateKey: dateKey,
        mealType: mealType,
      );
      return <int>[id];
    });
  }

  Future<FoodLogResult> logCombo({
    required int comboId,
    required double multiplier,
    required MealType mealType,
    required String dateKey,
  }) {
    return _logAndReward(mealType, dateKey, () {
      return _foodDao.logCombo(
        comboId: comboId,
        multiplier: multiplier,
        dateKey: dateKey,
        mealType: mealType,
      );
    });
  }

  /// Registra 1 ración de una receta casera. La receta se materializa como un
  /// alimento del catálogo donde "100 g" equivale a 1 ración.
  Future<FoodLogResult> logRecipeServing({
    required Recipe recipe,
    required MealType mealType,
    required String dateKey,
  }) {
    return _logAndReward(mealType, dateKey, () async {
      final String barcode = 'RECIPE_${recipe.id}';
      FoodItem? food = await _foodDao.getByBarcode(barcode);
      if (food == null) {
        final int foodId = await _foodDao.insertFood(
          FoodItemsCompanion.insert(
            barcode: Value(barcode),
            name: recipe.name,
            brand: const Value('Receta casera'),
            source: FoodSource.userCustom,
            defaultServingGrams: const Value(100.0),
            servingLabel: const Value('1 ración'),
            kcalPer100g: recipe.kcalPerServing,
            proteinPer100g: recipe.proteinPerServing,
            carbsPer100g: recipe.carbsPerServing,
            fatPer100g: recipe.fatPerServing,
            fiberPer100g: Value(recipe.fiberPerServing),
            sodiumMgPer100g: Value(recipe.sodiumMgPerServing),
            potassiumMgPer100g: Value(recipe.potassiumMgPerServing),
            magnesiumMgPer100g: Value(recipe.magnesiumMgPerServing),
          ),
        );
        food = await _foodDao.getById(foodId);
      }
      if (food == null) return const <int>[];

      final int id = await _foodDao.logFoodItemPortion(
        food: food,
        grams: food.defaultServingGrams,
        dateKey: dateKey,
        mealType: mealType,
      );
      await _recipeDao.touchRecipe(recipe.id);
      return <int>[id];
    });
  }

  /// Registra los alimentos extraídos de texto libre (docs/05 §5, ADR-03): cada
  /// término se enlaza con el catálogo local por FTS5; si no existe, se crea un
  /// alimento "Estimación" con los valores de respaldo para no perder el registro.
  Future<FoodLogResult> logParsedItems({
    required List<ParsedMealItem> items,
    required MealType mealType,
    required String dateKey,
  }) {
    return _logAndReward(mealType, dateKey, () async {
      final List<int> ids = <int>[];
      for (final ParsedMealItem item in items) {
        if (item.searchTerm.trim().isEmpty || item.grams <= 0) continue;
        final FoodItem? food = await _resolveFood(item);
        if (food == null) continue;
        ids.add(
          await _foodDao.logFoodItemPortion(
            food: food,
            grams: item.grams,
            dateKey: dateKey,
            mealType: mealType,
          ),
        );
      }
      return ids;
    });
  }

  Future<FoodItem?> _resolveFood(ParsedMealItem item) async {
    final List<FoodItem> matches = await _foodDao.searchFood(item.searchTerm, limit: 1);
    if (matches.isNotEmpty) return matches.first;
    final int id = await _foodDao.insertFood(
      FoodItemsCompanion.insert(
        name: item.searchTerm.trim(),
        source: FoodSource.textEstimate,
        kcalPer100g: item.fallbackKcal,
        proteinPer100g: item.fallbackP,
        carbsPer100g: item.fallbackC,
        fatPer100g: item.fallbackF,
      ),
    );
    return _foodDao.getById(id);
  }

  /// Copia lo registrado ayer en cada bloque de [mealTypes] (por defecto, todos).
  Future<FoodLogResult> repeatYesterday({
    required String toDateKey,
    List<MealType> mealTypes = MealType.values,
  }) async {
    final DateTime? target = DateTime.tryParse(toDateKey);
    final String fromDateKey =
        (target ?? _clock.now()).addDays(-1).dateKey;

    final List<int> ids = <int>[];
    int coins = 0;
    for (final MealType meal in mealTypes) {
      final FoodLogResult result = await _logAndReward(meal, toDateKey, () {
        return _foodDao.repeatMealFromYesterday(
          fromDateKey: fromDateKey,
          toDateKey: toDateKey,
          mealType: meal,
        );
      });
      ids.addAll(result.logIds);
      coins += result.coins;
    }
    return FoodLogResult(logIds: ids, coins: coins);
  }

  Future<void> deleteLog(int logId) => _foodDao.deleteFoodLog(logId);

  /// Guarda los alimentos de una comida como combo reutilizable.
  Future<int> saveCombo({
    required String name,
    required MealType mealType,
    required List<FoodLog> logs,
  }) {
    return _foodDao.createCombo(
      name: name,
      defaultMealType: mealType,
      itemsWithGrams: <MapEntry<int, double>>[
        for (final FoodLog l in logs) MapEntry<int, double>(l.foodItemId, l.gramsConsumed),
      ],
    );
  }

  Future<void> restoreLog(FoodLog log) => _foodDao.restoreFoodLog(log);

  /// Deshace un registro múltiple (combo, "repetir ayer").
  Future<void> deleteLogs(Iterable<int> logIds) async {
    await _db.transaction(() async {
      for (final int id in logIds) {
        await _foodDao.deleteFoodLog(id);
      }
    });
  }

  Future<FoodLogResult> _logAndReward(
    MealType mealType,
    String dateKey,
    Future<List<int>> Function() insert,
  ) {
    return _db.transaction(() async {
      final List<int> ids = await insert();
      final RewardAction? action = RewardAction.mealLogged(mealType);
      if (ids.isEmpty || action == null) return FoodLogResult(logIds: ids, coins: 0);
      final RewardGrant grant = await _rewards.grant(action, dateKey: dateKey);
      return FoodLogResult(logIds: ids, coins: grant.coins);
    });
  }
}

final foodLoggingServiceProvider = Provider<FoodLoggingService>((Ref ref) {
  return FoodLoggingService(
    ref.watch(appDatabaseProvider),
    ref.watch(foodDaoProvider),
    ref.watch(recipeDaoProvider),
    ref.watch(rewardServiceProvider),
    ref.watch(clockProvider),
  );
});
