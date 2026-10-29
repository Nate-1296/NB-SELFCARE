import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_tokens.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/quick_action_button.dart';
import '../../../../care/application/care_queries.dart';
import '../../../../care/application/treatment_service.dart';
import '../../../../care/presentation/care_l10n.dart';
import '../../../domain/hoy_widget_config.dart';
import 'bento_metric_card.dart';

// ============================================================================
// 10. CUIDADO DE HOY: PRÓXIMA TOMA Y HÁBITOS — 2×2 / 4×2
// ============================================================================
class HoyCareBentoCard extends ConsumerWidget {
  const HoyCareBentoCard({super.key, required this.size, required this.dateKey});

  final HoyWidgetSize size;
  final String dateKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final CareTodaySummary s = ref.watch(careTodaySummaryProvider(dateKey));
    final TodayDose? next = s.nextDose;
    final String headline = s.isEmpty
        ? l10n.careTitle
        : (s.dosesPending == 0 && s.habitsDone == s.habitsTotal
              ? l10n.todayCareAllDone
              : (s.dosesPending == 1
                    ? l10n.todayCareOneDosePending
                    : (s.dosesPending > 1
                          ? l10n.todayCareDosesPending('${s.dosesPending}')
                          : l10n.careHabitsTitle)));
    final String caption = s.isEmpty
        ? l10n.todayCareEmpty
        : <String>[
            if (next != null)
              '${next.slot.slotMinutes == null ? l10n.careDoseAnytime : CareText.hhmm(next.slot.slotMinutes!)} · ${next.treatment.name}',
            if (s.habitsTotal > 0) l10n.todayCareHabits('${s.habitsDone}', '${s.habitsTotal}'),
          ].join('\n');

    return BentoMetricCard(
      icon: AppIcons.cuidado,
      label: l10n.hoyWidgetCare,
      tone: c.accent,
      metric: Text(headline, style: context.type.metricS.copyWith(color: c.text), maxLines: 2),
      caption: caption,
      progress: s.habitsTotal + s.dosesTotal == 0
          ? null
          : (s.habitsDone + s.dosesTotal - s.dosesPending) / (s.habitsTotal + s.dosesTotal),
      actions: <Widget>[
        if (next != null)
          QuickActionButton(
            label: l10n.careDoseTaken,
            icon: Icons.check_rounded,
            onPressed: () {
              unawaited(HapticFeedback.selectionClick());
              unawaited(
                ref
                    .read(treatmentServiceProvider)
                    .markDose(
                      dateKey: dateKey,
                      treatmentId: next.treatment.id,
                      slotMinutes: next.slot.slotMinutes,
                      taken: true,
                    ),
              );
            },
          )
        else
          QuickActionButton(
            label: l10n.careTitle,
            icon: AppIcons.cuidado,
            onPressed: () => context.go('/cuidado'),
          ),
      ],
    );
  }
}
