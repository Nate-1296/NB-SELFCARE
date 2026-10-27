import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';

class JournalScaleBar extends StatelessWidget {
  const JournalScaleBar({super.key, 
    required this.label,
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

  final String label;
  final int value;
  final Color activeColor;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: c.isFlat ? c.line2 : c.line,
          width: c.isFlat ? 1.2 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            softWrap: true,
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: c.text2,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List<Widget>.generate(5, (int idx) {
              final int level = idx + 1;
              final bool selected = value == level;
              return GestureDetector(
                onTap: () {
                  unawaited(HapticFeedback.selectionClick());
                  onChanged(level);
                },
                child: Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? activeColor : c.bg3,
                    shape: BoxShape.circle,
                    border: c.isFlat && selected
                        ? Border.all(color: c.text, width: 1.4)
                        : null,
                  ),
                  child: Text(
                    '$level',
                    style: TextStyle(
                      fontFamily: ScFonts.display,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: selected ? c.ink : c.text2,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
