import 'package:flutter/material.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';

/// Dato breve (etiqueta + valor) de las vistas previas de pesaje y cinta.
class PreviewMiniStat extends StatelessWidget {
  const PreviewMiniStat({
    super.key,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: ScFonts.ui,
            fontSize: 11,
            color: c.text3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontFamily: ScFonts.display,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: highlight ? c.accent : c.text,
          ),
        ),
      ],
    );
  }
}
