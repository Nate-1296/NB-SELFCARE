import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/domain/metabolic_phase.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_theme.dart';
import '../../../../../shared/theme/sc_tokens.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/chip_pill.dart';
import '../../../../../shared/widgets/health_card.dart';
import '../../../../../shared/widgets/quick_action_button.dart';
import '../../../../../shared/widgets/tonal_badge.dart';
import '../../../../fasting/presentation/metabolic_phase_l10n.dart';
import '../../../../pet_gamification/domain/pet_catalog.dart';
import '../../../../pet_gamification/presentation/nibi/nibi_view.dart';
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
    this.look = const NibiLook(),
  });

  /// Sombrero que lleva puesto en la pestaña de Nibi.
  final NibiLook look;

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
        child: NibiAvatar(size: compact ? 52 : 60, look: look),
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
                fontWeight: FontWeight.w700,
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
                              fontWeight: FontWeight.w700,
                              color: c.text,
                            ),
                          ),
                          badgesWrap,
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Bocadillo: esquina superior izquierda cerrada, apuntando al avatar.
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                        decoration: BoxDecoration(
                          color: c.isFlat ? c.bg2 : c.bg3,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(18),
                            bottomLeft: Radius.circular(18),
                            bottomRight: Radius.circular(18),
                          ),
                          border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
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
          const SizedBox(height: ScSpace.m),
          QuickActionButton(
            label: context.l10n.todayIrAlSantuarioDe(petName),
            icon: AppIcons.nibi,
            tone: c.accent,
            onPressed: () => context.go('/nibi'),
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
  Widget build(BuildContext context) => TonalBadge(label: label, icon: icon, tone: color);
}
