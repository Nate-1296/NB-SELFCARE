import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_tokens.dart';
import '../../../../../shared/utils/daily_targets_calculator.dart';
import '../../../../../shared/utils/number_formats.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/card_header.dart';
import '../../../../../shared/widgets/health_card.dart';
import '../../../../../shared/widgets/progress_ring.dart';
import '../../../../../shared/widgets/quick_action_button.dart';
import 'profile_science.dart';

/// Tarjeta de Resumen Ejecutivo con gráfico circular centrado y tarjetas de métricas.
class GoalsSummaryCard extends StatelessWidget {
  const GoalsSummaryCard({
    super.key,
    required this.profile,
    required this.targets,
    required this.latestCalibration,
    required this.isCalibratingTdee,
    required this.onCalibrateTdee,
    required this.onEditGoals,
  });

  final UserProfile profile;
  final DailyMacroTargets targets;
  final TdeeCalibration? latestCalibration;
  final bool isCalibratingTdee;
  final VoidCallback onCalibrateTdee;
  final VoidCallback onEditGoals;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;

    final double pKcal = targets.proteinTargetG * 4.0;
    final double cKcal = targets.carbsTargetG * 4.0;
    final double fKcal = targets.fatTargetG * 9.0;
    final double totalMacroKcal = math.max(1.0, pKcal + cKcal + fKcal);

    final double pPct = (pKcal / totalMacroKcal) * 100;
    final double cPct = (cKcal / totalMacroKcal) * 100;
    final double fPct = (fKcal / totalMacroKcal) * 100;

    final Color rule = c.isFlat ? c.line2 : c.line;
    final double ruleWidth = c.isFlat ? 1.5 : 1;

