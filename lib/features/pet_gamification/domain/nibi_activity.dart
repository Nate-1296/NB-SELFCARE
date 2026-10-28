/// Lo que Nibi está haciendo. Ninguna actividad es negativa: Nibi siempre está
/// bien (ADR-08); como mucho, duerme o tiene curiosidad.
enum NibiActivity {
  idle,
  happy,
  eating,
  drinking,
  sleeping,
  zen,
  workout,
  weighing,
  celebrating,
  curious,

  /// Juega con su pelota (cuidado "Jugar").
  playing,
}

/// Reacción breve encima de la actividad: lo que hace al tocarlo y sus
/// pequeñas manías cuando está tranquilo. Todas son alegres.
enum NibiReaction {
  /// Caricia en la cabeza: ojos felices y corazones.
  pat(1.6),

  /// Cosquillas en la panza: se ríe y se sacude.
  giggle(1.4),

  /// Vuelta sobre sí mismo.
  spin(1.2),

  /// Salto con aleteo.
  hop(1.1),

  /// Bocanada de humo y chispas (es un dragón).
  puff(1.8),

  /// Ronroneo al mantenerlo pulsado: notas musicales.
  purr(2.4),

  /// Bostezo y estiramiento.
  yawn(2.2),

  /// Mira a un lado y a otro.
  lookAround(2.6),

  /// Despliega las alas.
  stretch(1.8),

  /// Resoplido con dos nubecitas.
  snort(1.2);

  const NibiReaction(this.seconds);

  /// Duración de la reacción.
  final double seconds;

  /// Las que lanza Nibi solo cuando nadie lo toca.
  static const List<NibiReaction> quirks = <NibiReaction>[yawn, lookAround, stretch, snort];
}

/// Datos reales del día que influyen en el ánimo de base de Nibi.
class NibiVitals {
  const NibiVitals({
    required this.hour,
    this.hydrationRatio = 0,
    this.sleptWell = false,
    this.fastingHours,
    this.workedOutToday = false,
    this.streakDays = 0,
    this.mealsLoggedToday = 0,
  });

  /// Hora local (0–23).
  final int hour;
  final double hydrationRatio;
  final bool sleptWell;

  /// Horas del ayuno en curso, o `null` si no hay ayuno.
  final double? fastingHours;
  final bool workedOutToday;
  final int streakDays;
  final int mealsLoggedToday;
}

/// Ánimo de base de Nibi y si lo envuelve el aura de cetosis.
class NibiMood {
  const NibiMood({required this.activity, required this.aura});

  final NibiActivity activity;

  /// Aura luminosa de la cetosis (ayuno ≥ 12 h, docs/08 §2).
  final bool aura;
}

/// Reglas puras: de los datos del día al ánimo de base de Nibi.
abstract final class NibiMoodResolver {
  /// Ayuno a partir del cual se dibuja el aura (docs/08 §2).
  static const double auraFastingHours = 12;

  static NibiMood resolve(NibiVitals v) {
    final bool aura = (v.fastingHours ?? 0) >= auraFastingHours;
    final NibiActivity activity;
    if (v.hour >= 23 || v.hour < 6) {
      // De noche Nibi duerme (y en esas horas tampoco se le despierta con avisos).
      activity = NibiActivity.sleeping;
    } else if (aura) {
      activity = NibiActivity.zen;
    } else if (v.hydrationRatio >= 1 && v.sleptWell) {
      activity = NibiActivity.celebrating;
    } else if (v.hydrationRatio >= 1 || v.sleptWell || v.workedOutToday || v.streakDays >= 7) {
      activity = NibiActivity.happy;
    } else if (v.mealsLoggedToday == 0 && v.hour >= 11) {
      // Sin registros todavía: curiosidad, nunca reproche.
      activity = NibiActivity.curious;
    } else {
      activity = NibiActivity.idle;
    }
    return NibiMood(activity: activity, aura: aura);
  }
}
