import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/database/app_database.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/chip_pill.dart';
import '../../../../shared/widgets/health_card.dart';

enum ChartMetric {
  weight,
  bodyFat,
  muscleMass,
  water,
  visceralFat,
  bodyScore,
  validatedFat,
}

enum ChartPeriod {
  sevenDays,
  thirtyDays,
  ninetyDays,
  allTime,
}

class WeightTrendChartCard extends StatefulWidget {
  const WeightTrendChartCard({
    super.key,
    required this.measurements,
    required this.targetWeightKg,
    this.onDeleteMeasurement,
  });

  final List<BodyMeasurement> measurements;
  final double targetWeightKg;
  final Future<void> Function(BodyMeasurement measurement)? onDeleteMeasurement;

  @override
  State<WeightTrendChartCard> createState() => _WeightTrendChartCardState();
}

class _WeightTrendChartCardState extends State<WeightTrendChartCard> {
  ChartMetric _selectedMetric = ChartMetric.weight;
  ChartPeriod _selectedPeriod = ChartPeriod.thirtyDays;
  bool _showHistoryList = false;
  int? _inspectedIndex;

  List<BodyMeasurement> get _filteredMeasurements {
    if (widget.measurements.isEmpty) return [];

    final now = DateTime.now();
    final int days;
    switch (_selectedPeriod) {
      case ChartPeriod.sevenDays:
        days = 7;
      case ChartPeriod.thirtyDays:
        days = 30;
      case ChartPeriod.ninetyDays:
        days = 90;
      case ChartPeriod.allTime:
        return widget.measurements;
    }

    final cutoff = now.subtract(Duration(days: days));
    final filtered = widget.measurements
        .where((m) => m.measuredAt.isAfter(cutoff))
        .toList();
    if (filtered.isNotEmpty) return filtered;

    // Respaldo: tomar las últimas N mediciones (más recientes) en orden cronológico
    final int start = math.max(0, widget.measurements.length - days);
    return widget.measurements.sublist(start);
  }

  String _metricName(ChartMetric metric) {
    switch (metric) {
      case ChartMetric.weight:
        return 'Peso & Tendencia';
      case ChartMetric.bodyFat:
        return '% Grasa';
      case ChartMetric.muscleMass:
        return 'Masa Muscular';
      case ChartMetric.water:
        return 'Agua Corporal';
      case ChartMetric.visceralFat:
        return 'Grasa Visceral';
      case ChartMetric.bodyScore:
        return 'Puntaje Corporal';
      case ChartMetric.validatedFat:
        return 'Grasa Validada';
    }
  }

  String _metricUnit(ChartMetric metric) {
    switch (metric) {
      case ChartMetric.weight:
      case ChartMetric.muscleMass:
        return 'kg';
      case ChartMetric.bodyFat:
      case ChartMetric.water:
      case ChartMetric.validatedFat:
        return '%';
      case ChartMetric.visceralFat:
        return 'Nivel';
      case ChartMetric.bodyScore:
        return '/100';
    }
  }

