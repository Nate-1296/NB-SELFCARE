import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/database/daos/health_sync_dao.dart';
import 'package:nb_selfcare/core/database/daos/milestone_dao.dart';
import 'package:nb_selfcare/core/database/daos/pet_dao.dart';
import 'package:nb_selfcare/core/database/daos/supplement_dao.dart';
import 'package:nb_selfcare/core/database/daos/user_profile_dao.dart';
import 'package:nb_selfcare/core/domain/enums.dart';
import 'package:nb_selfcare/features/body_metrics/application/tdee_calibration_service.dart';
import 'package:nb_selfcare/features/body_metrics/application/weigh_in_service.dart';
import 'package:nb_selfcare/features/body_metrics/domain/weigh_in_analyzer.dart';
import 'package:nb_selfcare/features/nutrition_hydration/application/food_logging_service.dart';
import 'package:nb_selfcare/features/profile_goals/application/profile_service.dart';
import 'package:nb_selfcare/features/today/application/daily_activity_service.dart';

import '../support/test_container.dart';

void main() {
  late AppDatabase db;
  final DateTime now = DateTime(2026, 10, 23, 7, 30);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await UserProfileDao(db).createProfile(
      UserProfilesCompanion.insert(
        name: 'Ana',
        birthDate: DateTime(1992, 3, 10),
        biologicalSex: BiologicalSex.female,
        heightCm: 165,
        targetWeightKg: 60,
      ),
    );
    await db.into(db.petStatus).insert(const PetStatusCompanion(coinsBalance: Value(0)));
  });

  tearDown(() => db.close());

  Future<int> coins() async => (await PetDao(db).getPetStatus())!.coinsBalance;

  group('WeighInService (cascada biométrica)', () {
    test('Primer pesaje: guarda EMA inicial, otorga monedas una sola vez al día', () async {
      final ProviderContainer c = createTestContainer(db, now: now);
      addTearDown(c.dispose);
      final WeighInService service = c.read(weighInServiceProvider);

      final WeighInResult first = await service.record(
        weightKg: 64.0,
        impedanceOhms: 520,
        source: MeasurementSource.miScale2Ble,
      );
      expect(first.analysis.trendWeightKg, 64.0);
      expect(first.analysis.hasImpedance, isTrue);
      expect(first.reward.coins, 15);

      final WeighInResult second = await service.record(
        weightKg: 64.2,
        impedanceOhms: null,
        source: MeasurementSource.manual,
      );
      expect(second.reward.granted, isFalse);
      expect(await coins(), 15);

      final List<BodyMeasurement> rows = await db.select(db.bodyMeasurements).get();
      expect(rows, hasLength(2));
      expect(rows.last.impedanceOhms, isNull);
      expect(rows.last.trendWeightKg, closeTo(64.02, 0.01));
    });

    test('La creatina activa explica una subida de peso como agua', () async {
      final ProviderContainer c = createTestContainer(db, now: now);
      addTearDown(c.dispose);
      final SupplementDao supplements = SupplementDao(db);
      final int creatineId = await supplements.createSupplement(
        name: 'Creatina',
        dosage: '5 g',
        affectsWaterRetention: true,
      );
      for (final String day in <String>['2026-10-21', '2026-10-22', '2026-10-23']) {
        await supplements.toggleSupplementIntake(
          supplementId: creatineId,
          dateKey: day,
          wasTaken: true,
        );
      }
      final WeighInService service = c.read(weighInServiceProvider);
      await service.record(weightKg: 64.0, impedanceOhms: null, source: MeasurementSource.manual);

      final ProviderContainer nextDay = createTestContainer(
        db,
        now: now.add(const Duration(days: 1)),
      );
      addTearDown(nextDay.dispose);
      final WeighInResult result = await nextDay
          .read(weighInServiceProvider)
          .record(weightKg: 64.9, impedanceOhms: null, source: MeasurementSource.manual);

      expect(result.analysis.retentionCauses, contains(RetentionCause.creatine));
      final BodyMeasurement latest = (await db.select(db.bodyMeasurements).get()).last;
      expect(latest.isWaterRetentionSpike, isTrue);
      expect(latest.spikeExplanation, contains('creatina'));
    });

    test('Alcanzar un mini-hito con el Peso Tendencia lo marca y premia', () async {
      final ProviderContainer c = createTestContainer(db, now: now);
      addTearDown(c.dispose);
      await MilestoneDao(db).generateMilestones(currentWeightKg: 66, targetWeightKg: 60);
      await db
          .into(db.bodyMeasurements)
          .insert(
            BodyMeasurementsCompanion.insert(
              dateKey: '2026-10-22',
              measuredAt: Value(now.subtract(const Duration(days: 1))),
              source: MeasurementSource.manual,
              weightKg: 64.6,
              trendWeightKg: 64.6,
              bmi: 23.7,
            ),
          );

      final WeighInResult result = await c
          .read(weighInServiceProvider)
          .record(weightKg: 63.5, impedanceOhms: null, source: MeasurementSource.manual);

      expect(result.milestonesReached.map((MilestoneGoal m) => m.targetWeightKg), <double>[64.5]);
      expect(await coins(), 15 + 25);
    });
  });

  group('TdeeCalibrationService', () {
    test('Solo toca recalibrar cada 14 días y nunca en modo manual', () {
      final UserProfile base = UserProfile(
        id: 1,
        name: 'Ana',
        birthDate: DateTime(1992, 3, 10),
        biologicalSex: BiologicalSex.female,
        heightCm: 165,
        targetWeightKg: 60,
        weeklyGoalRateKg: -0.5,
        dailyWaterGoalMl: 2500,
        dailyStepsGoal: 8000,
        dailySleepGoalHours: 7.5,
        currentAdaptiveTdeeKcal: 2000,
        lastTdeeCalibration: now.subtract(const Duration(days: 13)),
        themeMode: 'samsung_dark',
        isLocalAiEnabled: false,
        isCycleTrackingEnabled: false,
        isFastingEnabled: true,
        isManualMacroMode: false,
        activeDietArchetype: DietArchetype.flexible,
        activeDietPhase: DietPhase.deficit,
        calorieCyclingScheduleJson: '{}',
        caffeineBedtimeCutoffHours: 8,
        hasImpedanceContraindication: false,
        hasEatingDisorderHistory: false,
        takesHypoglycemicMedication: false,
        hasEinkScreen: false,
        hasSmartScale: true,
        vitalDevicesJson: '[]',
        careModulesJson:
            '["treatments","pelvic_floor","active_breaks","symptoms","checkups","habits"]',
        discreetNotifications: true,
        targetBedtimeMinutes: 1380,
        createdAt: DateTime(2026, 1, 1),
      );
      expect(TdeeCalibrationService.isDue(base, now), isFalse);
      expect(
        TdeeCalibrationService.isDue(
          base.copyWith(lastTdeeCalibration: Value(now.subtract(const Duration(days: 14)))),
          now,
        ),
        isTrue,
      );
      expect(
        TdeeCalibrationService.isDue(
          base.copyWith(lastTdeeCalibration: const Value(null), isManualMacroMode: true),
          now,
        ),
        isFalse,
      );
    });
  });

  group('FoodLoggingService', () {
    Future<FoodItem> oats() async {
      final int id = await db
          .into(db.foodItems)
          .insert(
            FoodItemsCompanion.insert(
              name: 'Avena',
              source: FoodSource.usdaSeed,
              kcalPer100g: 389,
              proteinPer100g: 16.9,
              carbsPer100g: 66.3,
              fatPer100g: 6.9,
            ),
          );
      return (db.select(db.foodItems)..where((t) => t.id.equals(id))).getSingle();
    }

    test('Desayuno da monedas una vez; los snacks no dan', () async {
      final ProviderContainer c = createTestContainer(db, now: now);
      addTearDown(c.dispose);
      final FoodLoggingService service = c.read(foodLoggingServiceProvider);
      final FoodItem food = await oats();

      final FoodLogResult first = await service.logPortion(
        food: food,
        grams: 40,
        mealType: MealType.breakfast,
        dateKey: '2026-10-23',
      );
      final FoodLogResult second = await service.logPortion(
        food: food,
        grams: 40,
        mealType: MealType.breakfast,
        dateKey: '2026-10-23',
      );
      final FoodLogResult snack = await service.logPortion(
        food: food,
        grams: 30,
        mealType: MealType.snack,
        dateKey: '2026-10-23',
      );

      expect(first.coins, 10);
      expect(second.coins, 0);
      expect(snack.coins, 0);
      expect(await coins(), 10);
    });

    test('Repetir ayer copia cada bloque y premia cada comida principal', () async {
      final ProviderContainer c = createTestContainer(db, now: now);
      addTearDown(c.dispose);
      final FoodLoggingService service = c.read(foodLoggingServiceProvider);
      final FoodItem food = await oats();
      for (final MealType meal in <MealType>[MealType.breakfast, MealType.dinner]) {
        await service.logPortion(food: food, grams: 50, mealType: meal, dateKey: '2026-10-22');
      }
      final int before = await coins();

      final FoodLogResult result = await service.repeatYesterday(toDateKey: '2026-10-23');
      expect(result.logIds, hasLength(2));
      expect(result.coins, 20);
      expect(await coins(), before + 20);

      await service.deleteLogs(result.logIds);
      final List<FoodLog> today = await (db.select(
        db.foodLogs,
      )..where((t) => t.dateKey.equals('2026-10-23'))).get();
      expect(today, isEmpty);
    });
  });

  group('DailyActivityService', () {
    test('Registrar sueño en un día nuevo no falla y no inventa fases REM/profundo', () async {
      final ProviderContainer c = createTestContainer(db, now: now);
      addTearDown(c.dispose);
      final int earned = await c
          .read(dailyActivityServiceProvider)
          .saveManualEntry(dateKey: '2026-10-23', steps: 6400, sleepMinutes: 470);

      final DailySummary summary = (await HealthSyncDao(db).getSummaryForDate('2026-10-23'))!;
      expect(summary.sleepDurationMinutes, 470);
      expect(summary.sleepDeepMinutes, 0);
      expect(summary.sleepRemMinutes, 0);
      expect(summary.calorieTargetKcal, 0);
      expect(earned, 23, reason: 'Cumplió la meta de 7,5 h: 15 × 1.5');
    });

    test('Dormir menos de la meta no da monedas de sueño', () async {
      final ProviderContainer c = createTestContainer(db, now: now);
      addTearDown(c.dispose);
      final int earned = await c
          .read(dailyActivityServiceProvider)
          .saveManualEntry(dateKey: '2026-10-23', steps: 0, sleepMinutes: 360);
      expect(earned, 0);
    });
  });

  group('ProfileService', () {
    test('Cambiar de fase de dieta registra su fecha de inicio', () async {
      final ProviderContainer c = createTestContainer(db, now: now);
      addTearDown(c.dispose);
      await c
          .read(profileServiceProvider)
          .update(const UserProfilesCompanion(activeDietPhase: Value(DietPhase.reverseDiet)));
      final UserProfile profile = (await UserProfileDao(db).getProfile())!;
      expect(profile.activeDietPhase, DietPhase.reverseDiet);
      expect(profile.activeDietPhaseStartedAt, now);
    });
  });
}
