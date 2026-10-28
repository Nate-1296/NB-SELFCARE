import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_tokens.dart';
import '../../../../../shared/utils/number_formats.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/metric_value.dart';
import '../../../../../shared/widgets/quick_action_button.dart';
import '../../../domain/hoy_widget_config.dart';
import 'bento_metric_card.dart';

/// Peso del último pesaje con su tendencia; en la versión ancha, la curva de
/// tendencia de los últimos pesajes.
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
    final AppLocalizations l10n = context.l10n;
    final String locale = l10n.localeName;
    final BodyMeasurement? m = latestMeasurement;
    final double metricSize = size.isHalfWidth ? 28 : 32;

    final String fatLine;
    if (m?.validatedBodyFatPercentage != null) {
      fatLine = l10n.todayGrasaNavy(
        NumberFormats.oneDecimal(m!.validatedBodyFatPercentage!, locale),
      );
    } else if (m?.bodyFatPercentage != null) {
      fatLine = l10n.todayGrasaBia(NumberFormats.oneDecimal(m!.bodyFatPercentage!, locale));
    } else {
      fatLine = l10n.todayMetaKg(NumberFormats.oneDecimal(targetWeightKg, locale));
    }

    final bool showSpark = !size.isHalfWidth && recentMeasurements.length >= 2;

    return BentoMetricCard(
      icon: AppIcons.cuerpo,
      label: l10n.todayPesoYEma,
      tone: c.accent,
      metric: m != null
          ? AnimatedMetricValue(
              value: m.weightKg,
              format: (double v) => NumberFormats.oneDecimal(v, locale),
              unit: l10n.unitKg,
              size: metricSize,
            )
          : Text(l10n.todaySinPesaje, style: context.type.metricS.copyWith(color: c.text2)),
      caption: m != null
          ? l10n.todayTendenciaEmaKg(NumberFormats.oneDecimal(m.trendWeightKg, locale))
          : l10n.todayConectaTuMiScale2,
      secondaryCaption: m != null && m.isWaterRetentionSpike
          ? l10n.todayRetencionHidricaTemporalDetectada
          : fatLine,
      side: showSpark
          ? SizedBox(
              width: 128,
              height: 60,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _MiniWeightSparklinePainter(
                    values: recentMeasurements.map((BodyMeasurement e) => e.trendWeightKg).toList(),
                    color: c.isFlat ? c.text : c.accent,
                    isFlat: c.isFlat,
                  ),
                ),
              ),
            )
          : null,
      actions: <Widget>[
        QuickActionButton(
          label: l10n.todayPesarme,
          icon: AppIcons.bascula,
          tone: c.accent,
          onPressed: () => context.go('/cuerpo'),
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

    Offset point(int i) {
      final double x = (i / (values.length - 1)) * (size.width - 6);
      final double normY = (values[i] - minV) / span;
      return Offset(x, size.height - 6 - (normY * (size.height - 12)));
    }

    final Path line = Path();
    for (int i = 0; i < values.length; i++) {
      final Offset p = point(i);
      if (i == 0) {
        line.moveTo(p.dx, p.dy);
      } else {
        line.lineTo(p.dx, p.dy);
      }
    }

    if (!isFlat) {
      final Path area = Path.from(line)
        ..lineTo(point(values.length - 1).dx, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
          ).createShader(Offset.zero & size),
      );
    }

    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = isFlat ? 2 : 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final Offset last = point(values.length - 1);
    canvas.drawCircle(last, 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _MiniWeightSparklinePainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.color != color ||
        oldDelegate.isFlat != isFlat;
  }
}
