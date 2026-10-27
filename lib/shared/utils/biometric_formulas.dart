import 'dart:math' as math;

/// Modelo contenedor con las 13 métricas derivadas de la báscula de bioimpedancia.
class DerivedBiometrics {
  const DerivedBiometrics({
    required this.weightKg,
    required this.bmi,
    required this.bodyFatPercentage,
    required this.muscleMassKg,
    required this.waterPercentage,
    required this.visceralFatIndex,
    required this.boneMassKg,
    required this.proteinPercentage,
    required this.basalMetabolicRateKcal,
    required this.metabolicAgeYears,
    required this.leanBodyMassKg,
    required this.bodyScore,
    required this.bodyType,
  });

  final double weightKg;
  final double bmi;
  final double bodyFatPercentage;
  final double muscleMassKg;
  final double waterPercentage;
  final int visceralFatIndex;
  final double boneMassKg;
  final double proteinPercentage;
  final int basalMetabolicRateKcal;
  final int metabolicAgeYears;
  final double leanBodyMassKg;
  final int bodyScore;
  final String bodyType;
}

/// Biblioteca pura de cálculo biométrico y fisiológico.
///
/// Todas las fórmulas derivan de los estándares de openScale / bodymiscale,
/// la ecuación US Navy, Katch-McArdle y el modelo de TDEE Adaptativo.
abstract final class BiometricFormulas {
  /// Calcula la edad en años con precisión decimal a partir de la fecha de nacimiento.
  static double calculateDynamicAge(DateTime birthDate, DateTime referenceDate) {
    final DateTime target = referenceDate;
    final int days = target.difference(birthDate).inDays;
    return days > 0 ? days / 365.25 : 0.0;
  }

  /// Calcula el Índice de Masa Corporal (BMI).
  static double calculateBmi({
    required double weightKg,
    required double heightCm,
  }) {
    if (heightCm <= 0) return 0.0;
    final double heightM = heightCm / 100.0;
    return double.parse((weightKg / (heightM * heightM)).toStringAsFixed(2));
  }

  /// Deriva las 13 métricas corporales. Si se suministra [impedanceOhms],
  /// utiliza las fórmulas empíricas BIA de Xiaomi. Si es nulo, emplea el
  /// modelo antropométrico estándar (fórmula de Deurenberg y balances fisiológicos).
  static DerivedBiometrics deriveMetrics({
    required double weightKg,
    required double heightCm,
    required double ageYears,
    required bool isMale,
    int? impedanceOhms,
  }) {
    if (impedanceOhms != null && impedanceOhms >= 100 && impedanceOhms <= 3000) {
      return deriveAllMetrics(
        weightKg: weightKg,
        heightCm: heightCm,
        ageYears: ageYears,
        isMale: isMale,
        impedanceOhms: impedanceOhms,
      );
    }
    return deriveAllMetricsEstimated(
      weightKg: weightKg,
      heightCm: heightCm,
      ageYears: ageYears,
      isMale: isMale,
    );
  }

