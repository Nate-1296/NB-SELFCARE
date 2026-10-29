import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_tokens.dart';
import '../../../../shared/utils/number_formats.dart';
import '../../../../shared/widgets/card_header.dart';
import '../../../../shared/widgets/health_card.dart';
import '../../../../shared/widgets/undo_snackbar.dart';
import '../../application/care_queries.dart';
import '../../application/health_log_services.dart';
import '../../domain/substance_catalog.dart';
import '../care_l10n.dart';
import 'guided_care_cards.dart';

/// Alcohol y tabaco: un toque por bebida o cigarrillo, y la semana en positivo.
class SubstancesCard extends ConsumerWidget {
  const SubstancesCard({super.key});

  Future<void> _log(BuildContext context, WidgetRef ref, SubstancePreset preset) async {
    unawaited(HapticFeedback.selectionClick());
    final SubstanceService service = ref.read(substanceServiceProvider);
    final int id = await service.log(preset);
    if (!context.mounted) return;
    showUndoSnackBar(
      context,
      message: context.l10n.careSubstanceLogged(CareText.substance(context.l10n, preset.key)),
      onUndo: () => unawaited(service.undo(id)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final SubstanceSummary summary = ref.watch(substanceSummaryProvider);
    final List<String> lines = <String>[
      if (summary.alcohol.thisWeek > 0 || summary.alcohol.lastWeek > 0)
        l10n.careAlcoholWeek(NumberFormats.fixed(summary.alcohol.thisWeek, 1)),
      if (summary.alcohol.isLower) l10n.careTrendLower('${summary.alcohol.reductionPercent}'),
      if (summary.tobacco.thisWeek > 0 || summary.tobacco.lastWeek > 0)
        l10n.careTobaccoWeek('${summary.tobacco.thisWeek.round()}'),
      if (summary.tobacco.isLower) l10n.careTrendLower('${summary.tobacco.reductionPercent}'),
    ];
    Widget chip(SubstancePreset p) {
      final int count = summary.today
          .where((SubstanceLog l) => l.presetKey == p.key)
          .fold(0, (int s, SubstanceLog l) => s + l.units);
      return ActionChip(
        avatar: Icon(CareText.substanceIcon(p), size: 18),
        label: Text(
          count == 0
              ? CareText.substance(l10n, p.key)
              : '${CareText.substance(l10n, p.key)} · $count',
        ),
        onPressed: () => unawaited(_log(context, ref, p)),
      );
    }

    return HealthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          CardHeader(
            icon: Icons.local_bar_outlined,
            tone: c.carbs,
            title: l10n.careSubstancesTitle,
            subtitle: l10n.careSubstancesHint,
            trailing: const LearnMoreButton(spec: CareScience.alcohol),
          ),
          const SizedBox(height: ScSpace.m),
          Text(l10n.careSubstancesToday, style: context.text.labelLarge),
          const SizedBox(height: ScSpace.xs),
          Wrap(
            spacing: ScSpace.s,
            runSpacing: ScSpace.s,
            children: <Widget>[
              for (final SubstancePreset p in SubstancePreset.alcohol) chip(p),
              for (final SubstancePreset p in SubstancePreset.tobacco) chip(p),
            ],
          ),
          if (summary.today.isNotEmpty) ...<Widget>[
            const SizedBox(height: ScSpace.s),
            Wrap(
              spacing: ScSpace.xs,
              children: <Widget>[
                for (final SubstanceLog l in summary.today)
                  InputChip(
                    label: Text(CareText.substance(l10n, l.presetKey)),
                    onDeleted: () async {
                      final SubstanceService service = ref.read(substanceServiceProvider);
                      await service.delete(l);
                      if (context.mounted) {
                        showUndoSnackBar(
                          context,
                          message: l10n.careSubstanceDeleted,
                          onUndo: () => unawaited(service.restore(l)),
                        );
                      }
                    },
                  ),
              ],
            ),
          ],
          for (final String line in lines) ...<Widget>[
            const SizedBox(height: ScSpace.xs),
            Text(line, style: context.type.caption.copyWith(color: c.text2)),
          ],
          const SizedBox(height: ScSpace.xs),
          Text(l10n.careAlcoholKcalNote, style: context.type.caption.copyWith(color: c.text3)),
        ],
      ),
    );
  }
}
