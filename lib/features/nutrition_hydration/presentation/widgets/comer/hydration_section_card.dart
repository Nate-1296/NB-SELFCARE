import 'package:flutter/material.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_tokens.dart';
import '../../../../../shared/utils/number_formats.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/card_header.dart';
import '../../../../../shared/widgets/health_card.dart';
import '../../../../../shared/widgets/metric_value.dart';
import '../../../../../shared/widgets/progress_bar.dart';
import '../../../../../shared/widgets/quick_action_button.dart';
import '../../../../../shared/widgets/section_head.dart';

/// Tarjeta completa de Hidratación del Día (+250 ml, +500 ml, vaso personalizado e historial).
class HydrationSectionCard extends StatelessWidget {
  const HydrationSectionCard({
    super.key,
    required this.logs,
    required this.goalMl,
    required this.formatClock,
    required this.onAdd250,
    required this.onAdd500,
    required this.onOpenCustom,
    required this.onDeleteGlass,
  });

  final List<HydrationLog> logs;
  final int goalMl;
  final String Function(DateTime) formatClock;
  final VoidCallback onAdd250;
  final VoidCallback onAdd500;
  final VoidCallback onOpenCustom;
  final ValueChanged<HydrationLog> onDeleteGlass;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final int totalMl = logs.fold(0, (int sum, HydrationLog item) => sum + item.volumeMl);
    final double ratio = goalMl > 0 ? (totalMl / goalMl).clamp(0.0, 1.0) : 0.0;
    final int pct = (ratio * 100).round();

    final AppLocalizations l10n = context.l10n;
    final String locale = l10n.localeName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHead(title: l10n.comerHidratacion),
        HealthCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              MetricLabel(icon: AppIcons.gota, label: l10n.comerAguaAcumulada, tone: c.water),
              const SizedBox(height: ScSpace.m),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Flexible(
                    child: AnimatedMetricValue(
                      value: totalMl.toDouble(),
                      format: (double v) => NumberFormats.integer(v, locale),
                      unit: l10n.unitMl,
                      size: 34,
                    ),
                  ),
                  const SizedBox(width: ScSpace.s),
                  Expanded(
                    child: Text(
                      l10n.todayWaterCaption(pct.toString(), NumberFormats.integer(goalMl, locale)),
                      textAlign: TextAlign.end,
                      style: context.type.caption,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ScSpace.m),
              ScProgressBar(value: ratio, color: c.water, height: 8),
              const SizedBox(height: ScSpace.l),
              Row(
                children: <Widget>[
                  Expanded(
                    child: QuickActionButton(
                      label: l10n.comer250Ml,
                      icon: AppIcons.add,
                      tone: c.water,
                      onPressed: onAdd250,
                    ),
                  ),
                  const SizedBox(width: ScSpace.s),
                  Expanded(
                    child: QuickActionButton(
                      label: l10n.comer500Ml,
                      icon: AppIcons.add,
                      tone: c.water,
                      onPressed: onAdd500,
                    ),
                  ),
                  const SizedBox(width: ScSpace.s),
                  Expanded(
                    child: QuickActionButton(
                      label: l10n.comerAMedida,
                      tone: c.text2,
                      onPressed: onOpenCustom,
                    ),
                  ),
                ],
              ),
              if (logs.isNotEmpty) ...<Widget>[
                const SizedBox(height: ScSpace.m),
                Wrap(
                  spacing: ScSpace.s - 2,
                  runSpacing: ScSpace.s - 2,
                  children: logs.map((HydrationLog item) {
                    return InputChip(
                      label: Text(
                        l10n.comerMl2(NumberFormats.group(item.volumeMl), formatClock(item.loggedAt)),
                      ),
                      visualDensity: VisualDensity.compact,
                      deleteButtonTooltipMessage: l10n.commonDelete,
                      onDeleted: () => onDeleteGlass(item),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