  /// Modelo antropométrico de estimación (Deurenberg) para cuando no hay bioimpedancia disponible.
  static DerivedBiometrics deriveAllMetricsEstimated({
    required double weightKg,
    required double heightCm,
    required double ageYears,
    required bool isMale,
  }) {
    final double bmi = calculateBmi(weightKg: weightKg, heightCm: heightCm);

    // Ecuación Deurenberg: % Grasa = 1.20*BMI + 0.23*Edad - 10.8*(1 si hombre, 0 si mujer) - 5.4
    final double deurenbergFat =
        (1.20 * bmi) + (0.23 * ageYears) - (10.8 * (isMale ? 1.0 : 0.0)) - 5.4;
    final double bodyFatPercentage = _clampDouble(deurenbergFat, 5.0, 65.0);

    // Masa Ósea estimada: ~4.5% hombre, ~4.0% mujer del peso corporal
    final double boneFraction = isMale ? 0.045 : 0.040;
    final double boneMassKg = _clampDouble(weightKg * boneFraction, 1.0, 5.2);

    // Masa Muscular estimada
    final double rawMuscle =
        weightKg - (weightKg * (bodyFatPercentage / 100.0)) - boneMassKg;
    final double muscleMassKg = double.parse(
      (rawMuscle > 0 ? rawMuscle : weightKg * 0.5).toStringAsFixed(2),
    );

    // Agua Corporal estimada (~72% de la masa magra)
    final double waterRaw = (100.0 - bodyFatPercentage) * 0.72;
    final double waterPercentage = _clampDouble(waterRaw, 35.0, 75.0);

    // Proteína Corporal estimada
    final double rawProtein =
        (muscleMassKg / weightKg) * 100.0 - waterPercentage;
    final double proteinPercentage = _clampDouble(rawProtein, 10.0, 26.0);

    // Grasa Visceral
    final int visceralFatIndex = _calculateVisceralFat(
      weightKg: weightKg,
      heightCm: heightCm,
      ageYears: ageYears,
      isMale: isMale,
    );

    // Masa Libre de Grasa y BMR
    final double leanBodyMassKg = double.parse(
      (weightKg * (1.0 - (bodyFatPercentage / 100.0))).toStringAsFixed(1),
    );
    final int basalMetabolicRateKcal =
        calculateKatchMcArdleBmr(leanBodyMassKg: leanBodyMassKg);

    // Edad Metabólica
    final int metabolicAgeYears = _calculateMetabolicAge(
      bmr: basalMetabolicRateKcal,
      ageYears: ageYears,
      isMale: isMale,
      weightKg: weightKg,
      heightCm: heightCm,
    );

    // Puntaje Corporal
    final int bodyScore = _calculateBodyScore(
      bmi: bmi,
      bodyFatPercentage: bodyFatPercentage,
      visceralFat: visceralFatIndex,
      waterPercentage: waterPercentage,
      muscleMassKg: muscleMassKg,
      weightKg: weightKg,
      isMale: isMale,
    );

    // Somatotipo
    final String bodyType = _determineSomatotype(
      bodyFatPercentage: bodyFatPercentage,
      muscleMassKg: muscleMassKg,
      weightKg: weightKg,
      isMale: isMale,
    );

    return DerivedBiometrics(
      weightKg: weightKg,
      bmi: bmi,
      bodyFatPercentage: double.parse(bodyFatPercentage.toStringAsFixed(1)),
      muscleMassKg: muscleMassKg,
      waterPercentage: double.parse(waterPercentage.toStringAsFixed(1)),
      visceralFatIndex: visceralFatIndex,
      boneMassKg: double.parse(boneMassKg.toStringAsFixed(2)),
      proteinPercentage: double.parse(proteinPercentage.toStringAsFixed(1)),
      basalMetabolicRateKcal: basalMetabolicRateKcal,
      metabolicAgeYears: metabolicAgeYears,
      leanBodyMassKg: leanBodyMassKg,
      bodyScore: bodyScore,
      bodyType: bodyType,
    );
  }

