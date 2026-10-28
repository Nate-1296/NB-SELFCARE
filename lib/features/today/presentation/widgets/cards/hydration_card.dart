import 'package:flutter/material.dart';

import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/utils/number_formats.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/metric_value.dart';
import '../../../../../shared/widgets/quick_action_button.dart';
import '../../../domain/hoy_widget_config.dart';
import 'bento_metric_card.dart';

// ============================================================================
// 3. WIDGET HIDRATACIÓN INTELIGENTE — 2×2 / 4×2
// ============================================================================
class HoyHydrationBentoCard extends StatelessWidget {
  const HoyHydrationBentoCard({
    super.key,
    required this.size,
    required this.totalWaterMl,
    required this.goalMl,
    required this.glassesCount,
    required this.canUndo,
    required this.onAdd250,
    required this.onAdd500,
    required this.onUndoLast,
  });

  final HoyWidgetSize size;
  final int totalWaterMl;
  final int goalMl;
  final int glassesCount;
  final bool canUndo;
  final VoidCallback onAdd250;
  final VoidCallback onAdd500;
  final VoidCallback onUndoLast;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final double ratio = goalMl > 0 ? (totalWaterMl / goalMl).clamp(0.0, 1.0) : 0.0;
    final String locale = l10n.localeName;

    return BentoMetricCard(
      icon: AppIcons.water,
      label: l10n.todayHidratacion,
      tone: c.water,
      labelTrailing: canUndo
          ? IconButton(
              onPressed: onUndoLast,
              tooltip: l10n.todayUndoLastGlass,
              icon: Icon(AppIcons.undo, size: 18, color: c.text2),
            )
          : null,
      metric: AnimatedMetricValue(
        value: totalWaterMl.toDouble(),
        format: (double v) => NumberFormats.integer(v, locale),
        unit: l10n.unitMl,
        size: size.isHalfWidth ? 28 : 32,
      ),
      caption: l10n.todayWaterCaption(
        NumberFormats.group(ratio * 100),
        NumberFormats.integer(goalMl, locale),
      ),
      secondaryCaption: size.isHalfWidth ? null : l10n.todayWaterGlasses(NumberFormats.group(glassesCount)),
      progress: ratio,
      actions: <Widget>[
        QuickActionButton(label: l10n.today250Ml, tone: c.water, onPressed: onAdd250),
        QuickActionButton(label: l10n.today500Ml, tone: c.water, onPressed: onAdd500),
      ],
    );
  }
}
