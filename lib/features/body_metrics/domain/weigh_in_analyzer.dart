import '../../../core/domain/enums.dart';
import '../../../shared/utils/biometric_formulas.dart';

/// Datos del día anterior y del contexto fisiológico que explican una subida de peso.
class RetentionContext {
  const RetentionContext({
    this.yesterdaySodiumMg,
    this.yesterdayCarbsG,
    this.avg7dCarbsG,
    this.isLutealPhase = false,
    this.takesWaterRetainingSupplement = false,
  });

  final int? yesterdaySodiumMg;
  final double? yesterdayCarbsG;
  final double? avg7dCarbsG;
  final bool isLutealPhase;
  final bool takesWaterRetainingSupplement;
}

/// Pesaje anterior relevante para la EMA y el detector de retención.
class PreviousWeighIn {
  const PreviousWeighIn({
    required this.weightKg,
    required this.trendWeightKg,
    this.waterPercentage,
    this.hadImpedance = false,
  });

  final double weightKg;
  final double trendWeightKg;
  final double? waterPercentage;
  final bool hadImpedance;
}

/// Causas reconocidas de una "falsa subida" de peso (docs/04 §4, docs/14 Fase 6).
enum RetentionCause {
  highSodium,
  glycogenReload,
  biaWaterShift,
  lutealPhase,
  creatine,
}

/// Resultado completo de analizar un pesaje antes de persistirlo.
class WeighInAnalysis {
  const WeighInAnalysis({
    required this.weightKg,
    required this.bmi,
    required this.trendWeightKg,
    required this.metrics,
    required this.hasImpedance,
    required this.retentionCauses,
    required this.spikeExplanation,
  });

  final double weightKg;
  final double bmi;
  final double trendWeightKg;
  final DerivedBiometrics metrics;
  final bool hasImpedance;
  final List<RetentionCause> retentionCauses;
  final String? spikeExplanation;

  bool get isWaterRetentionSpike => retentionCauses.isNotEmpty;
}

/// Reglas puras del pesaje: 13 métricas, Peso Tendencia (EMA), filtro de
/// invitados y detector de retención hídrica. Sin I/O ni reloj.
abstract final class WeighInAnalyzer {
  /// Diferencia relativa respecto a la tendencia a partir de la cual se pregunta
  /// "¿Eres tú?" (docs/04 §1).
  static const double guestDeviationRatio = 0.08;

  /// Subida mínima diaria que se evalúa como posible retención (docs/04 §4).
  static const double spikeThresholdKg = 0.40;

  /// Desviación relativa respecto a [previousTrendKg] si supera el umbral de
  /// invitado; `null` si el pesaje es plausible para el usuario.
  static double? guestDeviation({required double weightKg, required double? previousTrendKg}) {
    if (previousTrendKg == null || previousTrendKg <= 0) return null;
    final double ratio = (weightKg - previousTrendKg).abs() / previousTrendKg;
    return ratio > guestDeviationRatio ? ratio : null;
  }

  static WeighInAnalysis analyze({
    required double weightKg,
    required int? impedanceOhms,
    required double heightCm,
    required DateTime birthDate,
    required BiologicalSex sex,
    required DateTime measuredAt,
    required PreviousWeighIn? previous,
    required RetentionContext context,
  }) {
    final bool hasImpedance =
        impedanceOhms != null && impedanceOhms >= 100 && impedanceOhms <= 3000;
    final DerivedBiometrics metrics = BiometricFormulas.deriveMetrics(
      weightKg: weightKg,
      heightCm: heightCm,
      ageYears: BiometricFormulas.calculateDynamicAge(birthDate, measuredAt),
      isMale: sex.isMale,
      impedanceOhms: hasImpedance ? impedanceOhms : null,
    );

    final List<RetentionCause> causes = previous == null
        ? const <RetentionCause>[]
        : retentionCauses(
            weightKg: weightKg,
            previous: previous,
            currentWaterPct: hasImpedance ? metrics.waterPercentage : null,
            context: context,
          );

    return WeighInAnalysis(
      weightKg: weightKg,
      bmi: BiometricFormulas.calculateBmi(weightKg: weightKg, heightCm: heightCm),
      trendWeightKg: BiometricFormulas.calculateWeightEma(
        currentWeightKg: weightKg,
        previousEmaKg: previous?.trendWeightKg,
      ),
      metrics: metrics,
      hasImpedance: hasImpedance,
      retentionCauses: causes,
      spikeExplanation: causes.isEmpty ? null : explain(causes, context, weightKg, previous!),
    );
  }

  /// Causas que explican una subida ≥ [spikeThresholdKg]. Vacío si no hay subida
  /// o si ninguna causa fisiológica la explica.
  static List<RetentionCause> retentionCauses({
    required double weightKg,
    required PreviousWeighIn previous,
    required double? currentWaterPct,
    required RetentionContext context,
  }) {
    if (weightKg - previous.weightKg < spikeThresholdKg) return const <RetentionCause>[];

    final int? sodium = context.yesterdaySodiumMg;
    final double? carbs = context.yesterdayCarbsG;
    final double? avgCarbs = context.avg7dCarbsG;
    final double? previousWater = previous.hadImpedance ? previous.waterPercentage : null;

    return <RetentionCause>[
      if (sodium != null && sodium > 2500) RetentionCause.highSodium,
      if (carbs != null && avgCarbs != null && avgCarbs > 0 && carbs > 1.30 * avgCarbs)
        RetentionCause.glycogenReload,
      if (currentWaterPct != null &&
          previousWater != null &&
          currentWaterPct - previousWater >= 0.40)
        RetentionCause.biaWaterShift,
      if (context.isLutealPhase) RetentionCause.lutealPhase,
      if (context.takesWaterRetainingSupplement) RetentionCause.creatine,
    ];
  }

  /// Mensaje tranquilizador (positividad radical, sin culpa) para la tarjeta de falsa subida.
  static String explain(
    List<RetentionCause> causes,
    RetentionContext context,
    double weightKg,
    PreviousWeighIn previous,
  ) {
    final List<String> reasons = causes.map((RetentionCause cause) {
      return switch (cause) {
        RetentionCause.highSodium => 'sodio elevado ayer (${context.yesterdaySodiumMg} mg)',
        RetentionCause.glycogenReload =>
          'recarga de glucógeno (${context.yesterdayCarbsG!.round()} g de carbohidratos ayer)',
        RetentionCause.biaWaterShift => 'más agua corporal medida por bioimpedancia',
        RetentionCause.lutealPhase => 'fase lútea (retención fisiológica por progesterona)',
        RetentionCause.creatine => 'creatina (agua dentro del músculo, no grasa)',
      };
    }).toList();
    final String delta = (weightKg - previous.weightKg).toStringAsFixed(1);
    return '+$delta kg de agua temporal por ${reasons.join(', ')}. No es grasa: '
        'tu Peso Tendencia apenas se mueve.';
  }
}
