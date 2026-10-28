import 'package:flutter/material.dart';

import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/theme/sc_tokens.dart';

class ChartLegendDot extends StatelessWidget {
  const ChartLegendDot({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontFamily: ScFonts.ui, fontSize: 11.5, color: c.text2),
        ),
      ],
    );
  }
}

/// Cifra resumen del período ("Cambio", "Promedio"…), sin caja.
class ChartStatBox extends StatelessWidget {
  const ChartStatBox({super.key, required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.type.overline.copyWith(fontSize: 10),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: context.type.metricS.copyWith(
              fontSize: 16,
              color: c.isFlat ? c.text : (color ?? c.text),
            ),
          ),
        ),
      ],
    );
  }
}
