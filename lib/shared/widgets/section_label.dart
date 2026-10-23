import 'package:flutter/material.dart';

import '../theme/sc_colors.dart';
import '../theme/sc_theme.dart';
import '../util/responsive.dart';

/// Rótulo en mayúsculas para clasificar bloques de contenido con alto contraste.
class SectionLabel extends StatelessWidget {
  const SectionLabel({
    super.key,
    required this.label,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 8),
  });

  final String label;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;

    return Padding(
      padding: padding,
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: ScFonts.ui,
          fontSize: 12.0 * context.uiScale,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: c.text3,
        ),
      ),
    );
  }
}

