import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_theme.dart';
import '../../../../../shared/utils/daily_targets_calculator.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/health_card.dart';
import '../../../domain/hoy_widget_config.dart';

// ============================================================================
// 2. WIDGET OBJETIVOS DEL DÍA (CALORÍAS + MACROS + ACCIONES DE COMIDA) — 4×2 / 2×2
// ============================================================================
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
    final bool compact = size.isHalfWidth;

    final int effectiveGoalKcal = targets.effectiveCalorieTargetKcal;
    final int remainingKcal = effectiveGoalKcal - consumedKcal.round();
    final double kcalRatio = effectiveGoalKcal > 0
        ? (consumedKcal / effectiveGoalKcal).clamp(0.0, 1.0)
        : 0.0;
    final double proteinRatio = targets.proteinTargetG > 0
        ? (consumedProtein / targets.proteinTargetG).clamp(0.0, 1.0)
        : 0.0;
    final double carbsRatio = targets.carbsTargetG > 0
        ? (consumedCarbs / targets.carbsTargetG).clamp(0.0, 1.0)
        : 0.0;
    final double fatRatio = targets.fatTargetG > 0
        ? (consumedFat / targets.fatTargetG).clamp(0.0, 1.0)
        : 0.0;

    return HealthCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 4,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(AppIcons.calories, size: 19, color: c.calories),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          context.l10n.todayObjetivosDelDia,
                          softWrap: true,
                          style: TextStyle(
                            fontFamily: ScFonts.display,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: c.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    targets.netWorkoutKcal > 0
                        ? context.l10n.todayMetaKcalEntreno((effectiveGoalKcal).toString(), targets.netWorkoutKcal.toString()): context.l10n.todayMetaKcal((effectiveGoalKcal).toString()),
                    softWrap: true,
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: c.text2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (compact) ...<Widget>[
                Text(
                  context.l10n.todayKcal(remainingKcal.abs().toString()),
                  softWrap: true,
                  style: TextStyle(
                    fontFamily: ScFonts.display,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: c.text,
                  ),
                ),
                Text(
                  remainingKcal >= 0
                      ? context.l10n.todayDisponiblesConsumidas(consumedKcal.round().toString()): context.l10n.todayPorEncimaConsumidas(consumedKcal.round().toString()),
                  softWrap: true,
                  style: TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: 11.5,
                    color: c.text2,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: kcalRatio,
                  minHeight: 7,
                  backgroundColor: c.bg3,
                  valueColor: AlwaysStoppedAnimation<Color>(c.calories),
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 10),
                _MacroLinearRow(
                  label: context.l10n.todayProteina,
                  currentG: consumedProtein,
                  targetG: targets.proteinTargetG,
                  ratio: proteinRatio,
                  color: c.protein,
                ),
                const SizedBox(height: 6),
                _MacroLinearRow(
                  label: context.l10n.todayCarbos,
                  currentG: consumedCarbs,
                  targetG: targets.carbsTargetG,
                  ratio: carbsRatio,
                  color: c.carbs,
                ),
                const SizedBox(height: 6),
                _MacroLinearRow(
                  label: context.l10n.todayGrasas,
                  currentG: consumedFat,
                  targetG: targets.fatTargetG,
                  ratio: fatRatio,
                  color: c.fat,
                ),
              ] else ...<Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    SizedBox(
                      width: 88,
                      height: 88,
                      child: Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          SizedBox(
                            width: 88,
                            height: 88,
                            child: CircularProgressIndicator(
                              value: kcalRatio,
                              strokeWidth: 9,
                              strokeCap:
                                  c.isFlat ? StrokeCap.butt : StrokeCap.round,
                              backgroundColor: c.bg3,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(c.calories),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  '${remainingKcal.abs()}',
                                  style: TextStyle(
                                    fontFamily: ScFonts.display,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: c.text,
                                  ),
                                ),
                                Text(
                                  remainingKcal >= 0 ? 'restan' : 'extra',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: c.text2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _MacroLinearRow(
                            label: context.l10n.todayProteina,
                            currentG: consumedProtein,
                            targetG: targets.proteinTargetG,
                            ratio: proteinRatio,
                            color: c.protein,
                          ),
                          const SizedBox(height: 8),
                          _MacroLinearRow(
                            label: context.l10n.todayCarbohidratos,
                            currentG: consumedCarbs,
                            targetG: targets.carbsTargetG,
                            ratio: carbsRatio,
                            color: c.carbs,
                          ),
                          const SizedBox(height: 8),
                          _MacroLinearRow(
                            label: context.l10n.todayGrasasSaludables,
                            currentG: consumedFat,
                            targetG: targets.fatTargetG,
                            ratio: fatRatio,
                            color: c.fat,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          if (compact) ...<Widget>[
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => context.go('/comer'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                icon: const Icon(AppIcons.comer, size: 16),
                label: Text(context.l10n.todayRegistrarComida),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onRepeatYesterday,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                icon: const Icon(AppIcons.repeat, size: 15),
                label: Text(context.l10n.todayRepetirAyer),
              ),
            ),
          ] else
            Row(
              children: <Widget>[
                Expanded(
                  flex: 3,
                  child: FilledButton.tonalIcon(
                    onPressed: () => context.go('/comer'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    icon: const Icon(AppIcons.comer, size: 16),
                    label: Text(context.l10n.todayRegistrarComida),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: onRepeatYesterday,
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    icon: const Icon(AppIcons.repeat, size: 15),
                    label: Text(context.l10n.todayRepetirAyer),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MacroLinearRow extends StatelessWidget {
  const _MacroLinearRow({
    required this.label,
    required this.currentG,
    required this.targetG,
    required this.ratio,
    required this.color,
  });

  final String label;
  final double currentG;
  final double targetG;
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Flexible(
              child: Text(
                label,
                softWrap: true,
                style: TextStyle(
                  fontFamily: ScFonts.ui,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              context.l10n.todayG(currentG.toInt().toString(), targetG.toInt().toString()),
              style: TextStyle(
                fontFamily: ScFonts.display,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        LinearProgressIndicator(
          value: ratio,
          minHeight: 5,
          backgroundColor: c.bg3,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }
}
