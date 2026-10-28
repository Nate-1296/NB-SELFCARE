import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_tokens.dart';
import '../../../../../shared/utils/daily_targets_calculator.dart';
import '../../../../../shared/utils/number_formats.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/card_header.dart';
import '../../../../../shared/widgets/health_card.dart';
import '../../../../../shared/widgets/metric_value.dart';
import '../../../../../shared/widgets/progress_bar.dart';
import '../../../../../shared/widgets/progress_ring.dart';
import '../../../../../shared/widgets/quick_action_button.dart';
import '../../../domain/hoy_widget_config.dart';

/// Energía del día: kcal que quedan en un anillo, macros en barras y accesos
/// a registrar comida. En 2×2 el anillo cede su sitio a una barra.
class HoyNutritionBentoCard extends StatelessWidget {
  const HoyNutritionBentoCard({
    super.key,
    required this.size,
    required this.consumedKcal,
    required this.consumedProtein,
    required this.consumedCarbs,
    required this.consumedFat,
    required this.targets,
    required this.onRepeatYesterday,
  });

  final HoyWidgetSize size;
  final double consumedKcal;
  final double consumedProtein;
  final double consumedCarbs;
  final double consumedFat;
  final DailyMacroTargets targets;
  final VoidCallback onRepeatYesterday;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final String locale = l10n.localeName;
    final bool compact = size.isHalfWidth;

    final int goal = targets.effectiveCalorieTargetKcal;
    final int remaining = goal - consumedKcal.round();
    final double kcalRatio = goal > 0 ? (consumedKcal / goal).clamp(0.0, 1.0) : 0.0;

    final List<Widget> macros = <Widget>[
      _MacroRow(
        label: l10n.todayProteina,
        current: consumedProtein,
        target: targets.proteinTargetG.toDouble(),
        color: c.protein,
      ),
      _MacroRow(
        label: compact ? l10n.todayCarbos : l10n.todayCarbohidratos,
        current: consumedCarbs,
        target: targets.carbsTargetG.toDouble(),
        color: c.carbs,
      ),
      _MacroRow(
        label: compact ? l10n.todayGrasas : l10n.todayGrasasSaludables,
        current: consumedFat,
        target: targets.fatTargetG.toDouble(),
        color: c.fat,
      ),
    ];

    final Widget remainingMetric = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: compact ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: <Widget>[
        AnimatedMetricValue(
          value: remaining.abs().toDouble(),
          format: (double v) => NumberFormats.integer(v, locale),
          unit: compact ? l10n.unitKcal : null,
          size: compact ? 28 : 26,
        ),
        const SizedBox(height: 2),
        Text(
          remaining >= 0 ? l10n.todayKcalLeft : l10n.todayKcalOver,
          style: context.type.caption.copyWith(
            color: remaining >= 0 ? c.text2 : (c.isFlat ? c.text : c.warning),
          ),
        ),
      ],
    );

    final String goalLine = targets.netWorkoutKcal > 0
        ? l10n.todayMetaKcalEntreno(
            NumberFormats.integer(goal, locale),
            NumberFormats.group(targets.netWorkoutKcal),
          )
        : l10n.todayMetaKcal(NumberFormats.integer(goal, locale));

    return HealthCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(ScSpace.l, ScSpace.l - 2, ScSpace.l, ScSpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                height: 32,
                child: MetricLabel(
                  icon: AppIcons.calories,
                  label: l10n.todayObjetivosDelDia,
                  tone: c.calories,
                  trailing: compact ? null : Text(goalLine, style: context.type.caption),
                ),
              ),
              const SizedBox(height: ScSpace.s),
              if (compact) ...<Widget>[
                remainingMetric,
                const SizedBox(height: ScSpace.m),
                ScProgressBar(value: kcalRatio, color: c.calories, height: 6),
                const SizedBox(height: ScSpace.m),
                for (final Widget m in macros) ...<Widget>[m, const SizedBox(height: ScSpace.s)],
              ] else
                Row(
                  children: <Widget>[
                    ScProgressRing(
                      value: kcalRatio,
                      size: 112,
                      stroke: 10,
                      color: c.calories,
                      semanticsLabel: l10n.todayObjetivosDelDia,
                      child: FittedBox(fit: BoxFit.scaleDown, child: remainingMetric),
                    ),
                    const SizedBox(width: ScSpace.l + 4),
                    Expanded(
                      child: Column(
                        children: <Widget>[
                          for (int i = 0; i < macros.length; i++) ...<Widget>[
                            if (i > 0) const SizedBox(height: ScSpace.m),
                            macros[i],
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: ScSpace.l),
          if (compact)
            Column(
              children: <Widget>[
                QuickActionButton(
                  label: l10n.todayRegistrarComida,
                  icon: AppIcons.comer,
                  tone: c.accent,
                  emphasized: true,
                  onPressed: () => context.go('/comer'),
                ),
                const SizedBox(height: ScSpace.s - 2),
                QuickActionButton(
                  label: l10n.todayRepetirAyer,
                  icon: AppIcons.repeat,
                  tone: c.text2,
                  onPressed: onRepeatYesterday,
                ),
              ],
            )
          else
            Row(
              children: <Widget>[
                Expanded(
                  flex: 3,
                  child: QuickActionButton(
                    label: l10n.todayRegistrarComida,
                    icon: AppIcons.comer,
                    tone: c.accent,
                    emphasized: true,
                    onPressed: () => context.go('/comer'),
                  ),
                ),
                const SizedBox(width: ScSpace.s - 2),
                Expanded(
                  flex: 2,
                  child: QuickActionButton(
                    label: l10n.todayRepetirAyer,
                    icon: AppIcons.repeat,
                    tone: c.text2,
                    onPressed: onRepeatYesterday,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({
    required this.label,
    required this.current,
    required this.target,
    required this.color,
  });

  final String label;
  final double current;
  final double target;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final double ratio = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.type.caption.copyWith(color: c.text, fontWeight: FontWeight.w600),
              ),
            ),
            // Con texto grande la cifra se encoge antes que desbordar la fila.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: '${current.round()}',
                        style: context.type.metricS.copyWith(fontSize: 13.5),
                      ),
                      TextSpan(
                        text: ' / ${target.round()} g',
                        style: context.type.caption.copyWith(color: c.text3, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ScProgressBar(value: ratio, color: color, height: 5),
      ],
    );
  }
}
