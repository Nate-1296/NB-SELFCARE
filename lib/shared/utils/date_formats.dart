import 'package:intl/intl.dart';

/// Formatos de fecha legibles según el idioma activo.
abstract final class DateFormats {
  /// "lunes, 26 de octubre".
  static String weekdayDayMonth(DateTime date, String locale) =>
      DateFormat.MMMMEEEEd(locale).format(date);

  /// "26 oct 2026".
  static String shortDate(DateTime date, String locale) => DateFormat.yMMMd(locale).format(date);

  /// "07:30".
  static String time(DateTime date, String locale) => DateFormat.Hm(locale).format(date);
}
