/// Extensiones para formateo y cálculos cronológicos sin dependencias pesadas.
extension DateTimeExtensions on DateTime {
  /// Retorna la clave de fecha en formato ISO 'YYYY-MM-DD' para joins directos O(1).
  String get dateKey {
    final String y = year.toString().padLeft(4, '0');
    final String m = month.toString().padLeft(2, '0');
    final String d = day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Calcula la edad cronológica exacta con precisión decimal al vuelo.
  ///
  /// Cumple con la regla inquebrantable de persistencia (AGENTS.md):
  /// La edad nunca se almacena como entero estático, sino que se deriva dinámicamente.
  static double calculateAgeYears(DateTime birthDate, DateTime referenceDate) {
    final DateTime target = referenceDate;
    final int differenceInDays = target.difference(birthDate).inDays;
    return differenceInDays / 365.25;
  }

  /// Retorna la edad cronológica redondeada en años enteros.
  static int calculateAge(DateTime birthDate, DateTime referenceDate) {
    return calculateAgeYears(birthDate, referenceDate).floor();
  }

  /// Suma días de calendario conservando la hora local.
  ///
  /// A diferencia de `add(Duration(days: n))`, no se desplaza un día en los
  /// cambios de horario de verano (un día de 23 o 25 horas).
  DateTime addDays(int days) =>
      DateTime(year, month, day + days, hour, minute, second, millisecond, microsecond);

  /// Días de calendario desde [other] hasta esta fecha (negativo si es anterior),
  /// sin verse afectado por los cambios de horario.
  int calendarDaysSince(DateTime other) => DateTime.utc(year, month, day)
      .difference(DateTime.utc(other.year, other.month, other.day))
      .inDays;

  /// Retorna el inicio del día (00:00:00.000).
  DateTime get startOfDay => DateTime(year, month, day);

  /// Retorna el final del día (23:59:59.999).
  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59, 999);

  /// Compara si dos fechas corresponden al mismo día del calendario.
  bool isSameDay(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }

  /// Retorna el nombre del mes en español.
  String get monthName {
    const months = <String>[
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return months[(month - 1).clamp(0, 11)];
  }
}
