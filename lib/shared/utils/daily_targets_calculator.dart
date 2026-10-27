import 'dart:math' as math;

import '../../core/database/app_database.dart';
import '../../core/domain/enums.dart';
import '../../core/services/smart_meal_suggester.dart';
import 'biometric_formulas.dart';
import 'diet_phase_policy.dart';

/// Objetivos nutricionales y electrolíticos consolidados para un día específico.
class DailyMacroTargets {
  const DailyMacroTargets({
    required this.baseTdeeKcal,
    required this.goalAdjustmentKcal,
    required this.netWorkoutKcal,
    required this.effectiveCalorieTargetKcal,
    required this.proteinTargetG,
    required this.carbsTargetG,
    required this.fatTargetG,
    required this.fiberTargetG,
    required this.sodiumTargetMg,
    required this.potassiumTargetMg,
    required this.magnesiumTargetMg,
  });

  final int baseTdeeKcal;
  final int goalAdjustmentKcal;
  final int netWorkoutKcal;
  final int effectiveCalorieTargetKcal;
  final double proteinTargetG;
  final double carbsTargetG;
  final double fatTargetG;
  final double fiberTargetG;
  final double sodiumTargetMg;
  final double potassiumTargetMg;
  final double magnesiumTargetMg;
}

/// Calculadora centralizada y determinista de metas calóricas, macronutrientes
/// y electrolitos diarios. Garantiza coherencia absoluta entre Hoy, Nutrición y Perfil.
abstract final class DailyTargetsCalculator {
  /// Estima el TDEE inicial (Mifflin-St Jeor * factor moderado NEAT 1.375)
  /// al crear o actualizar un perfil antes de la primera calibración de 14 días.
  static int estimateInitialTdee({
    required double weightKg,
    required double heightCm,
    required DateTime birthDate,
    required BiologicalSex biologicalSex,
    required DateTime now,
    int dailyStepsGoal = 8000,
  }) {
    final double ageYears = BiometricFormulas.calculateDynamicAge(birthDate, now);
    final bool isMale = biologicalSex == BiologicalSex.male;
    final double bmr = (10.0 * weightKg) +
        (6.25 * heightCm) -
        (5.0 * ageYears) +
        (isMale ? 5.0 : -161.0);

    final double activityFactor;
    if (dailyStepsGoal >= 12000) {
      activityFactor = 1.55;
    } else if (dailyStepsGoal >= 8000) {
      activityFactor = 1.42;
    } else if (dailyStepsGoal >= 5000) {
      activityFactor = 1.32;
    } else {
      activityFactor = 1.22;
    }

    return (bmr * activityFactor).round().clamp(1200, 4500);
  }

  /// Calcula la Tasa Metabólica Basal (BMR Mifflin-St Jeor) actual del usuario.
  static int estimateBmr({
    required UserProfile profile,
    required DateTime referenceDate,
    double? currentWeightKg,
  }) {
    final double ageYears =
        BiometricFormulas.calculateDynamicAge(profile.birthDate, referenceDate);
    final bool isMale = profile.biologicalSex == BiologicalSex.male;
    final double refWeight = currentWeightKg ?? profile.targetWeightKg;
    final double bmr = (10.0 * refWeight) +
        (6.25 * profile.heightCm) -
        (5.0 * ageYears) +
        (isMale ? 5.0 : -161.0);
    return bmr.round().clamp(1000, 3200);
  }

