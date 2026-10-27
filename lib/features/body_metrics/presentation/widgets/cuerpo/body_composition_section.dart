import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_theme.dart';
import '../../../../../shared/theme/sc_tokens.dart';
import '../../../../../shared/widgets/app_icons.dart';
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
    final List<BiometricMetricSpec> specs =
        BiometricMetricCatalog.buildAll(l10n, profile: profile, latest: latest, referenceDate: referenceDate);
    final BiometricMetricSpec somatotype =
        specs.firstWhere((BiometricMetricSpec s) => s.kind == BiometricMetricKind.somatotype);
    final List<BiometricMetricSpec> grid =
        specs.where((BiometricMetricSpec s) => s.kind != BiometricMetricKind.somatotype).toList();

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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ScSpace.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (latest != null && latest!.impedanceOhms == null) ...<Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: ScSpace.m, vertical: ScSpace.s),
              decoration: BoxDecoration(
                color: c.bg3,
                borderRadius: BorderRadius.circular(ScRadius.control),
                border: Border.all(color: c.isFlat ? c.line2 : c.line, width: c.isFlat ? 1.5 : 1.0),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.info_outline, size: 16, color: c.text3),
                  const SizedBox(width: ScSpace.s),
                  Expanded(child: Text(l10n.cuerpoEstimatedNotice, style: context.text.bodySmall)),
                ],
              ),
            ),
            const SizedBox(height: ScSpace.s + 2),
          ],
          _SomatotypeHeroCard(spec: somatotype, onTap: () => open(somatotype)),
          const SizedBox(height: ScSpace.s + 2),
          for (int i = 0; i < grid.length; i += 2) ...<Widget>[
            if (i > 0) const SizedBox(height: ScSpace.s + 2),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(child: _MetricGridCard(spec: grid[i], onTap: () => open(grid[i]))),
                  const SizedBox(width: ScSpace.s + 2),
                  Expanded(
                    child: i + 1 < grid.length
                        ? _MetricGridCard(spec: grid[i + 1], onTap: () => open(grid[i + 1]))
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SomatotypeHeroCard extends StatelessWidget {
  const _SomatotypeHeroCard({
    required this.spec,
    required this.onTap,
  });

  final BiometricMetricSpec spec;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: c.bg2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: c.isFlat ? c.line2 : c.line,
            width: c.isFlat ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: c.soft,
                borderRadius: BorderRadius.circular(14),
                border: c.isFlat
                    ? Border.all(color: c.line2, width: 1.2)
                    : null,
              ),
              child: Icon(spec.icon, color: c.isFlat ? c.text : c.accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spec.title,
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 12,
                      color: c.text3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    spec.valueLabel,
                    style: TextStyle(
                      fontFamily: ScFonts.display,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: c.text,
                    ),
                    softWrap: true,
                  ),
                  Text(
                    spec.subtitle,
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 11,
                      color: c.text2,
                    ),
                    softWrap: true,
                  ),
                ],
              ),
            ),
            Icon(AppIcons.chevronRight, size: 20, color: c.text3),
          ],
        ),
      ),
    );
  }
}

class _MetricGridCard extends StatelessWidget {
  const _MetricGridCard({
    required this.spec,
    required this.onTap,
  });

  final BiometricMetricSpec spec;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final Color toneCol = BiometricMetricCatalog.toneColor(c, spec.tone);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: c.bg2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: c.isFlat ? c.line2 : c.line,
            width: c.isFlat ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(spec.icon, size: 15, color: c.isFlat ? c.text : c.accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    spec.title,
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.text3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              spec.valueLabel,
              style: TextStyle(
                fontFamily: ScFonts.display,
                fontSize: 17.5,
                fontWeight: FontWeight.w800,
                color: c.text,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: toneCol,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    spec.statusLabel,
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 10.5,
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
    );
  }
}
