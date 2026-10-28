import 'package:flutter/material.dart';

import '../theme/sc_colors.dart';
import '../theme/sc_theme.dart';
import '../theme/sc_tokens.dart';

/// Insignia compacta de estado ("Óptimo", "Activo", "+15 monedas").
///
/// En Modo Papel usa contorno de tinta para que nunca quede texto del mismo
/// color que su fondo.
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
      padding: const EdgeInsets.symmetric(horizontal: ScSpace.s, vertical: 3),
      decoration: BoxDecoration(
        color: c.isFlat ? c.bg2 : tint.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(c.isFlat ? 4 : ScRadius.pill),
        border: c.isFlat ? Border.all(color: c.line2, width: 1.2) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: ScSpace.xs),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: ScFonts.ui,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: foreground,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
