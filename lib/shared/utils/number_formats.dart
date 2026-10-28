import 'package:intl/intl.dart';

/// Formatos numéricos legibles según el idioma activo ("9.700", "82,7").
///
/// Sin idioma explícito usan el de la app ([Intl.defaultLocale], que fija
/// `main`), y español si aún no hay uno.
abstract final class NumberFormats {
  static String _locale(String? locale) => locale ?? Intl.defaultLocale ?? 'es';

  /// Entero con separador de miles del idioma.
  static String integer(num value, String locale) =>
      NumberFormat.decimalPattern(locale).format(value.round());

  /// Entero con separador de miles en el idioma de la app ("8.000").
  static String group(num value, [String? locale]) => integer(value, _locale(locale));

  /// Un decimal fijo ("82,7" en español).
  static String oneDecimal(num value, String locale) => fixed(value, 1, locale);

  /// [digits] decimales fijos con separadores del idioma ("0,50", "2.554").
  static String fixed(num value, int digits, [String? locale]) {
    final NumberFormat f = NumberFormat.decimalPattern(_locale(locale))
      ..minimumFractionDigits = digits
      ..maximumFractionDigits = digits;
    return f.format(value.isFinite ? value : 0);
  }

  /// Valor inicial de un campo editable: sin separador de miles y sin
  /// decimales sobrantes ("82,5", "75"). Los campos aceptan coma o punto.
  static String input(num value, {int maxDigits = 1, String? locale}) {
    final NumberFormat f = NumberFormat.decimalPattern(_locale(locale))
      ..minimumFractionDigits = 0
      ..maximumFractionDigits = maxDigits
      ..turnOffGrouping();
    return f.format(value.isFinite ? value : 0);
  }
}
