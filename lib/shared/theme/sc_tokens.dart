import 'package:flutter/material.dart';

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

  /// Espacio inferior para no quedar bajo la barra de navegación y la barra de ayuno.
  static const double bottomInset = 120;
}

/// Radios de esquina del sistema.
abstract final class ScRadius {
  static const double card = 22;
  static const double tile = 16;
  static const double control = 12;
  static const double pill = 999;
}

extension ScTextThemeX on BuildContext {
  /// Estilos tipográficos del tema activo (SpaceGrotesk para cifras y títulos, Manrope para UI).
  TextTheme get text => Theme.of(this).textTheme;
}
