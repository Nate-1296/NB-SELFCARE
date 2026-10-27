import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/widgets/app_icons.dart';
import 'meal_slot_selector.dart';

class FoodSearchItemCard extends StatelessWidget {
  const FoodSearchItemCard({super.key, 
    required this.food,
    required this.onTapDetail,
    required this.onQuickAdd,
    required this.onToggleFavorite,
  });

  final FoodItem food;
  final VoidCallback onTapDetail;
  final VoidCallback onQuickAdd;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final double servingG =
        food.defaultServingGrams > 0 ? food.defaultServingGrams : 100.0;
    final double ratio = servingG / 100.0;
    final int servingKcal = (food.kcalPer100g * ratio).round();
    final double p = food.proteinPer100g * ratio;
    final double carbs = food.carbsPer100g * ratio;
    final double fat = food.fatPer100g * ratio;

    return Material(
      color: c.bg2,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTapDetail,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: c.isFlat ? c.line2 : c.line,
              width: c.isFlat ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      food.name,
                      softWrap: true,
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                        height: 1.2,
                      ),
                    ),
                    if ((food.brand != null && food.brand!.trim().isNotEmpty) ||
                        (food.nutriScore != null &&
                            food.nutriScore!.trim().isNotEmpty)) ...<Widget>[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          if (food.brand != null &&
                              food.brand!.trim().isNotEmpty)
                            Text(
                              food.brand!.trim(),
                              style: TextStyle(
                                fontFamily: ScFonts.ui,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: c.text2,
                              ),
                            ),
                          if (food.nutriScore != null &&
                              food.nutriScore!.trim().isNotEmpty)
                            NutriScoreBadge(grade: food.nutriScore!),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      context.l10n.foodGKcalPGC(servingG.round().toString(), (servingKcal).toString(), p.toStringAsFixed(0).toString(), carbs.toStringAsFixed(0).toString(), fat.toStringAsFixed(0).toString()),
                      softWrap: true,
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.text2,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: food.isFavorite
                    ? context.l10n.foodQuitarDeFavoritos: context.l10n.foodMarcarComoFavorito,
                visualDensity: VisualDensity.compact,
                onPressed: onToggleFavorite,
                icon: Icon(
                  food.isFavorite ? AppIcons.starFilled : AppIcons.star,
                  size: 20,
                  color: food.isFavorite ? c.carbs : c.text3,
                ),
              ),
              const SizedBox(width: 2),
              Material(
                color: c.isFlat ? c.bg3 : c.accent.withValues(alpha: 0.16),
                shape: CircleBorder(
                  side: BorderSide(
                    color: c.isFlat ? c.line2 : c.accent.withValues(alpha: 0.5),
                    width: c.isFlat ? 1.4 : 1.0,
                  ),
                ),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onQuickAdd,
                  child: Padding(
                    padding: const EdgeInsets.all(9),
                    child: Icon(
                      AppIcons.add,
                      size: 20,
                      color: c.isFlat ? c.text : c.accent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptySearchState extends StatelessWidget {
  const EmptySearchState({super.key, 
    required this.query,
    required this.onCreateCustom,
    this.onSearchOff,
    this.isSearchingOff = false,
  });

  final String query;
  final VoidCallback onCreateCustom;
  final VoidCallback? onSearchOff;
  final bool isSearchingOff;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.restaurant_menu_rounded, size: 42, color: c.text3),
            const SizedBox(height: 12),
            Text(
              query.isEmpty
                  ? context.l10n.foodAunNoHayAlimentosEn: context.l10n.foodNoEncontramosEnTuCatalogo((query).toString()),
              textAlign: TextAlign.center,
              softWrap: true,
              style: TextStyle(
                fontFamily: ScFonts.display,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: c.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              query.isNotEmpty
                  ? context.l10n.foodPuedesBuscarloEnOpenFood: context.l10n.foodPuedesCrearloEnSegundosY,
              textAlign: TextAlign.center,
              softWrap: true,
              style: TextStyle(
                fontFamily: ScFonts.ui,
                fontSize: 13,
                color: c.text2,
              ),
            ),
            const SizedBox(height: 16),
            if (query.isNotEmpty && onSearchOff != null) ...<Widget>[
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: isSearchingOff ? null : onSearchOff,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: isSearchingOff
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.travel_explore_rounded, size: 18),
                  label: Text(
                    isSearchingOff
                        ? context.l10n.foodConsultandoOpenFoodFacts: context.l10n.foodBuscarEnOpenFoodFacts,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onCreateCustom,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(AppIcons.add, size: 18),
                label: Text(context.l10n.foodCrearAlimentoPropio),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SearchOpenFoodFactsTile extends StatelessWidget {
  const SearchOpenFoodFactsTile({super.key, 
    required this.query,
    required this.isSearching,
    required this.onSearch,
  });

  final String query;
  final bool isSearching;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.bg3,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: c.isFlat ? c.line2 : c.line,
          width: c.isFlat ? 1.3 : 1.0,
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.travel_explore_rounded,
            color: c.accent,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.l10n.foodNoEstaLoQueBuscas,
                  style: TextStyle(
                    fontFamily: ScFonts.display,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.foodBuscarEnElCatalogoOpen((query).toString()),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: 11.5,
                    color: c.text2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: isSearching ? null : onSearch,
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
            child: isSearching
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.l10n.foodBuscar),
          ),
        ],
      ),
    );
  }
}
