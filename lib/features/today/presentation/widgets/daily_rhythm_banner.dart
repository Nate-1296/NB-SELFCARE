import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';

class DailyRhythmBanner extends StatelessWidget {
  const DailyRhythmBanner({super.key, 
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

    return Padding(
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: c.bg2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: c.isFlat ? c.line2 : c.line,
            width: c.isFlat ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List<Widget>.generate(5, (int idx) {
                final bool active = idx < activePillars;
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? c.accent : c.bg3,
                    border: c.isFlat
                        ? Border.all(color: c.line2, width: 1.0)
                        : null,
                  ),
                );
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hiddenCount > 0
                    ? context.l10n.todayOcultaS((rhythmMessage).toString(), (hiddenCount).toString()): rhythmMessage,
                softWrap: true,
                style: TextStyle(
                  fontFamily: ScFonts.ui,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.text2,
                ),
              ),
            ),
            if (hiddenCount > 0)
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onCustomizeTap,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    context.l10n.todayMostrar,
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: c.accent,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