  double? _getValue(BodyMeasurement m, ChartMetric metric) {
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

  void _handleChartTouch(
    Offset localPosition,
    double totalWidth,
    int pointCount,
  ) {
    if (pointCount < 2) return;
    const double leftMargin = 38.0;
    const double rightMargin = 12.0;
    final double chartWidth = totalWidth - leftMargin - rightMargin;
    if (chartWidth <= 0) return;

    final double relX =
        ((localPosition.dx - leftMargin) / chartWidth).clamp(0.0, 1.0);
    final int nearestIdx =
        (relX * (pointCount - 1)).round().clamp(0, pointCount - 1);

    if (_inspectedIndex != nearestIdx) {
      unawaited(HapticFeedback.selectionClick());
      setState(() => _inspectedIndex = nearestIdx);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final data = _filteredMeasurements;
    final List<BodyMeasurement> validSeries = data
        .where((m) => _getValue(m, _selectedMetric) != null)
        .toList();

    final List<double> values = validSeries
        .map((m) => _getValue(m, _selectedMetric)!)
        .toList();

    final double? latestVal = values.isNotEmpty ? values.last : null;
    final double? firstVal = values.isNotEmpty ? values.first : null;
    final double? delta =
        (latestVal != null && firstVal != null) ? (latestVal - firstVal) : null;
    final double minVal = values.isNotEmpty ? values.reduce(math.min) : 0.0;
    final double maxVal = values.isNotEmpty ? values.reduce(math.max) : 0.0;
    final double avgVal = values.isNotEmpty
        ? values.fold(0.0, (acc, val) => acc + val) / values.length
        : 0.0;

    final int? safeInspectedIdx = (_inspectedIndex != null &&
            _inspectedIndex! >= 0 &&
            _inspectedIndex! < validSeries.length)
        ? _inspectedIndex
        : null;
    final BodyMeasurement? inspectedItem =
        safeInspectedIdx != null ? validSeries[safeInspectedIdx] : null;

    final List<BodyMeasurement> newestFirstHistory =
        widget.measurements.reversed.take(20).toList();

    return HealthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Evolución Temporal',
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                      softWrap: true,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _showHistoryList
                          ? 'Historial de pesajes ordenado del más reciente'
                          : 'Toca o desliza sobre la curva para inspeccionar',
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 12,
                        color: c.text3,
                      ),
                      softWrap: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(
                    color: c.isFlat ? c.line2 : c.line,
                    width: c.isFlat ? 1.5 : 1.0,
                  ),
                ),
                icon: Icon(
                  _showHistoryList
                      ? Icons.show_chart_rounded
                      : Icons.list_alt_rounded,
                  size: 16,
                  color: c.accent,
                ),
                label: Text(
                  _showHistoryList ? 'Gráfica' : 'Historial',
                  style: TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                onPressed: () =>
                    setState(() => _showHistoryList = !_showHistoryList),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Selector horizontal de Métricas
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ChartMetric.values.map((metric) {
                final bool isSelected = metric == _selectedMetric;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChipPill(
                    label: _metricName(metric),
                    active: isSelected,
                    activeColor: c.accent,
                    onTap: () => setState(() {
                      _selectedMetric = metric;
                      _inspectedIndex = null;
                    }),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          // Selector de Período y Leyenda informativa
          Row(
            children: [
              if (_selectedMetric == ChartMetric.weight && !_showHistoryList)
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _LegendDot(label: 'Peso', color: c.accent),
                      _LegendDot(label: 'EMA', color: c.protein),
                      _LegendDot(label: 'Meta', color: c.success),
                    ],
                  ),
                )
              else
                const Spacer(),
              _PeriodButton(
                label: '7D',
                isSelected: _selectedPeriod == ChartPeriod.sevenDays,
                onTap: () => setState(() {
                  _selectedPeriod = ChartPeriod.sevenDays;
                  _inspectedIndex = null;
                }),
              ),
              _PeriodButton(
                label: '30D',
                isSelected: _selectedPeriod == ChartPeriod.thirtyDays,
                onTap: () => setState(() {
                  _selectedPeriod = ChartPeriod.thirtyDays;
                  _inspectedIndex = null;
                }),
              ),
              _PeriodButton(
                label: '90D',
                isSelected: _selectedPeriod == ChartPeriod.ninetyDays,
                onTap: () => setState(() {
                  _selectedPeriod = ChartPeriod.ninetyDays;
                  _inspectedIndex = null;
                }),
              ),
              _PeriodButton(
                label: 'Todo',
                isSelected: _selectedPeriod == ChartPeriod.allTime,
                onTap: () => setState(() {
                  _selectedPeriod = ChartPeriod.allTime;
                  _inspectedIndex = null;
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_showHistoryList) ...[
            if (newestFirstHistory.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No hay pesajes registrados todavía.',
                    style: TextStyle(color: c.text3),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: newestFirstHistory.length,
                separatorBuilder: (_, _) => Divider(height: 1, color: c.line),
                itemBuilder: (context, idx) {
                  final m = newestFirstHistory[idx];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${m.weightKg.toStringAsFixed(1)} kg',
                          style: TextStyle(
                            fontFamily: ScFonts.display,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: c.text,
                          ),
                        ),
                        Text(
                          m.dateKey,
                          style: TextStyle(
                            fontFamily: ScFonts.ui,
                            fontSize: 12,
                            color: c.text3,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Wrap(
                      spacing: 8,
                      children: [
                        Text(
                          'EMA: ${m.trendWeightKg.toStringAsFixed(1)} kg',
                          style: TextStyle(fontSize: 12, color: c.text2),
                        ),
                        if (m.bodyFatPercentage != null)
                          Text(
                            'Grasa: ${m.bodyFatPercentage!.toStringAsFixed(1)}%',
                            style: TextStyle(fontSize: 12, color: c.accent),
                          ),
                        if (m.impedanceOhms != null)
                          Text(
                            '${m.impedanceOhms}Ω',
                            style: TextStyle(fontSize: 11, color: c.text3),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: c.bg3,
                            borderRadius: BorderRadius.circular(8),
                            border: c.isFlat
                                ? Border.all(color: c.line2, width: 1.0)
                                : null,
                          ),
                          child: Text(
                            m.source == 'mi_scale_2_ble'
                                ? 'BLE'
                                : (m.source == 'manual_navy_tape'
                                    ? 'Navy'
                                    : 'Manual'),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: c.text2,
                            ),
                          ),
                        ),
                        if (widget.onDeleteMeasurement != null)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Eliminar registro',
                            icon: Icon(
                              AppIcons.delete,
                              size: 16,
                              color: c.text3,
                            ),
                            onPressed: () =>
                                widget.onDeleteMeasurement!(m),
                          ),
                      ],
                    ),
                  );
                },
              ),
          ] else ...[
            if (inspectedItem != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: c.bg3,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: c.isFlat ? c.line2 : c.line,
                    width: c.isFlat ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${inspectedItem.dateKey} · '
                        '${_getValue(inspectedItem, _selectedMetric)!.toStringAsFixed(_selectedMetric == ChartMetric.visceralFat || _selectedMetric == ChartMetric.bodyScore ? 0 : 1)} ${_metricUnit(_selectedMetric)}'
                        '${_selectedMetric == ChartMetric.weight ? " (EMA ${inspectedItem.trendWeightKg.toStringAsFixed(1)} kg)" : ""}',
                        style: TextStyle(
                          fontFamily: ScFonts.display,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: c.text,
                        ),
                        softWrap: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _inspectedIndex = null),
                      child: Icon(AppIcons.close, size: 16, color: c.text3),
                    ),
                  ],
                ),
              ),
            ],

            if (values.length < 2)
              Container(
                height: 180,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.bg3,
                  borderRadius: BorderRadius.circular(16),
                  border: c.isFlat
                      ? Border.all(color: c.line2, width: 1.2)
                      : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(AppIcons.insights, size: 36, color: c.text3),
                      const SizedBox(height: 8),
                      Text(
                        values.isEmpty
                            ? 'Sin datos suficientes para graficar ${_metricName(_selectedMetric).toLowerCase()}.'
                            : 'Último valor: ${values.last.toStringAsFixed(1)} ${_metricUnit(_selectedMetric)}. Registra un segundo pesaje para trazar la tendencia.',
                        style: TextStyle(
                          fontFamily: ScFonts.ui,
                          fontSize: 12.5,
                          color: c.text2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) => _handleChartTouch(
                      details.localPosition,
                      constraints.maxWidth,
                      validSeries.length,
                    ),
                    onHorizontalDragUpdate: (details) => _handleChartTouch(
                      details.localPosition,
                      constraints.maxWidth,
                      validSeries.length,
                    ),
                    child: SizedBox(
                      height: 180,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _TrendChartPainter(
                          measurements: validSeries,
                          metric: _selectedMetric,
                          targetValue: _selectedMetric == ChartMetric.weight
                              ? widget.targetWeightKg
                              : null,
                          inspectedIndex: safeInspectedIdx,
                          isFlat: c.isFlat,
                          lineColor: c.accent,
                          trendColor: c.protein,
                          targetColor: c.success,
                          textColor: c.text3,
                          gridColor: c.line,
                        ),
                      ),
                    ),
                  );
                },
              ),

            const SizedBox(height: 16),

            // Resumen de Métricas del Período en Cuadrícula 2x2 para evitar truncamiento
            Row(
              children: [
                Expanded(
                  child: _StatBox(
                    label: 'Cambio',
                    value: delta != null
                        ? '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} ${_metricUnit(_selectedMetric)}'
                        : '--',
                    color: delta == null
                        ? c.text
                        : (_selectedMetric == ChartMetric.weight ||
                                _selectedMetric == ChartMetric.bodyFat ||
                                _selectedMetric == ChartMetric.visceralFat
                            ? (delta <= 0 ? c.success : c.warning)
                            : (delta >= 0 ? c.success : c.warning)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatBox(
                    label: 'Promedio',
                    value: values.isNotEmpty
                        ? '${avgVal.toStringAsFixed(1)} ${_metricUnit(_selectedMetric)}'
                        : '--',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _StatBox(
                    label: 'Mínimo',
                    value: values.isNotEmpty
                        ? '${minVal.toStringAsFixed(1)} ${_metricUnit(_selectedMetric)}'
                        : '--',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatBox(
                    label: 'Máximo',
                    value: values.isNotEmpty
                        ? '${maxVal.toStringAsFixed(1)} ${_metricUnit(_selectedMetric)}'
                        : '--',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: ScFonts.ui,
            fontSize: 10.5,
            color: c.text3,
          ),
        ),
      ],
    );
  }
}

class _PeriodButton extends StatelessWidget {
  const _PeriodButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
          color: isSelected ? c.accent : c.bg3,
          borderRadius: BorderRadius.circular(10),
          border: isSelected && c.isFlat
              ? Border.all(color: c.text, width: 1.5)
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: ScFonts.ui,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? c.ink : c.text2,
          ),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: c.bg3,
        borderRadius: BorderRadius.circular(12),
        border: c.isFlat ? Border.all(color: c.line2, width: 1.2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: c.text3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontFamily: ScFonts.display,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: color ?? c.text,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  _TrendChartPainter({
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
  });

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
        text: val.toStringAsFixed(metric == ChartMetric.visceralFat || metric == ChartMetric.bodyScore ? 0 : 1),
        style: TextStyle(fontSize: 10, color: textColor),
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
        text: 'Meta',
        style: TextStyle(
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
        final double x = leftMargin + (chartWidth * i / (count - 1));
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

    if (!isFlat) {
      final fillPath = Path()
        ..moveTo(validPoints.first.dx, size.height - bottomMargin);
      for (final pt in validPoints) {
        fillPath.lineTo(pt.dx, pt.dy);
      }
      fillPath.lineTo(validPoints.last.dx, size.height - bottomMargin);
      fillPath.close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withValues(alpha: 0.25),
            lineColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

      canvas.drawPath(fillPath, fillPaint);
    }

    if (metric == ChartMetric.weight && trendPoints.length >= 2) {
      final trendPath = Path()
        ..moveTo(trendPoints.first.dx, trendPoints.first.dy);
      for (int i = 1; i < trendPoints.length; i++) {
        trendPath.lineTo(trendPoints[i].dx, trendPoints[i].dy);
      }
      final trendPaint = Paint()
        ..color = isFlat ? textColor : trendColor.withValues(alpha: 0.85)
        ..strokeWidth = isFlat ? 1.5 : 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawPath(trendPath, trendPaint);
    }

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

    final dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    for (final pt in validPoints) {
      canvas.drawCircle(pt, isFlat ? 3.0 : 3.8, dotPaint);
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
        text: measurements.first.dateKey.substring(5),
        style: TextStyle(fontSize: 10, color: textColor),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(leftMargin, size.height - bottomMargin + 6),
      );

      textPainter.text = TextSpan(
        text: measurements.last.dateKey.substring(5),
        style: TextStyle(fontSize: 10, color: textColor),
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
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.measurements != measurements ||
        oldDelegate.metric != metric ||
        oldDelegate.targetValue != targetValue ||
        oldDelegate.inspectedIndex != inspectedIndex ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.trendColor != trendColor ||
        oldDelegate.isFlat != isFlat;
  }
}
