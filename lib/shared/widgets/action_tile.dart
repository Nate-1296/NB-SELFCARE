import 'package:flutter/material.dart';

import '../theme/sc_colors.dart';
import '../theme/sc_theme.dart';
import '../theme/sc_tokens.dart';
import 'pressable.dart';

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
    this.onPage = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? tone;
  final VoidCallback onTap;

  /// Sobre el fondo de la página (no dentro de una tarjeta): usa la superficie de tarjeta.
  final bool onPage;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final Color tint = tone ?? c.accent;
    return Semantics(
      button: true,
      label: subtitle == null ? title : '$title. $subtitle',
      excludeSemantics: true,
      child: Pressable(
        child: Material(
          color: c.isFlat || onPage ? c.bg2 : c.bg3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ScRadius.tileOf(c)),
            side: c.isFlat
                ? BorderSide(color: c.line2, width: 1.5)
                : (onPage ? BorderSide(color: c.line) : BorderSide.none),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                ScSpace.m + 2,
                ScSpace.m + 2,
                ScSpace.m,
                ScSpace.m + 2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(icon, size: 22, color: c.isFlat ? c.text : tint),
                  const SizedBox(height: ScSpace.m),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      color: c.text,
                    ),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: ScSpace.xxs),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 12,
                        color: c.text2,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
