/// Fases metabólicas orientativas del ayuno (docs/09 §1). Fuente única para la
/// pantalla de Ayuno, la barra persistente, la tarjeta de Hoy y la notificación.
enum MetabolicPhase {
  anabolic(0),
  glycogenolysis(4),
  fatBurning(12),
  ketosis(18),
  autophagy(24);

  const MetabolicPhase(this.startsAtHour);

  final int startsAtHour;

  static MetabolicPhase forHours(double hours) {
    MetabolicPhase phase = MetabolicPhase.anabolic;
    for (final MetabolicPhase p in MetabolicPhase.values) {
      if (hours >= p.startsAtHour) phase = p;
    }
    return phase;
  }

  /// Hora en que empieza la siguiente fase, o `null` si es la última.
  int? get nextStartsAtHour =>
      index + 1 < MetabolicPhase.values.length ? MetabolicPhase.values[index + 1].startsAtHour : null;
}
