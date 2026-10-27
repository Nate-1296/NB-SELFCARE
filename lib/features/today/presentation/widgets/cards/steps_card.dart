import 'package:flutter/material.dart';

import '../../../../../core/domain/activity_energy.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_theme.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/health_card.dart';
import '../../../domain/hoy_widget_config.dart';

// ============================================================================
// 5. WIDGET PASOS NEAT — 2×2 / 4×2
// ============================================================================
class HoyStepsBentoCard extends StatelessWidget {
  const HoyStepsBentoCard({
    super.key,
    required this.size,
    required this.steps,
    required this.goalSteps,
    required this.onQuickAdd1000,
    required this.onOpenSheet,
  });

  final HoyWidgetSize size;
  final int steps;
  final int goalSteps;
  final VoidCallback onQuickAdd1000;
  final VoidCallback onOpenSheet;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final double ratio =
        goalSteps > 0 ? (steps / goalSteps).clamp(0.0, 1.0) : 0.0;
    final int activeKcal = ActivityEnergy.kcalFromSteps(steps);

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
                  Icon(AppIcons.steps, size: 19, color: c.steps),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      context.l10n.todayPasosNeat,
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
                '$steps',
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
                context.l10n.todayMetaKcalActivas((goalSteps).toString(), (activeKcal).toString()),
                softWrap: true,
                style: TextStyle(
                  fontFamily: ScFonts.ui,
                  fontSize: 11.5,
                  color: c.text2,
                ),
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: ratio,
                minHeight: 7,
                backgroundColor: c.bg3,
                valueColor: AlwaysStoppedAnimation<Color>(c.steps),
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.tonal(
                  onPressed: onQuickAdd1000,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                  child: const Text(
                    '+1,000',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  onPressed: onOpenSheet,
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                  child: Text(
                    context.l10n.todayAjustar,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
