import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../database/app_database.dart';
import '../database/daos/food_dao.dart';

/// Servicio de resolución de códigos de barras (EAN-13, UPC) mediante Open Food Facts
/// con política inquebrantable de persistencia inmediata en SQLite local (FTS5).
///
/// Cumple estrictamente `AGENTS.md` §1.1: la única llamada HTTP permitida en toda la app
/// es la resolución puntual de un código de barras no cacheado.
class OpenFoodFactsService {
  OpenFoodFactsService(this._foodDao, {http.Client? httpClient})
      : _client = httpClient ?? http.Client(),
        _ownsClient = httpClient == null;

  final FoodDao _foodDao;
  final http.Client _client;
  final bool _ownsClient;

  static const String _userAgent =
      'NBSelfcare - Android - Version 0.1.0 - 100% Offline-First Health Sanctuary';

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

    // 2. Consulta puntual a Open Food Facts API v2
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
      final String name = _nonEmptyOrNull(product['product_name_es'] as String?) ??
          _nonEmptyOrNull(product['product_name'] as String?) ??
          _nonEmptyOrNull(product['generic_name'] as String?) ??
          'Producto $cleanBarcode';

      final String? brand = _nonEmptyOrNull(product['brands'] as String?);
      final String? nutriScore =
          _nonEmptyOrNull(product['nutriscore_grade'] as String?)?.toUpperCase();

      // Normalización a 100g
      final double kcal = _extractNum(nutriments, 'energy-kcal_100g') ??
          ((_extractNum(nutriments, 'energy_100g') ?? 0.0) / 4.184);

      final double protein = _extractNum(nutriments, 'proteins_100g') ?? 0.0;
      final double carbs = _extractNum(nutriments, 'carbohydrates_100g') ?? 0.0;
      final double fat = _extractNum(nutriments, 'fat_100g') ?? 0.0;
      final double? fiber = _extractNum(nutriments, 'fiber_100g');
      final double? sugars = _extractNum(nutriments, 'sugars_100g');

      // Minerales y Triángulo de Electrolitos (normalizados a miligramos por 100g)
      double? sodiumMg = _extractNum(nutriments, 'sodium_100g');
      if (sodiumMg != null) {
        if (sodiumMg < 25.0) {
          sodiumMg *= 1000.0; // OFF reporta sodio en gramos -> convertir a mg
        }
      } else {
        final double? saltG = _extractNum(nutriments, 'salt_100g');
        if (saltG != null) {
          sodiumMg = saltG * 400.0; // 1g sal ≈ 400mg sodio
        }
      }

      final double? potassiumMg = _normalizeGramsToMg(
        _extractNum(nutriments, 'potassium_100g'),
        gramsThreshold: 10.0,
      );
      final double? magnesiumMg = _normalizeGramsToMg(
        _extractNum(nutriments, 'magnesium_100g'),
        gramsThreshold: 5.0,
      );
      final double? calciumMg = _normalizeGramsToMg(
        _extractNum(nutriments, 'calcium_100g'),
        gramsThreshold: 10.0,
      );
      final double? ironMg = _normalizeGramsToMg(
        _extractNum(nutriments, 'iron_100g'),
        gramsThreshold: 1.0,
      );
      final double? vitaminCMg = _normalizeGramsToMg(
        _extractNum(nutriments, 'vitamin-c_100g'),
        gramsThreshold: 5.0,
      );

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
        sugarPer100g: drift.Value(sugars ?? 0.0),
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

  /// Cierra el cliente HTTP subyacente cuando el proveedor se destruye.
  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  String? _nonEmptyOrNull(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  double? _normalizeGramsToMg(double? value, {required double gramsThreshold}) {
    if (value == null) return null;
    if (value > 0 && value < gramsThreshold) {
      return double.parse((value * 1000.0).toStringAsFixed(1));
    }
    return double.parse(value.toStringAsFixed(1));
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
  final service = OpenFoodFactsService(foodDao);
  ref.onDispose(service.dispose);
  return service;
});
