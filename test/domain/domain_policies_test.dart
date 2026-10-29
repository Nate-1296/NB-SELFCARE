import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/domain/enums.dart';
import 'package:nb_selfcare/features/body_metrics/domain/weigh_in_analyzer.dart';
import 'package:nb_selfcare/features/pet_gamification/domain/reward_policy.dart';
import 'package:nb_selfcare/shared/utils/cycle_phase_calculator.dart';
import 'package:nb_selfcare/shared/utils/daily_targets_calculator.dart';
import 'package:nb_selfcare/shared/utils/diet_phase_policy.dart';

UserProfile _profile({
  DietPhase phase = DietPhase.deficit,
  DietArchetype archetype = DietArchetype.flexible,
  DateTime? phaseStartedAt,
  double weeklyRate = -0.5,
  bool edHistory = false,
}) {
  return UserProfile(
    id: 1,
    name: 'Ana',
    birthDate: DateTime(1992, 3, 10),
    biologicalSex: BiologicalSex.female,
    heightCm: 165,
    targetWeightKg: 60,
    weeklyGoalRateKg: weeklyRate,
    dailyWaterGoalMl: 2500,
    dailyStepsGoal: 8000,
    dailySleepGoalHours: 7.5,
    currentAdaptiveTdeeKcal: 2200,
    themeMode: 'samsung_dark',
    isLocalAiEnabled: false,
    isCycleTrackingEnabled: true,
    isFastingEnabled: true,
    isManualMacroMode: false,
    activeDietArchetype: archetype,
    activeDietPhase: phase,
    calorieCyclingScheduleJson: '{}',
    caffeineBedtimeCutoffHours: 8,
    activeDietPhaseStartedAt: phaseStartedAt,
    hasImpedanceContraindication: false,
    hasEatingDisorderHistory: edHistory,
    takesHypoglycemicMedication: false,
    hasEinkScreen: false,
    hasSmartScale: true,
    vitalDevicesJson: '[]',
    careModulesJson: '["treatments","pelvic_floor","active_breaks","symptoms","checkups","habits"]',
    discreetNotifications: true,
    targetBedtimeMinutes: 1380,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  final DateTime now = DateTime(2026, 10, 26, 9);

  group('RewardPolicy', () {
    test('El multiplicador 1.5× exige cumplir la meta de sueño del perfil', () {
      expect(
        RewardPolicy.sleepMultiplier(
          sleepMinutes: 420,
          deepMinutes: 0,
          remMinutes: 0,
          sleepGoalHours: 7.5,
        ),
        1.0,
      );
      expect(
        RewardPolicy.sleepMultiplier(
          sleepMinutes: 450,
          deepMinutes: 0,
          remMinutes: 0,
          sleepGoalHours: 7.5,
        ),
        1.5,
      );
      expect(
        RewardPolicy.sleepMultiplier(
          sleepMinutes: 400,
          deepMinutes: 50,
          remMinutes: 45,
          sleepGoalHours: 8,
        ),
        1.5,
        reason: 'REM + profundo ≥ 90 min también cuenta como reparador',
      );
    });

    test('Las monedas se redondean hacia arriba', () {
      expect(RewardPolicy.amountFor(RewardAction.weighIn, 1.5), 23);
      expect(RewardPolicy.amountFor(RewardAction.journalEntry, 1.0), 10);
    });

    test('Los snacks no dan monedas y cada comida principal tiene su propia clave diaria', () {
      expect(RewardAction.mealLogged(MealType.snack), isNull);
      expect(RewardAction.mealLogged(MealType.lunch)!.ledgerKey, 'meal_log_lunch');
      expect(RewardAction.mealLogged(MealType.lunch), RewardAction.mealLogged(MealType.lunch));
    });
  });

  group('DietPhasePolicy', () {
    test('Reverse diet suma 75 kcal por semana completa hasta llegar a mantenimiento', () {
      int adjustment(int days) => DietPhasePolicy.dailyAdjustmentKcal(
        phase: DietPhase.reverseDiet,
        weeklyGoalRateKg: -0.5,
        phaseStartedAt: now.subtract(Duration(days: days)),
        now: now,
      );
      expect(adjustment(0), -550);
      expect(adjustment(7), -475);
      expect(adjustment(20), -400);
      expect(adjustment(70), 0, reason: 'Nunca pasa a superávit');
    });

    test('Mantenimiento y diet break son normocalóricos', () {
      for (final DietPhase phase in <DietPhase>[DietPhase.maintenance, DietPhase.dietBreak]) {
        expect(
          DietPhasePolicy.dailyAdjustmentKcal(
            phase: phase,
            weeklyGoalRateKg: -0.75,
            phaseStartedAt: null,
            now: now,
          ),
          0,
        );
      }
    });

    test('Con historial de TCA el déficit diario se limita a 275 kcal', () {
      expect(
        DietPhasePolicy.dailyAdjustmentKcal(
          phase: DietPhase.deficit,
          weeklyGoalRateKg: -1.0,
          phaseStartedAt: null,
          now: now,
          hasEatingDisorderHistory: true,
        ),
        -275,
      );
      expect(
        DietPhasePolicy.dailyAdjustmentKcal(
          phase: DietPhase.deficit,
          weeklyGoalRateKg: -2.0,
          phaseStartedAt: null,
          now: now,
        ),
        -1100,
        reason: 'Piso de seguridad general (~1 kg/semana)',
      );
    });

    test('El diet break se marca como vencido pasados 14 días', () {
      expect(
        DietPhasePolicy.isDietBreakOverdue(
          phase: DietPhase.dietBreak,
          phaseStartedAt: now.subtract(const Duration(days: 15)),
          now: now,
        ),
        isTrue,
      );
      expect(
        DietPhasePolicy.isDietBreakOverdue(
          phase: DietPhase.dietBreak,
          phaseStartedAt: now.subtract(const Duration(days: 10)),
          now: now,
        ),
        isFalse,
      );
    });
  });

  group('DailyTargetsCalculator', () {
    test('El arquetipo keto reparte los macros con sus porcentajes', () {
      final DailyMacroTargets keto = DailyTargetsCalculator.compute(
        profile: _profile(archetype: DietArchetype.keto),
        now: now,
        currentWeightKg: 64,
      );
      final DailyMacroTargets flexible = DailyTargetsCalculator.compute(
        profile: _profile(),
        now: now,
        currentWeightKg: 64,
      );
      expect(keto.effectiveCalorieTargetKcal, flexible.effectiveCalorieTargetKcal);
      expect(keto.carbsTargetG, lessThan(30));
      expect(keto.fatTargetG, greaterThan(flexible.fatTargetG));
    });

    test('La compensación lútea y el ejercicio suman a la meta del día', () {
      final DailyMacroTargets base = DailyTargetsCalculator.compute(
        profile: _profile(),
        now: now,
        currentWeightKg: 64,
      );
      final DailyMacroTargets adjusted = DailyTargetsCalculator.compute(
        profile: _profile(),
        now: now,
        currentWeightKg: 64,
        netWorkoutKcal: 200,
        lutealCaloricSurgeKcal: 150,
      );
      expect(adjusted.effectiveCalorieTargetKcal - base.effectiveCalorieTargetKcal, 350);
    });
  });

  group('CyclePhaseCalculator', () {
    final DateTime start = DateTime(2026, 10, 1);
    FemaleCyclePhase phaseOn(int day, int length) => CyclePhaseCalculator.phaseFor(
      cycleStart: start,
      cycleLengthDays: length,
      date: start.add(Duration(days: day - 1)),
    ).phase;

    test('Ciclo de 28 días', () {
      expect(phaseOn(3, 28), FemaleCyclePhase.menstrual);
      expect(phaseOn(10, 28), FemaleCyclePhase.follicular);
      expect(phaseOn(14, 28), FemaleCyclePhase.ovulatory);
      expect(phaseOn(22, 28), FemaleCyclePhase.luteal);
    });

    test('En ciclos largos la fase lútea son los últimos 14 días', () {
      expect(phaseOn(17, 35), FemaleCyclePhase.follicular);
      expect(phaseOn(21, 35), FemaleCyclePhase.ovulatory);
      expect(phaseOn(30, 35), FemaleCyclePhase.luteal);
    });

    test('Una fecha anterior al inicio no tiene fase', () {
      expect(
        CyclePhaseCalculator.phaseFor(
          cycleStart: start,
          cycleLengthDays: 28,
          date: start.subtract(const Duration(days: 1)),
        ).phase,
        FemaleCyclePhase.unknown,
      );
    });
  });

  group('WeighInAnalyzer', () {
    WeighInAnalysis analyze({
      required double weight,
      required RetentionContext context,
      PreviousWeighIn previous = const PreviousWeighIn(weightKg: 64, trendWeightKg: 64.2),
      int? impedance,
    }) {
      return WeighInAnalyzer.analyze(
        weightKg: weight,
        impedanceOhms: impedance,
        heightCm: 165,
        birthDate: DateTime(1992, 3, 10),
        sex: BiologicalSex.female,
        measuredAt: now,
        previous: previous,
        context: context,
      );
    }

    test('Detecta invitados con desviación > 8% de la tendencia', () {
      expect(WeighInAnalyzer.guestDeviation(weightKg: 80, previousTrendKg: 64), isNotNull);
      expect(WeighInAnalyzer.guestDeviation(weightKg: 65, previousTrendKg: 64), isNull);
      expect(WeighInAnalyzer.guestDeviation(weightKg: 80, previousTrendKg: null), isNull);
    });

    test('La creatina y la fase lútea explican una subida de agua', () {
      final WeighInAnalysis a = analyze(
        weight: 64.8,
        context: const RetentionContext(isLutealPhase: true, takesWaterRetainingSupplement: true),
      );
      expect(a.retentionCauses, <RetentionCause>[
        RetentionCause.lutealPhase,
        RetentionCause.creatine,
      ]);
      expect(a.spikeExplanation, contains('No es grasa'));
    });

    test('Sin causa fisiológica una subida no se etiqueta como retención', () {
      expect(
        analyze(weight: 64.8, context: const RetentionContext()).isWaterRetentionSpike,
        isFalse,
      );
    });

    test('El salto de agua BIA exige impedancia en ambos pesajes', () {
      final WeighInAnalysis estimated = analyze(
        weight: 64.8,
        context: const RetentionContext(),
        previous: const PreviousWeighIn(weightKg: 64, trendWeightKg: 64, waterPercentage: 40),
      );
      expect(estimated.retentionCauses, isNot(contains(RetentionCause.biaWaterShift)));
    });

    test('La EMA avanza con alfa 0.1 desde la tendencia previa', () {
      final WeighInAnalysis a = analyze(weight: 65.2, context: const RetentionContext());
      expect(a.trendWeightKg, closeTo(64.2 + 0.1 * (65.2 - 64.2), 0.01));
    });
  });
}
