import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/domain/enums.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';

/// Metadatos visuales y semánticos unificados para cada momento de comida.
class MealSlotMeta {
  const MealSlotMeta({required this.key, required this.icon});

  final MealType key;
  final IconData icon;

  static const List<MealSlotMeta> all = <MealSlotMeta>[
    MealSlotMeta(key: MealType.breakfast, icon: Icons.wb_twilight_rounded),
    MealSlotMeta(key: MealType.lunch, icon: Icons.wb_sunny_rounded),
    MealSlotMeta(key: MealType.dinner, icon: Icons.nights_stay_rounded),
    MealSlotMeta(key: MealType.snack, icon: Icons.bakery_dining_rounded),
  ];

  String title(AppLocalizations l10n) => switch (key) {
    MealType.breakfast => l10n.foodDesayuno,
    MealType.lunch => l10n.foodAlmuerzo,
    MealType.dinner => l10n.foodCena,
    MealType.snack => l10n.foodSnacks,
  };

  /// Franja horaria orientativa (coincide con `MealType.forHour`).
  String timeHint(AppLocalizations l10n) => switch (key) {
    MealType.breakfast => '05:00 – 10:59',
    MealType.lunch => '11:00 – 15:59',
    MealType.dinner => '19:00 – 23:59',
    MealType.snack => l10n.foodEntreComidas,
  };

  static MealSlotMeta of(MealType mealType) {
    for (final MealSlotMeta item in all) {
      if (item.key == mealType) return item;
    }
    return all.last;
  }

  /// Determina el momento de comida sugerido según la hora actual del reloj.
  static MealType suggestedKeyForNow(DateTime now) => MealType.forHour(now.hour);

  Color accentColor(ScColors c) {
    if (c.isFlat) return c.text;
    return switch (key) {
      MealType.breakfast => c.carbs,
      MealType.lunch => c.calories,
      MealType.dinner => c.fasting,
      MealType.snack => c.protein,
    };
  }
}

/// Cuadrícula 2×2 sin truncamiento para seleccionar el bloque horario de comida.
class MealSlotSelectorGrid extends StatelessWidget {
  const MealSlotSelectorGrid({
    super.key,
    required this.selectedMealType,
    required this.onSelected,
    this.compact = false,
  });

  final MealType selectedMealType;
  final ValueChanged<MealType> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _MealSlotTile(
                meta: MealSlotMeta.all[0],
                selected: selectedMealType == MealSlotMeta.all[0].key,
                compact: compact,
                onTap: () => onSelected(MealSlotMeta.all[0].key),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MealSlotTile(
                meta: MealSlotMeta.all[1],
                selected: selectedMealType == MealSlotMeta.all[1].key,
                compact: compact,
                onTap: () => onSelected(MealSlotMeta.all[1].key),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: _MealSlotTile(
                meta: MealSlotMeta.all[2],
                selected: selectedMealType == MealSlotMeta.all[2].key,
                compact: compact,
                onTap: () => onSelected(MealSlotMeta.all[2].key),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MealSlotTile(
                meta: MealSlotMeta.all[3],
                selected: selectedMealType == MealSlotMeta.all[3].key,
                compact: compact,
                onTap: () => onSelected(MealSlotMeta.all[3].key),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MealSlotTile extends StatelessWidget {
  const _MealSlotTile({
    required this.meta,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final MealSlotMeta meta;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final Color tint = meta.accentColor(c);

    final Color bg = selected
        ? (c.isFlat ? c.bg3 : tint.withValues(alpha: 0.14))
        : (c.isFlat ? Colors.transparent : c.bg3.withValues(alpha: 0.65));
    final Color borderColor = selected ? (c.isFlat ? c.text : tint) : (c.isFlat ? c.line2 : c.line);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          unawaited(HapticFeedback.selectionClick());
          onTap();
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 9 : 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: selected ? 1.8 : (c.isFlat ? 1.4 : 1.0)),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                meta.icon,
                size: compact ? 16 : 18,
                color: selected ? (c.isFlat ? c.text : tint) : c.text2,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  meta.title(context.l10n),
                  softWrap: true,
                  style: TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: compact ? 13 : 13.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? c.text : c.text2,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, size: 16, color: c.isFlat ? c.text : tint),
            ],
          ),
        ),
      ),
    );
  }
}

/// Insignia visual Nutri-Score (A–E) compatible con Material You y E-Ink plano.
class NutriScoreBadge extends StatelessWidget {
  const NutriScoreBadge({super.key, required this.grade});

  final String grade;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final String normalized = grade.trim().toUpperCase();
    if (normalized.isEmpty || !const <String>{'A', 'B', 'C', 'D', 'E'}.contains(normalized)) {
      return const SizedBox.shrink();
    }

    Color badgeColor;
    switch (normalized) {
      case 'A':
        badgeColor = const Color(0xFF1E8F4E);
        break;
      case 'B':
        badgeColor = const Color(0xFF60AC0E);
        break;
      case 'C':
        badgeColor = const Color(0xFFE5AE07);
        break;
      case 'D':
        badgeColor = const Color(0xFFEC6B16);
        break;
      default:
        badgeColor = const Color(0xFFD93829);
    }

    if (c.isFlat) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: c.line2, width: 1.4),
        ),
        child: Text(
          context.l10n.foodNutriScore((normalized).toString()),
          style: TextStyle(
            fontFamily: ScFonts.ui,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: c.text,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: badgeColor.withValues(alpha: 0.6), width: 1),
      ),
      child: Text(
        context.l10n.foodNutriScore((normalized).toString()),
        style: TextStyle(
          fontFamily: ScFonts.ui,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: badgeColor,
        ),
      ),
    );
  }
}

/// Etiqueta legible de origen de datos nutricionales.
class FoodSourceBadge extends StatelessWidget {
  const FoodSourceBadge({super.key, required this.source});

  final FoodSource source;

  String _label(AppLocalizations l10n) => switch (source) {
    FoodSource.usdaSeed => l10n.foodUsdaBase,
    FoodSource.openFoodFacts => l10n.foodOpenFoodFacts,
    FoodSource.userCustom => l10n.foodMiReceta,
    FoodSource.textEstimate => l10n.foodEstimacion,
  };

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.bg3,
        borderRadius: BorderRadius.circular(7),
        border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
      ),
      child: Text(
        _label(context.l10n),
        style: TextStyle(
          fontFamily: ScFonts.ui,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: c.text2,
        ),
      ),
    );
  }
}