  /// Deriva las 13 métricas corporales completas a partir de la lectura BIA.
  static DerivedBiometrics deriveAllMetrics({
    required double weightKg,
    required double heightCm,
    required double ageYears,
    required bool isMale,
    required int impedanceOhms,
  }) {
    final double bmi = calculateBmi(weightKg: weightKg, heightCm: heightCm);
    final double heightM = heightCm / 100.0;

    // 1. Coeficiente base de Masa Libre de Grasa (LBM base)
    final double lbmBase = (heightCm * 9.058 / 100.0) * heightM +
        (weightKg * 0.32) +
        12.226 -
        (impedanceOhms * 0.0068) -
        (ageYears * 0.0542);

    // 2. Porcentaje de Grasa Corporal (BF%)
    final double adjust;
    final double coeff;

    if (isMale) {
      adjust = 0.8;
      coeff = weightKg < 61.0 ? 0.98 : 1.0;
    } else {
      adjust = ageYears <= 49 ? 9.25 : 7.25;
      if (weightKg > 60.0) {
        coeff = 0.96 * (heightCm > 160.0 ? 1.03 : 1.0);
      } else if (weightKg < 50.0) {
        coeff = 1.02 * (heightCm > 160.0 ? 1.03 : 1.0);
      } else {
        coeff = 1.0;
      }
    }

    final double rawFat = (1.0 - ((lbmBase - adjust) * coeff) / weightKg) * 100.0;
    final double bodyFatPercentage = _clampDouble(rawFat, 5.0, 75.0);

    // 3. Masa Ósea (Bone Mass)
    final double baseBone = isMale ? 0.18016894 : 0.245691014;
    final double boneRaw = -1.0 * (baseBone - (lbmBase * 0.05158));
    final double boneAdjusted = boneRaw > 2.2 ? boneRaw + 0.1 : boneRaw - 0.1;
    final double boneMassKg = _clampDouble(boneAdjusted, 1.0, 5.2);

    // 4. Masa Muscular (Muscle Mass)
    final double rawMuscle =
        weightKg - (weightKg * (bodyFatPercentage / 100.0)) - boneMassKg;
    final double muscleMassKg = double.parse(
      (rawMuscle > 0 ? rawMuscle : weightKg * 0.5).toStringAsFixed(2),
    );

    // 5. Porcentaje de Agua Corporal (Water %)
    final double waterRaw = (100.0 - bodyFatPercentage) * 0.70;
    final double adjustedWater =
        waterRaw < 50.0 ? waterRaw * 1.02 : waterRaw * 0.98;
    final double waterPercentage = _clampDouble(adjustedWater, 35.0, 75.0);

    // 6. Porcentaje de Proteína Corporal (Protein %)
    final double rawProtein =
        (muscleMassKg / weightKg) * 100.0 - waterPercentage;
    final double proteinPercentage = _clampDouble(rawProtein, 10.0, 26.0);

    // 7. Grasa Visceral (Índice 1 - 30)
    final int visceralFatIndex = _calculateVisceralFat(
      weightKg: weightKg,
      heightCm: heightCm,
      ageYears: ageYears,
      isMale: isMale,
    );

    // 8. TMB Basal Katch-McArdle y Masa Libre de Grasa Real
    final double leanBodyMassKg = double.parse(
      (weightKg * (1.0 - (bodyFatPercentage / 100.0))).toStringAsFixed(1),
    );
    final int basalMetabolicRateKcal =
        calculateKatchMcArdleBmr(leanBodyMassKg: leanBodyMassKg);

    // 9. Edad Metabólica
    final int metabolicAgeYears = _calculateMetabolicAge(
      bmr: basalMetabolicRateKcal,
      ageYears: ageYears,
      isMale: isMale,
      weightKg: weightKg,
      heightCm: heightCm,
    );

    // 10. Puntaje Corporal (Body Score 10 - 100)
    final int bodyScore = _calculateBodyScore(
      bmi: bmi,
      bodyFatPercentage: bodyFatPercentage,
      visceralFat: visceralFatIndex,
      waterPercentage: waterPercentage,
      muscleMassKg: muscleMassKg,
      weightKg: weightKg,
      isMale: isMale,
    );

    // 11. Somatotipo (9 Fenotipos)
    final String bodyType = _determineSomatotype(
      bodyFatPercentage: bodyFatPercentage,
      muscleMassKg: muscleMassKg,
      weightKg: weightKg,
      isMale: isMale,
    );

    return DerivedBiometrics(
      weightKg: weightKg,
      bmi: bmi,
      bodyFatPercentage: double.parse(bodyFatPercentage.toStringAsFixed(1)),
      muscleMassKg: muscleMassKg,
      waterPercentage: double.parse(waterPercentage.toStringAsFixed(1)),
      visceralFatIndex: visceralFatIndex,
      boneMassKg: double.parse(boneMassKg.toStringAsFixed(2)),
      proteinPercentage: double.parse(proteinPercentage.toStringAsFixed(1)),
      basalMetabolicRateKcal: basalMetabolicRateKcal,
      metabolicAgeYears: metabolicAgeYears,
      leanBodyMassKg: leanBodyMassKg,
      bodyScore: bodyScore,
      bodyType: bodyType,
    );
  }

  /// Tasa Metabólica Basal mediante fórmula Katch-McArdle: BMR = 370 + 21.6 * LBM
  static int calculateKatchMcArdleBmr({required double leanBodyMassKg}) {
    return (370.0 + (21.6 * leanBodyMassKg)).round();
  }

  /// Ecuación US Navy para estimación de grasa corporal mediante cinta métrica.
  ///
  /// Para hombres: requiere cintura (waistCm) y cuello (neckCm).
  /// Para mujeres: requiere cintura (waistCm), cuello (neckCm) y cadera (hipCm).
  static double calculateNavyBodyFatPercentage({
    required double heightCm,
    required double waistCm,
    required double neckCm,
    required bool isMale,
    double? hipCm,
  }) {
    if (isMale) {
      final double diff = waistCm - neckCm;
      if (diff <= 0) return 10.0;
      final double logDiff = math.log(diff) / math.ln10;
      final double logHeight = math.log(heightCm) / math.ln10;
      final double denom = 1.0324 - (0.19077 * logDiff) + (0.15456 * logHeight);
      final double fat = (495.0 / denom) - 450.0;
      return _clampDouble(fat, 4.0, 60.0);
    } else {
      final double hip = hipCm ?? waistCm * 1.1;
      final double sum = waistCm + hip - neckCm;
      if (sum <= 0) return 18.0;
      final double logSum = math.log(sum) / math.ln10;
      final double logHeight = math.log(heightCm) / math.ln10;
      final double denom = 1.29579 - (0.35004 * logSum) + (0.22100 * logHeight);
      final double fat = (495.0 / denom) - 450.0;
      return _clampDouble(fat, 8.0, 65.0);
    }
  }

