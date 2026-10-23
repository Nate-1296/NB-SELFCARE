import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_database.dart';

/// DAO especializado en el catálogo de alimentos, búsqueda FTS5 y registro de comidas.
class FoodDao {
  FoodDao(this._db);

  final AppDatabase _db;

  /// Búsqueda Full-Text Search (FTS5) insensible a tildes y diacríticos.
  ///
  /// Transforma "platano" en "platano*" para autocompletado en < 2ms.
  Future<List<FoodItem>> searchFood(String query, {int limit = 25}) async {
    final String sanitized = query.trim().replaceAll(RegExp(r'[^\w\s]'), '');
    if (sanitized.isEmpty) {
      return (_db.select(_db.foodItems)
            ..orderBy([(tbl) => OrderingTerm.desc(tbl.isFavorite)])
            ..limit(limit))
          .get();
    }

    final String ftsQuery = '$sanitized*';

    final searchResults = await _db.customSelect(
      '''
      SELECT f.* FROM food_items f
      JOIN food_items_fts fts ON f.id = fts.rowid
      WHERE food_items_fts MATCH ?
      ORDER BY f.is_favorite DESC, rank
      LIMIT ?
      ''',
      variables: [
        Variable.withString(ftsQuery),
        Variable.withInt(limit),
      ],
      readsFrom: {_db.foodItems},
    ).get();

    return searchResults.map((row) => _db.foodItems.map(row.data)).toList();
  }

  /// Busca un alimento por código de barras EAN-13 / UPC en el catálogo local.
  Future<FoodItem?> getByBarcode(String barcode) {
    return (_db.select(_db.foodItems)..where((tbl) => tbl.barcode.equals(barcode)))
        .getSingleOrNull();
  }

