import 'dart:math' as math;

/// Noche registrada: duración y hora de despertar (minutos desde medianoche).
class SleepNight {
  const SleepNight({required this.durationMinutes, required this.wakeMinutes});

  final int durationMinutes;
  final int wakeMinutes;

  /// Punto medio del sueño (minutos desde medianoche, 0–1439).
  int get midpointMinutes => (wakeMinutes - durationMinutes ~/ 2) % (24 * 60);
}

enum SleepRegularityBand { veryRegular, regular, variable }

/// Regularidad del horario de sueño: cuánto se mueve el punto medio de la
/// noche entre días. La constancia del horario pesa tanto como la duración
/// (Phillips et al., 2017; Windred et al., 2024).
class SleepRegularity {
  const SleepRegularity({required this.spreadMinutes, required this.nights});

  /// Desviación circular del punto medio, en minutos.
  final int spreadMinutes;
  final int nights;

  static const int minNights = 5;

  SleepRegularityBand get band {
    if (spreadMinutes <= 30) return SleepRegularityBand.veryRegular;
    if (spreadMinutes <= 60) return SleepRegularityBand.regular;
    return SleepRegularityBand.variable;
  }

  /// `null` si hay menos de [minNights] noches con hora de despertar.
  static SleepRegularity? from(List<SleepNight> nights) {
    final List<SleepNight> valid = nights
        .where((SleepNight n) => n.durationMinutes > 0 && n.durationMinutes < 24 * 60)
        .toList();
    if (valid.length < minNights) return null;
    // Estadística circular: las 23:50 y las 00:10 están a 20 minutos, no a 23 h.
    double sx = 0;
    double sy = 0;
    for (final SleepNight n in valid) {
      final double angle = n.midpointMinutes / (24 * 60) * 2 * math.pi;
      sx += math.cos(angle);
      sy += math.sin(angle);
    }
    final double r = math.sqrt(sx * sx + sy * sy) / valid.length;
    final double spreadRadians = r >= 1 ? 0 : math.sqrt(-2 * math.log(math.max(r, 1e-9)));
    final int spread = (spreadRadians / (2 * math.pi) * 24 * 60).round();
    return SleepRegularity(spreadMinutes: spread, nights: valid.length);
  }
}
