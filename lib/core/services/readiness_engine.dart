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
    required this.categoryLabel,
    required this.sleepSubScore,
    required this.rhrSubScore,
    required this.strainSubScore,
    required this.actionableAdvice,
    required this.insights,
  });

  /// Puntuación compuesta de 0 a 100.
  final int totalScore;
  final ReadinessCategory category;
  final String categoryLabel;

  /// Sub-puntuación de sueño (0 - 40 puntos).
  final double sleepSubScore;

  /// Sub-puntuación de Frecuencia Cardíaca en Reposo / RHR (0 - 35 puntos).
  final double rhrSubScore;

  /// Sub-puntuación de fatiga de entrenamiento acumulada (0 - 25 puntos).
  final double strainSubScore;

  /// Consejo directo y positivo (100% radical positivity, cero reproche).
  final String actionableAdvice;

  /// Lista de factores que componen la puntuación.
  final List<String> insights;

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
    final List<String> insights = <String>[];

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
        insights.add('Excelente proporción de sueño profundo N3 (${deepSleepMinutes.round()} min)');
      } else {
        sleepScore += (deepPct / 0.15) * 5.0;
      }
    } else {
      // Si no hay datos de fases, normalizar sobre los 40 puntos completos
      sleepScore = (sleepScore / 35.0) * 40.0;
    }
    sleepScore = sleepScore.clamp(0.0, 40.0);

    if (actualSleepHours >= safeTargetSleep) {
      insights.add('Meta de sueño alcanzada (${actualSleepHours.toStringAsFixed(1)} h / ${safeTargetSleep.toStringAsFixed(1)} h)');
    } else {
      final double diff = safeTargetSleep - actualSleepHours;
      insights.add('Déficit de descanso de ${diff.toStringAsFixed(1)} h respecto a tu objetivo');
    }

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
        insights.add('FC reposo favorable ($currentRhrBpm bpm, ${diff.abs()} bpm bajo tu media)');
      } else if (diff <= 2) {
        // Dentro del rango normal
        rhrScore = 32.0;
        insights.add('FC reposo estable ($currentRhrBpm bpm)');
      } else if (diff <= 5) {
        // Leve elevación (posible fatiga, digestión tardía o deshidratación)
        rhrScore = 24.0;
        insights.add('FC reposo ligeramente elevada (+$diff bpm sobre la media)');
      } else {
        // Elevación marcada (+6 bpm o más) = estrés autonómico o sobrecarga
        rhrScore = 14.0;
        insights.add('FC reposo significativamente elevada (+$diff bpm)');
      }
    }

    // --- 3. Pilar de Fatiga de Entrenamiento (0 a 25 puntos) ---
    double strainScore = 25.0;
    // Carga = horas en últimos 3 días * RPE promedio (1-10)
    final double trainingLoad = recent3DayWorkoutHours * averageRecentRpe;

    if (trainingLoad > 22.0) {
      // Carga muy alta en 3 días (ej. 3h a RPE 8 = 24)
      strainScore = 15.0;
      insights.add('Carga física reciente elevada (${recent3DayWorkoutHours.toStringAsFixed(1)} h acumuladas a RPE ${averageRecentRpe.toStringAsFixed(1)})');
    } else if (trainingLoad > 14.0) {
      strainScore = 20.0;
      insights.add('Estímulo de entrenamiento consolidado');
    } else {
      strainScore = 25.0;
      insights.add('Baja fatiga neuromuscular acumulada');
    }

    // Puntuación total
    final int total = (sleepScore + rhrScore + strainScore).round().clamp(0, 100);

    ReadinessCategory cat;
    String label;
    String advice;

    if (total >= 85) {
      cat = ReadinessCategory.optimal;
      label = 'Óptimo';
      advice =
          'Tu sistema nervioso central y reservas de glucógeno están en su punto máximo. '
          'Día excelente para entrenamientos de alta intensidad (RPE 8–9), levantamiento pesado o récords personales.';
    } else if (total >= 70) {
      cat = ReadinessCategory.favorable;
      label = 'Favorable';
      advice =
          'Nivel de energía equilibrado y estable. '
          'Apto para entrenamientos regulares a intensidad moderada (RPE 6–7) y progreso sostenido.';
    } else {
      cat = ReadinessCategory.recoveryNeeded;
      label = 'Recuperación Activa';
      advice =
          'Tu cuerpo indica que priorices la restauración hoy. '
          'Una caminata suave al aire libre, movilidad articular, buena hidratación con electrolitos y acostarte temprano multiplicarán tus resultados.';
    }

    return DailyReadinessResult(
      totalScore: total,
      category: cat,
      categoryLabel: label,
      sleepSubScore: double.parse(sleepScore.toStringAsFixed(1)),
      rhrSubScore: double.parse(rhrScore.toStringAsFixed(1)),
      strainSubScore: double.parse(strainScore.toStringAsFixed(1)),
      actionableAdvice: advice,
      insights: insights,
    );
  }
}

/// Provider de Riverpod para ReadinessEngine.
final readinessEngineProvider = Provider<ReadinessEngine>((ref) {
  return ReadinessEngine();
});
