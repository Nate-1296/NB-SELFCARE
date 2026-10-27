import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../database/app_database.dart';
import '../database/daos/food_dao.dart';
import '../domain/enums.dart';

/// Servicio de resolución de alimentos mediante Open Food Facts
/// con política inquebrantable de persistencia inmediata en SQLite local (FTS5).
///
/// Cumple estrictamente `AGENTS.md` §1.1: las llamadas HTTP son exclusivas a la API
/// pública de Open Food Facts para códigos de barras no cacheados o búsqueda de catálogo,
/// persistiendo todo resultado de forma inmediata en SQLite local.
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

    // Si es UPC-A de 12 dígitos, verificar si existe con 0 inicial (EAN-13)
    if (cleanBarcode.length == 12) {
      final FoodItem? cachedEan13 =
          await _foodDao.getByBarcode('0$cleanBarcode');
      if (cachedEan13 != null) return cachedEan13;
    }

    // 2. Consulta puntual a Open Food Facts API v2
    FoodItem? item = await _fetchProductByBarcode(cleanBarcode);
    if (item != null) return item;

    // Intento con normalización EAN-13 (0 al frente) si tiene 12 dígitos
    if (cleanBarcode.length == 12) {
      item = await _fetchProductByBarcode('0$cleanBarcode');
      if (item != null) return item;
    }

    return null;
  }

  Future<FoodItem?> _fetchProductByBarcode(String barcode) async {
    try {
      final Uri uri = Uri.parse(
        'https://world.openfoodfacts.org/api/v2/product/$barcode.json',
      );

      final http.Response response = await _client.get(
        uri,
        headers: <String, String>{'User-Agent': _userAgent},
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
      return await _parseAndPersistProduct(product, explicitBarcode: barcode);
    } catch (_) {
      return null;
    }
  }

  /// Busca productos en Open Food Facts por texto cuando la búsqueda local FTS5
  /// no arroja resultados suficientes. Cada resultado válido es cacheado en SQLite.
  Future<List<FoodItem>> searchProducts(
    String query, {
    int page = 1,
    int pageSize = 20,
  }) async {
    final String cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return <FoodItem>[];

    try {
      final Uri uri = Uri.parse(
        'https://world.openfoodfacts.org/cgi/search.pl?search_terms=${Uri.encodeComponent(cleanQuery)}&search_simple=1&action=process&json=1&page_size=$pageSize&page=$page',
      );

      final http.Response response = await _client.get(
        uri,
        headers: <String, String>{'User-Agent': _userAgent},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return <FoodItem>[];

      final Map<String, dynamic> json =
          jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic>? rawProducts = json['products'] as List<dynamic>?;
      if (rawProducts == null || rawProducts.isEmpty) return <FoodItem>[];

      final List<FoodItem> results = <FoodItem>[];

      for (final dynamic rawProd in rawProducts) {
        if (rawProd is! Map<String, dynamic>) continue;
        final FoodItem? item = await _parseAndPersistProduct(rawProd);
        if (item != null) {
          results.add(item);
        }
      }

      return results;
    } catch (_) {
      return <FoodItem>[];
    }
  }

  /// Normaliza y almacena en SQLite local un producto devuelto por Open Food Facts.
  Future<FoodItem?> _parseAndPersistProduct(
    Map<String, dynamic> product, {
    String? explicitBarcode,
  }) async {
    try {
      final String? rawCode = explicitBarcode ??
          _nonEmptyOrNull(product['code'] as String?);

      // Si tiene código de barras y ya está en base de datos local, devolverlo
      if (rawCode != null) {
        final FoodItem? existing = await _foodDao.getByBarcode(rawCode);
        if (existing != null) return existing;
      }

      final Map<String, dynamic> nutriments =
          (product['nutriments'] as Map<String, dynamic>?) ??
              <String, dynamic>{};

      // Extracción de metadatos básicos
      final String name = _nonEmptyOrNull(
            product['product_name_es'] as String?,
          ) ??
          _nonEmptyOrNull(product['product_name'] as String?) ??
          _nonEmptyOrNull(product['generic_name'] as String?) ??
          (rawCode != null ? 'Producto $rawCode' : 'Alimento');

      final String? brand = _nonEmptyOrNull(product['brands'] as String?);
      final String? nutriScore = _nonEmptyOrNull(
        product['nutriscore_grade'] as String?,
      )?.toUpperCase();
      final int? novaGroup = _extractNovaGroup(product);

      // Normalización a 100g
      final double kcal = _extractNum(nutriments, 'energy-kcal_100g') ??
          ((_extractNum(nutriments, 'energy_100g') ?? 0.0) / 4.184);

      final double protein = _extractNum(nutriments, 'proteins_100g') ?? 0.0;
      final double carbs =
          _extractNum(nutriments, 'carbohydrates_100g') ?? 0.0;
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

      final FoodItemsCompanion companion = FoodItemsCompanion(
        barcode: drift.Value(rawCode),
        name: drift.Value(name),
        brand: drift.Value(brand),
        source: const drift.Value(FoodSource.openFoodFacts),
        nutriScore: drift.Value(nutriScore),
        novaGroup: drift.Value(novaGroup),
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

      // Persistir inmediatamente en SQLite local (dispara triggers FTS5)
      final int id = await _foodDao.insertFood(companion);
      return await _foodDao.getById(id);
    } catch (_) {
      return null;
    }
  }

  int? _extractNovaGroup(Map<String, dynamic> product) {
    final dynamic g = product['nova_group'] ?? product['nova_groups'];
    if (g is num) return g.toInt().clamp(1, 4);
    if (g is String) {
      final int? parsed = int.tryParse(g);
      if (parsed != null) return parsed.clamp(1, 4);
    }
    return null;
  }

  /// Cierra el cliente HTTP subyacente cuando el proveedor se destruye.
  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  String? _nonEmptyOrNull(String? raw) {
    if (raw == null) return null;
    final String trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  double? _normalizeGramsToMg(
    double? value, {
    required double gramsThreshold,
  }) {
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
  final FoodDao foodDao = ref.watch(foodDaoProvider);
  final OpenFoodFactsService service = OpenFoodFactsService(foodDao);
  ref.onDispose(service.dispose);
  return service;
});
