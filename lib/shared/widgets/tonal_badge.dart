import 'package:flutter/material.dart';

import '../theme/sc_colors.dart';
import '../theme/sc_theme.dart';
import '../theme/sc_tokens.dart';

/// Insignia compacta de estado ("Óptimo", "Activo", "+15 monedas").
///
/// En Modo Papel usa superficie secundaria y tinta para que nunca quede
/// texto del mismo color que su fondo.
class TonalBadge extends StatelessWidget {
  const TonalBadge({super.key, required this.label, this.tone, this.icon});

  final String label;

  /// Color semántico; por defecto, el acento del tema.
  final Color? tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final Color tint = tone ?? c.accent;
    final Color foreground = c.isFlat ? c.text : tint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: ScSpace.s, vertical: ScSpace.xxs + 1),
      decoration: BoxDecoration(
        color: c.isFlat ? c.bg3 : tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(ScRadius.pill),
        border: c.isFlat ? Border.all(color: c.line2, width: 1.2) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: ScSpace.xs),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}
