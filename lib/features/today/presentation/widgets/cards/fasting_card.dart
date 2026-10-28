import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/domain/metabolic_phase.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_tokens.dart';
import '../../../../../shared/utils/number_formats.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/metric_value.dart';
import '../../../../../shared/widgets/quick_action_button.dart';
import '../../../../fasting/presentation/metabolic_phase_l10n.dart';
import '../../../domain/hoy_widget_config.dart';
import 'bento_metric_card.dart';

// ============================================================================
// 8. WIDGET AYUNO INTERMITENTE Y FASE METABÓLICA — 2×2 / 4×2
// ============================================================================
class HoyFastingBentoCard extends StatelessWidget {
  const HoyFastingBentoCard({
    super.key,
    required this.size,
    required this.activeFast,
    required this.now,
  });

  final HoyWidgetSize size;
  final FastingSession? activeFast;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final FastingSession? fast = activeFast;
    final bool isFasting = fast != null;

    final int elapsedMinutes = isFasting
        ? now.difference(fast.startedAt).inMinutes.clamp(0, 99999)
        : 0;
    final int h = elapsedMinutes ~/ 60;
    final int m = elapsedMinutes % 60;
    final double elapsedHours = elapsedMinutes / 60.0;
    final int targetH = fast?.targetHours ?? 16;
    final double ratio = isFasting && targetH > 0 ? (elapsedHours / targetH).clamp(0.0, 1.0) : 0.0;

    return BentoMetricCard(
      icon: AppIcons.fasting,
      label: l10n.todayAyuno,
      tone: c.fasting,
      metric: isFasting
          ? MetricValue(
              value: '$h:${m.toString().padLeft(2, '0')}',
              unit: l10n.unitHours,
              size: size.isHalfWidth ? 28 : 32,
            )
          : Text(l10n.today168Libre, style: context.type.metricS.copyWith(color: c.text2)),
      caption: isFasting
          ? l10n.todayMetaH(MetabolicPhase.forHours(elapsedHours).label(l10n), NumberFormats.group(targetH))
          : l10n.todayVentanaAbiertaDescansoDigestivoListo,
      captionEmphasis: isFasting && elapsedHours >= 12,
      progress: isFasting ? ratio : null,
      actions: <Widget>[
        QuickActionButton(
          label: isFasting ? l10n.todayVerProgreso : l10n.todayIniciarAyuno,
          icon: isFasting ? AppIcons.timer : AppIcons.fasting,
          tone: c.fasting,
          onPressed: () => context.push('/ayuno'),
        ),
      ],
    );
  }
}
