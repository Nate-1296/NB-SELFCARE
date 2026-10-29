/// Índice de Bienestar OMS-5 (WHO-5): cinco frases en positivo sobre las
/// últimas dos semanas, cada una de 0 ("en ningún momento") a 5 ("todo el
/// tiempo"). De uso libre, sin licencia (OMS, 1998).
enum WellbeingBand {
  /// 76–100.
  flourishing,

  /// 51–75.
  good,

  /// 29–50: conviene cuidarse un poco más estas semanas.
  low,

  /// 0–28: vale la pena hablarlo con alguien de confianza o un profesional.
  veryLow,
}

abstract final class WellbeingIndex {
  static const int questionCount = 5;
  static const int maxAnswer = 5;

  /// Puntuación 0–100 (suma × 4).
  static int percent(List<int> answers) {
    if (answers.length != questionCount) {
      throw ArgumentError('El OMS-5 tiene exactamente $questionCount respuestas');
    }
    final int raw = answers.fold(0, (int s, int a) => s + a.clamp(0, maxAnswer));
    return raw * 4;
  }

  static WellbeingBand band(int percent) {
    if (percent > 75) return WellbeingBand.flourishing;
    if (percent > 50) return WellbeingBand.good;
    if (percent > 28) return WellbeingBand.low;
    return WellbeingBand.veryLow;
  }

  /// Si se muestran los teléfonos de apoyo junto al resultado.
  static bool suggestsSupport(int percent) => band(percent) == WellbeingBand.veryLow;

  /// Un cambio de 10 puntos o más es el umbral de cambio relevante del índice.
  static const int meaningfulChange = 10;
}
