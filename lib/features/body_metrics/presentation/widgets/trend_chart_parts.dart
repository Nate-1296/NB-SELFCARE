import 'package:flutter/material.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';

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
          style: TextStyle(
            fontFamily: ScFonts.ui,
            fontSize: 10.5,
            color: c.text3,
          ),
        ),
      ],
    );
  }
}

class ChartPeriodButton extends StatelessWidget {
  const ChartPeriodButton({super.key, 
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
          color: isSelected ? c.accent : c.bg3,
          borderRadius: BorderRadius.circular(10),
          border: isSelected && c.isFlat
              ? Border.all(color: c.text, width: 1.5)
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: ScFonts.ui,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? c.ink : c.text2,
          ),
        ),
      ),
    );
  }
}

class ChartStatBox extends StatelessWidget {
  const ChartStatBox({super.key, 
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: c.bg3,
        borderRadius: BorderRadius.circular(12),
        border: c.isFlat ? Border.all(color: c.line2, width: 1.2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: c.text3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontFamily: ScFonts.display,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: color ?? c.text,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