  /// Fusión ponderada quincenal: 60% Bioimpedancia + 40% Cinta US Navy.
  static double calculateValidatedBodyFat({
    required double biaBodyFatPercentage,
    required double navyBodyFatPercentage,
  }) {
    final double result =
        (0.60 * biaBodyFatPercentage) + (0.40 * navyBodyFatPercentage);
    return double.parse(result.toStringAsFixed(1));
  }

  /// Actualiza la Media Móvil Exponencial (EMA) del peso con factor alpha = 0.1.
  static double calculateWeightEma({
    required double currentWeightKg,
    required double? previousEmaKg,
    double alpha = 0.1,
  }) {
    if (previousEmaKg == null || previousEmaKg <= 0) {
      return currentWeightKg;
    }
    final double nextEma = previousEmaKg + alpha * (currentWeightKg - previousEmaKg);
    return double.parse(nextEma.toStringAsFixed(2));
  }

  /// Detecta si una subida abrupta de peso (>= 0.4 kg) es retención hídrica/glucógeno.
  static bool detectWaterRetentionSpike({
    required double currentWeightKg,
    required double previousWeightKg,
    int? yesterdaySodiumMg,
    double? yesterdayCarbsGrams,
    double? avg7dCarbsGrams,
    double? currentWaterPct,
    double? previousWaterPct,
  }) {
    final double weightDelta = currentWeightKg - previousWeightKg;
    if (weightDelta < 0.40) return false;

    // 1. Alto consumo de sodio el día previo (> 2500 mg)
    if (yesterdaySodiumMg != null && yesterdaySodiumMg > 2500) {
      return true;
    }

    // 2. Supercompensación de carbohidratos (> 1.3x del promedio semanal)
    if (yesterdayCarbsGrams != null &&
        avg7dCarbsGrams != null &&
        avg7dCarbsGrams > 0 &&
        yesterdayCarbsGrams > 1.30 * avg7dCarbsGrams) {
      return true;
    }

    // 3. Incremento del agua corporal por BIA (>= 0.4%)
    if (currentWaterPct != null &&
        previousWaterPct != null &&
        (currentWaterPct - previousWaterPct) >= 0.40) {
      return true;
    }

    return false;
  }

  /// Calibra el TDEE Adaptativo tras una ventana móvil de 14 días.
  ///
  /// TDEE = AvgCalories - (DeltaEMA * 7700 / 14)
  /// Aplica filtro de seguridad de +/- 150 kcal por semana y no desciende del BMR.
  static int calibrateAdaptiveTdee({
    required double avgDailyIntakeKcal,
    required double startEmaKg,
    required double endEmaKg,
    required int previousTdeeKcal,
    required int userBmrKcal,
  }) {
    final double deltaEmaKg = endEmaKg - startEmaKg;
    final double caloricWeightChange = (deltaEmaKg * 7700.0) / 14.0;
    final double rawCalculatedTdee = avgDailyIntakeKcal - caloricWeightChange;

    // Filtro de variación máxima (+/- 300 kcal en 14 días)
    final double maxAllowed = previousTdeeKcal + 300.0;
    final double minAllowed = math.max(previousTdeeKcal - 300.0, userBmrKcal.toDouble());

    final double clampedTdee = _clampDouble(rawCalculatedTdee, minAllowed, maxAllowed);
    return clampedTdee.round();
  }

  // --- MÉTODOS PRIVADOS DE CÁLCULO AUXILIAR ---

