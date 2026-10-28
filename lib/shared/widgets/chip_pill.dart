import 'package:flutter/material.dart';

import '../theme/sc_colors.dart';
import '../theme/sc_theme.dart';
import '../theme/sc_tokens.dart';

/// Píldora de selección o filtro.
///
/// En color, la activa se rellena con el tono suave de su color y la inactiva
/// es una superficie neutra; en papel, la activa se invierte (tinta de fondo).
class ChipPill extends StatelessWidget {
  const ChipPill({
    super.key,
    required this.label,
    this.active = false,
    this.icon,
    this.iconColor,
    this.onTap,
    this.activeColor,
  });

  final String label;
  final bool active;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback? onTap;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final Color tint = activeColor ?? c.accent;
    final Color background = c.isFlat
        ? (active ? c.text : c.bg2)
        : (active ? tint.withValues(alpha: 0.18) : c.bg3);
    final Color foreground = c.isFlat ? (active ? c.bg : c.text) : (active ? tint : c.text);
    final Color resolvedIconColor = c.isFlat
        ? foreground
        : (iconColor ?? (active ? tint : c.text2));

    return Semantics(
      selected: active,
      button: onTap != null,
      child: AnimatedContainer(
        duration: ScMotion.of(context, ScMotion.quick),
        curve: ScMotion.ease,
        decoration: ShapeDecoration(
          color: background,
          shape: StadiumBorder(
            side: c.isFlat ? BorderSide(color: c.line2, width: 1.5) : BorderSide.none,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              // Zona táctil mínima de 48 dp (pautas de accesibilidad de Android).
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: EdgeInsets.fromLTRB(icon != null ? 12 : 16, 8, 16, 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (icon != null) ...<Widget>[
                      Icon(icon, size: 16, color: resolvedIconColor),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 13,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                        color: foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
