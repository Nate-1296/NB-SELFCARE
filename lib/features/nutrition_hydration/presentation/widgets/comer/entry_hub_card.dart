import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/clock/clock.dart';
import '../../../../../core/database/app_database.dart';
import '../../../../../core/domain/metabolic_phase.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_theme.dart';
import '../../../../../shared/theme/sc_tokens.dart';
import '../../../../../shared/widgets/action_tile.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/health_card.dart';
import '../../../../fasting/application/fasting_queries.dart';
import '../../../../fasting/presentation/metabolic_phase_l10n.dart';

/// Formas de registrar comida: búsqueda, código de barras y accesos rápidos.
///
/// Los accesos van en una cuadrícula de dos columnas con el icono encima del
/// texto, para que ningún título se parta en mitad de una palabra.
class ComerEntryHub extends ConsumerWidget {
  const ComerEntryHub({
    super.key,
    required this.onOpenSearch,
    required this.onOpenBarcode,
    required this.onOpenTextEntry,
    required this.onOpenCombos,
    required this.onOpenRecipes,
    required this.onOpenCustomFood,
    required this.onOpenSmartMenu,
    required this.onOpenFasting,
  });

  final VoidCallback onOpenSearch;
  final VoidCallback onOpenBarcode;
  final VoidCallback onOpenTextEntry;
  final VoidCallback onOpenCombos;
  final VoidCallback onOpenRecipes;
  final VoidCallback onOpenCustomFood;
  final VoidCallback onOpenSmartMenu;
  final VoidCallback onOpenFasting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final FastingSession? fast = ref.watch(activeFastingSessionStreamProvider).value;

    final String fastingSubtitle;
    if (fast == null) {
      fastingSubtitle = l10n.comerFastingIdle;
    } else {
      final double hours =
          ref.watch(clockProvider).now().difference(fast.startedAt).inMinutes / 60.0;
      fastingSubtitle = l10n.comerFastingActive(
        MetabolicPhase.forHours(hours).label(l10n),
        hours.floor(),
        fast.targetHours,
      );
    }

    final List<Widget> tiles = <Widget>[
      ActionTile(
        icon: AppIcons.textEntry,
        title: l10n.comerWriteMeal,
        subtitle: l10n.comerWriteMealHint,
        onTap: onOpenTextEntry,
      ),
      ActionTile(
        icon: AppIcons.combos,
        tone: c.carbs,
        title: l10n.comerCombos,
        subtitle: l10n.comerCombosHint,
        onTap: onOpenCombos,
      ),
      ActionTile(
        icon: Icons.soup_kitchen_rounded,
        tone: c.fat,
        title: l10n.comerRecipes,
        subtitle: l10n.comerRecipesHint,
        onTap: onOpenRecipes,
      ),
      ActionTile(
        icon: AppIcons.add,
        tone: c.protein,
        title: l10n.comerCreateFood,
        subtitle: l10n.comerCreateFoodHint,
        onTap: onOpenCustomFood,
      ),
      ActionTile(
        icon: AppIcons.chispa,
        title: l10n.comerSmartMenu,
        subtitle: l10n.comerSmartMenuHint,
        onTap: onOpenSmartMenu,
      ),
      ActionTile(
        icon: fast == null ? AppIcons.ayuno : AppIcons.ayunoFilled,
        tone: c.fasting,
        title: l10n.comerFasting,
        subtitle: fastingSubtitle,
        onTap: onOpenFasting,
      ),
    ];

    return HealthCard(
      padding: const EdgeInsets.all(ScSpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: _SearchField(onTap: onOpenSearch)),
              const SizedBox(width: ScSpace.s),
              _BarcodeButton(onTap: onOpenBarcode),
            ],
          ),
          const SizedBox(height: ScSpace.m),
          for (int i = 0; i < tiles.length; i += 2) ...<Widget>[
            if (i > 0) const SizedBox(height: ScSpace.s),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(child: tiles[i]),
                  const SizedBox(width: ScSpace.s),
                  Expanded(child: tiles[i + 1]),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final String label = context.l10n.comerSearchHint;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: c.bg3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ScRadius.tile),
          side: BorderSide(color: c.isFlat ? c.line2 : c.line, width: c.isFlat ? 1.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: ScSpace.l - 2),
            child: Row(
              children: <Widget>[
                Icon(AppIcons.search, size: 20, color: c.isFlat ? c.text : c.accent),
                const SizedBox(width: ScSpace.s + 2),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.text2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BarcodeButton extends StatelessWidget {
  const _BarcodeButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Tooltip(
      message: context.l10n.comerScanBarcode,
      child: Material(
        color: c.isFlat ? c.bg3 : c.accent.withValues(alpha: 0.14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ScRadius.tile),
          side: BorderSide(
            color: c.isFlat ? c.line2 : c.accent.withValues(alpha: 0.45),
            width: c.isFlat ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(AppIcons.barcode, color: c.isFlat ? c.text : c.accent),
          ),
        ),
      ),
    );
  }
}
