import 'package:flutter/material.dart';

import '../../../../../core/domain/activity_energy.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/utils/number_formats.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/metric_value.dart';
import '../../../../../shared/widgets/quick_action_button.dart';
import '../../../domain/hoy_widget_config.dart';
import 'bento_metric_card.dart';

// ============================================================================
// 5. WIDGET PASOS NEAT — 2×2 / 4×2
// ============================================================================
class HoyStepsBentoCard extends StatelessWidget {
  const HoyStepsBentoCard({
    super.key,
    required this.size,
    required this.steps,
    required this.goalSteps,
    required this.onQuickAdd1000,
    required this.onOpenSheet,
  });

  final HoyWidgetSize size;
  final int steps;
  final int goalSteps;
  final VoidCallback onQuickAdd1000;
  final VoidCallback onOpenSheet;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final String locale = l10n.localeName;
    final double ratio = goalSteps > 0 ? (steps / goalSteps).clamp(0.0, 1.0) : 0.0;
    final int activeKcal = ActivityEnergy.kcalFromSteps(steps);

    return BentoMetricCard(
      icon: AppIcons.steps,
      label: l10n.todayPasosNeat,
      tone: c.steps,
      metric: AnimatedMetricValue(
        value: steps.toDouble(),
        format: (double v) => NumberFormats.integer(v, locale),
        size: size.isHalfWidth ? 28 : 32,
      ),
      caption: l10n.todayStepsCaption(
        NumberFormats.integer(goalSteps, locale),
        NumberFormats.group(activeKcal),
      ),
      captionEmphasis: steps >= goalSteps && goalSteps > 0,
      progress: ratio,
      actions: <Widget>[
        QuickActionButton(label: l10n.todayAdd1000Steps, tone: c.steps, onPressed: onQuickAdd1000),
        QuickActionButton(label: l10n.todayAjustar, tone: c.text2, onPressed: onOpenSheet),
      ],
    );
  }
}
