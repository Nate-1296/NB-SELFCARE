import 'package:flutter/material.dart';

import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_theme.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/health_card.dart';
import '../../../domain/hoy_widget_config.dart';

// ============================================================================
// 3. WIDGET HIDRATACIÓN INTELIGENTE — 2×2 / 4×2
// ============================================================================
class HoyHydrationBentoCard extends StatelessWidget {
  const HoyHydrationBentoCard({
    super.key,
    required this.size,
    required this.totalWaterMl,
    required this.goalMl,
    required this.glassesCount,
    required this.canUndo,
    required this.onAdd250,
    required this.onAdd500,
    required this.onUndoLast,
  });

  final HoyWidgetSize size;
  final int totalWaterMl;
  final int goalMl;
  final int glassesCount;
  final bool canUndo;
  final VoidCallback onAdd250;
  final VoidCallback onAdd500;
  final VoidCallback onUndoLast;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final bool compact = size.isHalfWidth;
    final double ratio =
        goalMl > 0 ? (totalWaterMl / goalMl).clamp(0.0, 1.0) : 0.0;
    final int pct = (ratio * 100).round();

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
                  Icon(AppIcons.water, size: 19, color: c.water),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      context.l10n.todayHidratacion,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                      ),
                    ),
                  ),
                  if (canUndo)
                    IconButton(
                      onPressed: onUndoLast,
                      tooltip: context.l10n.todayUndoLastGlass,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                      icon: Icon(AppIcons.undo, size: 16, color: c.text2),
                    ),
                  Text(
                    '$pct%',
                    style: TextStyle(
                      fontFamily: ScFonts.display,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: c.isFlat ? c.text : c.water,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                context.l10n.todayMl((totalWaterMl).toString()),
                softWrap: true,
                style: TextStyle(
                  fontFamily: ScFonts.display,
                  fontSize: compact ? 22 : 24,
                  fontWeight: FontWeight.w800,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                compact
                    ? context.l10n.todayMetaMl((goalMl).toString()): context.l10n.todayMetaDiariaMlTomasRegistradas((goalMl).toString(), (glassesCount).toString()),
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
                valueColor: AlwaysStoppedAnimation<Color>(c.water),
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.tonal(
                  onPressed: onAdd250,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                  child: Text(
                    context.l10n.today250Ml,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  onPressed: onAdd500,
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                  child: Text(
                    context.l10n.today500Ml,
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
