import 'package:flutter/material.dart';

import '../theme/sc_colors.dart';
import '../theme/sc_theme.dart';

/// Cifra destacada con su unidad ("82.7 kg", "1 014 kcal").
class MetricValue extends StatelessWidget {
  const MetricValue({
    super.key,
    required this.value,
    this.unit,
    this.size = 28,
    this.color,
  });

  final String value;
  final String? unit;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: value,
            style: TextStyle(
              fontFamily: ScFonts.display,
              fontSize: size,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.03 * size,
              color: color ?? c.text,
              height: 1.0,
            ),
          ),
          if (unit != null)
            TextSpan(
              text: ' $unit',
              style: TextStyle(
                fontFamily: ScFonts.ui,
                fontSize: size * 0.45,
                fontWeight: FontWeight.w700,
                color: c.text2,
              ),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
