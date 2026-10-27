import 'package:flutter/material.dart';

import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_theme.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/health_card.dart';
import '../../../domain/hoy_widget_config.dart';

// ============================================================================
// 6. WIDGET SUEÑO Y DESCANSO REPARADOR — 2×2 / 4×2
// ============================================================================
class HoySleepBentoCard extends StatelessWidget {
  const HoySleepBentoCard({
    super.key,
    required this.size,
    required this.sleepHours,
    required this.goalHours,
    required this.hasSleepBonus,
    required this.onOpenSheet,
  });

  final HoyWidgetSize size;
  final double sleepHours;
  final double goalHours;
  final bool hasSleepBonus;
  final VoidCallback onOpenSheet;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final double ratio =
        goalHours > 0 ? (sleepHours / goalHours).clamp(0.0, 1.0) : 0.0;

    return HealthCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(AppIcons.sueno, size: 19, color: c.fasting),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      context.l10n.todaySueno,
                      softWrap: true,
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                sleepHours > 0 ? context.l10n.todayH2(sleepHours.toStringAsFixed(1).toString()): context.l10n.todayH3,
                softWrap: true,
                style: TextStyle(
                  fontFamily: ScFonts.display,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hasSleepBonus
                    ? context.l10n.todaySuenoReparadorBonoX15: context.l10n.todayMetaHDeDescanso(goalHours.toStringAsFixed(1).toString()),
                softWrap: true,
                style: TextStyle(
                  fontFamily: ScFonts.ui,
                  fontSize: 11.5,
                  fontWeight:
                      hasSleepBonus ? FontWeight.w700 : FontWeight.w500,
                  color: hasSleepBonus ? c.accent : c.text2,
                ),
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: ratio,
                minHeight: 7,
                backgroundColor: c.bg3,
                valueColor: AlwaysStoppedAnimation<Color>(c.fasting),
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: onOpenSheet,
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(vertical: 9),
              ),
              icon: const Icon(AppIcons.sueno, size: 15),
              label: Text(
                context.l10n.todayRegistrarSueno,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
