import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/services/smart_meal_suggester.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/utils/number_formats.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/sheet.dart';
import '../../../profile_goals/application/profile_queries.dart';
import '../../application/food_catalog_service.dart';
import '../../application/food_logging_service.dart';
import 'meal_slot_selector.dart';

/// Hoja modal del menú diario sugerido con porciones exactas.
class SmartMealMenuSheet extends ConsumerStatefulWidget {
  const SmartMealMenuSheet({super.key, required this.targetDateKey});

  final String targetDateKey;

  static Future<void> show(BuildContext context, {required String targetDateKey}) {
    return mostrarHojaMenu<void>(
      context,
      builder: (_) => SmartMealMenuSheet(targetDateKey: targetDateKey),
    );
  }

  @override
  ConsumerState<SmartMealMenuSheet> createState() => _SmartMealMenuSheetState();
}

class _SmartMealMenuSheetState extends ConsumerState<SmartMealMenuSheet> {
  SuggestedDailyMenu? _menu;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_generate());
  }

  Future<void> _generate() async {
    setState(() => _isLoading = true);
    final UserProfile? profile = ref.read(userProfileStreamProvider).value;

    if (profile == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final SuggestedDailyMenu m = await ref.read(foodCatalogServiceProvider).suggestMenu(profile);

    if (mounted) {
      setState(() {
        _menu = m;
        _isLoading = false;
      });
    }
  }

  Future<void> _logMealSlot(MealType mealSlot, List<SuggestedMealItem> items) async {
    final FoodLoggingService logging = ref.read(foodLoggingServiceProvider);
    unawaited(HapticFeedback.mediumImpact());

    for (final SuggestedMealItem item in items) {
      await logging.logPortion(
        food: item.food,
        grams: item.grams,
        mealType: mealSlot,
        dateKey: widget.targetDateKey,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.foodComidaRegistradaEnConPorciones(
                MealSlotMeta.of(mealSlot).title(context.l10n).toString(),
              ),
            ),
          ),
        );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
                  Icon(Icons.auto_awesome_rounded, color: c.accent, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.foodMenuSugeridoInteligente,
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
          if (_menu != null)
            Text(
              context.l10n.foodEstiloKcalMetaDiariaCalculada(
                _menu!.archetype.name.toString(),
                NumberFormats.group(_menu!.targetKcal),
              ),
              style: TextStyle(fontFamily: ScFonts.ui, fontSize: 12, color: c.text2),
            ),
          const SizedBox(height: 14),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _menu == null
                ? Center(child: Text(context.l10n.foodNoHayDatosDisponibles))
                : ListView(
                    children: _menu!.meals.entries.map((
                      MapEntry<MealType, List<SuggestedMealItem>> entry,
                    ) {
                      final MealType slot = entry.key;
                      final List<SuggestedMealItem> items = entry.value;
                      final String slotTitle = MealSlotMeta.of(slot).title(context.l10n);

                      final double slotKcal = items.fold(
                        0.0,
                        (double sum, SuggestedMealItem i) => sum + i.kcal,
                      );

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: c.bg3,
                          borderRadius: BorderRadius.circular(16),
                          border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Flexible(
                                  child: Text(
                                    context.l10n.foodKcal5(
                                      (slotTitle).toString(),
                                      NumberFormats.group(slotKcal),
                                    ),
                                    style: TextStyle(
                                      fontFamily: ScFonts.display,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      color: c.text,
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                  onPressed: () => _logMealSlot(slot, items),
                                  icon: const Icon(Icons.add_rounded, size: 16),
                                  label: Text(context.l10n.todayEntreno5s),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ...items.map((SuggestedMealItem item) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: <Widget>[
                                    Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 15,
                                      color: c.accent,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        context.l10n.foodG14(
                                          item.food.name.toString(),
                                          NumberFormats.group(item.grams),
                                        ),
                                        style: TextStyle(
                                          fontFamily: ScFonts.ui,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: c.text,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      context.l10n.foodKcal6(NumberFormats.group(item.kcal)),
                                      style: TextStyle(
                                        fontFamily: ScFonts.ui,
                                        fontSize: 12,
                                        color: c.text2,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
