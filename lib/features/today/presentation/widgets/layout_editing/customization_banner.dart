import 'package:flutter/material.dart';

import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_theme.dart';
import '../../../../../shared/widgets/app_icons.dart';

class CustomizationBanner extends StatelessWidget {
  const CustomizationBanner({super.key, required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Padding(
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.isFlat ? c.bg2 : c.soft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: c.isFlat ? c.line2 : c.accent.withValues(alpha: 0.45),
            width: 1.5,
          ),
        ),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: c.accent,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    context.l10n.todayPersonalizaHoyAlternaTamano22,
                    softWrap: true,
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                ),
              ],
            ),
            OutlinedButton.icon(
              onPressed: onReset,
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              icon: const Icon(AppIcons.refresh, size: 15),
              label: Text(context.l10n.todayRestaurarOrden),
            ),
          ],
        ),
      ),
    );
  }
}
