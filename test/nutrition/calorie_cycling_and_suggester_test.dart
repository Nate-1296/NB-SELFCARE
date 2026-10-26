import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/services/calorie_cycling_service.dart';
import 'package:nb_selfcare/core/services/smart_meal_suggester.dart';

void main() {
  group('Fase 4: CalorieCyclingService Tests', () {
    final CalorieCyclingService service = CalorieCyclingService();

    test('CalorieCyclingMode.flat yields equal targets across all 7 days', () {
      const int baseDailyKcal = 2000;
      final List<DayCalorieBudget> schedule = service.computeSchedule(
        baseDailyKcal: baseDailyKcal,
        mode: CalorieCyclingMode.flat,
      );

      expect(schedule.length, 7);
      for (final DayCalorieBudget day in schedule) {
        expect(day.targetKcal, 2000);
        expect(day.deltaKcal, 0);
      }
      final int totalWeekly =
          schedule.fold<int>(0, (int sum, DayCalorieBudget d) => sum + d.targetKcal);
      expect(totalWeekly, 14000);
    });

    test('CalorieCyclingMode.weekendBuffer preserves weekly total with Fri/Sat buffer', () {
      const int baseDailyKcal = 2000;
      final List<DayCalorieBudget> schedule = service.computeSchedule(
        baseDailyKcal: baseDailyKcal,
        mode: CalorieCyclingMode.weekendBuffer,
      );

      expect(schedule.length, 7);
      // Lunes a Jueves (1-4): 2000 - 150 = 1850
      for (int i = 0; i < 4; i++) {
        expect(schedule[i].targetKcal, 1850);
        expect(schedule[i].deltaKcal, -150);
      }
      // Viernes y Sábado (5-6): 2000 + 300 = 2300
      expect(schedule[4].targetKcal, 2300);
      expect(schedule[5].targetKcal, 2300);
      // Domingo (7): 2000
      expect(schedule[6].targetKcal, 2000);

      final int totalWeekly =
          schedule.fold<int>(0, (int sum, DayCalorieBudget d) => sum + d.targetKcal);
      expect(totalWeekly, 14000);
    });

    test('WeeklyCalorieBank tracks cumulative energy savings correctly', () {
      final DateTime wednesday = DateTime(2026, 10, 28);
      const String mondayKey = '2026-10-26';
      const String tuesdayKey = '2026-10-27';
      const String wednesdayKey = '2026-10-28';

      final WeeklyCalorieBank bank = service.computeWeeklyBank(
        baseDailyKcal: 2000,
        today: wednesday,
        caloriesLoggedByDateKey: <String, int>{
          mondayKey: 1800,
          tuesdayKey: 1900,
          wednesdayKey: 2200,
        },
      );

      expect(bank.daysLogged, 3);
      expect(bank.accumulatedTargetKcal, 6000);
      expect(bank.accumulatedConsumedKcal, 5900);
      expect(bank.netBalanceKcal, 100);
      expect(bank.hasBankSavings, isTrue);
    });

    test('Schedule serialization and parsing works symmetrically', () {
      final Map<int, int> original = <int, int>{
        1: 1850,
        2: 1850,
        3: 1850,
        4: 1850,
        5: 2300,
        6: 2300,
        7: 2000,
      };

      final String jsonStr = CalorieCyclingService.encodeScheduleJson(original);
      final Map<int, int> parsed =
          CalorieCyclingService.parseScheduleJson(jsonStr);

      expect(parsed.length, 7);
      for (int i = 1; i <= 7; i++) {
        expect(parsed[i], original[i]);
      }
    });
  });

  group('Fase 4: SmartMealSuggester and NutrientOracle Tests', () {
    test('Diet archetypes have correct macro definitions and sum to 100%', () {
      for (final DietArchetypeInfo arch in DietArchetypeInfo.archetypes.values) {
        expect(arch.proteinPct + arch.carbsPct + arch.fatPct, 100.0);
      }

      final DietArchetypeInfo keto = DietArchetypeInfo.getById('keto');
      expect(keto.carbsPct, 5.0);
      expect(keto.fatPct, 70.0);
      expect(keto.proteinPct, 25.0);

      final DietArchetypeInfo med = DietArchetypeInfo.getById('mediterranean');
      expect(med.carbsPct, 50.0);
      expect(med.fatPct, 30.0);
      expect(med.proteinPct, 20.0);
    });

    test('NutrientOracle recommends protein rich foods when protein gap is highest', () {
      final List<FoodItem> mockCatalog = <FoodItem>[
        const FoodItem(
          id: 1,
          name: 'Pechuga de pollo a la plancha',
          source: 'test',
          defaultServingGrams: 150.0,
          servingLabel: 'Porción',
          kcalPer100g: 165.0,
          proteinPer100g: 31.0,
          carbsPer100g: 0.0,
          fatPer100g: 3.6,
          fiberPer100g: 0.0,
          sugarPer100g: 0.0,
          sodiumMgPer100g: 74.0,
          potassiumMgPer100g: 256.0,
          magnesiumMgPer100g: 29.0,
          calciumMgPer100g: 15.0,
          ironMgPer100g: 1.0,
          zincMgPer100g: 0.8,
          vitaminCMgPer100g: 0.0,
          vitaminDUgPer100g: 0.1,
          vitaminB12UgPer100g: 0.3,
          barcode: '123456789012',
          isFavorite: true,
        ),
        const FoodItem(
          id: 2,
          name: 'Arroz blanco cocido',
          source: 'test',
          defaultServingGrams: 150.0,
          servingLabel: 'Taza',
          kcalPer100g: 130.0,
          proteinPer100g: 2.7,
          carbsPer100g: 28.2,
          fatPer100g: 0.3,
          fiberPer100g: 0.4,
          sugarPer100g: 0.1,
          sodiumMgPer100g: 1.0,
          potassiumMgPer100g: 35.0,
          magnesiumMgPer100g: 12.0,
          calciumMgPer100g: 10.0,
          ironMgPer100g: 0.2,
          zincMgPer100g: 0.5,
          vitaminCMgPer100g: 0.0,
          vitaminDUgPer100g: 0.0,
          vitaminB12UgPer100g: 0.0,
          barcode: '123456789013',
          isFavorite: false,
        ),
      ];

      final NutrientOracle oracle = NutrientOracle();
      final List<SuggestedMealItem> recs = oracle.recommendFromCatalog(
        remainingKcal: 400.0,
        remainingProteinG: 30.0,
        remainingCarbsG: 5.0,
        remainingFatG: 5.0,
        catalog: mockCatalog,
      );

      expect(recs.isNotEmpty, isTrue);
      final SuggestedMealItem topRec = recs.first;
      expect(topRec.food.name, contains('Pechuga'));
      expect(topRec.grams, greaterThan(50));
      expect(topRec.proteinG, greaterThan(20));
    });
  });
}
