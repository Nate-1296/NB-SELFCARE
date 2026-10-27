import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/database/daos/food_dao.dart';
import 'package:nb_selfcare/core/domain/enums.dart';
import 'package:nb_selfcare/core/services/text_assistant.dart';
import 'package:nb_selfcare/features/nutrition_hydration/application/food_logging_service.dart';

import '../support/test_container.dart';

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
            source: drift.Value(FoodSource.usdaSeed),
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

  group('TextAssistant Syntactic Meal Parser', () {
    test('Extrae gramajes exactos y alimentos con macros de respaldo', () async {
      const TextAssistant service = TextAssistant();
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
    });

    test('Convierte unidades comunes a porciones estandarizadas en gramos', () async {
      const TextAssistant service = TextAssistant();
      final result = await service.parseMealText('2 huevos cocidos y 1 manzana fresca');

      expect(result.items.length, equals(2));

      final huevos = result.items[0];
      expect(huevos.searchTerm.toLowerCase(), contains('huevo'));
      expect(huevos.grams, equals(110.0)); // 2 x 55g

      final manzana = result.items[1];
      expect(manzana.searchTerm.toLowerCase(), contains('manzana'));
      expect(manzana.grams, equals(150.0)); // 1 x 150g
    });

    test('Maneja entradas vacías devolviendo lista limpia', () async {
      const TextAssistant service = TextAssistant();
      final result = await service.parseMealText('   ');
      expect(result.items, isEmpty);
    });
  });

  group('TextAssistant Journal Semantic Analysis', () {
    test('Detecta ánimo elevado, vitalidad y genera insight empático breve', () async {
      const TextAssistant service = TextAssistant();
      final analysis = await service.analyzeJournal(
        'Hoy me desperté lleno de energía y fuerza, me siento feliz y motivado con mi progreso.',
      );

      expect(analysis.moodScore, greaterThanOrEqualTo(4));
      expect(analysis.energyLevel, greaterThanOrEqualTo(4));
      expect(analysis.stressLevel, lessThanOrEqualTo(2));
      expect(analysis.tags, contains('calma_interior'));
      expect(analysis.oneLineInsight.split(' ').length, lessThanOrEqualTo(18));
    });

    test('Detecta sobrecarga mental y estrés sugiriendo pausa reparadora', () async {
      const TextAssistant service = TextAssistant();
      final analysis = await service.analyzeJournal(
        'Día muy pesado con demasiado estrés, presión en el trabajo y agotamiento.',
      );

      expect(analysis.stressLevel, greaterThanOrEqualTo(4));
      expect(analysis.energyLevel, lessThanOrEqualTo(2));
      expect(analysis.tags, anyOf(contains('sobrecarga_mental'), contains('recuperacion_fisica')));
      expect(analysis.oneLineInsight.toLowerCase(), contains('pausa'));
    });
  });

  group('TextAssistant Pet Greetings and Radical Positivity', () {
    test('El saludo de ayuno sigue las fases de docs/09 sin adelantar la autofagia', () async {
      for (int seed = 0; seed < 4; seed++) {
        final String fatBurning = TextAssistant.buildNibiGreeting(
          petName: 'Nibi',
          hourOfDay: 10,
          fastingHours: 16.0,
          variationSeed: seed,
        );
        expect(fatBurning.toLowerCase(), isNot(contains('cetosis')));
        expect(fatBurning.toLowerCase(), isNot(contains('autofagia')));
        expect(fatBurning.split(' ').length, lessThanOrEqualTo(22));
      }
      expect(
        TextAssistant.buildNibiGreeting(petName: 'Nibi', hourOfDay: 10, fastingHours: 19),
        contains('cetosis'),
      );
    });

    test('Genera saludo de hidratación si cumplió la meta de agua', () async {
      final greeting = TextAssistant.buildNibiGreeting(
        petName: 'Nibi',
        hourOfDay: 10,
        waterMl: 2600,
        waterGoalMl: 2500,
      );

      expect(greeting, contains('hidratación'));
      expect(greeting.split(' ').length, lessThanOrEqualTo(22));
    });

    test('Nibi nunca regaña ni culpa en ausencia de datos', () async {
      final greeting = TextAssistant.buildNibiGreeting(
        petName: 'Nibi',
        hourOfDay: 10,
        sleepHours: 4.0, // Poco sueño, no debe regañar
        waterMl: 200, // Poca agua, no debe castigar
      );

      expect(greeting.toLowerCase(), isNot(contains('mal')));
      expect(greeting.toLowerCase(), isNot(contains('fallaste')));
      expect(greeting.toLowerCase(), isNot(contains('debes')));
      expect(greeting, contains('alegría verte'));
    });

    test('Varía dinámicamente el saludo de Nibi en cada visita según semilla y hora', () async {
      final Set<String> generatedMorning = <String>{};
      for (int seed = 1; seed <= 4; seed++) {
        final String g = TextAssistant.buildNibiGreeting(
          petName: 'Nibi',
          variationSeed: seed,
          hourOfDay: 8,
        );
        expect(g.split(' ').length, lessThanOrEqualTo(22));
        generatedMorning.add(g);
      }
      expect(generatedMorning.length, greaterThanOrEqualTo(3));

      final String nightGreeting = TextAssistant.buildNibiGreeting(
        petName: 'Nibi',
        variationSeed: 2,
        hourOfDay: 22,
      );
      expect(nightGreeting.split(' ').length, lessThanOrEqualTo(22));
      expect(generatedMorning.contains(nightGreeting), isFalse);
    });
  });

  group('Extractor de texto + FoodLoggingService', () {
    test('Resuelve comida contra base FTS5 e inserta registro en SQLite', () async {
      const TextAssistant service = TextAssistant();
      final ProviderContainer container = createTestContainer(db);
      addTearDown(container.dispose);

      final ParsedMealResult parsed = await service.parseMealText('200g pechuga de pollo');
      final FoodLogResult result = await container.read(foodLoggingServiceProvider).logParsedItems(
            items: parsed.items,
            mealType: MealType.lunch,
            dateKey: '2026-10-23',
          );

      expect(result.logIds.length, equals(1));
      final FoodItem logged = (await foodDao.getById(
        (await db.select(db.foodLogs).getSingle()).foodItemId,
      ))!;
      expect(logged.name, contains('pechuga de pollo'));

      // Verificar que se insertó el FoodLog correspondiente
      final logs = await (db.select(db.foodLogs)..where((tbl) => tbl.dateKey.equals('2026-10-23'))).get();
      expect(logs.length, equals(1));
      expect(logs.first.gramsConsumed, equals(200.0));
      // 165 kcal / 100g * 2 = 330 kcal
      expect(logs.first.totalKcal, equals(330.0));
      // 31g protein / 100g * 2 = 62g protein
      expect(logs.first.totalProteinG, equals(62.0));
    });
  });
}