    return HealthCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(ScSpace.l + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CardHeader(
            icon: Icons.track_changes_rounded,
            title: context.l10n.perfilMetasYGastoCalorico,
            subtitle: profile.isManualMacroMode == true
                ? context.l10n.perfilModoManualPrescripcionMedica
                : context.l10n.perfilCalibracionAdaptativaEnVentanaDe,
            trailing: IconButton(
              icon: Icon(Icons.info_outline_rounded, size: 20, color: c.text2),
              tooltip: context.l10n.perfilCienciaDelCalculoCalorico,
              onPressed: () => showTdeeScience(context),
            ),
          ),
          const SizedBox(height: ScSpace.xl),

          // Reparto de la meta diaria: anillo segmentado con la leyenda al lado.
          Row(
            children: <Widget>[
              ScProgressRing(
                size: 132,
                stroke: 12,
                segments: <RingSegment>[
                  RingSegment(fraction: pPct, color: c.protein),
                  RingSegment(fraction: cPct, color: c.carbs),
                  RingSegment(fraction: fPct, color: c.fat),
                ],
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(NumberFormats.group(targets.effectiveCalorieTargetKcal), style: context.type.metricM),
                      const SizedBox(height: 3),
                      Text(context.l10n.perfilKcalDia, style: context.type.caption),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: ScSpace.l + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _MacroLegend(
                      color: c.protein,
                      label: context.l10n.todayProteina,
                      grams: targets.proteinTargetG,
                      pct: pPct,
                    ),
                    const SizedBox(height: ScSpace.m),
                    _MacroLegend(
                      color: c.carbs,
                      label: context.l10n.todayCarbohidratos,
                      grams: targets.carbsTargetG,
                      pct: cPct,
                    ),
                    const SizedBox(height: ScSpace.m),
                    _MacroLegend(
                      color: c.fat,
                      label: context.l10n.todayGrasas,
                      grams: targets.fatTargetG,
                      pct: fPct,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: ScSpace.xl),

          // Ficha de metas: celdas separadas por filetes.
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ScRadius.tileOf(c)),
              border: Border.all(color: rule, width: ruleWidth),
            ),
            child: Column(
              children: <Widget>[
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(
                        child: _ExecutiveStatCard(
                          icon: AppIcons.fuego,
                          iconColor: c.calories,
                          label: context.l10n.perfilTdeeAdaptativo,
                          value: context.l10n.perfilKcal(
                            NumberFormats.group(profile.currentAdaptiveTdeeKcal),
                          ),
                          subtext: latestCalibration != null
                              ? context.l10n.perfilCalibrado(latestCalibration!.dateKey)
                              : context.l10n.perfilEstimacionInicial,
                          onTap: () => showTdeeScience(context),
                        ),
                      ),
                      VerticalDivider(width: ruleWidth, thickness: ruleWidth, color: rule),
                      Expanded(
                        child: _ExecutiveStatCard(
                          icon: AppIcons.cuerpo,
                          iconColor: c.accent,
                          label: context.l10n.perfilMetaDePeso,
                          value: context.l10n.perfilKg(NumberFormats.fixed(profile.targetWeightKg, 1)),
                          subtext: context.l10n.perfilObjetivoCorporal,
                          onTap: () => showWeightTrendScience(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: ruleWidth, thickness: ruleWidth, color: rule),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(
                        child: _ExecutiveStatCard(
                          icon: AppIcons.gota,
                          iconColor: c.water,
                          label: context.l10n.perfilMetaHidratacion,
                          value: context.l10n.perfilMl(NumberFormats.group(profile.dailyWaterGoalMl)),
                          subtext: context.l10n.perfilVasosRecomendados(
                            NumberFormats.group(profile.dailyWaterGoalMl / 250),
                          ),
                        ),
                      ),
                      VerticalDivider(width: ruleWidth, thickness: ruleWidth, color: rule),
                      Expanded(
                        child: _ExecutiveStatCard(
                          icon: AppIcons.pasos,
                          iconColor: c.steps,
                          label: context.l10n.perfilPasosYSueno,
                          value: context.l10n.perfilPasos(NumberFormats.group(profile.dailyStepsGoal)),
                          subtext: context.l10n.perfilHDescansoMeta(
                            NumberFormats.fixed(profile.dailySleepGoalHours, 1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ScSpace.l + 4),
          FilledButton.icon(
            onPressed: onEditGoals,
            icon: const Icon(AppIcons.edit, size: 18),
            label: Text(context.l10n.perfilAjustarMetasNutricionalesYCaloricas),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          const SizedBox(height: ScSpace.s),
          QuickActionButton(
            label: isCalibratingTdee
                ? context.l10n.perfilEvaluandoUltimos14Dias
                : context.l10n.perfilCalibrarTdeeAdaptativo14Dias,
            icon: isCalibratingTdee ? Icons.hourglass_top_rounded : Icons.auto_awesome_rounded,
            tone: c.text2,
            onPressed: isCalibratingTdee ? null : onCalibrateTdee,
          ),
        ],
      ),
    );
  }
}

/// Fila de leyenda del reparto: punto de color, nombre, gramos y porcentaje.
class _MacroLegend extends StatelessWidget {
  const _MacroLegend({
    required this.color,
    required this.label,
    required this.grams,
    required this.pct,
  });

  final Color color;
  final String label;
  final num grams;
  final double pct;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: ScSpace.s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: context.type.caption.copyWith(color: c.text2)),
              Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    TextSpan(
                      text: '${grams.round()} g',
                      style: context.type.metricS.copyWith(fontSize: 15),
                    ),
                    TextSpan(
                      text: '  ${pct.round()} %',
                      style: context.type.caption.copyWith(color: c.text3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExecutiveStatCard extends StatelessWidget {
  const _ExecutiveStatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.subtext,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String subtext;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final Widget body = Padding(
      padding: const EdgeInsets.fromLTRB(ScSpace.m + 2, ScSpace.m, ScSpace.m, ScSpace.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 15, color: c.isFlat ? c.text : iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.caption.copyWith(fontSize: 12),
                ),
              ),
              if (onTap != null) Icon(Icons.help_outline_rounded, size: 14, color: c.text3),
            ],
          ),
          const SizedBox(height: ScSpace.s - 2),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.type.metricS),
          const SizedBox(height: 2),
          Text(
            subtext,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.type.caption.copyWith(fontSize: 11, color: c.text3),
          ),
        ],
      ),
    );
    if (onTap == null) return body;
    return InkWell(onTap: onTap, child: body);
  }
}
