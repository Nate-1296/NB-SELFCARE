import '../domain/enums.dart';

/// Valores MET (Metabolic Equivalent of Task) para estimación calórica por bloques RPE.
/// Cada valor representa el gasto bruto. Para el gasto neto se descuenta 1.0 MET (metabolismo basal).
abstract final class MetConstants {
  /// Matriz oficial METs por categoría e intensidad RPE.
  static const Map<WorkoutCategory, Map<RpeIntensity, double>> table = {
    WorkoutCategory.weights: {
      RpeIntensity.light: 3.5,
      RpeIntensity.moderate: 5.0,
      RpeIntensity.intense: 6.5,
    },
    WorkoutCategory.calisthenics: {
      RpeIntensity.light: 3.8,
      RpeIntensity.moderate: 5.5,
      RpeIntensity.intense: 8.0,
    },
    WorkoutCategory.cardio: {
      RpeIntensity.light: 5.0,
      RpeIntensity.moderate: 7.5,
      RpeIntensity.intense: 10.5,
    },
    WorkoutCategory.sports: {
      RpeIntensity.light: 5.0,
      RpeIntensity.moderate: 7.0,
      RpeIntensity.intense: 9.5,
    },
  };

  /// Obtiene el MET aplicado para una categoría e intensidad dada.
  static double getMet(WorkoutCategory category, RpeIntensity intensity) {
    return table[category]?[intensity] ?? 5.0;
  }

  /// Calorías netas del bloque descontando el reposo (1.0 MET), fórmula ACSM de docs/06 §3:
  /// `round((MET - 1.0) × 3.5 × peso / 200 × minutos)`.
  static int calculateNetCalories({
    required double met,
    required double userWeightKg,
    required int durationMinutes,
  }) {
    if (userWeightKg <= 0 || durationMinutes <= 0) return 0;
    final double netMet = (met - 1.0).clamp(0.0, 20.0);
    return (netMet * 3.5 * userWeightKg / 200.0 * durationMinutes).round();
  }
}

