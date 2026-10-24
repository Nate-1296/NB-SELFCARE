import 'dart:math' as math;

import '../../core/constants/app_constants.dart';
import '../../core/database/app_database.dart';
import 'biometric_formulas.dart';

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
    required String biologicalSex,
    int dailyStepsGoal = 8000,
  }) {
    final double ageYears = BiometricFormulas.calculateDynamicAge(birthDate);
    final bool isMale = biologicalSex == 'male';
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
    double? currentWeightKg,
    DateTime? referenceDate,
  }) {
    final double ageYears =
        BiometricFormulas.calculateDynamicAge(profile.birthDate, referenceDate);
    final bool isMale = profile.biologicalSex == 'male';
    final double refWeight = currentWeightKg ?? profile.targetWeightKg;
    final double bmr = (10.0 * refWeight) +
        (6.25 * profile.heightCm) -
        (5.0 * ageYears) +
        (isMale ? 5.0 : -161.0);
    return bmr.round().clamp(1000, 3200);
  }

  /// Calcula la meta efectiva del día integrando TDEE adaptativo, ritmo semanal
  /// (déficit/mantenimiento/superávit) y gasto neto de ejercicio (RPE/METs).
  static DailyMacroTargets compute({
    required UserProfile profile,
    double? currentWeightKg,
    int netWorkoutKcal = 0,
  }) {
    final double ageYears = BiometricFormulas.calculateDynamicAge(profile.birthDate);
    final bool isMale = profile.biologicalSex == 'male';
    final double refWeight = currentWeightKg ?? profile.targetWeightKg;

    final double minSafeBmr = ((10.0 * refWeight) +
            (6.25 * profile.heightCm) -
            (5.0 * ageYears) +
            (isMale ? 5.0 : -161.0))
        .clamp(1100.0, 2600.0);

    final int baseTdee = profile.currentAdaptiveTdeeKcal;
    final int goalAdjustment =
        ((profile.weeklyGoalRateKg * AppConstants.kcalPerKgBodyFat) / 7.0).round();

    final int rawTarget = baseTdee + goalAdjustment + netWorkoutKcal;
    final int effectiveKcal = math.max(minSafeBmr.round(), rawTarget);

    // Proteína prioritaria para preservar masa muscular (2.0 g por kg peso objetivo)
    final double proteinG = (profile.targetWeightKg * 2.0).clamp(60.0, 230.0);
    final double proteinKcal = proteinG * 4.0;

    // Grasas esenciales (~27% de la meta calórica, mín 40g)
    final double fatG = ((effectiveKcal * 0.27) / 9.0).clamp(40.0, 130.0);
    final double fatKcal = fatG * 9.0;

    // Carbohidratos totales con la energía restante (mín 70g)
    final double remainingForCarbs = math.max(280.0, effectiveKcal - proteinKcal - fatKcal);
    final double carbsG = (remainingForCarbs / 4.0).clamp(70.0, 480.0);

    // Fibra recomendada: 14g por cada 1000 kcal
    final double fiberG = ((effectiveKcal / 1000.0) * 14.0).clamp(22.0, 45.0);

    return DailyMacroTargets(
      baseTdeeKcal: baseTdee,
      goalAdjustmentKcal: goalAdjustment,
      netWorkoutKcal: netWorkoutKcal,
      effectiveCalorieTargetKcal: effectiveKcal,
      proteinTargetG: double.parse(proteinG.toStringAsFixed(0)),
      carbsTargetG: double.parse(carbsG.toStringAsFixed(0)),
      fatTargetG: double.parse(fatG.toStringAsFixed(0)),
      fiberTargetG: double.parse(fiberG.toStringAsFixed(0)),
      sodiumTargetMg: 2300.0,
      potassiumTargetMg: 3500.0,
      magnesiumTargetMg: isMale ? 420.0 : 320.0,
    );
  }

  /// Sugiere el bloque horario de comida según la hora actual del dispositivo.
  static String defaultMealTypeForHour([int? hour]) {
    final int h = hour ?? DateTime.now().hour;
    if (h >= 5 && h < 11) return 'breakfast';
    if (h >= 11 && h < 16) return 'lunch';
    if (h >= 16 && h < 19) return 'snack';
    return 'dinner';
  }
}