  /// Obtiene un alimento por su clave primaria ID.
  Future<FoodItem?> getById(int id) {
    return (_db.select(_db.foodItems)..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  /// Guarda un nuevo alimento (proveniente de Open Food Facts o alta manual).
  Future<int> insertFood(FoodItemsCompanion companion) {
    return _db.into(_db.foodItems).insert(companion);
  }

  /// Registra una porción consumida en food_logs con totales desnormalizados.
  Future<int> logFood(FoodLogsCompanion companion) {
    return _db.into(_db.foodLogs).insert(companion);
  }

  /// Elimina un registro de comida por su ID.
  Future<int> deleteFoodLog(int logId) {
    return (_db.delete(_db.foodLogs)..where((tbl) => tbl.id.equals(logId))).go();
  }

  /// Emite en vivo todas las comidas registradas para una fecha dada (YYYY-MM-DD).
  Stream<List<FoodLog>> watchLogsForDate(String dateKey) {
    return (_db.select(_db.foodLogs)
          ..where((tbl) => tbl.dateKey.equals(dateKey))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.loggedAt)]))
        .watch();
  }

  /// Obtiene los registros de un bloque horario en una fecha (ej. desayuno de ayer).
  Future<List<FoodLog>> getLogsForDateAndMeal(String dateKey, String mealType) {
    return (_db.select(_db.foodLogs)
          ..where((tbl) => tbl.dateKey.equals(dateKey) & tbl.mealType.equals(mealType)))
        .get();
  }

  /// Flujo < 15 segundos: "Repetir comida de ayer".
  ///
  /// Copia en 1 sola transacción atómica todos los alimentos del bloque del día anterior.
  Future<List<int>> repeatMealFromYesterday({
    required String fromDateKey,
    required String toDateKey,
    required String mealType,
  }) async {
    final List<FoodLog> pastLogs = await getLogsForDateAndMeal(fromDateKey, mealType);
    if (pastLogs.isEmpty) return [];

    final now = DateTime.now();
    final List<int> newIds = [];

    await _db.transaction(() async {
      for (final log in pastLogs) {
        final id = await _db.into(_db.foodLogs).insert(
              FoodLogsCompanion(
                dateKey: Value(toDateKey),
                loggedAt: Value(now),
                mealType: Value(mealType),
                foodItemId: Value(log.foodItemId),
                gramsConsumed: Value(log.gramsConsumed),
                portionMultiplier: Value(log.portionMultiplier),
                totalKcal: Value(log.totalKcal),
                totalProteinG: Value(log.totalProteinG),
                totalCarbsG: Value(log.totalCarbsG),
                totalFatG: Value(log.totalFatG),
                totalFiberG: Value(log.totalFiberG),
                totalSodiumMg: Value(log.totalSodiumMg),
                totalPotassiumMg: Value(log.totalPotassiumMg),
                totalMagnesiumMg: Value(log.totalMagnesiumMg),
              ),
            );
        newIds.add(id);
      }
    });

    return newIds;
  }

  /// Emite la lista de plantillas de combos caseros guardados.
  Stream<List<MealCombo>> watchMealCombos() {
    return (_db.select(_db.mealCombos)
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.timesUsed)]))
        .watch();
  }

  /// Crea una nueva plantilla de combo casero con sus ingredientes y gramos base.
  Future<int> createCombo({
    required String name,
    required String defaultMealType,
    required List<MapEntry<int, double>> itemsWithGrams,
  }) async {
    return _db.transaction(() async {
      final comboId = await _db.into(_db.mealCombos).insert(
            MealCombosCompanion(
              name: Value(name),
              defaultMealType: Value(defaultMealType),
            ),
          );

      for (final entry in itemsWithGrams) {
        await _db.into(_db.mealComboItems).insert(
              MealComboItemsCompanion(
                comboId: Value(comboId),
                foodItemId: Value(entry.key),
                baseGrams: Value(entry.value),
              ),
            );
      }

      return comboId;
    });
  }

  /// Registra un combo escalado proporcionalmente (0.25x - 3.0x) en food_logs.
  Future<List<int>> logCombo({
    required int comboId,
    required double multiplier,
    required String dateKey,
    required String mealType,
  }) async {
    return _db.transaction(() async {
      // 1. Obtener ingredientes del combo
      final items = await (_db.select(_db.mealComboItems)
            ..where((tbl) => tbl.comboId.equals(comboId)))
          .get();

      final now = DateTime.now();
      final List<int> loggedIds = [];

      for (final item in items) {
        final food = await (_db.select(_db.foodItems)
              ..where((tbl) => tbl.id.equals(item.foodItemId)))
            .getSingleOrNull();

        if (food == null) continue;

        final double effectiveGrams = item.baseGrams * multiplier;
        final double ratio = effectiveGrams / 100.0;

        final logId = await _db.into(_db.foodLogs).insert(
              FoodLogsCompanion(
                dateKey: Value(dateKey),
                loggedAt: Value(now),
                mealType: Value(mealType),
                foodItemId: Value(food.id),
                gramsConsumed: Value(effectiveGrams),
                portionMultiplier: Value(multiplier),
                totalKcal: Value(double.parse((food.kcalPer100g * ratio).toStringAsFixed(1))),
                totalProteinG: Value(double.parse((food.proteinPer100g * ratio).toStringAsFixed(1))),
                totalCarbsG: Value(double.parse((food.carbsPer100g * ratio).toStringAsFixed(1))),
                totalFatG: Value(double.parse((food.fatPer100g * ratio).toStringAsFixed(1))),
                totalFiberG: Value(double.parse((food.fiberPer100g * ratio).toStringAsFixed(1))),
                totalSodiumMg: Value(double.parse((food.sodiumMgPer100g * ratio).toStringAsFixed(1))),
                totalPotassiumMg: Value(double.parse((food.potassiumMgPer100g * ratio).toStringAsFixed(1))),
                totalMagnesiumMg: Value(double.parse((food.magnesiumMgPer100g * ratio).toStringAsFixed(1))),
              ),
            );

        loggedIds.add(logId);
      }

      // Incrementar contador de uso del combo
      final combo = await (_db.select(_db.mealCombos)
            ..where((tbl) => tbl.id.equals(comboId)))
          .getSingleOrNull();
      if (combo != null) {
        final query = _db.update(_db.mealCombos)..where((tbl) => tbl.id.equals(comboId));
        await query.write(MealCombosCompanion(timesUsed: Value(combo.timesUsed + 1)));
      }

      return loggedIds;
    });
  }
}

/// Provider de Riverpod para inyectar FoodDao.
final foodDaoProvider = Provider<FoodDao>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return FoodDao(db);
});
