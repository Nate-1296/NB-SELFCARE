import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/database/daos/food_dao.dart';
import 'package:nb_selfcare/core/services/local_ai_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FoodDao foodDao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    foodDao = FoodDao(db);

    // Semilla básica de prueba
    await db.into(db.foodItems).insert(
          const FoodItemsCompanion(
            name: drift.Value('pechuga de pollo asada'),
            source: drift.Value('usda_seed'),
            kcalPer100g: drift.Value(165.0),
            proteinPer100g: drift.Value(31.0),
            carbsPer100g: drift.Value(0.0),
            fatPer100g: drift.Value(3.6),
            sodiumMgPer100g: drift.Value(74.0),
            potassiumMgPer100g: drift.Value(256.0),
            magnesiumMgPer100g: drift.Value(29.0),
            fiberPer100g: drift.Value(0.0),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('LocalAiService Memory Lifecycle (Lazy-Load + 120s TTL)', () {
    test('Arranca en estado UNLOADED (0 MB RAM) y pasa a READY bajo demanda', () async {
      final service = LocalAiService();
      expect(service.currentState, equals(AiMemoryState.unloaded));

      // Primera llamada de inferencia despierta el modelo
      final greeting = await service.generatePetGreeting(petName: 'Nibi');
      expect(greeting.isNotEmpty, isTrue);
      expect(service.currentState, equals(AiMemoryState.ready));

      service.dispose();
      expect(service.currentState, equals(AiMemoryState.unloaded));
    });

    test('Auto-expulsa de memoria RAM/GPU al expirar el tiempo de inactividad', () async {
      // Usamos un TTL muy corto (50ms) para verificar la auto-expulsión
      final service = LocalAiService(ttlDuration: const Duration(milliseconds: 50));
      expect(service.currentState, equals(AiMemoryState.unloaded));

      await service.parseMealText('100g de pollo');
      expect(service.currentState, equals(AiMemoryState.ready));

      // Esperar que el timer de TTL expire
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(service.currentState, equals(AiMemoryState.unloaded));

      service.dispose();
    });

    test('Llamada manual evictModel libera la memoria de inmediato', () async {
      final service = LocalAiService();
      await service.analyzeJournal('Me siento en paz');
      expect(service.currentState, equals(AiMemoryState.ready));

      service.evictModel();
      expect(service.currentState, equals(AiMemoryState.unloaded));

      service.dispose();
    });
  });

  group('LocalAiService Syntactic Meal Parser', () {
    test('Extrae gramajes exactos y alimentos con macros de respaldo', () async {
      final service = LocalAiService();
      final result = await service.parseMealText('200g pechuga de pollo y 150g de arroz integral');

      expect(result.items.length, equals(2));

      final pollo = result.items[0];
      expect(pollo.searchTerm.toLowerCase(), contains('pollo'));
      expect(pollo.grams, equals(200.0));
      expect(pollo.fallbackP, greaterThan(20.0)); // Alto en proteína

      final arroz = result.items[1];
      expect(arroz.searchTerm.toLowerCase(), contains('arroz'));
      expect(arroz.grams, equals(150.0));
      expect(arroz.fallbackC, greaterThan(20.0)); // Alto en carbohidratos

      service.dispose();
    });

    test('Convierte unidades comunes a porciones estandarizadas en gramos', () async {
      final service = LocalAiService();
      final result = await service.parseMealText('2 huevos cocidos y 1 manzana fresca');

      expect(result.items.length, equals(2));

      final huevos = result.items[0];
      expect(huevos.searchTerm.toLowerCase(), contains('huevo'));
      expect(huevos.grams, equals(110.0)); // 2 x 55g

      final manzana = result.items[1];
      expect(manzana.searchTerm.toLowerCase(), contains('manzana'));
      expect(manzana.grams, equals(150.0)); // 1 x 150g

      service.dispose();
    });

    test('Maneja entradas vacías devolviendo lista limpia', () async {
      final service = LocalAiService();
      final result = await service.parseMealText('   ');
      expect(result.items, isEmpty);
      service.dispose();
    });
  });

  group('LocalAiService Journal Semantic Analysis', () {
    test('Detecta ánimo elevado, vitalidad y genera insight empático breve', () async {
      final service = LocalAiService();
      final analysis = await service.analyzeJournal(
        'Hoy me desperté lleno de energía y fuerza, me siento feliz y motivado con mi progreso.',
      );

      expect(analysis.moodScore, greaterThanOrEqualTo(4));
      expect(analysis.energyLevel, greaterThanOrEqualTo(4));
      expect(analysis.stressLevel, lessThanOrEqualTo(2));
      expect(analysis.tags, contains('calma_interior'));
      expect(analysis.oneLineInsight.split(' ').length, lessThanOrEqualTo(18));

      service.dispose();
    });

    test('Detecta sobrecarga mental y estrés sugiriendo pausa reparadora', () async {
      final service = LocalAiService();
      final analysis = await service.analyzeJournal(
        'Día muy pesado con demasiado estrés, presión en el trabajo y agotamiento.',
      );

      expect(analysis.stressLevel, greaterThanOrEqualTo(4));
      expect(analysis.energyLevel, lessThanOrEqualTo(2));
      expect(analysis.tags, anyOf(contains('sobrecarga_mental'), contains('recuperacion_fisica')));
      expect(analysis.oneLineInsight.toLowerCase(), contains('pausa'));

      service.dispose();
    });
  });

  group('LocalAiService Pet Greetings and Radical Positivity', () {
    test('Genera saludo enfocado en cetosis si ayuno ≥ 14h', () async {
      final service = LocalAiService();
      final greeting = await service.generatePetGreeting(
        petName: 'Nibi',
        fastingHours: 16.0,
      );

      expect(greeting, contains('Cetosis activa'));
      expect(greeting.split(' ').length, lessThanOrEqualTo(22));

      service.dispose();
    });

    test('Genera saludo de hidratación si cumplió la meta de agua', () async {
      final service = LocalAiService();
      final greeting = await service.generatePetGreeting(
        petName: 'Nibi',
        waterMl: 2600,
        waterGoalMl: 2500,
      );

      expect(greeting, contains('hidratación'));
      expect(greeting.split(' ').length, lessThanOrEqualTo(22));

      service.dispose();
    });

    test('Nibi nunca regaña ni culpa en ausencia de datos', () async {
      final service = LocalAiService();
      final greeting = await service.generatePetGreeting(
        petName: 'Nibi',
        sleepHours: 4.0, // Poco sueño, no debe regañar
        waterMl: 200, // Poca agua, no debe castigar
      );

      expect(greeting.toLowerCase(), isNot(contains('mal')));
      expect(greeting.toLowerCase(), isNot(contains('fallaste')));
      expect(greeting.toLowerCase(), isNot(contains('debes')));
      expect(greeting, contains('alegría verte'));

      service.dispose();
    });
  });

  group('LocalAiService + FoodDao Resolution and Logging', () {
    test('Resuelve comida contra base FTS5 e inserta registro en SQLite', () async {
      final service = LocalAiService();
      final loggedFoods = await service.resolveAndLogMeal(
        foodDao: foodDao,
        text: '200g pechuga de pollo',
        mealType: 'lunch',
        dateKey: '2026-10-23',
      );

      expect(loggedFoods.length, equals(1));
      expect(loggedFoods.first.name, contains('pechuga de pollo'));

      // Verificar que se insertó el FoodLog correspondiente
      final logs = await (db.select(db.foodLogs)..where((tbl) => tbl.dateKey.equals('2026-10-23'))).get();
      expect(logs.length, equals(1));
      expect(logs.first.gramsConsumed, equals(200.0));
      // 165 kcal / 100g * 2 = 330 kcal
      expect(logs.first.totalKcal, equals(330.0));
      // 31g protein / 100g * 2 = 62g protein
      expect(logs.first.totalProteinG, equals(62.0));

      service.dispose();
    });
  });
}
