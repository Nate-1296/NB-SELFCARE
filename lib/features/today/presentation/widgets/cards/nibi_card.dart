import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/domain/metabolic_phase.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_theme.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/chip_pill.dart';
import '../../../../../shared/widgets/health_card.dart';
import '../../../../fasting/presentation/metabolic_phase_l10n.dart';
import '../../../../pet_gamification/presentation/shop_modal.dart';
import '../../../domain/hoy_widget_config.dart';

// ============================================================================
// 1. WIDGET COMPAÑERO NIBI (MENSAJE CONTEXTUAL VARIABLE) — 4×2 / 2×2
// ============================================================================
class HoyNibiBentoCard extends StatelessWidget {
  const HoyNibiBentoCard({
    super.key,
    required this.size,
    required this.petName,
    required this.coinsBalance,
    required this.streakDays,
    required this.aiGreeting,
    required this.fastingPhase,
    required this.hasSleepBonus,
    required this.onRefreshGreeting,
  });

  final HoyWidgetSize size;
  final String petName;
  final int coinsBalance;
  final int streakDays;
  final String aiGreeting;

  /// Fase del ayuno en curso; la etiqueta aparece desde la quema de grasa (12 h).
  final MetabolicPhase? fastingPhase;

  bool get _showsFastingTag =>
      fastingPhase != null && fastingPhase!.startsAtHour >= MetabolicPhase.fatBurning.startsAtHour;
  final bool hasSleepBonus;
  final VoidCallback onRefreshGreeting;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final bool compact = size.isHalfWidth;

    final Widget avatar = Semantics(
      button: true,
      label: context.l10n.todayOpenPet(petName),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => context.go('/nibi'),
        child: Container(
          width: compact ? 50 : 58,
          height: compact ? 50 : 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.soft,
            border: Border.all(color: c.isFlat ? c.line2 : c.accent, width: c.isFlat ? 1.8 : 1.5),
            image: const DecorationImage(
              image: AssetImage('assets/images/nibi_avatar.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );

    final Widget badgesWrap = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        ChipPill(
          icon: AppIcons.moneda,
          iconColor: c.isFlat ? c.text : c.warning,
          label: '$coinsBalance',
          onTap: () => ShopModal.show(context),
        ),
        ChipPill(
          icon: AppIcons.racha,
          iconColor: c.isFlat ? c.text : c.calories,
          label: '${streakDays}d',
          onTap: () => context.go('/nibi'),
        ),
      ],
    );

    return HealthCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          if (compact) ...<Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                avatar,
                IconButton(
                  tooltip: context.l10n.todayNuevoPensamientoDe(petName),
                  onPressed: onRefreshGreeting,
                  icon: Icon(AppIcons.chispa, size: 18, color: c.accent),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              petName,
              softWrap: true,
              style: TextStyle(
                fontFamily: ScFonts.display,
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: c.text,
              ),
            ),
            const SizedBox(height: 6),
            badgesWrap,
            const SizedBox(height: 10),
            Text(
              aiGreeting,
              softWrap: true,
              style: TextStyle(
                fontFamily: ScFonts.ui,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: c.text2,
                height: 1.38,
              ),
            ),
          ] else ...<Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                avatar,
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        alignment: WrapAlignment.spaceBetween,
                        children: <Widget>[
                          Text(
                            petName,
                            softWrap: true,
                            style: TextStyle(
                              fontFamily: ScFonts.display,
                              fontSize: 17.5,
                              fontWeight: FontWeight.w800,
                              color: c.text,
                            ),
                          ),
                          badgesWrap,
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: c.bg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: c.isFlat ? c.line2 : c.line,
                            width: c.isFlat ? 1.3 : 1.0,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                aiGreeting,
                                softWrap: true,
                                style: TextStyle(
                                  fontFamily: ScFonts.ui,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: c.text,
                                  height: 1.38,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              tooltip: context.l10n.todayNuevoPensamientoDe(petName),
                              onPressed: onRefreshGreeting,
                              icon: Icon(
                                AppIcons.chispa,
                                size: 18,
                                color: c.isFlat ? c.text : c.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          if (_showsFastingTag || hasSleepBonus) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: <Widget>[
                if (_showsFastingTag)
                  _StatusTag(
                    icon: AppIcons.chispa,
                    label: fastingPhase!.label(context.l10n),
                    color: c.fasting,
                  ),
                if (hasSleepBonus)
                  _StatusTag(
                    icon: AppIcons.sueno,
                    label: context.l10n.todayBonoSuenoX15,
                    color: c.accent,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.go('/nibi'),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              ),
              icon: Icon(AppIcons.nibi, size: 16, color: c.accent),
              label: Text(
                context.l10n.todayIrAlSantuarioDe((petName).toString()),
                softWrap: true,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: ScFonts.ui,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// COMPONENTES AUXILIARES COMPARTIDOS Y HOJA DE PASOS + SUEÑO
// ============================================================================
class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.isFlat ? c.bg3 : color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: c.isFlat ? c.line2 : color.withValues(alpha: 0.4),
          width: c.isFlat ? 1.2 : 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: c.isFlat ? c.text : color),
          const SizedBox(width: 5),
          Text(
            label,
            softWrap: true,
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: c.isFlat ? c.text : color,
            ),
          ),
        ],
      ),
    );
  }
}
