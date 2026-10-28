import 'package:flutter/material.dart';

import 'sc_colors.dart';
import 'sc_theme.dart';

/// Escala de espaciado (múltiplos de 4 dp).
abstract final class ScSpace {
  static const double xxs = 2;
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Margen lateral de todas las pantallas principales.
  static const double gutter = 16;

  /// Separación vertical entre tarjetas.
  static const double cardGap = 12;

  /// Espacio entre bloques temáticos de una pantalla (sección → sección).
  static const double sectionGap = 28;

  /// Espacio inferior para no quedar bajo la barra de navegación y la barra de ayuno.
  static const double bottomInset = 120;
}

/// Radios de esquina del sistema.
///
/// En Modo Papel las esquinas se cierran (aspecto de ficha impresa y bordes más
/// nítidos en la pantalla mate); por eso los componentes usan [ScRadius.cardOf].
abstract final class ScRadius {
  static const double card = 24;
  static const double tile = 18;
  static const double control = 14;
  static const double pill = 999;

  static const double paperCard = 14;
  static const double paperTile = 10;
  static const double paperControl = 8;

  static double cardOf(ScColors c) => c.isFlat ? paperCard : card;
  static double tileOf(ScColors c) => c.isFlat ? paperTile : tile;
  static double controlOf(ScColors c) => c.isFlat ? paperControl : control;
}

/// Duraciones y curvas de las microinteracciones.
///
/// En Modo Papel (E-Ink) y con "Quitar animaciones" del sistema todas las
/// duraciones son cero: cada cambio se dibuja en un solo fotograma, sin estelas.
abstract final class ScMotion {
  static const Duration press = Duration(milliseconds: 110);
  static const Duration quick = Duration(milliseconds: 180);
  static const Duration standard = Duration(milliseconds: 320);
  static const Duration emphasized = Duration(milliseconds: 650);

  static const Curve ease = Curves.easeOutCubic;
  static const Curve spring = Curves.easeOutBack;

  /// Si la vista actual debe animarse.
  static bool enabled(BuildContext context) {
    final bool reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return !reduced && !context.sc.isFlat;
  }

  /// [base] si hay animaciones; [Duration.zero] en Modo Papel o movimiento reducido.
  static Duration of(BuildContext context, Duration base) =>
      enabled(context) ? base : Duration.zero;
}

/// Estilos tipográficos semánticos: cifras, etiquetas y textos de apoyo.
///
/// Las cifras usan dígitos tabulares para que no "bailen" al animarse o al
/// cambiar cada segundo (cronómetros).
@immutable
class ScType {
  const ScType._(this._c);

  final ScColors _c;

  static const List<FontFeature> _tabular = <FontFeature>[FontFeature.tabularFigures()];

  TextStyle _display(double size, {FontWeight weight = FontWeight.w700, Color? color}) => TextStyle(
    fontFamily: ScFonts.display,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: -0.035 * size,
    height: 1.0,
    color: color ?? _c.text,
    fontFeatures: _tabular,
  );

  /// Cifra protagonista de una pantalla (peso, cronómetro).
  TextStyle get metricXL => _display(44);

  /// Cifra principal de una tarjeta grande.
  TextStyle get metricL => _display(32);

  /// Cifra de una tarjeta compacta.
  TextStyle get metricM => _display(24);

  /// Cifra en filas y rejillas de métricas.
  TextStyle get metricS => _display(18);

  /// Unidad que acompaña a una cifra ("kg", "ml").
  TextStyle unit(double metricSize) => TextStyle(
    fontFamily: ScFonts.ui,
    fontSize: (metricSize * 0.42).clamp(11.0, 18.0),
    fontWeight: FontWeight.w600,
    color: _c.text2,
    height: 1.0,
  );

  /// Rótulo de tarjeta junto a su icono ("Agua", "Peso").
  TextStyle get label => TextStyle(
    fontFamily: ScFonts.ui,
    fontSize: 13.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.1,
    color: _c.text,
    height: 1.2,
  );

  /// Rótulo pequeño en mayúsculas sobre cifras ("META", "TENDENCIA").
  TextStyle get overline => TextStyle(
    fontFamily: ScFonts.ui,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.9,
    color: _c.text3,
    height: 1.2,
  );

  /// Texto de apoyo bajo una cifra o un título.
  TextStyle get caption => TextStyle(
    fontFamily: ScFonts.ui,
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    color: _c.text2,
    height: 1.35,
  );

  /// Texto explicativo de párrafo.
  TextStyle get body => TextStyle(
    fontFamily: ScFonts.ui,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: _c.text2,
    height: 1.45,
  );
}

extension ScTextThemeX on BuildContext {
  /// Estilos tipográficos del tema activo (SpaceGrotesk para cifras y títulos, Manrope para UI).
  TextTheme get text => Theme.of(this).textTheme;

  /// Estilos semánticos de cifras y rótulos del sistema de diseño.
  ScType get type => ScType._(sc);
}
