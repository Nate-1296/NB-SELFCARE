import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';

class MacroDetailBox extends StatelessWidget {
  const MacroDetailBox({super.key, 
    required this.title,
    required this.value,
    required this.sublabel,
    required this.accentColor,
  });

  final String title;
  final String value;
  final String sublabel;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: c.isFlat ? c.line2 : c.line,
          width: c.isFlat ? 1.3 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            softWrap: true,
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: c.text2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            softWrap: true,
            style: TextStyle(
              fontFamily: ScFonts.display,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sublabel,
            softWrap: true,
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 11,
              color: c.text3,
            ),
          ),
        ],
      ),
    );
  }
}

class GramStepButton extends StatelessWidget {
  const GramStepButton({super.key, 
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Material(
      color: c.bg3,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          unawaited(HapticFeedback.selectionClick());
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: c.isFlat ? c.line2 : c.line,
              width: c.isFlat ? 1.4 : 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: ScFonts.display,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: c.text,
            ),
          ),
        ),
      ),
    );
  }
}

class MacroLegendDot extends StatelessWidget {
  const MacroLegendDot({super.key, 
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontFamily: ScFonts.ui,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: c.text2,
          ),
        ),
      ],
    );
  }
}

class ElectrolyteDetailRow extends StatelessWidget {
  const ElectrolyteDetailRow({super.key, 
    required this.label,
    required this.valueText,
    required this.isReported,
  });

  final String label;
  final String valueText;
  final bool isReported;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            softWrap: true,
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: c.text2,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          valueText,
          style: TextStyle(
            fontFamily: ScFonts.display,
            fontSize: 12.5,
            fontWeight: isReported ? FontWeight.w800 : FontWeight.w600,
            fontStyle: isReported ? FontStyle.normal : FontStyle.italic,
            color: isReported ? c.text : c.text3,
          ),
        ),
      ],
    );
  }
}
