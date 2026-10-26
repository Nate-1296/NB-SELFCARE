import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_database.dart';

/// Registro de comida consumida combinado con los metadatos de su alimento (JOIN).
class FoodLogWithItem {
  const FoodLogWithItem({
    required this.log,
    this.foodItem,
  });

  final FoodLog log;
  final FoodItem? foodItem;
}

/// Ingrediente resuelto dentro de una plantilla de combo casero.
class MealComboIngredientDetail {
  const MealComboIngredientDetail({
    required this.foodItem,
    required this.baseGrams,
  });

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

/// DAO especializado en el catálogo de alimentos, búsqueda FTS5 y registro de comidas.
class FoodDao {
  FoodDao(this._db);

  final AppDatabase _db;

  /// Búsqueda Full-Text Search (FTS5) insensible a tildes y diacríticos.
  ///
  /// Conserva letras Unicode (á, é, í, ó, ú, ü, ñ) y filtra operadores reservados
  /// de FTS5, transformando cada palabra en un prefijo `token*` para autocompletado en < 2ms.
  Future<List<FoodItem>> searchFood(String query, {int limit = 25}) async {
    final String cleaned = query
        .trim()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ');
    const Set<String> ftsOperators = <String>{'AND', 'OR', 'NOT', 'NEAR'};
    final List<String> tokens = cleaned
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty && !ftsOperators.contains(t.toUpperCase()))
        .toList();

    if (tokens.isEmpty) {
      return (_db.select(_db.foodItems)
            ..orderBy([
              (tbl) => OrderingTerm.desc(tbl.isFavorite),
              (tbl) => OrderingTerm.desc(tbl.lastUsedAt),
              (tbl) => OrderingTerm.asc(tbl.name),
            ])
            ..limit(limit))
          .get();
    }

    final String ftsQuery = tokens.map((t) => '$t*').join(' ');

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

