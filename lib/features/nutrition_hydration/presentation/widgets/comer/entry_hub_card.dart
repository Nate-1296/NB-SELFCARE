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
import '../../../../../shared/widgets/pressable.dart';
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
        onPage: true,
        icon: AppIcons.textEntry,
        title: l10n.comerWriteMeal,
        subtitle: l10n.comerWriteMealHint,
        onTap: onOpenTextEntry,
      ),
      ActionTile(
        onPage: true,
        icon: AppIcons.combos,
        tone: c.carbs,
        title: l10n.comerCombos,
        subtitle: l10n.comerCombosHint,
        onTap: onOpenCombos,
      ),
      ActionTile(
        onPage: true,
        icon: Icons.soup_kitchen_rounded,
        tone: c.fat,
        title: l10n.comerRecipes,
        subtitle: l10n.comerRecipesHint,
        onTap: onOpenRecipes,
      ),
      ActionTile(
        onPage: true,
        icon: AppIcons.add,
        tone: c.protein,
        title: l10n.comerCreateFood,
        subtitle: l10n.comerCreateFoodHint,
        onTap: onOpenCustomFood,
      ),
      ActionTile(
        onPage: true,
        icon: AppIcons.chispa,
        title: l10n.comerSmartMenu,
        subtitle: l10n.comerSmartMenuHint,
        onTap: onOpenSmartMenu,
      ),
      ActionTile(
        onPage: true,
        icon: fast == null ? AppIcons.ayuno : AppIcons.ayunoFilled,
        tone: c.fasting,
        title: l10n.comerFasting,
        subtitle: fastingSubtitle,
        onTap: onOpenFasting,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(ScSpace.gutter, ScSpace.xs, ScSpace.gutter, ScSpace.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _SearchField(onTap: onOpenSearch, onScan: onOpenBarcode),
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

/// Buscador protagonista con el escáner integrado a la derecha.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.onTap, required this.onScan});

  final VoidCallback onTap;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final String label = context.l10n.comerSearchHint;
    return Pressable(
      scale: 0.985,
      child: Material(
        color: c.bg2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ScRadius.tileOf(c)),
          side: BorderSide(color: c.isFlat ? c.line2 : c.line, width: c.isFlat ? 1.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Semantics(
                button: true,
                label: label,
                excludeSemantics: true,
                child: InkWell(
                  onTap: onTap,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 56),
                    padding: const EdgeInsets.only(left: ScSpace.l),
                    child: Row(
                      children: <Widget>[
                        Icon(AppIcons.search, size: 22, color: c.isFlat ? c.text : c.accent),
                        const SizedBox(width: ScSpace.m),
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: ScFonts.ui,
                              fontSize: 15,
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
            ),
            Container(width: c.isFlat ? 1.5 : 1, height: 28, color: c.isFlat ? c.line2 : c.line),
            IconButton(
              tooltip: context.l10n.comerScanBarcode,
              onPressed: onScan,
              style: IconButton.styleFrom(fixedSize: const Size(56, 56)),
              icon: Icon(AppIcons.barcode, color: c.isFlat ? c.text : c.accent),
            ),
          ],
        ),
      ),
    );
  }
}
