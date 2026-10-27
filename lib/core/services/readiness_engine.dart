import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Clasificación clínica de la disposición diaria (Readiness).
enum ReadinessCategory {
  optimal,
  favorable,
  recoveryNeeded,
}

/// Resultado integral del cálculo de disposición diaria y recuperación metabólica.
class DailyReadinessResult {
  const DailyReadinessResult({
    required this.totalScore,
    required this.category,
    required this.sleepSubScore,
    required this.rhrSubScore,
    required this.strainSubScore,
  });

  /// Puntuación compuesta de 0 a 100.
  final int totalScore;
  final ReadinessCategory category;

  /// Sub-puntuación de sueño (0 - 40 puntos).
  final double sleepSubScore;

  /// Sub-puntuación de Frecuencia Cardíaca en Reposo / RHR (0 - 35 puntos).
  final double rhrSubScore;

  /// Sub-puntuación de fatiga de entrenamiento acumulada (0 - 25 puntos).
  final double strainSubScore;

  bool get isOptimal => category == ReadinessCategory.optimal;
  bool get isRecoveryNeeded => category == ReadinessCategory.recoveryNeeded;
}

/// Motor de Disposición y Recuperación Diaria ("Readiness Engine").
///
/// Algoritmo compuesto multivariable:
/// 1. Calidad y duración del sueño (40%): Cumplimiento de la meta de descanso y porcentaje de sueño profundo N3.
/// 2. Autonomía cardíaca en reposo / RHR (35%): Desviación respecto a la línea base individual de 14 días.
/// 3. Carga y fatiga de entrenamiento acumulada (25%): Índice volumen x RPE en los últimos 3 días.
class ReadinessEngine {
  /// Calcula la disposición del día.
  DailyReadinessResult compute({
    required double actualSleepHours,
    required double targetSleepHours,
    double? deepSleepMinutes,
    int? currentRhrBpm,
    int? baselineRhrBpm,
    required double recent3DayWorkoutHours,
    required double averageRecentRpe,
  }) {
    // --- 1. Pilar de Sueño (0 a 40 puntos) ---
    final double safeTargetSleep = targetSleepHours > 0 ? targetSleepHours : 8.0;
    final double sleepRatio = (actualSleepHours / safeTargetSleep).clamp(0.0, 1.25);
    double sleepScore = (sleepRatio * 35.0).clamp(0.0, 35.0);

    if (deepSleepMinutes != null && deepSleepMinutes > 0) {
      // Sueño profundo saludable es ~15% - 25% del total
      final double totalMinutes = actualSleepHours * 60.0;
      final double deepPct = totalMinutes > 0 ? (deepSleepMinutes / totalMinutes) : 0.0;
      if (deepPct >= 0.15) {
        sleepScore += 5.0; // Bonus sueño profundo óptimo
      } else {
        sleepScore += (deepPct / 0.15) * 5.0;
      }
    } else {
      // Si no hay datos de fases, normalizar sobre los 40 puntos completos
      sleepScore = (sleepScore / 35.0) * 40.0;
    }
    sleepScore = sleepScore.clamp(0.0, 40.0);

    // --- 2. Pilar de Frecuencia Cardíaca en Reposo (0 a 35 puntos) ---
    double rhrScore = 32.0; // Valor favorable por defecto si no hay pulsómetro
    if (currentRhrBpm != null && currentRhrBpm > 0) {
      final int base = (baselineRhrBpm != null && baselineRhrBpm > 0)
          ? baselineRhrBpm
          : currentRhrBpm;
      final int diff = currentRhrBpm - base;

      if (diff <= -1) {
        // RHR por debajo de la línea base = recuperación parasimpática óptima
        rhrScore = 35.0;
      } else if (diff <= 2) {
        // Dentro del rango normal
        rhrScore = 32.0;
      } else if (diff <= 5) {
        // Leve elevación (posible fatiga, digestión tardía o deshidratación)
        rhrScore = 24.0;
      } else {
        // Elevación marcada (+6 bpm o más) = estrés autonómico o sobrecarga
        rhrScore = 14.0;
      }
    }

    // --- 3. Pilar de Fatiga de Entrenamiento (0 a 25 puntos) ---
    double strainScore = 25.0;
    // Carga = horas en últimos 3 días * RPE promedio (1-10)
    final double trainingLoad = recent3DayWorkoutHours * averageRecentRpe;

    if (trainingLoad > 22.0) {
      // Carga muy alta en 3 días (ej. 3h a RPE 8 = 24)
      strainScore = 15.0;
    } else if (trainingLoad > 14.0) {
      strainScore = 20.0;
    } else {
      strainScore = 25.0;
    }

    // Puntuación total
    final int total = (sleepScore + rhrScore + strainScore).round().clamp(0, 100);

    final ReadinessCategory cat = total >= 85
        ? ReadinessCategory.optimal
        : total >= 70
            ? ReadinessCategory.favorable
            : ReadinessCategory.recoveryNeeded;

    return DailyReadinessResult(
      totalScore: total,
      category: cat,
      sleepSubScore: double.parse(sleepScore.toStringAsFixed(1)),
      rhrSubScore: double.parse(rhrScore.toStringAsFixed(1)),
      strainSubScore: double.parse(strainScore.toStringAsFixed(1)),
    );
  }
}

/// Provider de Riverpod para ReadinessEngine.
final readinessEngineProvider = Provider<ReadinessEngine>((ref) {
  return ReadinessEngine();
});
