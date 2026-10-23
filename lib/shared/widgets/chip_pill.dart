import 'package:flutter/material.dart';

import '../theme/sc_colors.dart';
import '../theme/sc_theme.dart';

/// Píldora de selección o filtro con forma de estadio y borde definido.
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
    final Color resolvedIconColor = iconColor ?? (active ? tint : c.text2);

    return Material(
      color: active ? (c.isFlat ? Colors.transparent : tint.withValues(alpha: 0.15)) : Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(
          color: active ? tint : (c.isFlat ? c.line2 : c.line),
          width: active ? 1.8 : 1.2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
                  color: active ? (c.isFlat ? c.text : tint) : c.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
