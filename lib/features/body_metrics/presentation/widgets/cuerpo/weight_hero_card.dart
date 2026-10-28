import 'package:flutter/material.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/domain/enums.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_tokens.dart';
import '../../../../../shared/utils/date_formats.dart';
import '../../../../../shared/utils/number_formats.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/health_card.dart';
import '../../../../../shared/widgets/metric_value.dart';
import '../../../../../shared/widgets/tonal_badge.dart';

/// Peso actual, distancia a la meta, peso tendencia y aviso de retención de líquidos.
class WeightHeroCard extends StatelessWidget {
  const WeightHeroCard({super.key, required this.profile, required this.latest});

  final UserProfile profile;
  final BodyMeasurement? latest;

  String _sourceLabel(AppLocalizations l10n, MeasurementSource source) => switch (source) {
    MeasurementSource.miScale2Ble => l10n.cuerpoSourceScale,
    MeasurementSource.healthConnect => l10n.cuerpoSourceHealthConnect,
    MeasurementSource.manual => l10n.cuerpoSourceManual,
    MeasurementSource.navyTape => l10n.cuerpoSourceTape,
  };

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final BodyMeasurement? m = latest;
    final double? toGoal = m == null ? null : m.trendWeightKg - profile.targetWeightKg;

    final String locale = l10n.localeName;
    return HealthCard(
      padding: const EdgeInsets.all(ScSpace.l + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(l10n.cuerpoCurrentWeight.toUpperCase(), style: context.type.overline),
              ),
              if (toGoal != null)
                Flexible(
                  child: TonalBadge(
                    label: toGoal.abs() < 0.1
                        ? l10n.cuerpoGoalReached
                        : l10n.cuerpoToGoal(NumberFormats.oneDecimal(toGoal.abs(), locale)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: ScSpace.s),
          if (m == null)
            MetricValue(value: '--', unit: l10n.unitKg, size: 52, color: c.text3)
          else
            AnimatedMetricValue(
              value: m.weightKg,
              format: (double v) => NumberFormats.oneDecimal(v, locale),
              unit: l10n.unitKg,
              size: 52,
            ),
          const SizedBox(height: ScSpace.xs + 2),
          Text(
            m == null
                ? l10n.cuerpoNoWeighIn
                : l10n.cuerpoWeighInMeta(
                    DateFormats.shortDate(m.measuredAt, locale),
                    _sourceLabel(l10n, m.source),
                  ),
            style: context.type.caption,
          ),
          const SizedBox(height: ScSpace.l + 2),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: _Stat(
                    label: l10n.cuerpoTrend,
                    value: m == null ? '--' : NumberFormats.oneDecimal(m.trendWeightKg, locale),
                  ),
                ),
                VerticalDivider(width: ScSpace.xl, color: c.isFlat ? c.line2 : c.line),
                Expanded(
                  child: _Stat(
                    label: l10n.cuerpoGoal,
                    value: NumberFormats.oneDecimal(profile.targetWeightKg, locale),
                    emphasize: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ScSpace.m),
          Text(l10n.cuerpoTrendExplainer, style: context.type.caption.copyWith(color: c.text3)),
          if (m?.isWaterRetentionSpike ?? false) ...<Widget>[
            const SizedBox(height: ScSpace.m),
            _WaterNotice(explanation: m?.spikeExplanation),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.emphasize = false});

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label.toUpperCase(), style: context.type.overline),
        const SizedBox(height: ScSpace.xs),
        MetricValue(
          value: value,
          unit: context.l10n.unitKg,
          size: 22,
          color: emphasize && !c.isFlat ? c.accent : null,
        ),
      ],
    );
  }
}

class _WaterNotice extends StatelessWidget {
  const _WaterNotice({required this.explanation});

  final String? explanation;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Container(
      padding: const EdgeInsets.all(ScSpace.m),
      decoration: BoxDecoration(
        color: c.isFlat ? c.bg2 : c.water.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ScRadius.tileOf(c)),
        border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(AppIcons.gota, size: 20, color: c.isFlat ? c.text : c.water),
          const SizedBox(width: ScSpace.s + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(context.l10n.cuerpoWaterTitle, style: context.text.titleSmall),
                const SizedBox(height: ScSpace.xxs),
                Text(
                  explanation ?? context.l10n.cuerpoWaterFallback,
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
