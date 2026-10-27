import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/domain/metabolic_phase.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_theme.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/health_card.dart';
import '../../../../fasting/presentation/metabolic_phase_l10n.dart';
import '../../../domain/hoy_widget_config.dart';

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
    final FastingSession? fast = activeFast;
    final bool isFasting = fast != null;

    final int elapsedMinutes = isFasting
        ? now.difference(fast.startedAt).inMinutes.clamp(0, 99999)
        : 0;
    final int h = elapsedMinutes ~/ 60;
    final int m = elapsedMinutes % 60;
    final double elapsedHours = elapsedMinutes / 60.0;
    final int targetH = fast?.targetHours ?? 16;
    final double ratio =
        isFasting && targetH > 0 ? (elapsedHours / targetH).clamp(0.0, 1.0) : 0.0;

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
                  Icon(AppIcons.fasting, size: 19, color: c.fasting),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      context.l10n.todayAyuno,
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
                isFasting ? '${h}h ${m.toString().padLeft(2, '0')}m' : context.l10n.today168Libre,
                softWrap: true,
                style: TextStyle(
                  fontFamily: ScFonts.display,
                  fontSize: isFasting ? 22 : 19,
                  fontWeight: FontWeight.w800,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isFasting
                    ? context.l10n.todayMetaH(MetabolicPhase.forHours(elapsedHours).label(context.l10n), (targetH).toString()): context.l10n.todayVentanaAbiertaDescansoDigestivoListo,
                softWrap: true,
                style: TextStyle(
                  fontFamily: ScFonts.ui,
                  fontSize: 11.5,
                  color: isFasting && elapsedHours >= 12 ? c.fasting : c.text2,
                  fontWeight: isFasting && elapsedHours >= 12
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
              if (isFasting) ...<Widget>[
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: ratio,
                  minHeight: 7,
                  backgroundColor: c.bg3,
                  valueColor: AlwaysStoppedAnimation<Color>(c.fasting),
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => context.push('/ayuno'),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(vertical: 9),
              ),
              icon: Icon(
                isFasting ? AppIcons.timer : AppIcons.fasting,
                size: 16,
              ),
              label: Text(
                isFasting ? context.l10n.todayVerProgreso: context.l10n.todayIniciarAyuno,
                style:
                    const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
