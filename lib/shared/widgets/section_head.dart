import 'package:flutter/material.dart';

import '../theme/sc_colors.dart';
import '../theme/sc_theme.dart';
import '../util/responsive.dart';

/// Encabezado de sección con título y acción secundaria opcional.
class SectionHead extends StatelessWidget {
  const SectionHead({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.big = false,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final double size = (big ? 22.0 : 19.0) * context.uiScale;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitle != null) ...[
                  Text(
                    subtitle!.toUpperCase(),
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 11.5 * context.uiScale,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: c.text3,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: ScFonts.display,
                    fontSize: size,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.02 * size,
                    color: c.text,
                  ),
                ),
              ],
            ),
          ),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  actionLabel!,
                  style: TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: 13.5 * context.uiScale,
                    fontWeight: FontWeight.w700,
                    color: c.accent,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

