import 'package:flutter/material.dart';

import '../theme/sc_colors.dart';
import '../theme/sc_theme.dart';
import '../theme/sc_tokens.dart';
import '../utils/responsive.dart';

/// Encabezado de sección: título con una línea de contexto debajo y una
/// acción de texto opcional a la derecha.
class SectionHead extends StatelessWidget {
  const SectionHead({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.big = false,
    this.subtitle,
    this.padding = const EdgeInsets.fromLTRB(20, ScSpace.sectionGap, 12, 10),
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool big;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final double size = (big ? 22.0 : 19.0) * context.uiScale;

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: ScFonts.display,
                      fontSize: size,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.025 * size,
                      color: c.text,
                    ),
                  ),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: context.type.caption.copyWith(color: c.text3)),
                ],
              ],
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                textStyle: TextStyle(
                  fontFamily: ScFonts.ui,
                  fontSize: 13.5 * context.uiScale,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}
