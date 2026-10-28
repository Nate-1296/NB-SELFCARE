import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_theme.dart';
import '../../../../../shared/theme/sc_tokens.dart';
import '../../../../../shared/widgets/card_header.dart';
import '../../../../../shared/widgets/health_card.dart';
import '../../../../../shared/widgets/progress_bar.dart';
import '../../../../../shared/widgets/science_on_demand_sheet.dart';
import '../../../../../shared/widgets/tonal_badge.dart';
import '../../../domain/nutrient_totals.dart';

/// Grado de procesamiento (NOVA) de lo comido en el día.
///
/// Solo calcula porcentajes sobre las kcal de alimentos con grupo NOVA
/// conocido; el resto se indica aparte en lugar de contarlo como "comida real".
class NovaQualityCard extends StatelessWidget {
  const NovaQualityCard({super.key, required this.totals});

  final NutrientTotals totals;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final double classified = totals.classifiedKcal;
    final int freshPct = classified > 0
        ? (totals.minimallyProcessedKcal / classified * 100).round()
        : 0;
    final bool highUltra = classified > 0 && freshPct < 75;

    return HealthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CardHeader(
            icon: Icons.eco_rounded,
            tone: c.protein,
            title: l10n.comerNovaTitle,
            trailing: classified > 0
                ? TonalBadge(
                    label: l10n.comerNovaFreshBadge(freshPct),
                    tone: highUltra ? c.warning : c.protein,
                  )
                : null,
          ),
          const SizedBox(height: ScSpace.m),
          if (classified > 0) ...<Widget>[
            ScProgressBar(value: freshPct / 100.0, color: c.protein, height: 7),
            const SizedBox(height: ScSpace.s),
            Wrap(
              spacing: ScSpace.m,
              runSpacing: ScSpace.xxs,
              children: <Widget>[
                Text(
                  l10n.comerNovaFreshKcal(totals.minimallyProcessedKcal.round()),
                  style: context.text.bodySmall,
                ),
                Text(
                  l10n.comerNovaUltraKcal(totals.ultraProcessedKcal.round()),
                  style: context.text.bodySmall?.copyWith(
                    fontWeight: highUltra ? FontWeight.w700 : null,
                    color: highUltra && !c.isFlat ? c.warning : null,
                  ),
                ),
              ],
            ),
          ],
          if (totals.unclassifiedKcal >= 1) ...<Widget>[
            if (classified > 0) const SizedBox(height: ScSpace.xs),
            Text(
              classified > 0
                  ? l10n.comerNovaPartial(totals.unclassifiedKcal.round())
                  : l10n.comerNovaNone,
              style: context.text.bodySmall,
            ),
          ],
          const SizedBox(height: ScSpace.xs),
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              foregroundColor: c.isFlat ? c.text : c.accent,
            ),
            onPressed: () =>
                unawaited(ScienceOnDemandSheet.show(context, ScienceSpec.novaClassification())),
            icon: const Icon(Icons.info_outline_rounded, size: 16),
            label: Text(
              l10n.comerNovaHowItWorks,
              style: const TextStyle(fontFamily: ScFonts.ui, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
