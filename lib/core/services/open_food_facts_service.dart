import 'dart:async';
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

  /// Escaneos en curso por código: un doble escaneo comparte la misma petición.
  final Map<String, Future<FoodItem?>> _inFlight = <String, Future<FoodItem?>>{};

  /// EAN-8, UPC-A, EAN-13 y GTIN-14: solo dígitos. Cualquier otra cosa (un QR
  /// con una URL, texto) no se envía a internet.
  static final RegExp _validBarcode = RegExp(r'^\d{8,14}$');

  static const String _userAgent =
      'NBSelfcare - Android - Version 0.1.0 - 100% Offline-First Health Sanctuary';

  /// Resuelve un código de barras. Busca primero en la caché local SQLite.
  /// Si no existe, consulta la API de Open Food Facts, normaliza a 100g,
  /// guarda inmediatamente en SQLite (activando triggers FTS5) y retorna el alimento.
  Future<FoodItem?> resolveBarcode(String barcode) {
    final String cleanBarcode = barcode.trim();
    if (!_validBarcode.hasMatch(cleanBarcode)) return Future<FoodItem?>.value();
    // Bloque con llaves: si el callback devolviera el Future quitado del mapa,
    // whenComplete esperaría a sí mismo y el escaneo no terminaría nunca.
    return _inFlight[cleanBarcode] ??= _resolve(cleanBarcode).whenComplete(() {
      unawaited(_inFlight.remove(cleanBarcode));
    });
  }

  Future<FoodItem?> _resolve(String cleanBarcode) async {
    // 1. Consulta en caché SQLite local
    final FoodItem? cached = await _foodDao.getByBarcode(cleanBarcode);
    if (cached != null) {
      return cached;
    }

    // Si es UPC-A de 12 dígitos, verificar si existe con 0 inicial (EAN-13)
    if (cleanBarcode.length == 12) {
      final FoodItem? cachedEan13 = await _foodDao.getByBarcode('0$cleanBarcode');
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
      final Uri uri = Uri.parse('https://world.openfoodfacts.org/api/v2/product/$barcode.json');

      final http.Response response = await _client
          .get(uri, headers: <String, String>{'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 4));

      if (response.statusCode != 200) return null;

      final Object? json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) return null;
      final Object? status = json['status'];
      final Object? product = json['product'];
      if (status is! num || status.toInt() != 1 || product is! Map<String, dynamic>) return null;
      return await _parseAndPersistProduct(product, explicitBarcode: barcode);
    } catch (_) {
      return null;
    }
  }

  /// Busca productos en Open Food Facts por texto cuando la búsqueda local FTS5
  /// no arroja resultados suficientes. Cada resultado válido es cacheado en SQLite.
  Future<List<FoodItem>> searchProducts(String query, {int page = 1, int pageSize = 20}) async {
    final String cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return <FoodItem>[];

    try {
      final Uri uri = Uri.parse(
        'https://world.openfoodfacts.org/cgi/search.pl?search_terms=${Uri.encodeComponent(cleanQuery)}&search_simple=1&action=process&json=1&page_size=$pageSize&page=$page',
      );

      final http.Response response = await _client
          .get(uri, headers: <String, String>{'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return <FoodItem>[];

      final Object? json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) return <FoodItem>[];
      final Object? rawProducts = json['products'];
      if (rawProducts is! List<dynamic> || rawProducts.isEmpty) return <FoodItem>[];

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
    final String? rawCode = explicitBarcode ?? _text(product['code']);
    try {
      // Si tiene código de barras y ya está en base de datos local, devolverlo
      if (rawCode != null) {
        final FoodItem? existing = await _foodDao.getByBarcode(rawCode);
        if (existing != null) return existing;
      }

      // Los datos vienen de una base colaborativa: cualquier campo puede faltar
      // o venir con otro tipo (números como texto, marcas en lista…).
      final Object? rawNutriments = product['nutriments'];
      final Map<String, dynamic> nutriments = rawNutriments is Map<String, dynamic>
          ? rawNutriments
          : <String, dynamic>{};

      final String name =
          _text(product['product_name_es']) ??
          _text(product['product_name']) ??
          _text(product['generic_name']) ??
          (rawCode != null ? 'Producto $rawCode' : 'Alimento');

      final String? brand = _text(product['brands']);
      final String? grade = _text(product['nutriscore_grade'])?.toUpperCase();
      final String? nutriScore = grade != null && RegExp(r'^[A-E]$').hasMatch(grade) ? grade : null;
      final int? novaGroup = _extractNovaGroup(product);

      // Normalización a 100 g, acotada a lo físicamente posible.
      final double kcal =
          (_extractNum(nutriments, 'energy-kcal_100g') ??
                  ((_extractNum(nutriments, 'energy_100g') ?? 0.0) / 4.184))
              .clamp(0.0, 900.0);

      final double protein = _grams(nutriments, 'proteins_100g') ?? 0.0;
      final double carbs = _grams(nutriments, 'carbohydrates_100g') ?? 0.0;
      final double fat = _grams(nutriments, 'fat_100g') ?? 0.0;
      final double? fiber = _grams(nutriments, 'fiber_100g');
      final double? sugars = _grams(nutriments, 'sugars_100g');

      // Open Food Facts normaliza sodio y sal a gramos por 100 g.
      double? sodiumMg = _grams(nutriments, 'sodium_100g');
      if (sodiumMg != null) {
        sodiumMg = double.parse((sodiumMg * 1000.0).toStringAsFixed(1));
      } else {
        final double? saltG = _grams(nutriments, 'salt_100g');
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
      // Otro escaneo pudo guardarlo entre la consulta y la inserción (código único).
      return rawCode == null ? null : _foodDao.getByBarcode(rawCode);
    }
  }

  /// Grupo NOVA (1–4); cualquier otro valor se trata como "sin clasificar".
  int? _extractNovaGroup(Map<String, dynamic> product) {
    final Object? g = product['nova_group'] ?? product['nova_groups'];
    final int? group = g is num && g.isFinite
        ? g.toInt()
        : (g is String ? int.tryParse(g.trim()) : null);
    return group != null && group >= 1 && group <= 4 ? group : null;
  }

  /// Cierra el cliente HTTP subyacente cuando el proveedor se destruye.
  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  /// Texto no vacío a partir de un campo de tipo libre (texto, número o lista).
  String? _text(Object? raw) {
    final String? text = switch (raw) {
      final String s => s,
      final num n when n.isFinite => n.toString(),
      final List<dynamic> l => l.whereType<String>().join(', '),
      _ => null,
    };
    final String? trimmed = text?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  /// Gramos por 100 g acotados a 0–100.
  double? _grams(Map<String, dynamic> map, String key) => _extractNum(map, key)?.clamp(0.0, 100.0);

  double? _normalizeGramsToMg(double? value, {required double gramsThreshold}) {
    if (value == null || value < 0) return null;
    if (value > 0 && value < gramsThreshold) {
      return double.parse((value * 1000.0).toStringAsFixed(1));
    }
    return double.parse(value.toStringAsFixed(1));
  }

  /// Número finito; "NaN", "Infinity" o texto no numérico cuentan como ausente.
  double? _extractNum(Map<String, dynamic> map, String key) {
    final Object? val = map[key];
    final double? parsed = val is num
        ? val.toDouble()
        : (val is String ? double.tryParse(val.trim()) : null);
    return parsed != null && parsed.isFinite ? parsed : null;
  }
}

/// Provider de Riverpod para inyectar OpenFoodFactsService.
final openFoodFactsServiceProvider = Provider<OpenFoodFactsService>((ref) {
  final FoodDao foodDao = ref.watch(foodDaoProvider);
  final OpenFoodFactsService service = OpenFoodFactsService(foodDao);
  ref.onDispose(service.dispose);
  return service;
});
