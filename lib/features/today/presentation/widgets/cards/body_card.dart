import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_theme.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/health_card.dart';
import '../../../domain/hoy_widget_config.dart';

// ============================================================================
// 4. WIDGET PESO Y COMPOSICIÓN EMA — 2×2 / 4×2 (CON MINI CURVA EN 4×2)
// ============================================================================
class HoyBodyBentoCard extends StatelessWidget {
  const HoyBodyBentoCard({
    super.key,
    required this.size,
    required this.latestMeasurement,
    required this.recentMeasurements,
    required this.targetWeightKg,
  });

  final HoyWidgetSize size;
  final BodyMeasurement? latestMeasurement;
  final List<BodyMeasurement> recentMeasurements;
  final double targetWeightKg;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final bool compact = size.isHalfWidth;
    final BodyMeasurement? m = latestMeasurement;

    final String fatLine;
    if (m?.validatedBodyFatPercentage != null) {
      fatLine =
          context.l10n.todayGrasaNavy(m!.validatedBodyFatPercentage!.toStringAsFixed(1).toString());
    } else if (m?.bodyFatPercentage != null) {
      fatLine = context.l10n.todayGrasaBia(m!.bodyFatPercentage!.toStringAsFixed(1).toString());
    } else {
      fatLine = context.l10n.todayMetaKg(targetWeightKg.toStringAsFixed(1).toString());
    }

    return HealthCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(AppIcons.cuerpo, size: 19, color: c.accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      context.l10n.todayPesoYEma,
                      softWrap: true,
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (!compact && recentMeasurements.length >= 2)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                      child: _buildWeightTexts(context, c, m, fatLine),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 120,
                      height: 54,
                      child: CustomPaint(
                        painter: _MiniWeightSparklinePainter(
                          values: recentMeasurements
                              .map((e) => e.trendWeightKg)
                              .toList(),
                          color: c.accent,
                          isFlat: c.isFlat,
                        ),
                      ),
                    ),
                  ],
                )
              else
                _buildWeightTexts(context, c, m, fatLine),
              if (m != null && m.isWaterRetentionSpike) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  context.l10n.todayRetencionHidricaTemporalDetectada,
                  softWrap: true,
                  style: TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: c.water,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => context.go('/cuerpo'),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(vertical: 9),
              ),
              icon: const Icon(AppIcons.bascula, size: 16),
              label: Text(
                context.l10n.todayPesarme,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightTexts(BuildContext context, ScColors c, BodyMeasurement? m, String fatLine) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          m != null ? context.l10n.todayKg2(m.weightKg.toStringAsFixed(1).toString()): context.l10n.todaySinPesaje,
          softWrap: true,
          style: TextStyle(
            fontFamily: ScFonts.display,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: c.text,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          m != null
              ? context.l10n.todayTendenciaEmaKg(m.trendWeightKg.toStringAsFixed(1).toString()): context.l10n.todayConectaTuMiScale2,
          softWrap: true,
          style: TextStyle(
            fontFamily: ScFonts.ui,
            fontSize: 11.5,
            color: c.text2,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          fatLine,
          softWrap: true,
          style: TextStyle(
            fontFamily: ScFonts.ui,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: c.accent,
          ),
        ),
      ],
    );
  }
}

class _MiniWeightSparklinePainter extends CustomPainter {
  const _MiniWeightSparklinePainter({
    required this.values,
    required this.color,
    required this.isFlat,
  });

  final List<double> values;
  final Color color;
  final bool isFlat;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final double minV = values.reduce(math.min);
    final double maxV = values.reduce(math.max);
    final double span = (maxV - minV).abs() < 0.2 ? 1.0 : (maxV - minV);

    final Path path = Path();
    for (int i = 0; i < values.length; i++) {
      final double x = (i / (values.length - 1)) * size.width;
      final double normY = (values[i] - minV) / span;
      final double y = size.height - 6 - (normY * (size.height - 12));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final Paint linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = isFlat ? 2.2 : 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _MiniWeightSparklinePainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.color != color ||
        oldDelegate.isFlat != isFlat;
  }
}