  static int _calculateVisceralFat({
    required double weightKg,
    required double heightCm,
    required double ageYears,
    required bool isMale,
  }) {
    final double subcalc;
    final double visceral;

    if (isMale) {
      if (heightCm < weightKg * 1.6) {
        subcalc = -1.0 * (heightCm * 0.4 - (heightCm * heightCm) * 0.0826);
        visceral = (weightKg * 305.0) / (subcalc + 48.0) - 2.9 + (ageYears * 0.15);
      } else {
        subcalc = 0.765 + heightCm * (-0.0015);
        visceral = -1.0 * (heightCm * 0.143 - weightKg * subcalc) +
            (ageYears * 0.15) -
            5.0;
      }
    } else {
      if (heightCm < weightKg * 1.6) {
        subcalc = -1.0 * (heightCm * 0.4 - (heightCm * heightCm) * 0.0826);
        visceral = (weightKg * 305.0) / (subcalc + 48.0) - 4.9 + (ageYears * 0.15);
      } else {
        subcalc = 0.765 + heightCm * (-0.0015);
        visceral = -1.0 * (heightCm * 0.143 - weightKg * subcalc) +
            (ageYears * 0.15) -
            7.0;
      }
    }

    final int result = visceral.round();
    if (result < 1) return 1;
    if (result > 30) return 30;
    return result;
  }

  static int _calculateMetabolicAge({
    required int bmr,
    required double ageYears,
    required bool isMale,
    required double weightKg,
    required double heightCm,
  }) {
    // Estimación Harris-Benedict promedio de referencia
    final double expectedBmr = isMale
        ? 88.362 + (13.397 * weightKg) + (4.799 * heightCm) - (5.677 * ageYears)
        : 447.593 + (9.247 * weightKg) + (3.098 * heightCm) - (4.330 * ageYears);

    final double ratio = bmr / expectedBmr;
    // Si BMR es superior al esperado, la edad biológica es menor
    final double deltaYears = (1.0 - ratio) * 15.0;
    final int estimatedAge = (ageYears + deltaYears).round();

    final int minAge = math.max(12, (ageYears - 10).round());
    final int maxAge = (ageYears + 15).round();

    if (estimatedAge < minAge) return minAge;
    if (estimatedAge > maxAge) return maxAge;
    return estimatedAge;
  }

  static int _calculateBodyScore({
    required double bmi,
    required double bodyFatPercentage,
    required int visceralFat,
    required double waterPercentage,
    required double muscleMassKg,
    required double weightKg,
    required bool isMale,
  }) {
    double score = 100.0;

    // Penalización BMI
    if (bmi < 18.5) {
      score -= (18.5 - bmi) * 3.0;
    } else if (bmi > 24.9) {
      score -= (bmi - 24.9) * 2.5;
    }

    // Penalización Grasa Corporal
    final double minFat = isMale ? 10.0 : 18.0;
    final double maxFat = isMale ? 20.0 : 28.0;
    if (bodyFatPercentage > maxFat) {
      score -= (bodyFatPercentage - maxFat) * 1.5;
    } else if (bodyFatPercentage < minFat) {
      score -= (minFat - bodyFatPercentage) * 1.0;
    }

    // Penalización Grasa Visceral
    if (visceralFat > 9) {
      score -= (visceralFat - 9) * 2.0;
    }

    // Penalización Agua
    final double minWater = isMale ? 50.0 : 45.0;
    if (waterPercentage < minWater) {
      score -= (minWater - waterPercentage) * 0.8;
    }

    final int finalScore = score.round();
    if (finalScore < 10) return 10;
    if (finalScore > 100) return 100;
    return finalScore;
  }

  static String _determineSomatotype({
    required double bodyFatPercentage,
    required double muscleMassKg,
    required double weightKg,
    required bool isMale,
  }) {
    final double musclePct = (muscleMassKg / weightKg) * 100.0;
    final double fatLow = isMale ? 12.0 : 20.0;
    final double fatHigh = isMale ? 22.0 : 30.0;
    final double muscleLow = isMale ? 40.0 : 32.0;
    final double muscleHigh = isMale ? 52.0 : 42.0;

    final int fatLevel = bodyFatPercentage < fatLow
        ? 0
        : (bodyFatPercentage <= fatHigh ? 1 : 2);
    final int muscleLevel = musclePct < muscleLow
        ? 0
        : (musclePct <= muscleHigh ? 1 : 2);

    // Matriz 3x3
    if (fatLevel == 2) {
      if (muscleLevel == 0) return 'obese';
      if (muscleLevel == 1) return 'overweight';
      return 'thick_set';
    } else if (fatLevel == 1) {
      if (muscleLevel == 0) return 'lack_exercise';
      if (muscleLevel == 1) return 'balanced';
      return 'balanced_muscular';
    } else {
      if (muscleLevel == 0) return 'skinny';
      if (muscleLevel == 1) return 'balanced_skinny';
      return 'skinny_muscular';
    }
  }

  static double _clampDouble(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}
