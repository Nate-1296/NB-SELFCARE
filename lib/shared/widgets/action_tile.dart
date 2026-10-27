import 'package:flutter/material.dart';

import '../theme/sc_colors.dart';
import '../theme/sc_theme.dart';
import '../theme/sc_tokens.dart';

/// Acceso rápido en cuadrícula: icono arriba y texto debajo, de modo que el
/// título disponga de todo el ancho y nunca se partan palabras.
class ActionTile extends StatelessWidget {
  const ActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.tone,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final Color tint = tone ?? c.accent;
    return Semantics(
      button: true,
      label: subtitle == null ? title : '$title. $subtitle',
      excludeSemantics: true,
      child: Material(
        color: c.bg3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ScRadius.tile),
          side: BorderSide(color: c.isFlat ? c.line2 : c.line, width: c.isFlat ? 1.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(ScSpace.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 22, color: c.isFlat ? c.text : tint),
                const SizedBox(height: ScSpace.s),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ).copyWith(color: c.text),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: ScSpace.xxs),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: ScFonts.ui, fontSize: 11.5, color: c.text2, height: 1.25),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
