import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_tokens.dart';

class DailyRhythmBanner extends StatelessWidget {
  const DailyRhythmBanner({
    super.key,
    required this.activePillars,
    required this.hiddenCount,
    required this.onCustomizeTap,
  });

  final int activePillars;
  final int hiddenCount;
  final VoidCallback onCustomizeTap;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final String rhythmMessage;
    if (activePillars == 0) {
      rhythmMessage = context.l10n.todayTuDiaEmpiezaEnBlanco;
    } else if (activePillars < 4) {
      rhythmMessage = context.l10n.todayDe5HabitosConMovimiento((activePillars).toString());
    } else {
      rhythmMessage = context.l10n.todayDiaRedondoDe5Habitos((activePillars).toString());
    }

    // Sin caja: una franja discreta bajo el saludo, con un segmento por hábito.
    return Padding(
      padding: const EdgeInsets.only(left: ScSpace.xs),
      child: Row(
        children: <Widget>[
          ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List<Widget>.generate(5, (int idx) {
                final bool active = idx < activePillars;
                return AnimatedContainer(
                  duration: ScMotion.of(context, ScMotion.standard),
                  width: 14,
                  height: 5,
                  margin: const EdgeInsets.only(right: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: active
                        ? (c.isFlat ? c.text : c.accent)
                        : (c.isFlat ? c.bg : c.text.withValues(alpha: 0.12)),
                    border: c.isFlat ? Border.all(color: c.line2) : null,
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: ScSpace.s + 2),
          Expanded(
            child: Text(
              hiddenCount > 0
                  ? context.l10n.todayOcultaS(rhythmMessage, hiddenCount.toString())
                  : rhythmMessage,
              style: context.type.caption,
            ),
          ),
          if (hiddenCount > 0)
            TextButton(onPressed: onCustomizeTap, child: Text(context.l10n.todayMostrar)),
        ],
      ),
    );
  }
}
