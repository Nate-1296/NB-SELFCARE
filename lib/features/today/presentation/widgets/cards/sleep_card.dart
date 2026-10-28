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
// 6. WIDGET SUEÑO Y DESCANSO REPARADOR — 2×2 / 4×2
// ============================================================================
class HoySleepBentoCard extends StatelessWidget {
  const HoySleepBentoCard({
    super.key,
    required this.size,
    required this.sleepHours,
    required this.goalHours,
    required this.hasSleepBonus,
    required this.onOpenSheet,
  });

  final HoyWidgetSize size;
  final double sleepHours;
  final double goalHours;
  final bool hasSleepBonus;
  final VoidCallback onOpenSheet;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final String locale = l10n.localeName;
    final double ratio = goalHours > 0 ? (sleepHours / goalHours).clamp(0.0, 1.0) : 0.0;

    return BentoMetricCard(
      icon: AppIcons.sueno,
      label: l10n.todaySueno,
      tone: c.fasting,
      metric: sleepHours > 0
          ? AnimatedMetricValue(
              value: sleepHours,
              format: (double v) => NumberFormats.oneDecimal(v, locale),
              unit: l10n.unitHours,
              size: size.isHalfWidth ? 28 : 32,
            )
          : MetricValue(
              value: '--',
              unit: l10n.unitHours,
              size: size.isHalfWidth ? 28 : 32,
              color: c.text3,
            ),
      caption: hasSleepBonus
          ? l10n.todaySuenoReparadorBonoX15
          : l10n.todaySleepGoalCaption(NumberFormats.oneDecimal(goalHours, locale)),
      captionEmphasis: hasSleepBonus,
      progress: ratio,
      actions: <Widget>[
        QuickActionButton(
          label: sleepHours > 0 ? l10n.commonEdit : l10n.todayRegistrarSueno,
          icon: AppIcons.sueno,
          tone: c.fasting,
          onPressed: onOpenSheet,
        ),
      ],
    );
  }
}
