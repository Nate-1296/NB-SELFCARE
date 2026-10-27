import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_tokens.dart';
import '../../../../shared/utils/date_formats.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/health_card.dart';
import '../../../../shared/widgets/section_head.dart';
import '../../application/fasting_queries.dart';

/// Últimos ayunos terminados.
class FastHistory extends ConsumerWidget {
  const FastHistory({super.key, required this.onDelete});

  final ValueChanged<FastingSession> onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final List<FastingSession> history = ref.watch(recentFastsProvider).value ?? const <FastingSession>[];
    if (history.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHead(title: l10n.fastHistoryTitle),
        for (final FastingSession s in history)
          HealthCard(
            padding: const EdgeInsets.symmetric(horizontal: ScSpace.l, vertical: ScSpace.m),
            child: Row(
              children: <Widget>[
                Icon(
                  s.isCompleted ? AppIcons.check : AppIcons.fasting,
                  size: 20,
                  color: s.isCompleted ? (c.isFlat ? c.text : c.success) : c.text2,
                ),
                const SizedBox(width: ScSpace.m),
                Expanded(
                  child: Builder(
                    builder: (BuildContext context) {
                      final DateTime end = s.actualEndedAt ?? s.plannedEndAt;
                      final int minutes = end.difference(s.startedAt).inMinutes.clamp(0, 99999);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            l10n.fastHistoryLine(s.protocolName, minutes ~/ 60, (minutes % 60).toString().padLeft(2, '0')),
                            style: context.text.titleSmall,
                          ),
                          Text(
                            l10n.fastHistoryWhen(
                              DateFormats.shortDate(s.startedAt, l10n.localeName),
                              DateFormats.time(s.startedAt, l10n.localeName),
                              DateFormats.time(end, l10n.localeName),
                            ),
                            style: context.text.bodySmall,
                          ),
                        ],
                      );
                    },
                  ),
                ),
                IconButton(
                  tooltip: l10n.fastDelete,
                  icon: Icon(AppIcons.delete, size: 18, color: c.text3),
                  onPressed: () => onDelete(s),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
