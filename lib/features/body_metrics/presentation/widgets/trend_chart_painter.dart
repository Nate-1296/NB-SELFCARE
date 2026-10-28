import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/database/app_database.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/utils/number_formats.dart';
import 'weight_trend_chart_card.dart';

class TrendChartPainter extends CustomPainter {
  TrendChartPainter({
    required this.measurements,
    required this.metric,
    this.targetValue,
    this.inspectedIndex,
    required this.isFlat,
    required this.lineColor,
    required this.trendColor,
    required this.targetColor,
    required this.textColor,
    required this.gridColor,
    required this.goalLabel,
    required this.localeName,
  });

  final String goalLabel;
  final String localeName;
  final List<BodyMeasurement> measurements;
  final ChartMetric metric;
  final double? targetValue;
  final int? inspectedIndex;
  final bool isFlat;
  final Color lineColor;
  final Color trendColor;
  final Color targetColor;
  final Color textColor;
  final Color gridColor;

  double? _extractVal(BodyMeasurement m) {
    switch (metric) {
      case ChartMetric.weight:
        return m.weightKg;
      case ChartMetric.bodyFat:
        return m.bodyFatPercentage;
      case ChartMetric.muscleMass:
        return m.muscleMassKg;
      case ChartMetric.water:
        return m.waterPercentage;
      case ChartMetric.visceralFat:
        return m.visceralFatIndex?.toDouble();
      case ChartMetric.bodyScore:
        return m.bodyScore?.toDouble();
      case ChartMetric.validatedFat:
        return m.validatedBodyFatPercentage;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final validPoints = <Offset>[];
    final trendPoints = <Offset>[];

    final values = measurements.map(_extractVal).whereType<double>().toList();
    if (values.length < 2) return;

    double minV = values.reduce(math.min);
    double maxV = values.reduce(math.max);

    if (targetValue != null) {
      minV = math.min(minV, targetValue!);
      maxV = math.max(maxV, targetValue!);
    }
    if (metric == ChartMetric.weight) {
      for (final m in measurements) {
        minV = math.min(minV, m.trendWeightKg);
        maxV = math.max(maxV, m.trendWeightKg);
      }
    }

    final double padding = (maxV - minV) * 0.15;
    minV -= (padding > 0.5 ? padding : 1.0);
    maxV += (padding > 0.5 ? padding : 1.0);
    final double range = (maxV - minV) > 0 ? (maxV - minV) : 1.0;

    const double leftMargin = 38.0;
    const double bottomMargin = 22.0;
    const double topMargin = 12.0;
    const double rightMargin = 12.0;

    final double chartWidth = size.width - leftMargin - rightMargin;
    final double chartHeight = size.height - bottomMargin - topMargin;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i <= 3; i++) {
      final double ratio = i / 3.0;
      final double y = topMargin + chartHeight * (1.0 - ratio);
      final double val = minV + range * ratio;

      canvas.drawLine(
        Offset(leftMargin, y),
        Offset(size.width - rightMargin, y),
        gridPaint,
      );

      textPainter.text = TextSpan(
        text: NumberFormats.fixed(val, metric == ChartMetric.visceralFat || metric == ChartMetric.bodyScore ? 0 : 1),
        style: TextStyle(fontFamily: ScFonts.ui, fontSize: 10, color: textColor),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(leftMargin - textPainter.width - 6, y - textPainter.height / 2),
      );
    }

    if (targetValue != null && targetValue! >= minV && targetValue! <= maxV) {
      final double targetY =
          topMargin + chartHeight * (1.0 - (targetValue! - minV) / range);
      final targetPaint = Paint()
        ..color = targetColor
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      double curX = leftMargin;
      while (curX < size.width - rightMargin) {
        canvas.drawLine(
          Offset(curX, targetY),
          Offset(math.min(curX + 6, size.width - rightMargin), targetY),
          targetPaint,
        );
        curX += 10;
      }

      textPainter.text = TextSpan(
        text: goalLabel,
        style: TextStyle(
          fontFamily: ScFonts.ui,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: targetColor,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(size.width - rightMargin - 30, targetY - 14),
      );
    }

    final int count = measurements.length;
    for (int i = 0; i < count; i++) {
      final m = measurements[i];
      final double? v = _extractVal(m);
      if (v != null) {
        final double x = leftMargin + chartWidth * timeFraction(measurements, i);
        final double y = topMargin + chartHeight * (1.0 - (v - minV) / range);
        validPoints.add(Offset(x, y));

        if (metric == ChartMetric.weight) {
          final double trendY =
              topMargin + chartHeight * (1.0 - (m.trendWeightKg - minV) / range);
          trendPoints.add(Offset(x, trendY));
        }
      }
    }

    if (validPoints.length < 2) return;

    final bool hasTrend = metric == ChartMetric.weight && trendPoints.length >= 2;
    final List<Offset> filled = hasTrend ? trendPoints : validPoints;
    final Color fillColor = hasTrend ? trendColor : lineColor;
    if (!isFlat) {
      final fillPath = Path()
        ..moveTo(filled.first.dx, size.height - bottomMargin);
      for (final pt in filled) {
        fillPath.lineTo(pt.dx, pt.dy);
      }
      fillPath.lineTo(filled.last.dx, size.height - bottomMargin);
      fillPath.close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            fillColor.withValues(alpha: 0.22),
            fillColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

      canvas.drawPath(fillPath, fillPaint);
    }

    if (hasTrend) {
      final trendPath = Path()
        ..moveTo(trendPoints.first.dx, trendPoints.first.dy);
      for (int i = 1; i < trendPoints.length; i++) {
        trendPath.lineTo(trendPoints[i].dx, trendPoints[i].dy);
      }
      final trendPaint = Paint()
        ..color = trendColor
        ..strokeWidth = isFlat ? 2.5 : 3.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(trendPath, trendPaint);
    } else {
      // Sin tendencia, la serie se une con una línea; con tendencia los
      // pesajes diarios quedan como puntos para no competir con ella.
      final path = Path()..moveTo(validPoints.first.dx, validPoints.first.dy);
      for (int i = 1; i < validPoints.length; i++) {
        path.lineTo(validPoints[i].dx, validPoints[i].dy);
      }
      final linePaint = Paint()
        ..color = lineColor
        ..strokeWidth = isFlat ? 2.0 : 2.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, linePaint);
    }

    final dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    for (final pt in validPoints) {
      canvas.drawCircle(pt, hasTrend ? 2.6 : (isFlat ? 3.0 : 3.8), dotPaint);
    }

    // Cursor vertical de inspección
    if (inspectedIndex != null &&
        inspectedIndex! >= 0 &&
        inspectedIndex! < validPoints.length) {
      final Offset selPt = validPoints[inspectedIndex!];
      final Paint cursorPaint = Paint()
        ..color = textColor
        ..strokeWidth = 1.2;
      canvas.drawLine(
        Offset(selPt.dx, topMargin),
        Offset(selPt.dx, size.height - bottomMargin),
        cursorPaint,
      );
      canvas.drawCircle(selPt, isFlat ? 5.5 : 6.0, dotPaint);
    }

    if (measurements.isNotEmpty) {
      textPainter.text = TextSpan(
        text: DateFormat.MMMd(localeName).format(measurements.first.measuredAt),
        style: TextStyle(fontFamily: ScFonts.ui, fontSize: 10, color: textColor),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(leftMargin, size.height - bottomMargin + 6),
      );

      textPainter.text = TextSpan(
        text: DateFormat.MMMd(localeName).format(measurements.last.measuredAt),
        style: TextStyle(fontFamily: ScFonts.ui, fontSize: 10, color: textColor),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          size.width - rightMargin - textPainter.width,
          size.height - bottomMargin + 6,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant TrendChartPainter oldDelegate) {
    return oldDelegate.measurements != measurements ||
        oldDelegate.metric != metric ||
        oldDelegate.targetValue != targetValue ||
        oldDelegate.inspectedIndex != inspectedIndex ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.trendColor != trendColor ||
        oldDelegate.isFlat != isFlat;
  }
}

/// Posición horizontal (0–1) de un punto según su fecha, para que los huecos
/// entre pesajes se vean como tiempo real y no como pasos iguales.
double timeFraction(List<BodyMeasurement> series, int index) {
  if (series.length < 2) return 0;
  final int span = series.last.measuredAt.difference(series.first.measuredAt).inMinutes;
  if (span <= 0) return index / (series.length - 1);
  return (series[index].measuredAt.difference(series.first.measuredAt).inMinutes / span).clamp(0.0, 1.0);
}
