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
