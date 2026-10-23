import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/database/daos/food_dao.dart';
import 'package:nb_selfcare/core/database/daos/hydration_dao.dart';
import 'package:nb_selfcare/core/database/daos/pet_dao.dart';
import 'package:nb_selfcare/core/database/daos/user_profile_dao.dart';
import 'package:nb_selfcare/core/services/open_food_facts_service.dart';

void main() {
  late AppDatabase db;
  late FoodDao foodDao;
  late PetDao petDao;
  late HydrationDao hydrationDao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    foodDao = FoodDao(db);
    petDao = PetDao(db);
    hydrationDao = HydrationDao(db, petDao);

    // Perfil inicial
    await UserProfileDao(db).createProfile(
      UserProfilesCompanion(
        name: const drift.Value('Nathan'),
        birthDate: drift.Value(DateTime(1998, 5, 20)),
        biologicalSex: const drift.Value('male'),
        heightCm: const drift.Value(178.0),
        targetWeightKg: const drift.Value(72.0),
        weeklyGoalRateKg: const drift.Value(-0.5),
        dailyWaterGoalMl: const drift.Value(2000),
        dailyStepsGoal: const drift.Value(8000),
        dailySleepGoalHours: const drift.Value(7.5),
      ),
    );

    // Mascota Nibi inicial
    await db.into(db.petStatus).insert(
          const PetStatusCompanion(
            petName: drift.Value('Nibi'),
            coinsBalance: drift.Value(50),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('OpenFoodFactsService & FTS5 Cache', () {
    test('Resuelve código de barras desde Open Food Facts y lo persiste en SQLite', () async {
      final mockHttpClient = MockClient((request) async {
        if (request.url.path.contains('7702001041400')) {
          final sampleOffJson = {
            'status': 1,
            'product': {
              'product_name_es': 'Avena en Hojuelas Integral',
              'brands': 'Quaker',
              'nutriscore_grade': 'a',
              'nutriments': {
                'energy-kcal_100g': 375.0,
                'proteins_100g': 13.5,
                'carbohydrates_100g': 67.0,
                'fat_100g': 7.0,
                'fiber_100g': 10.0,
                'sodium_100g': 0.005, // 5 mg
                'potassium_100g': 0.420, // 420 mg
                'magnesium_100g': 0.138, // 138 mg
              },
            },
          };
          return http.Response(jsonEncode(sampleOffJson), 200);
        }
        return http.Response('{"status": 0}', 404);
      });

      final offService = OpenFoodFactsService(foodDao, httpClient: mockHttpClient);

      final food = await offService.resolveBarcode('7702001041400');
      expect(food, isNotNull);
      expect(food!.name, equals('Avena en Hojuelas Integral'));
      expect(food.kcalPer100g, equals(375.0));
      expect(food.proteinPer100g, equals(13.5));
      expect(food.sodiumMgPer100g, closeTo(5.0, 0.1));
      expect(food.potassiumMgPer100g, closeTo(420.0, 1.0));
      expect(food.magnesiumMgPer100g, closeTo(138.0, 1.0));

      // Verificar que se guardó en SQLite y se encuentra inmediatamente en la caché
      final cached = await foodDao.getByBarcode('7702001041400');
      expect(cached, isNotNull);
      expect(cached!.name, equals('Avena en Hojuelas Integral'));

      // Verificar que es indexado y localizable por FTS5
      final ftsResults = await foodDao.searchFood('hojuelas');
      expect(ftsResults, isNotEmpty);
      expect(ftsResults.first.barcode, equals('7702001041400'));
    });
  });

  group('Combos Caseros con Escalador Proporcional', () {
    test('Crea combo y lo registra escalado al 1.5x en food_logs', () async {
      // 1. Insertar dos ingredientes base
      final huevoId = await foodDao.insertFood(
        const FoodItemsCompanion(
          name: drift.Value('Huevo Entero'),
          source: drift.Value('usda_seed'),
          kcalPer100g: drift.Value(143.0),
          proteinPer100g: drift.Value(12.6),
          carbsPer100g: drift.Value(0.7),
          fatPer100g: drift.Value(9.5),
        ),
      );

      final aguacateId = await foodDao.insertFood(
        const FoodItemsCompanion(
          name: drift.Value('Aguacate Hass'),
          source: drift.Value('usda_seed'),
          kcalPer100g: drift.Value(160.0),
          proteinPer100g: drift.Value(2.0),
          carbsPer100g: drift.Value(8.5),
          fatPer100g: drift.Value(14.7),
        ),
      );

      // 2. Crear combo con 100g de huevo y 50g de aguacate
      final comboId = await foodDao.createCombo(
        name: 'Desayuno Keto',
        defaultMealType: 'breakfast',
        itemsWithGrams: [
          MapEntry(huevoId, 100.0),
          MapEntry(aguacateId, 50.0),
        ],
      );

      // 3. Registrar con escalador de 1.5x
      final loggedIds = await foodDao.logCombo(
        comboId: comboId,
        multiplier: 1.5,
        dateKey: '2026-10-23',
        mealType: 'breakfast',
      );

      expect(loggedIds, hasLength(2));

      // 4. Verificar logs escalados:
      // Huevo 100g * 1.5 = 150g -> 143 * 1.5 = 214.5 kcal
      // Aguacate 50g * 1.5 = 75g -> 160 * 0.75 = 120.0 kcal
      final logs = await foodDao.getLogsForDateAndMeal('2026-10-23', 'breakfast');
      expect(logs, hasLength(2));

      final huevoLog = logs.firstWhere((l) => l.foodItemId == huevoId);
      expect(huevoLog.gramsConsumed, equals(150.0));
      expect(huevoLog.totalKcal, closeTo(214.5, 0.1));

      final aguacateLog = logs.firstWhere((l) => l.foodItemId == aguacateId);
      expect(aguacateLog.gramsConsumed, equals(75.0));
      expect(aguacateLog.totalKcal, closeTo(120.0, 0.1));
    });
  });

  group('Flujo < 15s: Repetir Comida de Ayer', () {
    test('Copia todos los alimentos del bloque del día anterior con un toque', () async {
      final foodId = await foodDao.insertFood(
        const FoodItemsCompanion(
          name: drift.Value('Pechuga de Pollo'),
          source: drift.Value('usda_seed'),
          kcalPer100g: drift.Value(165.0),
          proteinPer100g: drift.Value(31.0),
          carbsPer100g: drift.Value(0.0),
          fatPer100g: drift.Value(3.6),
        ),
      );

      // Comida registrada ayer
      await foodDao.logFood(
        FoodLogsCompanion(
          dateKey: const drift.Value('2026-10-22'),
          loggedAt: drift.Value(DateTime(2026, 10, 22, 13, 0)),
          mealType: const drift.Value('lunch'),
          foodItemId: drift.Value(foodId),
          gramsConsumed: const drift.Value(200.0),
          portionMultiplier: const drift.Value(1.0),
          totalKcal: const drift.Value(330.0),
          totalProteinG: const drift.Value(62.0),
          totalCarbsG: const drift.Value(0.0),
          totalFatG: const drift.Value(7.2),
          totalFiberG: const drift.Value(0.0),
          totalSodiumMg: const drift.Value(140.0),
          totalPotassiumMg: const drift.Value(500.0),
          totalMagnesiumMg: const drift.Value(50.0),
        ),
      );

      // Repetir en el día de hoy
      final repeated = await foodDao.repeatMealFromYesterday(
        fromDateKey: '2026-10-22',
        toDateKey: '2026-10-23',
        mealType: 'lunch',
      );

      expect(repeated, hasLength(1));

      final todayLogs = await foodDao.getLogsForDateAndMeal('2026-10-23', 'lunch');
      expect(todayLogs, hasLength(1));
      expect(todayLogs.first.gramsConsumed, equals(200.0));
      expect(todayLogs.first.totalKcal, equals(330.0));
    });
  });

  group('Registro Atómico de Hidratación y Recompensas', () {
    test('Registrar vasos acumula mililitros y otorga recompensa al alcanzar la meta diaria', () async {
      // Registrar 4 vasos de 500ml = 2000ml (alcanza la meta diaria de 2000ml)
      await hydrationDao.logGlass(dateKey: '2026-10-23', volumeMl: 500, dailyGoalMl: 2000);
      await hydrationDao.logGlass(dateKey: '2026-10-23', volumeMl: 500, dailyGoalMl: 2000);
      await hydrationDao.logGlass(dateKey: '2026-10-23', volumeMl: 500, dailyGoalMl: 2000);

      // Todavía 1500 ml -> saldo debe seguir en 50
      var pet = await petDao.getPetStatus();
      expect(pet!.coinsBalance, equals(50));

      // Cuarto vaso -> 2000 ml alcanzados -> otorga +15 monedas (50 + 15 = 65)
      await hydrationDao.logGlass(dateKey: '2026-10-23', volumeMl: 500, dailyGoalMl: 2000);

      pet = await petDao.getPetStatus();
      expect(pet!.coinsBalance, equals(65));

      // Un quinto vaso no debe otorgar doble recompensa (idempotencia diaria)
      await hydrationDao.logGlass(dateKey: '2026-10-23', volumeMl: 250, dailyGoalMl: 2000);
      pet = await petDao.getPetStatus();
      expect(pet!.coinsBalance, equals(65));
    });
  });
}
