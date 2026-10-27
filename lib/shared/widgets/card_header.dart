import 'package:flutter/material.dart';

import '../theme/sc_colors.dart';
import '../theme/sc_tokens.dart';

/// Encabezado uniforme de tarjeta: icono tonal, título, subtítulo opcional y acción.
class CardHeader extends StatelessWidget {
  const CardHeader({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.tone,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color? tone;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final Color tint = tone ?? c.accent;
    return Row(
      children: <Widget>[
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.isFlat ? c.bg3 : tint.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(ScRadius.control),
            border: c.isFlat ? Border.all(color: c.line2, width: 1.2) : null,
          ),
          child: Icon(icon, size: 19, color: c.isFlat ? c.text : tint),
        ),
        const SizedBox(width: ScSpace.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleLarge),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall,
                ),
            ],
          ),
        ),
        if (trailing != null) ...<Widget>[const SizedBox(width: ScSpace.s), trailing!],
      ],
    );
  }
}
