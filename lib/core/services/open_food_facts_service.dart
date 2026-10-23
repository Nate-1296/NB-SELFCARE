import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../database/app_database.dart';
import '../database/daos/food_dao.dart';

/// Servicio de resolución de códigos de barras (EAN-13, UPC) mediante Open Food Facts
/// con política inquebrantable de persistencia inmediata en SQLite local (FTS5).
class OpenFoodFactsService {
  OpenFoodFactsService(this._foodDao, {http.Client? httpClient})
      : _client = httpClient ?? http.Client();

  final FoodDao _foodDao;
  final http.Client _client;

  static const String _userAgent =
      'NBSelfcare - Android - Version 1.0.0 - 100% Offline-First Health Sanctuary';

  /// Resuelve un código de barras. Busca primero en la caché local SQLite.
  /// Si no existe, consulta la API de Open Food Facts, normaliza a 100g,
  /// guarda inmediatamente en SQLite (activando triggers FTS5) y retorna el alimento.
  Future<FoodItem?> resolveBarcode(String barcode) async {
    final String cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty) return null;

    // 1. Consulta en caché SQLite local
    final FoodItem? cached = await _foodDao.getByBarcode(cleanBarcode);
    if (cached != null) {
      return cached;
    }

    // 2. Consulta a Open Food Facts API v2
    try {
      final uri = Uri.parse(
        'https://world.openfoodfacts.org/api/v2/product/$cleanBarcode.json',
      );

      final response = await _client.get(
        uri,
        headers: {'User-Agent': _userAgent},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode != 200) return null;

      final Map<String, dynamic> json =
          jsonDecode(response.body) as Map<String, dynamic>;

      final int status = (json['status'] as num?)?.toInt() ?? 0;
      if (status != 1 || json['product'] == null) {
        return null;
      }

      final Map<String, dynamic> product =
          json['product'] as Map<String, dynamic>;
      final Map<String, dynamic> nutriments =
          (product['nutriments'] as Map<String, dynamic>?) ?? {};

      // Extracción de metadatos básicos
      final String name = (product['product_name_es'] as String?)?.trim() ??
          (product['product_name'] as String?)?.trim() ??
          (product['generic_name'] as String?)?.trim() ??
          'Producto $cleanBarcode';

      final String? brand = (product['brands'] as String?)?.trim();
      final String? nutriScore =
          (product['nutriscore_grade'] as String?)?.toUpperCase();

      // Normalización a 100g
      final double kcal = _extractNum(nutriments, 'energy-kcal_100g') ??
          ((_extractNum(nutriments, 'energy_100g') ?? 0.0) / 4.184);

      final double protein = _extractNum(nutriments, 'proteins_100g') ?? 0.0;
      final double carbs = _extractNum(nutriments, 'carbohydrates_100g') ?? 0.0;
      final double fat = _extractNum(nutriments, 'fat_100g') ?? 0.0;
      final double? fiber = _extractNum(nutriments, 'fiber_100g');

      // Minerales y Triángulo de Electrolitos (Sodio en mg, Potasio en mg, Magnesio en mg)
      double? sodiumMg = _extractNum(nutriments, 'sodium_100g');
      if (sodiumMg != null) {
        sodiumMg *= 1000.0; // OFF reporta sodio en gramos -> convertir a mg
      } else {
        final double? saltG = _extractNum(nutriments, 'salt_100g');
        if (saltG != null) {
          sodiumMg = saltG * 400.0; // 1g sal aprox 400mg sodio
        }
      }

      double? potassiumMg = _extractNum(nutriments, 'potassium_100g');
      if (potassiumMg != null && potassiumMg < 10.0) {
        potassiumMg *= 1000.0; // Normalizar si viene en g
      }

      double? magnesiumMg = _extractNum(nutriments, 'magnesium_100g');
      if (magnesiumMg != null && magnesiumMg < 5.0) {
        magnesiumMg *= 1000.0;
      }

      final double? calciumMg = _extractNum(nutriments, 'calcium_100g');
      final double? ironMg = _extractNum(nutriments, 'iron_100g');
      final double? vitaminCMg = _extractNum(nutriments, 'vitamin-c_100g');

      final companion = FoodItemsCompanion(
        barcode: drift.Value(cleanBarcode),
        name: drift.Value(name),
        brand: drift.Value(brand),
        source: const drift.Value('open_food_facts'),
        nutriScore: drift.Value(nutriScore),
        defaultServingGrams: const drift.Value(100.0),
        servingLabel: const drift.Value('100g'),
        kcalPer100g: drift.Value(double.parse(kcal.toStringAsFixed(1))),
        proteinPer100g: drift.Value(double.parse(protein.toStringAsFixed(1))),
        carbsPer100g: drift.Value(double.parse(carbs.toStringAsFixed(1))),
        fatPer100g: drift.Value(double.parse(fat.toStringAsFixed(1))),
        fiberPer100g: drift.Value(fiber ?? 0.0),
        sugarPer100g: const drift.Value(0.0),
        sodiumMgPer100g: drift.Value(sodiumMg ?? 0.0),
        potassiumMgPer100g: drift.Value(potassiumMg ?? 0.0),
        magnesiumMgPer100g: drift.Value(magnesiumMg ?? 0.0),
        calciumMgPer100g: drift.Value(calciumMg ?? 0.0),
        ironMgPer100g: drift.Value(ironMg ?? 0.0),
        zincMgPer100g: const drift.Value(0.0),
        vitaminCMgPer100g: drift.Value(vitaminCMg ?? 0.0),
        vitaminDUgPer100g: const drift.Value(0.0),
        vitaminB12UgPer100g: const drift.Value(0.0),
      );

      // Persistir inmediatamente en SQLite
      final int id = await _foodDao.insertFood(companion);
      return await _foodDao.getById(id);
    } catch (_) {
      return null;
    }
  }

  double? _extractNum(Map<String, dynamic> map, String key) {
    final dynamic val = map[key];
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val);
    return null;
  }
}

/// Provider de Riverpod para inyectar OpenFoodFactsService.
final openFoodFactsServiceProvider = Provider<OpenFoodFactsService>((ref) {
  final foodDao = ref.watch(foodDaoProvider);
  return OpenFoodFactsService(foodDao);
});
