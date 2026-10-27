import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/enums.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/services/smart_meal_suggester.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/health_card.dart';
import '../../../../shared/widgets/sheet.dart';
import '../../application/food_catalog_service.dart';
import '../../application/food_logging_service.dart';

/// Hoja modal del "Oráculo de Nutrientes" para cerrar déficits al final del día.
class NutrientOracleSheet extends ConsumerWidget {
  const NutrientOracleSheet({
    super.key,
    required this.remainingKcal,
    required this.remainingProteinG,
    required this.remainingCarbsG,
    required this.remainingFatG,
    required this.targetDateKey,
    required this.mealType,
  });

  final double remainingKcal;
  final double remainingProteinG;
  final double remainingCarbsG;
  final double remainingFatG;
  final String targetDateKey;
  final MealType mealType;

  static Future<void> show(
    BuildContext context, {
    required double remainingKcal,
    required double remainingProteinG,
    required double remainingCarbsG,
    required double remainingFatG,
    required String targetDateKey,
    MealType mealType = MealType.dinner,
  }) {
    return mostrarHojaMenu<void>(
      context,
      builder: (_) => NutrientOracleSheet(
        remainingKcal: remainingKcal,
        remainingProteinG: remainingProteinG,
        remainingCarbsG: remainingCarbsG,
        remainingFatG: remainingFatG,
        targetDateKey: targetDateKey,
        mealType: mealType,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final FoodCatalogService catalog = ref.watch(foodCatalogServiceProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
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
                  Icon(Icons.lightbulb_rounded, color: c.accent, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.foodOraculoDeNutrientes,
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
          const SizedBox(height: 4),
          Text(
            context.l10n.foodTeFaltanKcalPG(remainingKcal.round().toString(), remainingProteinG.round().toString(), remainingCarbsG.round().toString(), remainingFatG.round().toString()),
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 12,
              color: c.text2,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: FutureBuilder<List<SuggestedMealItem>>(
              future: catalog.closeGap(
                remainingKcal: remainingKcal,
                remainingProteinG: remainingProteinG,
                remainingCarbsG: remainingCarbsG,
                remainingFatG: remainingFatG,
              ),
              builder: (BuildContext ctx,
                  AsyncSnapshot<List<SuggestedMealItem>> snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final List<SuggestedMealItem> recs =
                    snap.data ?? <SuggestedMealItem>[];
                if (recs.isEmpty) {
                  return Center(
                    child: Text(
                      context.l10n.foodTusMetasEstanPracticamenteCubiertas,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.text2),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: recs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (BuildContext ctx, int i) {
                    final SuggestedMealItem item = recs[i];
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
                              size: 18,
                              color: c.accent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  item.food.name,
                                  style: TextStyle(
                                    fontFamily: ScFonts.ui,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: c.text,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  context.l10n.foodServirGKcal(item.grams.round().toString(), item.kcal.round().toString()),
                                  style: TextStyle(
                                    fontFamily: ScFonts.ui,
                                    fontSize: 11.5,
                                    color: c.accent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  context.l10n.foodPGCGG4(item.proteinG.toString(), item.carbsG.toString(), item.fatG.toString()),
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
                            ),
                            onPressed: () async {
                              unawaited(HapticFeedback.mediumImpact());
                              await ref.read(foodLoggingServiceProvider).logPortion(
                                    food: item.food,
                                    grams: item.grams,
                                    mealType: mealType,
                                    dateKey: targetDateKey,
                                  );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      context.l10n.foodGDeRegistrados(item.grams.round().toString(), item.food.name.toString()),
                                    ),
                                  ),
                                );
                                Navigator.of(context).pop();
                              }
                            },
                            child: Text(context.l10n.foodComer),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
