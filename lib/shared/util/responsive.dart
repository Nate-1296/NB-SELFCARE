import 'package:flutter/widgets.dart';

/// Punto de quiebre según el ancho disponible de la pantalla.
enum Bp { compact, medium, expanded }

/// Clasifica un ancho en [Bp].
Bp breakpointFor(double width) {
  if (width >= 1024) return Bp.expanded;
  if (width >= 600) return Bp.medium;
  return Bp.compact;
}

/// Número de columnas para rejillas de métricas y tarjetas según el ancho.
int gridColumns(double width) {
  if (width >= 1200) return 4;
  if (width >= 800) return 3;
  if (width >= 540) return 2;
  return 1;
}

/// Factor de escala tipográfica para títulos y tarjetas.
double uiScaleFor(double width) {
  switch (breakpointFor(width)) {
    case Bp.compact:
      return 1.0;
    case Bp.medium:
      return 1.12;
    case Bp.expanded:
      return 1.25;
  }
}

/// Extensiones de contexto para consultar valores de escala reactivos.
extension ResponsiveContextX on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;
  Bp get bp => breakpointFor(screenWidth);
  bool get isWide => bp != Bp.compact;
  int get gridCols => gridColumns(screenWidth);
  double get uiScale => uiScaleFor(screenWidth);

  /// Factor para escalar tarjetas y círculos de salud.
  double get cardScale => isWide ? 1.15 : 1.0;
}