  /// Calcula la meta efectiva del día integrando TDEE adaptativo, ritmo semanal
  /// (déficit/mantenimiento/superávit), fases de dieta y gasto neto de ejercicio (RPE/METs).
  /// Si el usuario activó [isManualMacroMode], se respetan sus valores médicos o personalizados.
  static DailyMacroTargets compute({
    required UserProfile profile,
    required DateTime now,
    double? currentWeightKg,
    int netWorkoutKcal = 0,
    int lutealCaloricSurgeKcal = 0,
  }) {
    final double ageYears = BiometricFormulas.calculateDynamicAge(profile.birthDate, now);
    final bool isMale = profile.biologicalSex == BiologicalSex.male;
    final double refWeight = currentWeightKg ?? profile.targetWeightKg;

    // 1. Caso Especial: Modo Manual / Prescripción Médica o Deportiva
    if (profile.isManualMacroMode && profile.manualKcalTarget != null) {
      final int manualKcal = profile.manualKcalTarget!;
      final double manualProtein = (profile.manualProteinG ?? (profile.targetWeightKg * 2.0)).toDouble();
      final double manualCarbs = (profile.manualCarbsG ?? 150).toDouble();
      final double manualFat = (profile.manualFatG ?? 50).toDouble();
      final double fiberG = ((manualKcal / 1000.0) * 14.0).clamp(20.0, 45.0);

      return DailyMacroTargets(
        baseTdeeKcal: manualKcal,
        goalAdjustmentKcal: 0,
        netWorkoutKcal: netWorkoutKcal,
        effectiveCalorieTargetKcal: manualKcal + netWorkoutKcal,
        proteinTargetG: manualProtein,
        carbsTargetG: manualCarbs,
        fatTargetG: manualFat,
        fiberTargetG: double.parse(fiberG.toStringAsFixed(0)),
        sodiumTargetMg: 2300.0,
        potassiumTargetMg: 3500.0,
        magnesiumTargetMg: isMale ? 420.0 : 320.0,
      );
    }

    final double minSafeBmr = ((10.0 * refWeight) +
            (6.25 * profile.heightCm) -
            (5.0 * ageYears) +
            (isMale ? 5.0 : -161.0))
        .clamp(1100.0, 2600.0);

    final int baseTdee = profile.currentAdaptiveTdeeKcal;

    // 2. Ajuste según la fase de dieta activa (déficit, mantenimiento, diet break, reverse diet)
    final int goalAdjustment = DietPhasePolicy.dailyAdjustmentKcal(
      phase: profile.activeDietPhase,
      weeklyGoalRateKg: profile.weeklyGoalRateKg,
      phaseStartedAt: profile.activeDietPhaseStartedAt,
      now: now,
      hasEatingDisorderHistory: profile.hasEatingDisorderHistory,
    );

    final int rawTarget = baseTdee + goalAdjustment + netWorkoutKcal + lutealCaloricSurgeKcal;
    final int effectiveKcal = math.max(minSafeBmr.round(), rawTarget);

    final ({double proteinG, double carbsG, double fatG}) macros =
        _macroSplit(profile, effectiveKcal);

    // Fibra recomendada: 14g por cada 1000 kcal
    final double fiberG = ((effectiveKcal / 1000.0) * 14.0).clamp(22.0, 45.0);

    return DailyMacroTargets(
      baseTdeeKcal: baseTdee,
      goalAdjustmentKcal: goalAdjustment,
      netWorkoutKcal: netWorkoutKcal,
      effectiveCalorieTargetKcal: effectiveKcal,
      proteinTargetG: macros.proteinG.roundToDouble(),
      carbsTargetG: macros.carbsG.roundToDouble(),
      fatTargetG: macros.fatG.roundToDouble(),
      fiberTargetG: fiberG.roundToDouble(),
      sodiumTargetMg: 2300.0,
      potassiumTargetMg: 3500.0,
      magnesiumTargetMg: isMale ? 420.0 : 320.0,
    );
  }

  /// Reparto de macronutrientes. En modo flexible prioriza la proteína
  /// (2 g/kg del peso meta), ~27 % de grasa y el resto en carbohidratos; con un
  /// arquetipo activo (keto, mediterránea…) se usan sus porcentajes.
  static ({double proteinG, double carbsG, double fatG}) _macroSplit(
    UserProfile profile,
    int kcal,
  ) {
    if (profile.activeDietArchetype != DietArchetype.flexible) {
      final DietArchetypeInfo info = DietArchetypeInfo.getById(profile.activeDietArchetype);
      return (
        proteinG: kcal * info.proteinPct / 100 / 4,
        carbsG: kcal * info.carbsPct / 100 / 4,
        fatG: kcal * info.fatPct / 100 / 9,
      );
    }

    final double proteinG = (profile.targetWeightKg * 2.0).clamp(60.0, 230.0);
    final double fatG = ((kcal * 0.27) / 9.0).clamp(40.0, 130.0);
    final double remainingForCarbs = math.max(280.0, kcal - proteinG * 4.0 - fatG * 9.0);
    final double carbsG = (remainingForCarbs / 4.0).clamp(70.0, 480.0);
    return (proteinG: proteinG, carbsG: carbsG, fatG: fatG);
  }
}
