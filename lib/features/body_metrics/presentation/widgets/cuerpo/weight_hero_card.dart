import 'package:flutter/material.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/domain/enums.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_theme.dart';
import '../../../../../shared/theme/sc_tokens.dart';
import '../../../../../shared/utils/date_formats.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/health_card.dart';
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

    return HealthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.cuerpoCurrentWeight, style: context.text.titleSmall?.copyWith(color: c.text3)),
          Text(
            m == null
                ? l10n.cuerpoNoWeighIn
                : l10n.cuerpoWeighInMeta(
                    DateFormats.shortDate(m.measuredAt, l10n.localeName),
                    _sourceLabel(l10n, m.source),
                  ),
            style: context.text.bodySmall,
          ),
          const SizedBox(height: ScSpace.s),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: ScSpace.m,
            runSpacing: ScSpace.s,
            children: <Widget>[
              Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    TextSpan(
                      text: m?.weightKg.toStringAsFixed(1) ?? '--',
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                      ),
                    ),
                    TextSpan(
                      text: ' kg',
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: c.text2,
                      ),
                    ),
                  ],
                ),
              ),
              if (toGoal != null)
                TonalBadge(
                  label: toGoal.abs() < 0.1
                      ? l10n.cuerpoGoalReached
                      : l10n.cuerpoToGoal(toGoal.abs().toStringAsFixed(1)),
                ),
            ],
          ),
          const SizedBox(height: ScSpace.m),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: _Stat(
                    label: l10n.cuerpoTrend,
                    value: m == null ? '-- kg' : '${m.trendWeightKg.toStringAsFixed(1)} kg',
                  ),
                ),
                const SizedBox(width: ScSpace.s),
                Expanded(
                  child: _Stat(
                    label: l10n.cuerpoGoal,
                    value: '${profile.targetWeightKg.toStringAsFixed(1)} kg',
                    emphasize: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ScSpace.s),
          Text(l10n.cuerpoTrendExplainer, style: context.text.bodySmall),
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
    return Container(
      padding: const EdgeInsets.all(ScSpace.s + 2),
      decoration: BoxDecoration(
        color: c.bg3,
        borderRadius: BorderRadius.circular(ScRadius.control),
        border: Border.all(color: c.isFlat ? c.line2 : c.line, width: c.isFlat ? 1.5 : 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: TextStyle(fontFamily: ScFonts.ui, fontSize: 11.5, color: c.text3)),
          const SizedBox(height: ScSpace.xxs),
          Text(
            value,
            style: TextStyle(
              fontFamily: ScFonts.display,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: emphasize && !c.isFlat ? c.accent : c.text,
            ),
          ),
        ],
      ),
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
        color: c.bg3,
        borderRadius: BorderRadius.circular(ScRadius.tile - 2),
        border: Border.all(color: c.isFlat ? c.line2 : c.water, width: c.isFlat ? 1.5 : 1.2),
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
                Text(explanation ?? context.l10n.cuerpoWaterFallback, style: context.text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
