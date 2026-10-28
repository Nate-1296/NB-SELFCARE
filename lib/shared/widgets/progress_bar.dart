import 'package:flutter/material.dart';

import '../theme/sc_colors.dart';
import '../theme/sc_tokens.dart';

/// Barra de progreso del sistema: extremos redondeados, pista tenue del mismo
/// color y avance animado.
///
/// En Modo Papel la pista es un contorno de tinta y el relleno es sólido, que
/// se lee mejor en E-Ink que dos grises cercanos.
class ScProgressBar extends StatelessWidget {
  const ScProgressBar({
    super.key,
    required this.value,
    this.color,
    this.height = 8,
    this.semanticsLabel,
  });

  /// Progreso entre 0 y 1 (se recorta).
  final double value;
  final Color? color;
  final double height;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final Color fill = c.isFlat ? c.text : (color ?? c.accent);
    final double v = value.isNaN ? 0 : value.clamp(0.0, 1.0);
    final BorderRadius radius = BorderRadius.circular(height);

    return Semantics(
      label: semanticsLabel,
      value: '${(v * 100).round()} %',
      child: RepaintBoundary(
        child: Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: c.isFlat ? c.bg2 : fill.withValues(alpha: 0.2),
            borderRadius: radius,
            border: c.isFlat ? Border.all(color: c.line2, width: 1.2) : null,
          ),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: v),
            duration: ScMotion.of(context, ScMotion.emphasized),
            curve: ScMotion.ease,
            builder: (BuildContext context, double t, Widget? _) => FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: t,
              child: DecoratedBox(
                decoration: BoxDecoration(color: fill, borderRadius: radius),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
