import 'package:flutter/material.dart';

import '../theme/sc_colors.dart';

/// Tarjeta principal de salud inspirada en la nueva interfaz de Samsung Health.
///
/// Ofrece esquinas redondeadas continuas (22 px), superficie elevada limpia y
/// conmutación automática a modo plano con bordes de 1.5 px en Modo Papel (NXTPAPER).
class HealthCard extends StatelessWidget {
  const HealthCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18.0),
    this.margin = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
    this.onTap,
    this.backgroundColor,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final Color bg = backgroundColor ?? c.bg2;
    final BorderSide side = BorderSide(
      color: borderColor ?? (c.isFlat ? c.line2 : c.line),
      width: c.isFlat ? 1.5 : 1.0,
    );

    final Widget card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22.0),
        border: Border.fromBorderSide(side),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22.0),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );

    return card;
  }
}