  /// Consulta combinada por FTS5 + filtros de favoritos o creados por el usuario.
  Future<List<FoodItem>> filterCatalog({
    String query = '',
    bool onlyFavorites = false,
    bool onlyCustom = false,
    int limit = 40,
  }) async {
    final String trimmed = query.trim();
    if (trimmed.isNotEmpty) {
      final List<FoodItem> ftsItems =
          await searchFood(trimmed, limit: limit * 2);
      return ftsItems
          .where((item) {
            if (onlyFavorites && !item.isFavorite) return false;
            if (onlyCustom && item.source != 'user_custom') return false;
            return true;
          })
          .take(limit)
          .toList();
    }

    final selectQuery = _db.select(_db.foodItems);
    if (onlyFavorites && onlyCustom) {
      selectQuery.where(
        (tbl) => tbl.isFavorite.equals(true) & tbl.source.equals('user_custom'),
      );
    } else if (onlyFavorites) {
      selectQuery.where((tbl) => tbl.isFavorite.equals(true));
    } else if (onlyCustom) {
      selectQuery.where((tbl) => tbl.source.equals('user_custom'));
    }

    selectQuery
      ..orderBy([
        (tbl) => OrderingTerm.desc(tbl.isFavorite),
        (tbl) => OrderingTerm.desc(tbl.lastUsedAt),
        (tbl) => OrderingTerm.asc(tbl.name),
      ])
      ..limit(limit);

    return selectQuery.get();
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

  /// Restaura un registro de comida previamente eliminado (flujo Deshacer).
  Future<int> restoreFoodLog(FoodLog log) {
    return _db.into(_db.foodLogs).insert(
          FoodLogsCompanion(
            dateKey: Value(log.dateKey),
            loggedAt: Value(log.loggedAt),
            mealType: Value(log.mealType),
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
  }

  /// Actualiza los gramos y/o el bloque horario de un registro existente recalculando nutrientes.
  Future<void> updateFoodLogEntry({
    required FoodLog existingLog,
    FoodItem? food,
    required double newGrams,
    String? mealType,
  }) async {
    final double safeGrams = newGrams.clamp(1.0, 5000.0);
    final query = _db.update(_db.foodLogs)
      ..where((tbl) => tbl.id.equals(existingLog.id));

    if (food != null) {
      final double ratio = safeGrams / 100.0;
      final double portionMult = food.defaultServingGrams > 0
          ? safeGrams / food.defaultServingGrams
          : 1.0;

      await query.write(
        FoodLogsCompanion(
          mealType: mealType != null ? Value(mealType) : const Value.absent(),
          gramsConsumed: Value(safeGrams),
          portionMultiplier:
              Value(double.parse(portionMult.toStringAsFixed(2))),
          totalKcal: Value(
              double.parse((food.kcalPer100g * ratio).toStringAsFixed(1))),
          totalProteinG: Value(
              double.parse((food.proteinPer100g * ratio).toStringAsFixed(1))),
          totalCarbsG: Value(
              double.parse((food.carbsPer100g * ratio).toStringAsFixed(1))),
          totalFatG:
              Value(double.parse((food.fatPer100g * ratio).toStringAsFixed(1))),
          totalFiberG: Value(
              double.parse((food.fiberPer100g * ratio).toStringAsFixed(1))),
          totalSodiumMg: Value(
              double.parse((food.sodiumMgPer100g * ratio).toStringAsFixed(1))),
          totalPotassiumMg: Value(double.parse(
              (food.potassiumMgPer100g * ratio).toStringAsFixed(1))),
          totalMagnesiumMg: Value(double.parse(
              (food.magnesiumMgPer100g * ratio).toStringAsFixed(1))),
        ),
      );
      return;
    }

    final double scale = existingLog.gramsConsumed > 0
        ? safeGrams / existingLog.gramsConsumed
        : 1.0;
    await query.write(
      FoodLogsCompanion(
        mealType: mealType != null ? Value(mealType) : const Value.absent(),
        gramsConsumed: Value(safeGrams),
        portionMultiplier: Value(
          double.parse((existingLog.portionMultiplier * scale).toStringAsFixed(2)),
        ),
        totalKcal:
            Value(double.parse((existingLog.totalKcal * scale).toStringAsFixed(1))),
        totalProteinG: Value(
            double.parse((existingLog.totalProteinG * scale).toStringAsFixed(1))),
        totalCarbsG: Value(
            double.parse((existingLog.totalCarbsG * scale).toStringAsFixed(1))),
        totalFatG:
            Value(double.parse((existingLog.totalFatG * scale).toStringAsFixed(1))),
        totalFiberG: Value(
            double.parse((existingLog.totalFiberG * scale).toStringAsFixed(1))),
        totalSodiumMg: Value(
            double.parse((existingLog.totalSodiumMg * scale).toStringAsFixed(1))),
        totalPotassiumMg: Value(double.parse(
            (existingLog.totalPotassiumMg * scale).toStringAsFixed(1))),
        totalMagnesiumMg: Value(double.parse(
            (existingLog.totalMagnesiumMg * scale).toStringAsFixed(1))),
      ),
    );
  }

  /// Marca o desmarca un alimento como favorito para priorizarlo en búsquedas FTS5.
  Future<void> toggleFavorite(int foodId, bool isFavorite) async {
    final query = _db.update(_db.foodItems)
      ..where((tbl) => tbl.id.equals(foodId));
    await query.write(FoodItemsCompanion(isFavorite: Value(isFavorite)));
  }

  /// Elimina una plantilla de combo casero y sus ingredientes asociados.
  Future<void> deleteCombo(int comboId) async {
    await _db.transaction(() async {
      await (_db.delete(_db.mealComboItems)
            ..where((tbl) => tbl.comboId.equals(comboId)))
          .go();
      await (_db.delete(_db.mealCombos)
            ..where((tbl) => tbl.id.equals(comboId)))
          .go();
    });
  }

  /// Obtiene el contexto nutricional reciente (sodio y carbohidratos de ayer + promedio 7d)
  /// para alimentar el detector fisiológico de retención hídrica / supercompensación de glucógeno.
  Future<({int? yesterdaySodiumMg, double? yesterdayCarbsG, double? avg7dCarbsG})>
      getRetentionNutritionContext(String todayDateKey) async {
    final DateTime? parsedToday = DateTime.tryParse(todayDateKey);
    final DateTime refDate = parsedToday ?? DateTime.now();
    String fmtDate(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final String yesterdayKey =
        fmtDate(refDate.subtract(const Duration(days: 1)));
    final String eightDaysAgoKey =
        fmtDate(refDate.subtract(const Duration(days: 8)));

    final yesterdayRows = await _db.customSelect(
      '''
      SELECT SUM(total_sodium_mg) AS sodium, SUM(total_carbs_g) AS carbs
      FROM food_logs
      WHERE date_key = ?
      ''',
      variables: [Variable.withString(yesterdayKey)],
      readsFrom: {_db.foodLogs},
    ).get();

    int? yesterdaySodiumMg;
    double? yesterdayCarbsG;
    if (yesterdayRows.isNotEmpty) {
      final double? rawSodium = yesterdayRows.first.readNullable<double>('sodium');
      final double? rawCarbs = yesterdayRows.first.readNullable<double>('carbs');
      if (rawSodium != null) yesterdaySodiumMg = rawSodium.round();
      if (rawCarbs != null) yesterdayCarbsG = rawCarbs;
    }

    final avgRows = await _db.customSelect(
      '''
      SELECT AVG(daily_carbs) AS avg_carbs
      FROM (
        SELECT date_key, SUM(total_carbs_g) AS daily_carbs
        FROM food_logs
        WHERE date_key >= ? AND date_key < ?
        GROUP BY date_key
        HAVING daily_carbs > 0
      )
      ''',
      variables: [
        Variable.withString(eightDaysAgoKey),
        Variable.withString(yesterdayKey),
      ],
      readsFrom: {_db.foodLogs},
    ).get();

    double? avg7dCarbsG;
    if (avgRows.isNotEmpty) {
      avg7dCarbsG = avgRows.first.readNullable<double>('avg_carbs');
    }

    return (
      yesterdaySodiumMg: yesterdaySodiumMg,
      yesterdayCarbsG: yesterdayCarbsG,
      avg7dCarbsG: avg7dCarbsG,
    );
  }

  /// Emite en vivo todas las comidas registradas para una fecha dada (YYYY-MM-DD).
  Stream<List<FoodLog>> watchLogsForDate(String dateKey) {
    return (_db.select(_db.foodLogs)
          ..where((tbl) => tbl.dateKey.equals(dateKey))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.loggedAt)]))
        .watch();
  }

  /// Obtiene de forma asíncrona todas las comidas registradas para una fecha dada.
  Future<List<FoodLog>> getLogsForDate(String dateKey) {
    return (_db.select(_db.foodLogs)
          ..where((tbl) => tbl.dateKey.equals(dateKey))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.loggedAt)]))
        .get();
  }

  /// Emite en vivo todas las comidas registradas para una fecha dada junto con su alimento mediante JOIN.
  Stream<List<FoodLogWithItem>> watchLogsWithItemForDate(String dateKey) {
    final query = _db.select(_db.foodLogs).join([
      leftOuterJoin(_db.foodItems, _db.foodItems.id.equalsExp(_db.foodLogs.foodItemId)),
    ])
      ..where(_db.foodLogs.dateKey.equals(dateKey))
      ..orderBy([OrderingTerm.asc(_db.foodLogs.loggedAt)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return FoodLogWithItem(
          log: row.readTable(_db.foodLogs),
          foodItem: row.readTableOrNull(_db.foodItems),
        );
      }).toList();
    });
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

  /// Emite los combos caseros con sus ingredientes y totales base (1.0x) en tiempo real.
  Stream<List<MealComboWithDetails>> watchMealCombosWithDetails() {
    final combosQuery = _db.select(_db.mealCombos)
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.timesUsed)]);

    return combosQuery.watch().asyncMap((combos) async {
      if (combos.isEmpty) return const <MealComboWithDetails>[];

      final List<MealComboWithDetails> out = <MealComboWithDetails>[];
      for (final combo in combos) {
        final joinedRows = await (_db.select(_db.mealComboItems).join([
          innerJoin(
            _db.foodItems,
            _db.foodItems.id.equalsExp(_db.mealComboItems.foodItemId),
          ),
        ])
              ..where(_db.mealComboItems.comboId.equals(combo.id)))
            .get();

        final List<MealComboIngredientDetail> ingredients =
            <MealComboIngredientDetail>[];
        double baseKcal = 0.0;
        double baseP = 0.0;
        double baseC = 0.0;
        double baseF = 0.0;

        for (final row in joinedRows) {
          final item = row.readTable(_db.mealComboItems);
          final food = row.readTable(_db.foodItems);
          final double ratio = item.baseGrams / 100.0;
          baseKcal += food.kcalPer100g * ratio;
          baseP += food.proteinPer100g * ratio;
          baseC += food.carbsPer100g * ratio;
          baseF += food.fatPer100g * ratio;
          ingredients.add(
            MealComboIngredientDetail(
              foodItem: food,
              baseGrams: item.baseGrams,
            ),
          );
        }

        out.add(
          MealComboWithDetails(
            combo: combo,
            ingredients: ingredients,
            baseKcal: baseKcal,
            baseProteinG: baseP,
            baseCarbsG: baseC,
            baseFatG: baseF,
          ),
        );
      }
      return out;
    });
  }

  /// Emite en vivo el conjunto de fechas (YYYY-MM-DD) dentro de un rango que tienen registros.
  Stream<Set<String>> watchLoggedDateKeysInRange(
    String startDateKey,
    String endDateKey,
  ) {
    return _db
        .customSelect(
          '''
          SELECT DISTINCT date_key FROM food_logs
          WHERE date_key >= ? AND date_key <= ?
          ''',
          variables: [
            Variable.withString(startDateKey),
            Variable.withString(endDateKey),
          ],
          readsFrom: {_db.foodLogs},
        )
        .watch()
        .map((rows) => rows.map((r) => r.read<String>('date_key')).toSet());
  }

  /// Registra una porción exacta de un [FoodItem] y actualiza su marca `lastUsedAt`.
  Future<int> logFoodItemPortion({
    required FoodItem food,
    required double grams,
    required String dateKey,
    required String mealType,
  }) async {
    final double safeGrams = grams.clamp(1.0, 5000.0);
    final double ratio = safeGrams / 100.0;
    final double portionMult = food.defaultServingGrams > 0
        ? safeGrams / food.defaultServingGrams
        : 1.0;
    final DateTime now = DateTime.now();

    return _db.transaction(() async {
      final int logId = await _db.into(_db.foodLogs).insert(
            FoodLogsCompanion(
              dateKey: Value(dateKey),
              loggedAt: Value(now),
              mealType: Value(mealType),
              foodItemId: Value(food.id),
              gramsConsumed: Value(safeGrams),
              portionMultiplier:
                  Value(double.parse(portionMult.toStringAsFixed(2))),
              totalKcal: Value(
                  double.parse((food.kcalPer100g * ratio).toStringAsFixed(1))),
              totalProteinG: Value(double.parse(
                  (food.proteinPer100g * ratio).toStringAsFixed(1))),
              totalCarbsG: Value(
                  double.parse((food.carbsPer100g * ratio).toStringAsFixed(1))),
              totalFatG: Value(
                  double.parse((food.fatPer100g * ratio).toStringAsFixed(1))),
              totalFiberG: Value(
                  double.parse((food.fiberPer100g * ratio).toStringAsFixed(1))),
              totalSodiumMg: Value(double.parse(
                  (food.sodiumMgPer100g * ratio).toStringAsFixed(1))),
              totalPotassiumMg: Value(double.parse(
                  (food.potassiumMgPer100g * ratio).toStringAsFixed(1))),
              totalMagnesiumMg: Value(double.parse(
                  (food.magnesiumMgPer100g * ratio).toStringAsFixed(1))),
            ),
          );

      await (_db.update(_db.foodItems)..where((tbl) => tbl.id.equals(food.id)))
          .write(FoodItemsCompanion(lastUsedAt: Value(now)));

      return logId;
    });
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
