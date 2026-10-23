import 'package:flutter/material.dart';

import '../theme/sc_colors.dart';

/// Botón circular para controles rápidos, inspirado en NB Sound.
class RoundButton extends StatelessWidget {
  const RoundButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 46,
    this.iconSize = 22,
    this.primary = false,
    this.ghost = false,
    this.color,
    this.backgroundColor,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;

  /// Si es true, usa el color de acento como fondo.
  final bool primary;

  /// Si es true, es transparente sin fondo.
  final bool ghost;

  /// Sobrescribe el color del ícono.
  final Color? color;

  /// Sobrescribe el fondo del botón.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final Color bg = backgroundColor ??
        (primary
            ? c.accent
            : ghost
                ? Colors.transparent
                : c.bg3);
    final Color fg = color ?? (primary ? c.ink : c.text);

    return Material(
      color: bg,
      shape: CircleBorder(
        side: c.isFlat && !primary && !ghost
            ? BorderSide(color: c.line2, width: 1.5)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: iconSize, color: fg),
        ),
      ),
    );
  }
}

