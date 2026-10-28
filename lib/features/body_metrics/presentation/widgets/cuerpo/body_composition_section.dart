import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_tokens.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/health_card.dart';
import '../metric_detail_sheet.dart';
import 'body_metric_catalog.dart';

/// Las 13 métricas de composición corporal: tipo de cuerpo destacado y
/// cuadrícula 2 × 6. Cada tarjeta abre su explicación.
class BodyCompositionSection extends StatelessWidget {
  const BodyCompositionSection({
    super.key,
    required this.profile,
    required this.latest,
    required this.referenceDate,
    required this.onMeasureTape,
  });

  final UserProfile profile;
  final BodyMeasurement? latest;
  final DateTime referenceDate;
  final VoidCallback onMeasureTape;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final List<BiometricMetricSpec> specs = BiometricMetricCatalog.buildAll(
      l10n,
      profile: profile,
      latest: latest,
      referenceDate: referenceDate,
    );
    final BiometricMetricSpec somatotype = specs.firstWhere(
      (BiometricMetricSpec s) => s.kind == BiometricMetricKind.somatotype,
    );
    final List<BiometricMetricSpec> grid = specs
        .where((BiometricMetricSpec s) => s.kind != BiometricMetricKind.somatotype)
        .toList();

    void open(BiometricMetricSpec spec) {
      final bool isTape = spec.kind == BiometricMetricKind.validatedNavyFat;
      unawaited(
        BiometricMetricDetailSheet.show(
          context: context,
          spec: spec,
          onActionTap: isTape ? onMeasureTape : null,
          actionLabel: isTape ? l10n.cuerpoTapeButton : null,
        ),
      );
    }

    final Color rule = c.isFlat ? c.line2 : c.line;
    final double ruleWidth = c.isFlat ? 1.5 : 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ScSpace.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (latest != null && latest!.impedanceOhms == null) ...<Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.info_outline, size: 16, color: c.text3),
                const SizedBox(width: ScSpace.s),
                Expanded(
                  child: Text(
                    l10n.cuerpoEstimatedNotice,
                    style: context.type.caption.copyWith(color: c.text3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ScSpace.m),
          ],
          _SomatotypeHeroCard(spec: somatotype, onTap: () => open(somatotype)),
          const SizedBox(height: ScSpace.cardGap),
          // Ficha técnica: una sola tarjeta con las métricas en rejilla y filetes
          // finos entre celdas, en lugar de doce cajas sueltas.
          HealthCard(
            margin: EdgeInsets.zero,
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                for (int i = 0; i < grid.length; i += 2) ...<Widget>[
                  if (i > 0) Divider(height: ruleWidth, thickness: ruleWidth, color: rule),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(
                          child: _MetricCell(spec: grid[i], onTap: () => open(grid[i])),
                        ),
                        VerticalDivider(width: ruleWidth, thickness: ruleWidth, color: rule),
                        Expanded(
                          child: i + 1 < grid.length
                              ? _MetricCell(spec: grid[i + 1], onTap: () => open(grid[i + 1]))
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SomatotypeHeroCard extends StatelessWidget {
  const _SomatotypeHeroCard({required this.spec, required this.onTap});

  final BiometricMetricSpec spec;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return HealthCard(
      margin: EdgeInsets.zero,
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Icon(spec.icon, color: c.isFlat ? c.text : c.accent, size: 26),
          const SizedBox(width: ScSpace.m + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(spec.title.toUpperCase(), style: context.type.overline),
                const SizedBox(height: ScSpace.xs),
                Text(spec.valueLabel, style: context.text.headlineSmall),
                const SizedBox(height: 2),
                Text(spec.subtitle, style: context.type.caption),
              ],
            ),
          ),
          Icon(AppIcons.chevronRight, size: 22, color: c.text3),
        ],
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({required this.spec, required this.onTap});

  final BiometricMetricSpec spec;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final Color toneCol = BiometricMetricCatalog.toneColor(c, spec.tone);

    return Semantics(
      button: true,
      label: '${spec.title}: ${spec.valueLabel}. ${spec.statusLabel}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(ScSpace.l, ScSpace.m + 2, ScSpace.m, ScSpace.m + 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(spec.icon, size: 15, color: c.text3),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      spec.title,
                      style: context.type.caption.copyWith(fontSize: 12, color: c.text2),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ScSpace.s),
              Text(
                spec.valueLabel,
                style: context.type.metricS.copyWith(fontSize: 20),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: ScSpace.xs + 2),
              Row(
                children: <Widget>[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: c.isFlat ? Colors.transparent : toneCol,
                      shape: BoxShape.circle,
                      border: c.isFlat ? Border.all(color: c.text, width: 1.5) : null,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      spec.statusLabel,
                      style: context.type.caption.copyWith(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: c.isFlat ? c.text2 : toneCol,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
