/// Estado de la racha tras registrar el primer hábito de un día.
class StreakUpdate {
  const StreakUpdate({
    required this.currentStreakDays,
    required this.highestStreakDays,
    required this.shieldsAvailable,
    required this.shieldsConsumed,
  });

  final int currentStreakDays;
  final int highestStreakDays;
  final int shieldsAvailable;
  final int shieldsConsumed;
}

/// Reglas de la racha diaria (ADR-08: gamificación positiva).
///
/// * Cada día perdido entre el último día activo y hoy consume un escudo.
/// * Si los escudos no alcanzan para cubrir todo el hueco, la racha vuelve a
///   empezar en 1 y los escudos se conservan (nunca se gastan en vano).
/// * Sin historial previo, la racha simplemente avanza.
/// * Nada de esto afecta a Nibi: la mascota no enferma ni regaña.
abstract final class StreakPolicy {
  static StreakUpdate onFirstHabitOfDay({
    required DateTime day,
    required DateTime? lastActiveDay,
    required int currentStreakDays,
    required int highestStreakDays,
    required int shieldsAvailable,
  }) {
    int nextStreak;
    int shields = shieldsAvailable;
    int consumed = 0;

    if (lastActiveDay == null || currentStreakDays <= 0) {
      // Sin historial en el libro mayor no hay huecos que evaluar: se continúa
      // la racha existente (p. ej. restaurada de un respaldo) o se inicia en 1.
      nextStreak = currentStreakDays + 1;
    } else {
      final int missedDays = missedDaysBetween(lastActiveDay, day);
      if (missedDays == 0) {
        nextStreak = currentStreakDays + 1;
      } else if (missedDays <= shields) {
        shields -= missedDays;
        consumed = missedDays;
        nextStreak = currentStreakDays + 1;
      } else {
        nextStreak = 1;
      }
    }

    return StreakUpdate(
      currentStreakDays: nextStreak,
      highestStreakDays: nextStreak > highestStreakDays ? nextStreak : highestStreakDays,
      shieldsAvailable: shields,
      shieldsConsumed: consumed,
    );
  }

  /// Días de calendario completos sin actividad entre [lastActive] y [day].
  static int missedDaysBetween(DateTime lastActive, DateTime day) {
    final DateTime a = DateTime.utc(lastActive.year, lastActive.month, lastActive.day);
    final DateTime b = DateTime.utc(day.year, day.month, day.day);
    final int gap = b.difference(a).inDays - 1;
    return gap < 0 ? 0 : gap;
  }
}
