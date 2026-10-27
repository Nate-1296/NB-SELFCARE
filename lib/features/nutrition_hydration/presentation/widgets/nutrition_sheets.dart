import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/models/food_models.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../application/food_catalog_service.dart';
import 'meal_slot_selector.dart';

/// Hoja interactiva para editar gramos, cambiar momento del día o eliminar un alimento registrado.
class EditFoodLogSheet extends ConsumerStatefulWidget {
  const EditFoodLogSheet({
    super.key,
    required this.entry,
    required this.onDeleteRequested,
  });

  final FoodLogWithItem entry;
  final VoidCallback onDeleteRequested;

  @override
  ConsumerState<EditFoodLogSheet> createState() => _EditFoodLogSheetState();
}

class _EditFoodLogSheetState extends ConsumerState<EditFoodLogSheet> {
  late double _grams;
  late MealType _mealType;
  late final TextEditingController _gramsCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _grams = widget.entry.log.gramsConsumed;
    _mealType = widget.entry.log.mealType;
    _gramsCtrl = TextEditingController(text: _grams.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _gramsCtrl.dispose();
    super.dispose();
  }

  void _setGrams(double val) {
    final double clamped = val.clamp(1.0, 5000.0);
    setState(() {
      _grams = clamped;
      _gramsCtrl.text = clamped.toStringAsFixed(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final FoodLog log = widget.entry.log;
    final FoodItem? food = widget.entry.foodItem;
    final String name = food?.name ?? context.l10n.foodAlimentoRegistrado;

    final double scale =
        log.gramsConsumed > 0 ? _grams / log.gramsConsumed : 1.0;
    final double previewKcal = food != null
        ? food.kcalPer100g * (_grams / 100.0)
        : log.totalKcal * scale;
    final double previewP = food != null
        ? food.proteinPer100g * (_grams / 100.0)
        : log.totalProteinG * scale;
    final double previewC = food != null
        ? food.carbsPer100g * (_grams / 100.0)
        : log.totalCarbsG * scale;
    final double previewF = food != null
        ? food.fatPer100g * (_grams / 100.0)
        : log.totalFatG * scale;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      softWrap: true,
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.foodAjustaLaCantidadConsumidaO,
                      softWrap: true,
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 12.5,
                        color: c.text2,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: context.l10n.commonClose,
                icon: Icon(AppIcons.close, color: c.text2),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Resumen en vivo de calorías y macros recalculados
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.bg3,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: c.isFlat ? c.line2 : c.line,
                width: c.isFlat ? 1.4 : 1.0,
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  AppIcons.fuego,
                  color: c.isFlat ? c.text : c.calories,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        context.l10n.foodKcal3(previewKcal.round().toString()),
                        style: TextStyle(
                          fontFamily: ScFonts.display,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: c.text,
                        ),
                      ),
                      Text(
                        context.l10n.foodProteinaGCarbosGGrasas(previewP.toStringAsFixed(1).toString(), previewC.toStringAsFixed(1).toString(), previewF.toStringAsFixed(1).toString()),
                        softWrap: true,
                        style: TextStyle(
                          fontFamily: ScFonts.ui,
                          fontSize: 12,
                          color: c.text2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Text(
            context.l10n.foodGramosConsumidos,
            style: TextStyle(
              fontFamily: ScFonts.display,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: c.text,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              OutlinedButton(
                onPressed: () {
                  unawaited(HapticFeedback.selectionClick());
                  _setGrams(_grams - 25);
                },
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(context.l10n.food25G),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _gramsCtrl,
                  textAlign: TextAlign.center,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                    fontFamily: ScFonts.display,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: c.text,
                  ),
                  decoration: InputDecoration(
                    suffixText: 'g',
                    filled: true,
                    fillColor: c.bg3,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onChanged: (String v) {
                    final double? parsed =
                        double.tryParse(v.trim().replaceAll(',', '.'));
                    if (parsed != null && parsed > 0) {
                      setState(() => _grams = parsed.clamp(1.0, 5000.0));
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  unawaited(HapticFeedback.selectionClick());
                  _setGrams(_grams + 25);
                },
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(context.l10n.food25G2),
              ),
            ],
          ),

          if (_grams <= 600) ...<Widget>[
            Slider(
              value: _grams.clamp(5.0, 600.0),
              min: 5.0,
              max: 600.0,
              divisions: 119,
              label: context.l10n.foodG10(_grams.round().toString()),
              onChanged: _setGrams,
            ),
          ] else
            const SizedBox(height: 14),

          Text(
            context.l10n.foodMoverAOtroMomento,
            style: TextStyle(
              fontFamily: ScFonts.display,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: c.text,
            ),
          ),
          const SizedBox(height: 8),
          MealSlotSelectorGrid(
            selectedMealType: _mealType,
            compact: true,
            onSelected: (MealType nextMeal) {
              setState(() => _mealType = nextMeal);
            },
          ),

          const SizedBox(height: 20),

          Row(
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: _isSaving
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        widget.onDeleteRequested();
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.isFlat ? c.text : c.danger,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(AppIcons.delete, size: 18),
                label: Text(context.l10n.commonDelete),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isSaving
                      ? null
                      : () async {
                          setState(() => _isSaving = true);
                          unawaited(HapticFeedback.lightImpact());
                          await ref.read(foodCatalogServiceProvider).updateLogEntry(
                                log: log,
                                food: food,
                                grams: _grams,
                                mealType: _mealType,
                              );
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: c.ink,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(AppIcons.check, size: 18),
                  label: Text(
                    context.l10n.foodGuardarCambios,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

