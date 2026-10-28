import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/utils/number_formats.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/health_card.dart';
import '../../../../shared/widgets/sheet.dart';
import '../../application/food_logging_service.dart';
import '../../application/nutrition_queries.dart';
import 'meal_slot_selector.dart';
import 'recipe_builder_sheet.dart';

/// Hoja modal que lista las recetas guardadas para registro rápido en 1 toque.
class SavedRecipesSheet extends ConsumerWidget {
  const SavedRecipesSheet({
    super.key,
    required this.targetDateKey,
    this.initialMealType = MealType.lunch,
  });

  final String targetDateKey;
  final MealType initialMealType;

  static Future<void> show(
    BuildContext context, {
    required String targetDateKey,
    MealType initialMealType = MealType.lunch,
  }) {
    return mostrarHojaMenu<void>(
      context,
      builder: (_) => SavedRecipesSheet(
        targetDateKey: targetDateKey,
        initialMealType: initialMealType,
      ),
    );
  }

  Future<void> _logRecipeServing(
    BuildContext context,
    WidgetRef ref,
    Recipe recipe,
  ) async {
    unawaited(HapticFeedback.mediumImpact());
    await ref.read(foodLoggingServiceProvider).logRecipeServing(
          recipe: recipe,
          mealType: initialMealType,
          dateKey: targetDateKey,
        );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.food1RacionDeRegistradaEn(recipe.name.toString(), MealSlotMeta.of(initialMealType).title(context.l10n).toString()),
          ),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final AsyncValue<List<Recipe>> recipesAsync =
        ref.watch(allRecipesStreamProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.soup_kitchen_rounded, color: c.accent, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.foodMisRecetasCaseras,
                    style: TextStyle(
                      fontFamily: ScFonts.display,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: c.text,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(AppIcons.close, color: c.text2),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.foodBatchCookingYRecetasMultiracion,
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 12,
              color: c.text2,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: c.isFlat ? c.line2 : c.accent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () async {
                final Recipe? created = await RecipeBuilderSheet.show(
                  context,
                  targetDateKey: targetDateKey,
                  initialMealType: initialMealType,
                );
                if (created != null && context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              icon: const Icon(AppIcons.add, size: 16),
              label: Text(context.l10n.foodCrearNuevaRecetaMultiracion),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: recipesAsync.when(
              data: (List<Recipe> recipes) {
                if (recipes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.soup_kitchen_outlined,
                          size: 44,
                          color: c.text3,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          context.l10n.foodAunNoHasCreadoRecetas,
                          style: TextStyle(
                            fontFamily: ScFonts.display,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: c.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.l10n.foodCreaPlatosMultiracionParaPorcionar,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: ScFonts.ui,
                            fontSize: 12,
                            color: c.text2,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: recipes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (BuildContext ctx, int i) {
                    final Recipe r = recipes[i];
                    return HealthCard(
                      margin: EdgeInsets.zero,
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: c.isFlat ? c.bg3 : c.soft,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.restaurant_rounded,
                              size: 20,
                              color: c.accent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  r.name,
                                  style: TextStyle(
                                    fontFamily: ScFonts.ui,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: c.text,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  context.l10n.foodKcalRindeRaciones(r.kcalPerServing.round().toString(), r.totalYieldServings.toString()),
                                  style: TextStyle(
                                    fontFamily: ScFonts.ui,
                                    fontSize: 11.5,
                                    color: c.text2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  context.l10n.foodPGCGG2(NumberFormats.fixed(r.proteinPerServing, 1), NumberFormats.fixed(r.carbsPerServing, 1), NumberFormats.fixed(r.fatPerServing, 1)),
                                  style: TextStyle(
                                    fontFamily: ScFonts.ui,
                                    fontSize: 11,
                                    color: c.text3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                            ),
                            onPressed: () => _logRecipeServing(ctx, ref, r),
                            child: Text(
                              context.l10n.food1Racion,
                              style: const TextStyle(fontSize: 11.5),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object e, _) => Text(context.l10n.foodError((e).toString())),
            ),
          ),
        ],
      ),
    );
  }
}
