import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';

/// Punto para la curva temporal de concentración de cafeína en sangre.
class CaffeineDecayPoint {
  const CaffeineDecayPoint({
    required this.time,
    required this.residualMg,
  });

  final DateTime time;
  final double residualMg;
}

/// Estado farmacocinético de la cafeína activa en el organismo.
class CaffeineStatus {
  const CaffeineStatus({
    required this.currentResidualMg,
    required this.bedtimeResidualMg,
    required this.recommendedCutoffTime,
    required this.isCurfewPassed,
    required this.willDisruptSleep,
  });

  final double currentResidualMg;
  final double bedtimeResidualMg;
  final DateTime recommendedCutoffTime;
  final bool isCurfewPassed;
  final bool willDisruptSleep;
}

/// Servicio de modelado farmacocinético de la cafeína (Semivida $T_{1/2} = 5.5\text{ h}$).
///
/// Mecanismo fisiológico:
/// La cafeína es un antagonista competitivo de los receptores de adenosina ($A_1$ y $A_{2A}$).
/// Una concentración sérica $> 25\text{ mg}$ durante el inicio del sueño suprime la fase
/// N3 (sueño profundo de ondas lentas) y eleva la latencia de conciliación.
class CaffeinePharmacokineticsService {
  /// Semivida promedio de eliminación en adultos sanos no fumadores (en horas).
  static const double halfLifeHours = 5.5;

  /// Umbral residual máximo recomendado al momento de dormir para no perturbar el sueño profundo N3.
  static const double maxBedtimeResidualMg = 25.0;

  /// Calcula la cafeína residual en un momento específico a partir de un historial de ingestas.
  double computeResidualCaffeineAt({
    required List<CaffeineLog> logs,
    required DateTime targetTime,
  }) {
    double totalResidual = 0.0;

    for (final CaffeineLog log in logs) {
      if (log.loggedAt.isAfter(targetTime)) {
        continue;
      }

      final double elapsedHours =
          targetTime.difference(log.loggedAt).inMinutes / 60.0;
      if (elapsedHours < 0) continue;

      // C(t) = C0 * (0.5)^(t / 5.5)
      final double decayFactor = math.pow(0.5, elapsedHours / halfLifeHours).toDouble();
      totalResidual += log.caffeineMg * decayFactor;
    }

    return double.parse(totalResidual.toStringAsFixed(1));
  }

  /// Calcula la hora límite recomendada ("Curfew") para la última toma de cafeína
  /// respecto a la hora objetivo de acostarse (por defecto 23:00).
  ///
  /// Para una taza estándar (100 mg):
  /// $100 \cdot (0.5)^{(h / 5.5)} \le 25 \implies (0.5)^{(h / 5.5)} \le 0.25 \implies h / 5.5 = 2 \implies h = 11\text{ h}$ antes.
  DateTime computeBedtimeCutoff({
    required DateTime targetBedtime,
    double typicalDoseMg = 100.0,
    double maxResidual = maxBedtimeResidualMg,
  }) {
    final double safeMax = maxResidual > 0 ? maxResidual : maxBedtimeResidualMg;
    if (typicalDoseMg <= safeMax) {
      return targetBedtime;
    }

    // h = halfLife * log2(typicalDose / maxResidual)
    final double ratio = typicalDoseMg / safeMax;
    final double hoursBefore = halfLifeHours * (math.log(ratio) / math.ln2);

    return targetBedtime.subtract(
      Duration(minutes: (hoursBefore * 60).round()),
    );
  }

  /// Evalúa el estado integral de cafeína: nivel actual, nivel proyectado al dormir y alerta de sueño.
  ///
  /// Con [cutoffHoursBeforeBed] (preferencia del perfil) la hora límite es
  /// `targetBedtime - cutoffHoursBeforeBed`; sin ella se deriva de una taza de 100 mg.
  CaffeineStatus evaluateStatus({
    required List<CaffeineLog> logs,
    required DateTime targetBedtime,
    required DateTime currentTime,
    double? cutoffHoursBeforeBed,
  }) {
    final DateTime now = currentTime;
    final double currentResidual = computeResidualCaffeineAt(
      logs: logs,
      targetTime: now,
    );
    final double bedtimeResidual = computeResidualCaffeineAt(
      logs: logs,
      targetTime: targetBedtime,
    );
    final DateTime cutoffTime = cutoffHoursBeforeBed != null && cutoffHoursBeforeBed > 0
        ? targetBedtime.subtract(Duration(minutes: (cutoffHoursBeforeBed * 60).round()))
        : computeBedtimeCutoff(
            targetBedtime: targetBedtime,
            typicalDoseMg: 100.0,
            maxResidual: maxBedtimeResidualMg,
          );

    final bool isPassed = now.isAfter(cutoffTime);
    final bool willDisrupt = bedtimeResidual > maxBedtimeResidualMg;

    return CaffeineStatus(
      currentResidualMg: currentResidual,
      bedtimeResidualMg: bedtimeResidual,
      recommendedCutoffTime: cutoffTime,
      isCurfewPassed: isPassed,
      willDisruptSleep: willDisrupt,
    );
  }

  /// Genera puntos de muestra cada 30 o 60 minutos para graficar la curva de decaimiento en la UI.
  List<CaffeineDecayPoint> generateDecayCurve({
    required List<CaffeineLog> logs,
    required DateTime startTime,
    required DateTime endTime,
    int intervalMinutes = 30,
  }) {
    if (logs.isEmpty || endTime.isBefore(startTime)) {
      return <CaffeineDecayPoint>[];
    }

    final int stepMinutes = intervalMinutes > 0 ? intervalMinutes : 30;
    final List<CaffeineDecayPoint> points = <CaffeineDecayPoint>[];
    DateTime cursor = startTime;

    while (cursor.isBefore(endTime) || cursor.isAtSameMomentAs(endTime)) {
      final double residual = computeResidualCaffeineAt(
        logs: logs,
        targetTime: cursor,
      );
      points.add(CaffeineDecayPoint(time: cursor, residualMg: residual));
      cursor = cursor.add(Duration(minutes: stepMinutes));
    }

    return points;
  }
}

/// Provider de Riverpod para CaffeinePharmacokineticsService.
final caffeinePharmacokineticsServiceProvider =
    Provider<CaffeinePharmacokineticsService>((ref) {
  return CaffeinePharmacokineticsService();
});
