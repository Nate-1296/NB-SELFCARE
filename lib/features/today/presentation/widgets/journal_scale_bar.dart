import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_tokens.dart';

class JournalScaleBar extends StatelessWidget {
  const JournalScaleBar({
    super.key,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: context.type.caption.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: ScSpace.s - 2),
        Row(
          children: List<Widget>.generate(5, (int idx) {
            final int level = idx + 1;
            final bool selected = value == level;
            final bool filled = level <= value;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: idx == 0 ? 0 : 4),
                child: Semantics(
                  selected: selected,
                  button: true,
                  label: '$label $level',
                  excludeSemantics: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(ScRadius.controlOf(c) - 4),
                    onTap: () {
                      unawaited(HapticFeedback.selectionClick());
                      onChanged(level);
                    },
                    child: SizedBox(
                      height: 48,
                      child: Center(
                        child: AnimatedContainer(
                          duration: ScMotion.of(context, ScMotion.quick),
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            // Escala acumulativa: se rellenan los niveles hasta el elegido.
                            color: c.isFlat
                                ? (selected ? c.text : c.bg2)
                                : (filled
                                      ? activeColor.withValues(alpha: selected ? 1 : 0.28)
                                      : c.bg3),
                            borderRadius: BorderRadius.circular(ScRadius.controlOf(c) - 4),
                            border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
                          ),
                          child: Text(
                            '$level',
                            style: context.type.metricS.copyWith(
                              fontSize: 13.5,
                              color: c.isFlat
                                  ? (selected ? c.bg : c.text)
                                  : (selected
                                        ? (activeColor.computeLuminance() > 0.45
                                              ? const Color(0xFF0A0C10)
                                              : Colors.white)
                                        : c.text2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
