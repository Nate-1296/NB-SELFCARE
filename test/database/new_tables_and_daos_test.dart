import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/database/daos/caffeine_dao.dart';
import 'package:nb_selfcare/core/database/daos/digestive_dao.dart';
import 'package:nb_selfcare/core/database/daos/female_cycle_dao.dart';
import 'package:nb_selfcare/core/database/daos/milestone_dao.dart';
import 'package:nb_selfcare/core/database/daos/protocol_dao.dart';
import 'package:nb_selfcare/core/database/daos/recipe_dao.dart';
import 'package:nb_selfcare/core/database/daos/supplement_dao.dart';
import 'package:nb_selfcare/core/database/daos/user_profile_dao.dart';
import 'package:nb_selfcare/core/domain/enums.dart';
import 'package:nb_selfcare/shared/utils/cycle_phase_calculator.dart';

void main() {
  late AppDatabase db;
  late RecipeDao recipeDao;
  late SupplementDao supplementDao;
  late FemaleCycleDao femaleCycleDao;
  late DigestiveDao digestiveDao;
  late CaffeineDao caffeineDao;
  late ProtocolDao protocolDao;
  late MilestoneDao milestoneDao;
  late UserProfileDao userProfileDao;

  setUp(() {
    // Base de datos en memoria para pruebas
    db = AppDatabase(NativeDatabase.memory());
    recipeDao = RecipeDao(db);
    supplementDao = SupplementDao(db);
    femaleCycleDao = FemaleCycleDao(db);
    digestiveDao = DigestiveDao(db);
    caffeineDao = CaffeineDao(db);
    protocolDao = ProtocolDao(db);
    milestoneDao = MilestoneDao(db);
    userProfileDao = UserProfileDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Fase 1: Nuevas Tablas y DAOs Relacionales', () {
    test('RecipeDao: Crea receta multiración y calcula macros consolidados por porción', () async {
      // 1. Insertar dos ingredientes base en food_items
      final int polloId = await db.into(db.foodItems).insert(
            const FoodItemsCompanion(
              name: Value('Pechuga de Pollo'),
              source: Value(FoodSource.userCustom),
              kcalPer100g: Value(165.0),
              proteinPer100g: Value(31.0),
              carbsPer100g: Value(0.0),
              fatPer100g: Value(3.6),
            ),
          );

      final int arrozId = await db.into(db.foodItems).insert(
            const FoodItemsCompanion(
              name: Value('Arroz Cocido'),
              source: Value(FoodSource.userCustom),
              kcalPer100g: Value(130.0),
              proteinPer100g: Value(2.7),
              carbsPer100g: Value(28.0),
              fatPer100g: Value(0.3),
            ),
          );

      // 2. Crear receta para 4 porciones: 400g pollo + 400g arroz
      // Total Pollo: 660 kcal, 124g P, 0g C, 14.4g F
      // Total Arroz: 520 kcal, 10.8g P, 112g C, 1.2g F
      // Suma total: 1180 kcal, 134.8g P, 112g C, 15.6g F
      // Porción (÷4): 295 kcal, 33.7g P, 28g C, 3.9g F
      final int recipeId = await recipeDao.createRecipe(
        name: 'Arroz con Pollo Meal Prep',
        description: '4 raciones para la semana',
        defaultMealType: MealType.lunch,
        totalYieldServings: 4,
        cookedTotalWeightGrams: 800.0,
        ingredients: [
          RecipeIngredientDraft(foodItemId: polloId, rawGrams: 400.0),
          RecipeIngredientDraft(foodItemId: arrozId, rawGrams: 400.0),
        ],
      );

      final RecipeWithIngredients? created = await recipeDao.getRecipeWithIngredients(recipeId);
      expect(created, isNotNull);
      expect(created!.recipe.name, 'Arroz con Pollo Meal Prep');
      expect(created.recipe.totalYieldServings, 4);
      expect(created.recipe.kcalPerServing, closeTo(295.0, 0.5));
      expect(created.recipe.proteinPerServing, closeTo(33.7, 0.5));
      expect(created.recipe.carbsPerServing, closeTo(28.0, 0.5));
      expect(created.ingredients.length, 2);

      // Eliminar receta y verificar cascada
      final int deletedRows = await recipeDao.deleteRecipe(recipeId);
      expect(deletedRows, 1);
      final RecipeWithIngredients? afterDelete = await recipeDao.getRecipeWithIngredients(recipeId);
      expect(afterDelete, isNull);
    });

    test('SupplementDao: Registra suplementos y detecta retención hídrica por Creatina', () async {
      final int creatinaId = await supplementDao.createSupplement(
        name: 'Creatina Creapure',
        dosage: '5g',
        targetTimeOfDayMinutes: 780, // 1:00 PM
        affectsWaterRetention: true,
      );

      final activeSupplements = await supplementDao.getAllSupplements();
      expect(activeSupplements.length, 1);
      expect(activeSupplements.first.name, 'Creatina Creapure');

      // Antes de tomarla: no detecta retención activa
      final bool activeBefore = await supplementDao.hasActiveWaterRetentionSupplement('2026-10-26');
      expect(activeBefore, isFalse);

      // Registrar 3 tomas en días distintos
      await supplementDao.toggleSupplementIntake(dateKey: '2026-10-24', supplementId: creatinaId, wasTaken: true);
      await supplementDao.toggleSupplementIntake(dateKey: '2026-10-25', supplementId: creatinaId, wasTaken: true);
      await supplementDao.toggleSupplementIntake(dateKey: '2026-10-26', supplementId: creatinaId, wasTaken: true);

      final bool activeAfter = await supplementDao.hasActiveWaterRetentionSupplement('2026-10-26');
      expect(activeAfter, isTrue);
    });

    test('FemaleCycleDao: Calcula fases hormonales y compensación calórica lútea', () async {
      final DateTime cycleStart = DateTime(2026, 10, 1);

      await femaleCycleDao.logCycleStart(
        cycleStartDate: cycleStart,
        cycleLengthDays: 28,
        flowIntensity: 'medium',
        symptomsJson: '["cramps"]',
      );

      // Día 3 del ciclo -> Menstrual
      final day3Info = await femaleCycleDao.calculateCurrentPhase(DateTime(2026, 10, 3));
      expect(day3Info.phase, FemaleCyclePhase.menstrual);
      expect(day3Info.isLutealMetabolicSurge, isFalse);
      expect(day3Info.recommendedCaloricSurgeKcal, 0);

      // Día 10 del ciclo -> Folicular
      final day10Info = await femaleCycleDao.calculateCurrentPhase(DateTime(2026, 10, 10));
      expect(day10Info.phase, FemaleCyclePhase.follicular);

      // Día 15 del ciclo -> Ovulatoria
      final day15Info = await femaleCycleDao.calculateCurrentPhase(DateTime(2026, 10, 15));
      expect(day15Info.phase, FemaleCyclePhase.ovulatory);

      // Día 22 del ciclo -> Lútea (Premenstrual con incremento metabólico sugerido)
      final day22Info = await femaleCycleDao.calculateCurrentPhase(DateTime(2026, 10, 22));
      expect(day22Info.phase, FemaleCyclePhase.luteal);
      expect(day22Info.isLutealMetabolicSurge, isTrue);
      expect(day22Info.recommendedCaloricSurgeKcal, 150);
    });

    test('DigestiveDao: Registra tipos de Bristol 1-7 y filtra malestares significativos', () async {
      await digestiveDao.logDigestiveEvent(
        dateKey: '2026-10-25',
        bristolType: 4, // Normal / Óptimo
        discomfortLevel: 1,
      );

      await digestiveDao.logDigestiveEvent(
        dateKey: '2026-10-26',
        bristolType: 6, // Diarrea ligera / inflamación
        discomfortLevel: 4,
        symptomsJson: '["bloating", "gas"]',
      );

      final todayLogs = await digestiveDao.getLogsForDate('2026-10-26');
      expect(todayLogs.length, 1);
      expect(todayLogs.first.bristolType, 6);
      expect(todayLogs.first.discomfortLevel, 4);

      final discomfortLogs = await digestiveDao.getRecentDiscomfortLogs(7);
      expect(discomfortLogs.length, 1);
      expect(discomfortLogs.first.discomfortLevel, 4);
    });

    test('CaffeineDao: Calcula decaimiento exponencial de cafeína (vida media 5.5h)', () async {
      final now = DateTime(2026, 10, 26, 14, 0); // 2:00 PM

      // Registrar espresso doble (160 mg) a las 2:00 PM
      await caffeineDao.logCaffeine(
        dateKey: '2026-10-26',
        sourceName: 'espresso_doble',
        caffeineMg: 160.0,
        loggedAt: now,
      );

      final logs = await caffeineDao.getLogsForDate('2026-10-26');
      expect(logs.length, 1);

      // A las 7:30 PM (5.5h después): debe quedar exactamente la mitad (~80 mg)
      final atHalfLife = now.add(const Duration(minutes: 330));
      final remainingAtHalfLife = CaffeineDao.calculateResidualCaffeineAt(atHalfLife, logs);
      expect(remainingAtHalfLife, closeTo(80.0, 1.0));

      // A las 11:00 PM (9 horas después): C(9) = 160 * 0.5^(9 / 5.5) ≈ 51.5 mg
      final bedtime = now.add(const Duration(hours: 9));
      final remainingBedtime = CaffeineDao.calculateResidualCaffeineAt(bedtime, logs);
      expect(remainingBedtime, inInclusiveRange(48.0, 55.0));
    });

    test('ProtocolDao: Guarda y recupera el plan semanal activo "Mi Protocolo"', () async {
      await protocolDao.saveActiveProtocol(
        planName: 'Protocolo Recomposición Otoño',
        fastingDaysBitmask: '{"1":16,"2":16,"3":16,"4":16,"5":20,"6":0,"7":0}',
        workoutSlotsJson: '[{"day":1,"type":"weights","hour":18}]',
        dietArchetype: 'mediterranean',
      );

      final active = await protocolDao.getActiveProtocol();
      expect(active, isNotNull);
      expect(active!.planName, 'Protocolo Recomposición Otoño');
      expect(active.dietArchetype, 'mediterranean');
    });

    test('MilestoneDao: Divide meta de peso en mini-hitos de 1.5kg (Happy Scale)', () async {
      // Peso actual: 80.0 kg, Meta: 75.0 kg (5 kg a perder) -> 4 hitos (78.5, 77.0, 75.5, 75.0)
      await milestoneDao.generateMilestones(
        currentWeightKg: 80.0,
        targetWeightKg: 75.0,
        stepKg: 1.5,
      );

      final milestones = await milestoneDao.getMilestones();
      expect(milestones.length, 4);
      expect(milestones[0].targetWeightKg, 78.5);
      expect(milestones[1].targetWeightKg, 77.0);
      expect(milestones[2].targetWeightKg, 75.5);
      expect(milestones[3].targetWeightKg, 75.0);

      // Marcar primer hito como completado
      await milestoneDao.markCompleted(milestones[0].id, DateTime.now());
      final updatedMilestones = await milestoneDao.getMilestones();
      expect(updatedMilestones[0].isCompleted, isTrue);
    });

    test('UserProfileDao: Control manual de macronutrientes y arquetipos dietéticos', () async {
      await db.into(db.userProfiles).insert(
            UserProfilesCompanion(
              name: const Value('Nathan'),
              birthDate: Value(DateTime(1995, 5, 20)),
              biologicalSex: const Value(BiologicalSex.male),
              heightCm: const Value(178.0),
              targetWeightKg: const Value(72.0),
            ),
          );

      // Activar modo manual médico (ej. 1800 kcal, 150g P, 180g C, 50g F)
      await userProfileDao.updateManualMacroMode(
        isManual: true,
        manualKcal: 1800,
        manualProteinG: 150,
        manualCarbsG: 180,
        manualFatG: 50,
      );

      await userProfileDao.updateDietArchetype(DietArchetype.mediterranean);
      await userProfileDao.updateDietPhase(DietPhase.dietBreak, startedAt: DateTime(2026, 10, 20));
      await userProfileDao.updateCycleTrackingEnabled(false);
      await userProfileDao.updateFastingEnabled(true);

      final profile = await userProfileDao.getProfile();
      expect(profile, isNotNull);
      expect(profile!.isManualMacroMode, isTrue);
      expect(profile.manualKcalTarget, 1800);
      expect(profile.manualProteinG, 150);
      expect(profile.activeDietArchetype, DietArchetype.mediterranean);
      expect(profile.activeDietPhase, DietPhase.dietBreak);
      expect(profile.isCycleTrackingEnabled, isFalse);
      expect(profile.isFastingEnabled, isTrue);
    });
  });
}
