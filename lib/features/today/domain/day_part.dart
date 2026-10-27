/// Franja del día para el saludo de la pantalla Hoy.
enum DayPart {
  morning,
  afternoon,
  night;

  /// Mañana 05–12, tarde 12–19, noche 19–05.
  static DayPart forHour(int hour) {
    if (hour >= 5 && hour < 12) return DayPart.morning;
    if (hour >= 12 && hour < 19) return DayPart.afternoon;
    return DayPart.night;
  }
}
