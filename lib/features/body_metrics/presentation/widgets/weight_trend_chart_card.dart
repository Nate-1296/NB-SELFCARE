import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/theme/sc_tokens.dart';
import '../../../../shared/utils/date_formats.dart';
import '../../../../shared/utils/number_formats.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/card_header.dart';
import '../../../../shared/widgets/health_card.dart';
import 'trend_chart_painter.dart';
import 'trend_chart_parts.dart';

enum ChartMetric { weight, bodyFat, muscleMass, water, visceralFat, bodyScore, validatedFat }

enum ChartPeriod { sevenDays, thirtyDays, ninetyDays, allTime }

class WeightTrendChartCard extends StatefulWidget {
  const WeightTrendChartCard({
    super.key,
    required this.measurements,
    required this.targetWeightKg,
    required this.now,
    this.onDeleteMeasurement,
  });

  final List<BodyMeasurement> measurements;
  final DateTime now;
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

    final DateTime now = widget.now;
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
    final filtered = widget.measurements.where((m) => m.measuredAt.isAfter(cutoff)).toList();
    if (filtered.isNotEmpty) return filtered;

    // Respaldo: tomar las últimas N mediciones (más recientes) en orden cronológico
    final int start = math.max(0, widget.measurements.length - days);
    return widget.measurements.sublist(start);
  }

  String _periodName(ChartPeriod period) => switch (period) {
    ChartPeriod.sevenDays => context.l10n.bodyPeriodDays('7'),
    ChartPeriod.thirtyDays => context.l10n.bodyPeriodDays('30'),
    ChartPeriod.ninetyDays => context.l10n.bodyPeriodDays('90'),
    ChartPeriod.allTime => context.l10n.bodyTodo,
  };

  String _metricName(ChartMetric metric) {
    switch (metric) {
      case ChartMetric.weight:
        return context.l10n.bodyPesoTendencia;
      case ChartMetric.bodyFat:
        return context.l10n.bodyGrasa2;
      case ChartMetric.muscleMass:
        return context.l10n.bodyMasaMuscular;
      case ChartMetric.water:
        return context.l10n.bodyAguaCorporal;
      case ChartMetric.visceralFat:
        return context.l10n.bodyGrasaVisceral;
      case ChartMetric.bodyScore:
        return context.l10n.bodyPuntajeCorporal;
      case ChartMetric.validatedFat:
        return context.l10n.bodyGrasaValidada;
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
        return context.l10n.bodyNivel;
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

  String _formatValue(BodyMeasurement m) => NumberFormat.decimalPatternDigits(
    locale: context.l10n.localeName,
    decimalDigits:
        _selectedMetric == ChartMetric.visceralFat || _selectedMetric == ChartMetric.bodyScore
        ? 0
        : 1,
  ).format(_getValue(m, _selectedMetric));

  void _handleChartTouch(Offset localPosition, double totalWidth, List<BodyMeasurement> series) {
    if (series.length < 2) return;
    const double leftMargin = 38.0;
    const double rightMargin = 12.0;
    final double chartWidth = totalWidth - leftMargin - rightMargin;
    if (chartWidth <= 0) return;

    final double relX = ((localPosition.dx - leftMargin) / chartWidth).clamp(0.0, 1.0);
    int nearestIdx = 0;
    double best = double.infinity;
    for (int i = 0; i < series.length; i++) {
      final double d = (timeFraction(series, i) - relX).abs();
      if (d < best) {
        best = d;
        nearestIdx = i;
      }
    }

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

    final List<double> values = validSeries.map((m) => _getValue(m, _selectedMetric)!).toList();

    final double? latestVal = values.isNotEmpty ? values.last : null;
    final double? firstVal = values.isNotEmpty ? values.first : null;
    final double? delta = (latestVal != null && firstVal != null) ? (latestVal - firstVal) : null;
    final double minVal = values.isNotEmpty ? values.reduce(math.min) : 0.0;
    final double maxVal = values.isNotEmpty ? values.reduce(math.max) : 0.0;
    final double avgVal = values.isNotEmpty
        ? values.fold(0.0, (acc, val) => acc + val) / values.length
        : 0.0;

    final int? safeInspectedIdx =
        (_inspectedIndex != null && _inspectedIndex! >= 0 && _inspectedIndex! < validSeries.length)
        ? _inspectedIndex
        : null;
    final BodyMeasurement? inspectedItem = safeInspectedIdx != null
        ? validSeries[safeInspectedIdx]
        : null;

    final List<BodyMeasurement> newestFirstHistory = widget.measurements.reversed.take(20).toList();

    return HealthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardHeader(
            icon: Icons.show_chart_rounded,
            title: context.l10n.bodyEvolucionTemporal,
            subtitle: _showHistoryList
                ? context.l10n.bodyHistorialDePesajesOrdenadoDel
                : context.l10n.bodyTocaODeslizaSobreLa,
            trailing: TextButton.icon(
              onPressed: () => setState(() => _showHistoryList = !_showHistoryList),
              icon: Icon(
                _showHistoryList ? Icons.show_chart_rounded : Icons.list_alt_rounded,
                size: 18,
              ),
              label: Text(_showHistoryList ? context.l10n.bodyGrafica : context.l10n.bodyHistorial),
            ),
          ),
          const SizedBox(height: 12),

          // Medida y período en dos desplegables (como "Fase actual" en Ajustar
          // metas): ocho chips y cuatro botones recargaban la tarjeta.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<ChartMetric>(
                  isExpanded: true,
                  initialValue: _selectedMetric,
                  decoration: InputDecoration(
                    labelText: context.l10n.bodyChartMetricLabel,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  items: <DropdownMenuItem<ChartMetric>>[
                    for (final ChartMetric metric in ChartMetric.values)
                      DropdownMenuItem<ChartMetric>(
                        value: metric,
                        child: Text(_metricName(metric), overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (ChartMetric? metric) {
                    if (metric == null) return;
                    setState(() {
                      _selectedMetric = metric;
                      _inspectedIndex = null;
                    });
                  },
                ),
              ),
              const SizedBox(width: ScSpace.s),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<ChartPeriod>(
                  isExpanded: true,
                  initialValue: _selectedPeriod,
                  decoration: InputDecoration(
                    labelText: context.l10n.bodyChartPeriodLabel,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  items: <DropdownMenuItem<ChartPeriod>>[
                    for (final ChartPeriod period in ChartPeriod.values)
                      DropdownMenuItem<ChartPeriod>(
                        value: period,
                        child: Text(_periodName(period), overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (ChartPeriod? period) {
                    if (period == null) return;
                    setState(() {
                      _selectedPeriod = period;
                      _inspectedIndex = null;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Selector de Período y Leyenda informativa
          if (_selectedMetric == ChartMetric.weight && !_showHistoryList) ...[
            Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ChartLegendDot(label: context.l10n.chartWeighIns, color: c.text3),
                ChartLegendDot(label: context.l10n.chartTrend, color: c.accent),
                ChartLegendDot(label: context.l10n.chartGoal, color: c.text2),
              ],
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),

          if (_showHistoryList) ...[
            if (newestFirstHistory.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    context.l10n.bodyNoHayPesajesRegistradosTodavia,
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
                        Flexible(
                          child: Text(
                            context.l10n.todayKg2(
                              NumberFormats.oneDecimal(m.weightKg, context.l10n.localeName),
                            ),
                            style: TextStyle(
                              fontFamily: ScFonts.display,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: c.text,
                            ),
                          ),
                        ),
                        Text(
                          m.dateKey,
                          style: TextStyle(fontFamily: ScFonts.ui, fontSize: 12, color: c.text3),
                        ),
                      ],
                    ),
                    subtitle: Wrap(
                      spacing: 8,
                      children: [
                        Text(
                          context.l10n.bodyEmaKg(
                            NumberFormats.oneDecimal(m.trendWeightKg, context.l10n.localeName),
                          ),
                          style: TextStyle(fontSize: 12, color: c.text2),
                        ),
                        if (m.bodyFatPercentage != null)
                          Text(
                            context.l10n.bodyGrasa(
                              NumberFormats.oneDecimal(
                                m.bodyFatPercentage!,
                                context.l10n.localeName,
                              ),
                            ),
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: c.bg3,
                            borderRadius: BorderRadius.circular(8),
                            border: c.isFlat ? Border.all(color: c.line2, width: 1.0) : null,
                          ),
                          child: Text(
                            m.source == MeasurementSource.miScale2Ble
                                ? 'BLE'
                                : (m.source == MeasurementSource.navyTape
                                      ? context.l10n.bodyNavy
                                      : context.l10n.cuerpoManualWeighIn),
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
                            tooltip: context.l10n.comerEliminarRegistro,
                            icon: Icon(AppIcons.delete, size: 16, color: c.text3),
                            onPressed: () => widget.onDeleteMeasurement!(m),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: c.isFlat ? c.bg2 : c.bg3,
                  borderRadius: BorderRadius.circular(ScRadius.controlOf(c)),
                  border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedMetric == ChartMetric.weight
                            ? context.l10n.bodyChartInspectTrend(
                                DateFormats.shortDate(
                                  inspectedItem.measuredAt,
                                  context.l10n.localeName,
                                ),
                                _formatValue(inspectedItem),
                                _metricUnit(_selectedMetric),
                                NumberFormats.oneDecimal(
                                  inspectedItem.trendWeightKg,
                                  context.l10n.localeName,
                                ),
                              )
                            : context.l10n.bodyChartInspect(
                                DateFormats.shortDate(
                                  inspectedItem.measuredAt,
                                  context.l10n.localeName,
                                ),
                                _formatValue(inspectedItem),
                                _metricUnit(_selectedMetric),
                              ),
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
                  color: c.isFlat ? c.bg2 : c.bg3,
                  borderRadius: BorderRadius.circular(ScRadius.tileOf(c)),
                  border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
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
                            ? context.l10n.bodySinDatosSuficientesParaGraficar(
                                _metricName(_selectedMetric).toLowerCase().toString(),
                              )
                            : context.l10n.bodyUltimoValorRegistraUnSegundo(
                                NumberFormats.oneDecimal(values.last, context.l10n.localeName),
                                _metricUnit(_selectedMetric).toString(),
                              ),
                        style: TextStyle(fontFamily: ScFonts.ui, fontSize: 12.5, color: c.text2),
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
                    onTapDown: (details) =>
                        _handleChartTouch(details.localPosition, constraints.maxWidth, validSeries),
                    onHorizontalDragUpdate: (details) =>
                        _handleChartTouch(details.localPosition, constraints.maxWidth, validSeries),
                    child: SizedBox(
                      height: 180,
                      width: double.infinity,
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: TrendChartPainter(
                            measurements: validSeries,
                            metric: _selectedMetric,
                            targetValue: _selectedMetric == ChartMetric.weight
                                ? widget.targetWeightKg
                                : null,
                            inspectedIndex: safeInspectedIdx,
                            isFlat: c.isFlat,
                            lineColor: _selectedMetric == ChartMetric.weight ? c.text3 : c.accent,
                            trendColor: c.accent,
                            targetColor: c.text2,
                            textColor: c.text3,
                            gridColor: c.line,
                            goalLabel: context.l10n.chartGoal,
                            localeName: context.l10n.localeName,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

            const SizedBox(height: 16),

            // Resumen del período: cuatro columnas de cifras, sin cajas.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ChartStatBox(
                    label: context.l10n.bodyCambio,
                    value: delta != null
                        ? '${delta >= 0 ? '+' : ''}${NumberFormats.oneDecimal(delta, context.l10n.localeName)} ${_metricUnit(_selectedMetric)}'
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
                Expanded(
                  child: ChartStatBox(
                    label: context.l10n.bodyPromedio,
                    value: values.isNotEmpty
                        ? context.l10n.bodyTexto(
                            NumberFormats.oneDecimal(avgVal, context.l10n.localeName).toString(),
                            _metricUnit(_selectedMetric).toString(),
                          )
                        : '--',
                  ),
                ),
                Expanded(
                  child: ChartStatBox(
                    label: context.l10n.bodyMinimo,
                    value: values.isNotEmpty
                        ? context.l10n.bodyTexto2(
                            NumberFormats.oneDecimal(minVal, context.l10n.localeName).toString(),
                            _metricUnit(_selectedMetric).toString(),
                          )
                        : '--',
                  ),
                ),
                Expanded(
                  child: ChartStatBox(
                    label: context.l10n.bodyMaximo,
                    value: values.isNotEmpty
                        ? context.l10n.bodyTexto3(
                            NumberFormats.oneDecimal(maxVal, context.l10n.localeName).toString(),
                            _metricUnit(_selectedMetric).toString(),
                          )
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
