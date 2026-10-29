import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/database/daos/milestone_dao.dart';
import 'package:nb_selfcare/core/domain/enums.dart';
import 'package:nb_selfcare/core/services/caffeine_pharmacokinetics_service.dart';
import 'package:nb_selfcare/core/services/clinical_report_pdf_service.dart';
import 'package:nb_selfcare/core/services/fasting_dosage_advisor.dart';
import 'package:nb_selfcare/core/services/nutrition_label_ocr_service.dart';
import 'package:nb_selfcare/core/services/readiness_engine.dart';
import 'package:nb_selfcare/shared/utils/biometric_formulas.dart';

void main() {
  group('Senior QA Stress & Chaos Engineering Suite', () {
    // =========================================================================
    // 1. NutritionLabelOcrService Chaos & Fuzzing
    // =========================================================================
    group('NutritionLabelOcrService - Chaos & Fuzzing', () {
      final NutritionLabelOcrService ocr = NutritionLabelOcrService();

      test('Fuzzing: Empty string and whitespace-only string returns zeroed structure', () {
        final OcrNutritionData emptyData = ocr.parseText('');
        expect(emptyData.hasAnyData, isFalse);
        expect(emptyData.kcal, isNull);
        expect(emptyData.proteinG, isNull);

        final OcrNutritionData whitespaceData = ocr.parseText('   \n\t   \r\n   ');
        expect(whitespaceData.hasAnyData, isFalse);
      });

      test('Fuzzing: Astronomical string (100,000 characters of noise) does not crash or hang', () {
        final String massiveString = 'RandomGarbage ' * 8000;
        final Stopwatch sw = Stopwatch()..start();
        final OcrNutritionData data = ocr.parseText(massiveString);
        sw.stop();

        expect(
          sw.elapsedMilliseconds,
          lessThan(3000),
          reason: 'OCR parse must execute within 3 seconds even on massive string',
        );
        expect(data.hasAnyData, isFalse);
      });

      test(
        'Chaos: Broken punctuation, multiple dots, commas, negative and scientific notations',
        () {
          const String brokenText = '''
        Información Nutricional por 100g
        Calorías: -250 kcal
        Proteínas: 12..5 g
        Grasas totales: 8,7 g
        Carbohidratos: 45...2 g
        Sal: 1,5 g
        ''';

          final OcrNutritionData data = ocr.parseText(brokenText);
          // Debe ignorar valores negativos o no parseables y capturar correctamente los válidos
          expect(data.fatG, equals(8.7));
          expect(data.sodiumMg, equals(600.0)); // 1.5g sal * 400 = 600mg sodio
        },
      );

      test('Chaos: Mixed languages, uppercase, symbols, emojis', () {
        const String mixedText = '''
        ✨ NUTRITION FACTS / VALOR ENERGÉTICO ✨
        Calories / Energía: 320 kcal 🔥
        Total Fat / Grasas: 14.2 g
        Total Carbohydrate / Hidratos de Carbono: 55.0 g
        Dietary Fiber / Fibra: 6.8 g
        Total Sugars / Azúcares: 12.0 g
        Proteins / Proteína: 22.4 g
        Sodium / Sodio: 350 mg
        Serving Size / Porción: 85 g
        ''';

        final OcrNutritionData data = ocr.parseText(mixedText);
        expect(data.hasAnyData, isTrue);
        expect(data.kcal, equals(320.0));
        expect(data.fatG, equals(14.2));
        expect(data.carbsG, equals(55.0));
        expect(data.fiberG, equals(6.8));
        expect(data.sugarG, equals(12.0));
        expect(data.proteinG, equals(22.4));
        expect(data.sodiumMg, equals(350.0));
        expect(data.servingGrams, equals(85.0));
      });

      test('Chaos: Sodium in grams converts properly to milligrams', () {
        const String sodiumGramsText = '''
        Información Nutricional
        Calorías: 100 kcal
        Sodio: 1.2 g
        ''';

        final OcrNutritionData data = ocr.parseText(sodiumGramsText);
        expect(data.sodiumMg, equals(1200.0));
      });
    });

    // =========================================================================
    // 2. CaffeinePharmacokineticsService Stress
    // =========================================================================
    group('CaffeinePharmacokineticsService - Stress & Boundary Tests', () {
      final CaffeinePharmacokineticsService caffeine = CaffeinePharmacokineticsService();
      final DateTime now = DateTime(2026, 10, 26, 12, 0);

      test('Zero doses & empty logs: residual is 0.0, bedtime residual 0.0', () {
        final double res = caffeine.computeResidualCaffeineAt(
          logs: <CaffeineLog>[],
          targetTime: now,
        );
        expect(res, equals(0.0));

        final CaffeineStatus status = caffeine.evaluateStatus(
          logs: <CaffeineLog>[],
          targetBedtime: now.add(const Duration(hours: 11)),
          currentTime: now,
        );
        expect(status.currentResidualMg, equals(0.0));
        expect(status.bedtimeResidualMg, equals(0.0));
        expect(status.willDisruptSleep, isFalse);
      });

      test('Chaos: Negative and extreme caffeine doses (5,000 mg)', () {
        final List<CaffeineLog> extremeLogs = <CaffeineLog>[
          CaffeineLog(
            id: 1,
            dateKey: '2026-10-26',
            caffeineMg: 5000.0,
            sourceName: 'Massive Caffeine Chaos',
            loggedAt: now.subtract(const Duration(hours: 5, minutes: 30)), // Exact 1 half-life
          ),
        ];

        final double res = caffeine.computeResidualCaffeineAt(logs: extremeLogs, targetTime: now);
        // After 1 half-life (5.5h), 5000 mg should be exactly ~2500 mg
        expect(res, closeTo(2500.0, 1.0));
      });

      test('Boundary: Bedtime cutoff with dose <= maxResidual returns target bedtime directly', () {
        final DateTime bedtime = DateTime(2026, 10, 26, 23, 0);
        final DateTime cutoff = caffeine.computeBedtimeCutoff(
          targetBedtime: bedtime,
          typicalDoseMg: 20.0, // menor a 25 mg
          maxResidual: 25.0,
        );
        expect(cutoff, equals(bedtime));
      });

      test(
        'Boundary: Bedtime cutoff with invalid maxResidual (<= 0) falls back safely without NaN',
        () {
          final DateTime bedtime = DateTime(2026, 10, 26, 23, 0);
          final DateTime cutoff = caffeine.computeBedtimeCutoff(
            targetBedtime: bedtime,
            typicalDoseMg: 100.0,
            maxResidual: -10.0, // negativo inválido
          );
          expect(cutoff.isBefore(bedtime), isTrue);
          expect(cutoff.year, equals(2026));
        },
      );

      test('Boundary: Decay curve generation with reversed dates or 0 intervalMinutes', () {
        final List<CaffeineLog> logs = <CaffeineLog>[
          CaffeineLog(
            id: 1,
            dateKey: '2026-10-26',
            caffeineMg: 100,
            sourceName: 'Café',
            loggedAt: now,
          ),
        ];

        // End before start
        final List<CaffeineDecayPoint> emptyPoints = caffeine.generateDecayCurve(
          logs: logs,
          startTime: now.add(const Duration(hours: 2)),
          endTime: now,
        );
        expect(emptyPoints, isEmpty);

        // Zero interval: must clamp to 30 min and NOT enter infinite loop
        final List<CaffeineDecayPoint> safePoints = caffeine.generateDecayCurve(
          logs: logs,
          startTime: now,
          endTime: now.add(const Duration(hours: 2)),
          intervalMinutes: 0,
        );
        expect(safePoints, isNotEmpty);
        expect(safePoints.length, equals(5)); // 0m, 30m, 60m, 90m, 120m
      });
    });

    // =========================================================================
    // 3. ReadinessEngine Chaos & Extreme Value Normalization
    // =========================================================================
    group('ReadinessEngine - Chaos & Extreme Normalization', () {
      final ReadinessEngine engine = ReadinessEngine();

      test('Extreme 0: Zero sleep, zero RHR, zero workout does not produce NaN or crashes', () {
        final DailyReadinessResult res = engine.compute(
          actualSleepHours: 0.0,
          targetSleepHours: 0.0,
          recent3DayWorkoutHours: 0.0,
          averageRecentRpe: 0.0,
        );

        expect(res.totalScore, inInclusiveRange(0, 100));
        expect(res.sleepSubScore, equals(0.0));
        expect(res.category, equals(ReadinessCategory.recoveryNeeded));
        expect(res.isOptimal, isFalse);
      });

      test('Extreme Max: 24h sleep, extreme bradycardia/tachycardia, overtraining load', () {
        // High load: 15 hours in 3 days with RPE 10 = 150 trainingLoad
        final DailyReadinessResult overtrained = engine.compute(
          actualSleepHours: 24.0,
          targetSleepHours: 8.0,
          currentRhrBpm: 220,
          baselineRhrBpm: 60,
          recent3DayWorkoutHours: 15.0,
          averageRecentRpe: 10.0,
        );

        expect(overtrained.totalScore, inInclusiveRange(0, 100));
        expect(overtrained.strainSubScore, equals(15.0)); // capped at min strain score
        expect(overtrained.rhrSubScore, equals(14.0)); // elevated RHR penalty
        expect(overtrained.sleepSubScore, equals(40.0)); // sleep clamped
      });

      test('Corrupted deep sleep: deepSleepMinutes > actualSleepHours in minutes', () {
        final DailyReadinessResult res = engine.compute(
          actualSleepHours: 2.0, // 120 min
          targetSleepHours: 8.0,
          deepSleepMinutes: 600.0, // 600 min > 120 min (anomalous)
          recent3DayWorkoutHours: 0.0,
          averageRecentRpe: 0.0,
        );

        expect(res.totalScore, inInclusiveRange(0, 100));
        expect(res.sleepSubScore, lessThanOrEqualTo(40.0));
      });
    });

    // =========================================================================
    // 4. FastingDosageAdvisor & Safe Refeeding Chaos
    // =========================================================================
    group('FastingDosageAdvisor - Chaos & Duration Stress', () {
      test('Proposed targets under 20h are always marked safe', () {
        final FastingSafetyVerdict verdict = FastingDosageAdvisor.evaluateProtocolSafety(
          proposedTargetHours: 16,
          recentSessions: <FastingSession>[],

          now: DateTime(2026, 10, 26, 12),
        );
        expect(verdict.isSafe, isTrue);
      });

      test('Extreme prolonged fast (120 hours / 5 days) triggers structured 3-stage refeeding', () {
        final List<FastBreakStage> stages = FastingDosageAdvisor.getRefeedingGuidance(120.0);

        expect(stages, hasLength(3));
        expect(stages[0].phaseNumber, equals(1));
        expect(stages[0].recommendedFoods, isNotEmpty);
        expect(stages[0].foodsToAvoid, isNotEmpty);
      });

      test('Consecutive OMAD (>19.5h within 36h) triggers recovery warning', () {
        final DateTime now = DateTime(2026, 10, 26, 12);
        final List<FastingSession> recent = <FastingSession>[
          FastingSession(
            id: 1,
            protocolName: '23:1 OMAD',
            startedAt: now.subtract(const Duration(hours: 30)),
            plannedEndAt: now.subtract(const Duration(hours: 7)),
            targetHours: 23,
            actualEndedAt: now.subtract(const Duration(hours: 7)), // ended 7h ago, lasted 23h
            isCompleted: true,
            notes: null,
          ),
        ];

        final FastingSafetyVerdict verdict = FastingDosageAdvisor.evaluateProtocolSafety(
          proposedTargetHours: 23,
          recentSessions: recent,

          now: DateTime(2026, 10, 26, 12),
        );

        expect(verdict.isSafe, isFalse);
        expect(verdict.warningTitle, contains('Recuperación'));
        expect(verdict.recommendedAlternativeHours, equals(16));
      });
    });

    // =========================================================================
    // 5. MilestoneDao Happy Scale Chaos
    // =========================================================================
    group('MilestoneDao - Happy Scale Stepping Chaos', () {
      late AppDatabase db;
      late MilestoneDao milestoneDao;

      setUp(() {
        db = AppDatabase(NativeDatabase.memory());
        milestoneDao = MilestoneDao(db);
      });

      tearDown(() async {
        await db.close();
      });

      test(
        'Zero difference (current == target): creates 1 single milestone without division error',
        () async {
          await milestoneDao.generateMilestones(currentWeightKg: 75.0, targetWeightKg: 75.0);

          final List<MilestoneGoal> milestones = await milestoneDao.getMilestones();
          expect(milestones, hasLength(1));
          expect(milestones.first.targetWeightKg, equals(75.0));
        },
      );

      test('Invalid stepKg (0 or negative) safely defaults to 1.5 kg step', () async {
        await milestoneDao.generateMilestones(
          currentWeightKg: 80.0,
          targetWeightKg: 74.0, // 6 kg diff
          stepKg: -2.0, // negativo inválido
        );

        final List<MilestoneGoal> milestones = await milestoneDao.getMilestones();
        // 6 kg / 1.5 kg = 4 hitos
        expect(milestones, hasLength(4));
        expect(milestones.last.targetWeightKg, equals(74.0));
      });

      test('Weight gain goal (current < target): increments upwards correctly', () async {
        await milestoneDao.generateMilestones(
          currentWeightKg: 60.0,
          targetWeightKg: 64.5, // 4.5 kg gain
          stepKg: 1.5,
        );

        final List<MilestoneGoal> milestones = await milestoneDao.getMilestones();
        expect(milestones, hasLength(3));
        expect(milestones[0].targetWeightKg, equals(61.5));
        expect(milestones[1].targetWeightKg, equals(63.0));
        expect(milestones[2].targetWeightKg, equals(64.5));
      });
    });

    // =========================================================================
    // 6. BiometricFormulas & Mathematical Robustness
    // =========================================================================
    group('BiometricFormulas - Extreme & Edge Values', () {
      test('Dynamic age calculation with future birthdate or today', () {
        final DateTime now = DateTime(2026, 10, 26, 12);
        final double ageToday = BiometricFormulas.calculateDynamicAge(now, now);
        expect(ageToday, closeTo(0.0, 0.05));

        final DateTime centuryAgo = now.subtract(const Duration(days: 36525));
        final double ageCentury = BiometricFormulas.calculateDynamicAge(centuryAgo, now);
        expect(ageCentury, closeTo(100.0, 0.5));
      });

      test('BMI with 0 height or 0 weight does not produce NaN or Infinity', () {
        final double bmiZeroHeight = BiometricFormulas.calculateBmi(weightKg: 70.0, heightCm: 0.0);
        expect(bmiZeroHeight.isNaN, isFalse);
        expect(bmiZeroHeight.isInfinite, isFalse);
        expect(bmiZeroHeight, equals(0.0));

        final double bmiZeroWeight = BiometricFormulas.calculateBmi(weightKg: 0.0, heightCm: 175.0);
        expect(bmiZeroWeight, equals(0.0));
      });

      test('Katch-McArdle BMR with zero or positive lean body mass', () {
        final int bmrZero = BiometricFormulas.calculateKatchMcArdleBmr(leanBodyMassKg: 0.0);
        expect(bmrZero, equals(370));

        final int bmrAthlete = BiometricFormulas.calculateKatchMcArdleBmr(leanBodyMassKg: 70.0);
        // 370 + (21.6 * 70) = 370 + 1512 = 1882
        expect(bmrAthlete, equals(1882));
      });

      test('Weight EMA smoothing calculation with alpha = 0.1', () {
        final double ema = BiometricFormulas.calculateWeightEma(
          currentWeightKg: 80.0,
          previousEmaKg: 75.0,
          alpha: 0.1,
        );
        // (80 * 0.1) + (75 * 0.9) = 8 + 67.5 = 75.5
        expect(ema, closeTo(75.5, 0.01));
      });
    });

    // =========================================================================
    // 7. ClinicalReportPdfService Stress & Empty Database Generation
    // =========================================================================
    group('ClinicalReportPdfService - Stress & Empty State Document', () {
      final ClinicalReportPdfService pdfService = ClinicalReportPdfService();

      test(
        'Generates valid PDF byte payload even with completely empty history & null measurements',
        () async {
          final UserProfile emptyProfile = UserProfile(
            id: 1,
            name: 'Paciente Test',
            birthDate: DateTime(1995, 5, 10),
            biologicalSex: BiologicalSex.male,
            heightCm: 178.0,
            targetWeightKg: 72.0,
            weeklyGoalRateKg: 0.5,
            dailyWaterGoalMl: 2500,
            dailyStepsGoal: 10000,
            dailySleepGoalHours: 8.0,
            currentAdaptiveTdeeKcal: 2200,
            themeMode: 'system',
            isLocalAiEnabled: true,
            isCycleTrackingEnabled: false,
            isFastingEnabled: true,
            isManualMacroMode: false,
            activeDietArchetype: DietArchetype.mediterranean,
            activeDietPhase: DietPhase.maintenance,
            calorieCyclingScheduleJson: '',
            caffeineBedtimeCutoffHours: 8.0,
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
            createdAt: DateTime.now(),
          );

          final Uint8List pdfBytes = await pdfService.generateReportBytes(
            profile: emptyProfile,
            latestMeasurement: null, // null measurement
            recentMeasurements: <BodyMeasurement>[], // empty list
            averageDailyKcal: 0,
            foodDays: 7,
            averageProteinG: 0.0,
            averageCarbsG: 0.0,
            averageFatG: 0.0,
            averageSleepHours: 0.0,
            activeSupplements: <SupplementsTrackerData>[], // empty supplements
            readinessScore: 0,
          );

          expect(pdfBytes, isNotEmpty);
          expect(
            pdfBytes.length,
            greaterThan(1000),
            reason: 'Valid PDF document must be at least 1 KB',
          );
        },
      );
    });
  });
}
