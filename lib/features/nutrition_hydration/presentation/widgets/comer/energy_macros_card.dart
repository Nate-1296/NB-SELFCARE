import 'package:flutter/material.dart';

import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_tokens.dart';
import '../../../../../shared/utils/number_formats.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/health_card.dart';
import '../../../../../shared/widgets/metric_value.dart';
import '../../../../../shared/widgets/progress_bar.dart';
import '../../../../../shared/widgets/progress_ring.dart';
import '../../../../../shared/widgets/quick_action_button.dart';
import '../../../../../shared/widgets/tonal_badge.dart';

/// Tarjeta Hero de Energía y Macronutrientes con anillo calórico y carbohidratos netos.
class EnergyAndMacrosCard extends StatelessWidget {
  const EnergyAndMacrosCard({
    super.key,
    required this.totalKcal,
    required this.targetKcal,
    required this.netWorkoutKcal,
    required this.totalP,
    required this.targetP,
    required this.totalC,
    required this.targetC,
    required this.netCarbs,
    required this.totalFiber,
    required this.totalF,
    required this.targetF,
    this.onOpenOracle,
  });

  final double totalKcal;
  final int targetKcal;
  final int netWorkoutKcal;
  final double totalP;
  final double targetP;
  final double totalC;
  final double targetC;
  final double netCarbs;
  final double totalFiber;
  final double totalF;
  final double targetF;
  final VoidCallback? onOpenOracle;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final String locale = l10n.localeName;
    final int consumedInt = totalKcal.round();
    final int remaining = targetKcal - consumedInt;
    final double kcalRatio = targetKcal > 0 ? (totalKcal / targetKcal).clamp(0.0, 1.0) : 0.0;

    return HealthCard(
      padding: const EdgeInsets.all(ScSpace.l + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.comerBalanceEnergetico.toUpperCase(), style: context.type.overline),
          const SizedBox(height: ScSpace.m),
          Row(
            children: <Widget>[
              ScProgressRing(
                value: kcalRatio,
                size: 124,
                stroke: 11,
                color: c.calories,
                semanticsLabel: l10n.comerBalanceEnergetico,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      AnimatedMetricValue(
                        value: consumedInt.toDouble(),
                        format: (double v) => NumberFormats.integer(v, locale),
                        size: 28,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.comerOfGoalKcal(NumberFormats.integer(targetKcal, locale)),
                        style: context.type.caption,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: ScSpace.l + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      (remaining >= 0 ? l10n.comerAvailableLabel : l10n.comerOverLabel)
                          .toUpperCase(),
                      style: context.type.overline,
                    ),
                    const SizedBox(height: ScSpace.xs),
                    AnimatedMetricValue(
                      value: remaining.abs().toDouble(),
                      format: (double v) => NumberFormats.integer(v, locale),
                      unit: l10n.unitKcal,
                      size: 26,
                      color: remaining >= 0 ? null : (c.isFlat ? c.text : c.warning),
                    ),
                    if (netWorkoutKcal > 0) ...<Widget>[
                      const SizedBox(height: ScSpace.s),
                      TonalBadge(
                        label: l10n.comerKcalEntreno(NumberFormats.group(netWorkoutKcal)),
                        tone: c.steps,
                        icon: AppIcons.bolt,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: ScSpace.l + 2),
          _MacroWideRow(
            label: l10n.todayProteina,
            currentG: totalP,
            targetG: targetP,
            badgeText: totalP >= targetP
                ? l10n.comerMetaCubierta
                : l10n.comerFaltanG(NumberFormats.group(targetP - totalP)),
            barColor: c.protein,
          ),
          const SizedBox(height: ScSpace.m + 2),
          _MacroWideRow(
            label: l10n.todayCarbohidratos,
            currentG: totalC,
            targetG: targetC,
            badgeText: l10n.comerNetosGFibraG(
              NumberFormats.group(netCarbs),
              NumberFormats.group(totalFiber),
            ),
            barColor: c.carbs,
          ),
          const SizedBox(height: ScSpace.m + 2),
          _MacroWideRow(
            label: l10n.todayGrasasSaludables,
            currentG: totalF,
            targetG: targetF,
            badgeText: totalF >= targetF
                ? l10n.comerMetaCubierta
                : l10n.comerFaltanG(NumberFormats.group(targetF - totalF)),
            barColor: c.fat,
          ),
          if (onOpenOracle != null) ...<Widget>[
            const SizedBox(height: ScSpace.l),
            QuickActionButton(
              label: l10n.comerQueComerParaCerrarMis,
              icon: Icons.auto_awesome_rounded,
              tone: c.accent,
              onPressed: onOpenOracle,
            ),
          ],
        ],
      ),
    );
  }
}

class _MacroWideRow extends StatelessWidget {
  const _MacroWideRow({
    required this.label,
    required this.currentG,
    required this.targetG,
    required this.badgeText,
    required this.barColor,
  });

  final String label;
  final double currentG;
  final double targetG;
  final String badgeText;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final double ratio = targetG > 0 ? (currentG / targetG).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(child: Text(label, style: context.type.label)),
            Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: NumberFormats.group(currentG),
                    style: context.type.metricS.copyWith(fontSize: 16),
                  ),
                  TextSpan(
                    text: ' / ${targetG.round()} g',
                    style: context.type.caption.copyWith(color: c.text3),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: ScSpace.s - 2),
        ScProgressBar(value: ratio, color: barColor, height: 7),
        const SizedBox(height: ScSpace.xs + 1),
        Text(badgeText, style: context.type.caption.copyWith(fontSize: 12, color: c.text3)),
      ],
    );
  }
}
