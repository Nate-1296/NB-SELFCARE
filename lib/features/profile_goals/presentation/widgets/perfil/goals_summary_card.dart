import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_theme.dart';
import '../../../../../shared/utils/daily_targets_calculator.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/health_card.dart';
import 'profile_science.dart';

/// Tarjeta de Resumen Ejecutivo con gráfico circular centrado y tarjetas de métricas.
class GoalsSummaryCard extends StatelessWidget {
  const GoalsSummaryCard({super.key, 
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

    return HealthCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Cabecera espaciosa y limpia con acceso a ciencia pedagógica
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.l10n.perfilMetasYGastoCalorico,
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 17.5,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      profile.isManualMacroMode == true
                          ? context.l10n.perfilModoManualPrescripcionMedica: context.l10n.perfilCalibracionAdaptativaEnVentanaDe,
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 12,
                        color: c.text2,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: c.accent,
                ),
                tooltip: context.l10n.perfilCienciaDelCalculoCalorico,
                onPressed: () => showTdeeScience(context),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // Gráfico circular centrado y en grande
          Center(
            child: SizedBox(
              width: 148,
              height: 148,
              child: CustomPaint(
                painter: _NutritionalPieChartPainter(
                  proteinPct: pPct,
                  carbsPct: cPct,
                  fatPct: fPct,
                  proteinColor: c.protein,
                  carbsColor: c.carbs,
                  fatColor: c.fat,
                  backgroundColor: c.bg3,
                  isFlat: c.isFlat,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '${targets.effectiveCalorieTargetKcal}',
                        style: TextStyle(
                          fontFamily: ScFonts.display,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: c.text,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        context.l10n.perfilKcalDia,
                        style: TextStyle(
                          fontFamily: ScFonts.ui,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: c.text3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Leyenda horizontal espaciosa con gramos y porcentajes
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 6,
              children: <Widget>[
                _LegendDot(
                  color: c.protein,
                  label:
                      context.l10n.perfilProteinaG(targets.proteinTargetG.toStringAsFixed(0).toString(), pPct.toStringAsFixed(0).toString()),
                ),
                _LegendDot(
                  color: c.carbs,
                  label:
                      context.l10n.perfilCarbosG(targets.carbsTargetG.toStringAsFixed(0).toString(), cPct.toStringAsFixed(0).toString()),
                ),
                _LegendDot(
                  color: c.fat,
                  label:
                      context.l10n.perfilGrasasG(targets.fatTargetG.toStringAsFixed(0).toString(), fPct.toStringAsFixed(0).toString()),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Cuadrícula 2x2 de tarjetas para los datos pequeños con ciencia pedagógica al toque
          Row(
            children: <Widget>[
              Expanded(
                child: _ExecutiveStatCard(
                  icon: AppIcons.fuego,
                  iconColor: c.calories,
                  label: context.l10n.perfilTdeeAdaptativo,
                  value: context.l10n.perfilKcal(profile.currentAdaptiveTdeeKcal.toString()),
                  subtext: latestCalibration != null
                      ? context.l10n.perfilCalibrado(latestCalibration!.dateKey.toString()): context.l10n.perfilEstimacionInicial,
                  onTap: () => showTdeeScience(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ExecutiveStatCard(
                  icon: AppIcons.cuerpo,
                  iconColor: c.accent,
                  label: context.l10n.perfilMetaDePeso,
                  value: context.l10n.perfilKg(profile.targetWeightKg.toStringAsFixed(1).toString()),
                  subtext: context.l10n.perfilObjetivoCorporal,
                  onTap: () => showWeightTrendScience(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _ExecutiveStatCard(
                  icon: AppIcons.gota,
                  iconColor: c.water,
                  label: context.l10n.perfilMetaHidratacion,
                  value: context.l10n.perfilMl(profile.dailyWaterGoalMl.toString()),
                  subtext:
                      context.l10n.perfilVasosRecomendados((profile.dailyWaterGoalMl / 250).round().toString()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ExecutiveStatCard(
                  icon: AppIcons.pasos,
                  iconColor: c.steps,
                  label: context.l10n.perfilPasosYSueno,
                  value: context.l10n.perfilPasos(profile.dailyStepsGoal.toString()),
                  subtext:
                      context.l10n.perfilHDescansoMeta(profile.dailySleepGoalHours.toStringAsFixed(1).toString()),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Botón 1: Ajustar Metas (arriba de auto-calibrar, expandido y destacado)
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.tonalIcon(
              onPressed: onEditGoals,
              icon: Icon(AppIcons.edit, size: 16, color: c.accent),
              label: Text(
                context.l10n.perfilAjustarMetasNutricionalesYCaloricas,
                style: const TextStyle(
                  fontFamily: ScFonts.ui,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: c.isFlat ? c.line2 : Colors.transparent,
                    width: c.isFlat ? 1.5 : 0.0,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Botón 2: Auto-Calibrar TDEE (abajo, expandido con estilo outline)
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: isCalibratingTdee ? null : onCalibrateTdee,
              icon: Icon(
                isCalibratingTdee
                    ? Icons.hourglass_top_rounded
                    : Icons.auto_awesome_rounded,
                size: 16,
                color: c.accent,
              ),
              label: Text(
                isCalibratingTdee
                    ? context.l10n.perfilEvaluandoUltimos14Dias: context.l10n.perfilCalibrarTdeeAdaptativo14Dias,
                style: const TextStyle(
                  fontFamily: ScFonts.ui,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: c.isFlat ? c.line2 : c.line,
                  width: c.isFlat ? 1.5 : 1.0,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
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
    final Widget cardBody = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: c.bg3,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: c.isFlat ? c.line2 : c.line,
          width: c.isFlat ? 1.4 : 1.0,
        ),
      ),
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
                  style: TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: c.text2,
                  ),
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.help_outline_rounded,
                  size: 13,
                  color: c.text3,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: ScFonts.display,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: c.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 10,
              color: c.text3,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: cardBody,
        ),
      );
    }

    return cardBody;
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontFamily: ScFonts.ui,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: c.text2,
          ),
        ),
      ],
    );
  }
}

/// CustomPainter para el gráfico de pastel/anillo de composición nutricional
/// garantizando definición nítida en modo dual (OLED y Papel E-Ink).
class _NutritionalPieChartPainter extends CustomPainter {
  _NutritionalPieChartPainter({
    required this.proteinPct,
    required this.carbsPct,
    required this.fatPct,
    required this.proteinColor,
    required this.carbsColor,
    required this.fatColor,
    required this.backgroundColor,
    required this.isFlat,
  });

  final double proteinPct;
  final double carbsPct;
  final double fatPct;
  final Color proteinColor;
  final Color carbsColor;
  final Color fatColor;
  final Color backgroundColor;
  final bool isFlat;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double strokeWidth = isFlat ? 18.0 : 16.0;
    final double radius = (size.width - strokeWidth) / 2;

    final Paint bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, bgPaint);

    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    int activeSegments = 0;
    if (proteinPct > 0) activeSegments++;
    if (carbsPct > 0) activeSegments++;
    if (fatPct > 0) activeSegments++;

    // Separación angular limpia entre rebanadas (indispensable para NXTPAPER / E-Ink y estética de calidad)
    final double gapAngle = activeSegments > 1 ? (isFlat ? 0.08 : 0.05) : 0.0;
    double currentAngle = -math.pi / 2;

    void drawSegment(double pct, Color color) {
      if (pct <= 0) return;
      final double totalSweep = (pct / 100.0) * 2 * math.pi;
      final double sweepAngle = math.max(0.01, totalSweep - gapAngle);
      final double startWithGap = currentAngle + (gapAngle / 2);

      final Paint paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = isFlat ? StrokeCap.butt : StrokeCap.round;

      canvas.drawArc(rect, startWithGap, sweepAngle, false, paint);

      // Si estamos en modo plano / papel E-Ink, dibujamos además divisores nítidos
      if (isFlat && activeSegments > 1) {
        final Paint dividerPaint = Paint()
          ..color = backgroundColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;

        final double x1 = center.dx +
            (radius - strokeWidth / 2 - 1) * math.cos(currentAngle);
        final double y1 = center.dy +
            (radius - strokeWidth / 2 - 1) * math.sin(currentAngle);
        final double x2 = center.dx +
            (radius + strokeWidth / 2 + 1) * math.cos(currentAngle);
        final double y2 = center.dy +
            (radius + strokeWidth / 2 + 1) * math.sin(currentAngle);
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), dividerPaint);
      }

      currentAngle += totalSweep;
    }

    drawSegment(proteinPct, proteinColor);
    drawSegment(carbsPct, carbsColor);
    drawSegment(fatPct, fatColor);

    // Si es modo plano / papel, dibujar bordes exterior e interior sutiles para definición nítida E-Ink
    if (isFlat) {
      final Paint rimPaint = Paint()
        ..color = backgroundColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(center, radius - strokeWidth / 2, rimPaint);
      canvas.drawCircle(center, radius + strokeWidth / 2, rimPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NutritionalPieChartPainter oldDelegate) {
    return oldDelegate.proteinPct != proteinPct ||
        oldDelegate.carbsPct != carbsPct ||
        oldDelegate.fatPct != fatPct ||
        oldDelegate.proteinColor != proteinColor ||
        oldDelegate.carbsColor != carbsColor ||
        oldDelegate.fatColor != fatColor ||
        oldDelegate.isFlat != isFlat;
  }
}
