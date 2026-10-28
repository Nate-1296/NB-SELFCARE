import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nb_selfcare/core/clock/clock.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/database/daos/food_dao.dart';
import 'package:nb_selfcare/core/services/open_food_facts_service.dart';

/// Escenarios reales de red y de datos de Open Food Facts: caídas, tiempos de
/// espera, JSON roto, productos a medio rellenar por la comunidad y escaneos
/// repetidos. Lo único aceptable es "no encontrado" o un alimento coherente;
/// nunca una excepción ni un alimento con cifras imposibles.
Map<String, Object?> _product(Map<String, Object?> fields, {Map<String, Object?>? nutriments}) =>
    <String, Object?>{
      'status': 1,
      'product': <String, Object?>{
        ...fields,
        'nutriments': nutriments ?? <String, Object?>{'energy-kcal_100g': 100, 'proteins_100g': 5},
      },
    };

void main() {
  late AppDatabase db;
  late FoodDao foodDao;
  final List<Uri> requests = <Uri>[];

  OpenFoodFactsService serviceWith(FutureOr<http.Response> Function(http.Request) handler) {
    return OpenFoodFactsService(
      foodDao,
      httpClient: MockClient((http.Request r) async {
        requests.add(r.url);
        return handler(r);
      }),
    );
  }

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    foodDao = FoodDao(db, clock: Clock.fixed(DateTime(2026, 10, 27, 12)));
    requests.clear();
  });

  tearDown(() => db.close());

  group('Fallos de red', () {
    final Map<String, FutureOr<http.Response> Function(http.Request)> failures =
        <String, FutureOr<http.Response> Function(http.Request)>{
          'HTTP 500': (_) => http.Response('Internal error', 500),
          'HTTP 404': (_) => http.Response('{"status":0}', 404),
          'HTTP 429 (límite de peticiones)': (_) => http.Response('Too many requests', 429),
          'sin conexión (SocketException)': (_) =>
              throw const SocketException('Network is unreachable'),
          'certificado inválido / proxy cautivo': (_) => throw const HandshakeException('bad cert'),
          'portal cautivo devuelve HTML': (_) => http.Response('<html>Wi-Fi login</html>', 200),
          'JSON truncado': (_) => http.Response('{"status":1,"product":{"product_na', 200),
          'JSON que no es objeto': (_) => http.Response('[1,2,3]', 200),
          'status 0 (no existe)': (_) =>
              http.Response('{"status":0,"status_verbose":"product not found"}', 200),
          'product nulo': (_) => http.Response('{"status":1,"product":null}', 200),
          'product de tipo incorrecto': (_) => http.Response('{"status":1,"product":"x"}', 200),
        };

    for (final MapEntry<String, FutureOr<http.Response> Function(http.Request)> f
        in failures.entries) {
      test('${f.key}: escaneo y búsqueda devuelven vacío sin excepción', () async {
        final OpenFoodFactsService s = serviceWith(f.value);
        expect(await s.resolveBarcode('7702001041400'), isNull);
        expect(await s.searchProducts('avena'), isEmpty);
        expect(await db.select(db.foodItems).get(), isEmpty, reason: 'no se guarda basura');
      });
    }

    test('servidor que no responde: el escaneo termina en ≤ 4 s por intento', () async {
      final OpenFoodFactsService s = serviceWith((_) async {
        await Future<void>.delayed(const Duration(seconds: 30));
        return http.Response('{}', 200);
      });
      final Stopwatch sw = Stopwatch()..start();
      expect(await s.resolveBarcode('7702001041400'), isNull);
      expect(sw.elapsed, lessThan(const Duration(seconds: 6)));
    }, timeout: const Timeout(Duration(seconds: 20)));
  });

  group('Datos de la comunidad incompletos o mal tipados', () {
    test('nombre numérico, marcas en lista y nutrientes como texto', () async {
      final OpenFoodFactsService s = serviceWith(
        (_) => http.Response(
          jsonEncode(
            _product(
              <String, Object?>{
                'product_name': 12345,
                'brands': <String>['A', 'B'],
              },
              nutriments: <String, Object?>{
                'energy-kcal_100g': '250',
                'proteins_100g': '7.5',
                'fat_100g': 'n/a',
              },
            ),
          ),
          200,
        ),
      );
      final FoodItem? f = await s.resolveBarcode('8410000000001');
      expect(f, isNotNull, reason: 'un producto con datos raros sigue siendo útil');
      expect(f!.kcalPer100g, 250);
      expect(f.proteinPer100g, 7.5);
      expect(f.fatPer100g, 0);
      expect(f.name, isNotEmpty);
    });

    test('solo energía en kJ: se convierte a kcal', () async {
      final OpenFoodFactsService s = serviceWith(
        (_) => http.Response(
          jsonEncode(
            _product(
              <String, Object?>{'product_name': 'Galleta'},
              nutriments: <String, Object?>{'energy_100g': 2092},
            ),
          ),
          200,
        ),
      );
      expect((await s.resolveBarcode('8410000000002'))!.kcalPer100g, closeTo(500, 0.5));
    });

    test('valores negativos, NaN o imposibles no se guardan como tales', () async {
      final OpenFoodFactsService s = serviceWith(
        (_) => http.Response(
          jsonEncode(
            _product(
              <String, Object?>{'product_name': 'Error de carga'},
              nutriments: <String, Object?>{
                'energy-kcal_100g': -50,
                'proteins_100g': 300,
                'carbohydrates_100g': 'NaN',
                'fat_100g': -2,
              },
            ),
          ),
          200,
        ),
      );
      final FoodItem f = (await s.resolveBarcode('8410000000003'))!;
      expect(f.kcalPer100g, inInclusiveRange(0, 900));
      expect(f.proteinPer100g, inInclusiveRange(0, 100));
      expect(f.carbsPer100g.isFinite, isTrue);
      expect(f.carbsPer100g, inInclusiveRange(0, 100));
      expect(f.fatPer100g, inInclusiveRange(0, 100));
    });

    test('sodio siempre en gramos: sal pura y caldo concentrado', () async {
      final OpenFoodFactsService s = serviceWith(
        (http.Request r) => http.Response(
          jsonEncode(
            _product(
              <String, Object?>{'product_name': 'Sal'},
              nutriments: <String, Object?>{
                'energy-kcal_100g': 0,
                'sodium_100g': r.url.path.contains('8410000000004') ? 38.7 : 0.4,
              },
            ),
          ),
          200,
        ),
      );
      expect(
        (await s.resolveBarcode('8410000000004'))!.sodiumMgPer100g,
        closeTo(38700, 1),
        reason: '38,7 g de sodio por 100 g (sal de mesa) son 38 700 mg',
      );
      expect((await s.resolveBarcode('8410000000005'))!.sodiumMgPer100g, closeTo(400, 1));
    });

    test('nova y nutriscore en formatos inesperados', () async {
      final OpenFoodFactsService s = serviceWith(
        (_) => http.Response(
          jsonEncode(
            _product(<String, Object?>{
              'product_name': 'Refresco',
              'nova_group': '9',
              'nutriscore_grade': 7,
            }),
          ),
          200,
        ),
      );
      final FoodItem f = (await s.resolveBarcode('8410000000006'))!;
      expect(f.novaGroup, isNull, reason: 'NOVA 9 no existe: sin clasificar');
      expect(f.nutriScore, isNull);
    });

    test('búsqueda con resultados mixtos: guarda los válidos y salta los rotos', () async {
      final OpenFoodFactsService s = serviceWith(
        (_) => http.Response(
          jsonEncode(<String, Object?>{
            'products': <Object?>[
              null,
              'texto',
              <String, Object?>{
                'code': '8410000000010',
                'product_name': 'Avena A',
                'nutriments': <String, Object?>{},
              },
              <String, Object?>{
                'code': '8410000000011',
                'product_name': 'Avena B',
                'nutriments': 'roto',
              },
              <String, Object?>{
                'product_name': 'Sin código',
                'nutriments': <String, Object?>{'energy-kcal_100g': 380},
              },
            ],
          }),
          200,
        ),
      );
      final List<FoodItem> found = await s.searchProducts('avena');
      expect(found.map((FoodItem f) => f.name), containsAll(<String>['Avena A', 'Sin código']));
    });
  });

  group('Códigos y caché', () {
    test('caché local: un código ya guardado no vuelve a salir a internet', () async {
      final OpenFoodFactsService s = serviceWith(
        (_) => http.Response(jsonEncode(_product(<String, Object?>{'product_name': 'Leche'})), 200),
      );
      await s.resolveBarcode('7702001000001');
      final int calls = requests.length;
      for (int i = 0; i < 5; i++) {
        expect((await s.resolveBarcode('7702001000001'))!.name, 'Leche');
      }
      expect(requests.length, calls);
    });

    test('espacios, saltos de línea y vacío', () async {
      final OpenFoodFactsService s = serviceWith(
        (_) => http.Response(jsonEncode(_product(<String, Object?>{'product_name': 'Pan'})), 200),
      );
      expect(await s.resolveBarcode('   '), isNull);
      expect(await s.resolveBarcode(''), isNull);
      expect(requests, isEmpty);
      expect((await s.resolveBarcode(' 7702001000002\n'))!.barcode, '7702001000002');
    });

    test('códigos que no son EAN/UPC (QR con URL) no se envían a la API', () async {
      final OpenFoodFactsService s = serviceWith((_) => http.Response('{}', 200));
      expect(await s.resolveBarcode('https://evil.example/../../x?y=1'), isNull);
      expect(await s.resolveBarcode('ABC-123'), isNull);
      expect(requests, isEmpty, reason: 'la única salida a internet es un código numérico');
    });

    test('UPC-A de 12 dígitos encuentra su EAN-13 con 0 delante', () async {
      final OpenFoodFactsService s = serviceWith(
        (http.Request r) => r.url.path.contains('0012345678905')
            ? http.Response(
                jsonEncode(_product(<String, Object?>{'product_name': 'Importado'})),
                200,
              )
            : http.Response('{"status":0}', 404),
      );
      expect((await s.resolveBarcode('012345678905'))?.name, 'Importado');
    });

    test(
      'doble escaneo simultáneo del mismo producto: ambos lo obtienen y se guarda una vez',
      () async {
        final OpenFoodFactsService s = serviceWith((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return http.Response(
            jsonEncode(_product(<String, Object?>{'product_name': 'Yogur'})),
            200,
          );
        });
        final List<FoodItem?> both = await Future.wait(<Future<FoodItem?>>[
          s.resolveBarcode('7702001000003'),
          s.resolveBarcode('7702001000003'),
        ]);
        expect(both.every((FoodItem? f) => f?.name == 'Yogur'), isTrue);
        expect(await db.select(db.foodItems).get(), hasLength(1));
        expect((await s.resolveBarcode('7702001000003'))?.name, 'Yogur');
      },
    );

    test('todas las peticiones van solo a world.openfoodfacts.org por HTTPS', () async {
      final OpenFoodFactsService s = serviceWith((_) => http.Response('{"status":0}', 200));
      await s.resolveBarcode('7702001000004');
      await s.resolveBarcode('012345678906');
      await s.searchProducts('pollo & arroz / "100%"');
      expect(requests, isNotEmpty);
      for (final Uri u in requests) {
        expect(u.scheme, 'https');
        expect(u.host, 'world.openfoodfacts.org');
      }
    });
  });
}
