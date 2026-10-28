import 'package:flutter/material.dart';

import '../theme/sc_colors.dart';
import '../theme/sc_tokens.dart';
import 'pressable.dart';

/// Tarjeta base del sistema.
///
/// En color: superficie elevada con un filo apenas visible y esquinas amplias;
/// si es pulsable, se hunde levemente al tocarla. En Modo Papel: ficha con
/// borde de tinta de 1,5 px, esquinas más cerradas y sin efectos.
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
    final BorderRadius radius = BorderRadius.circular(ScRadius.cardOf(c));
    final BorderSide side = BorderSide(
      color: borderColor ?? (c.isFlat ? c.line2 : c.line),
      width: c.isFlat ? 1.5 : 1.0,
    );

    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) content = InkWell(onTap: onTap, child: content);

    final Widget card = Padding(
      padding: margin,
      child: Material(
        color: backgroundColor ?? c.bg2,
        shape: RoundedRectangleBorder(borderRadius: radius, side: side),
        clipBehavior: Clip.antiAlias,
        child: content,
      ),
    );

    return onTap == null ? card : Pressable(scale: 0.985, child: card);
  }
}
