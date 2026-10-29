import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/models/food_models.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/utils/number_formats.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../application/food_catalog_service.dart';
import '../../application/food_logging_service.dart';
import 'meal_slot_selector.dart';

/// Subpágina de gestión y escalado proporcional (0.25x – 3.0x) de Combos Caseros.
class CombosModalSheet extends ConsumerStatefulWidget {
  const CombosModalSheet({super.key, required this.dateKey, required this.initialMealType});

  final String dateKey;
  final MealType initialMealType;

  @override
  ConsumerState<CombosModalSheet> createState() => _CombosModalSheetState();
}

class _CombosModalSheetState extends ConsumerState<CombosModalSheet> {
  double _multiplier = 1.0;
  late MealType _mealType;

  static const List<double> _quickStops = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _mealType = widget.initialMealType;
  }

  String _formatMultiplier(double m) {
    if ((m - m.roundToDouble()).abs() < 0.01) {
      return '${NumberFormats.fixed(m, 1)}x';
    }
    return '${NumberFormats.fixed(m, 2)}x';
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final List<MealComboWithDetails> combos =
        ref.watch(mealCombosProvider).value ?? const <MealComboWithDetails>[];
    return Builder(
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(AppIcons.combos, color: c.accent, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.foodMisCombosCaseros,
                      softWrap: true,
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.commonClose,
                    icon: Icon(AppIcons.close, color: c.text2),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              if (combos.isEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: c.bg3,
                    borderRadius: BorderRadius.circular(18),
                    border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        context.l10n.foodAunNoHasGuardadoCombos,
                        style: TextStyle(
                          fontFamily: ScFonts.display,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: c.text,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.l10n.foodCuandoRegistres2OMas,
                        softWrap: true,
                        style: TextStyle(
                          fontFamily: ScFonts.ui,
                          fontSize: 13,
                          color: c.text2,
                          height: 1.38,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...<Widget>[
                Text(
                  context.l10n.foodEligeElMomentoDelDia,
                  softWrap: true,
                  style: TextStyle(fontFamily: ScFonts.ui, fontSize: 12.5, color: c.text2),
                ),
                const SizedBox(height: 12),

                MealSlotSelectorGrid(
                  selectedMealType: _mealType,
                  compact: true,
                  onSelected: (MealType nextMeal) {
                    setState(() => _mealType = nextMeal);
                  },
                ),

                const SizedBox(height: 14),

                // Control de multiplicador 0.25x - 3.0x
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  decoration: BoxDecoration(
                    color: c.bg3,
                    borderRadius: BorderRadius.circular(16),
                    border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              context.l10n.foodTamanoDeLaPorcion,
                              softWrap: true,
                              style: TextStyle(
                                fontFamily: ScFonts.ui,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: c.text,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: c.bg2,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: c.isFlat ? c.line2 : c.accent),
                            ),
                            child: Text(
                              _formatMultiplier(_multiplier),
                              style: TextStyle(
                                fontFamily: ScFonts.display,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: c.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _multiplier,
                        min: 0.25,
                        max: 3.0,
                        divisions: 11,
                        label: _formatMultiplier(_multiplier),
                        onChanged: (double val) => setState(() => _multiplier = val),
                      ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _quickStops.map((double stop) {
                          final bool active = (_multiplier - stop).abs() < 0.02;
                          return ChoiceChip(
                            label: Text(_formatMultiplier(stop)),
                            selected: active,
                            visualDensity: VisualDensity.compact,
                            onSelected: (_) {
                              unawaited(HapticFeedback.selectionClick());
                              setState(() => _multiplier = stop);
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                for (final MealComboWithDetails item in combos)
                  _ComboCardItem(
                    detail: item,
                    multiplier: _multiplier,
                    multiplierText: _formatMultiplier(_multiplier),
                    onDelete: () => ref.read(foodCatalogServiceProvider).deleteCombo(item.combo.id),
                    onLog: () async {
                      unawaited(HapticFeedback.mediumImpact());
                      await ref
                          .read(foodLoggingServiceProvider)
                          .logCombo(
                            comboId: item.combo.id,
                            multiplier: _multiplier,
                            mealType: _mealType,
                            dateKey: widget.dateKey,
                          );
                      if (context.mounted) {
                        final MealSlotMeta slot = MealSlotMeta.of(_mealType);
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content: Text(
                                context.l10n.foodComboAnadidoA(
                                  item.combo.name.toString(),
                                  _formatMultiplier(_multiplier).toString(),
                                  slot.title(context.l10n).toString(),
                                ),
                              ),
                            ),
                          );
                      }
                    },
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ComboCardItem extends StatelessWidget {
  const _ComboCardItem({
    required this.detail,
    required this.multiplier,
    required this.multiplierText,
    required this.onDelete,
    required this.onLog,
  });

  final MealComboWithDetails detail;
  final double multiplier;
  final String multiplierText;
  final VoidCallback onDelete;
  final VoidCallback onLog;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final int scaledKcal = (detail.baseKcal * multiplier).round();
    final double scaledP = detail.baseProteinG * multiplier;
    final double scaledC = detail.baseCarbsG * multiplier;
    final double scaledF = detail.baseFatG * multiplier;

    final String ingredientsSummary = detail.ingredients
        .map(
          (MealComboIngredientDetail ing) => context.l10n.foodG12(
            ing.foodItem.name.toString(),
            NumberFormats.group(ing.baseGrams * multiplier),
          ),
        )
        .join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.bg3,
        borderRadius: BorderRadius.circular(18),
        border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
      ),
      child: Column(
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
                      detail.combo.name,
                      softWrap: true,
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.foodUsadoVeces(detail.combo.timesUsed.toString()),
                      style: TextStyle(fontFamily: ScFonts.ui, fontSize: 11.5, color: c.text3),
                    ),
                  ],
                ),
              ),
              Text(
                context.l10n.foodKcal4(NumberFormats.group(scaledKcal)),
                style: TextStyle(
                  fontFamily: ScFonts.display,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: c.isFlat ? c.text : c.calories,
                ),
              ),
            ],
          ),
          if (ingredientsSummary.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              ingredientsSummary,
              softWrap: true,
              style: TextStyle(fontFamily: ScFonts.ui, fontSize: 12.5, color: c.text2, height: 1.3),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            context.l10n.foodPGCGG3(
              NumberFormats.fixed(scaledP, 0),
              NumberFormats.fixed(scaledC, 0),
              NumberFormats.fixed(scaledF, 0),
            ),
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: c.text2,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              IconButton(
                tooltip: context.l10n.foodEliminarCombo,
                visualDensity: VisualDensity.compact,
                onPressed: onDelete,
                icon: Icon(AppIcons.delete, size: 19, color: c.text3),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onLog,
                  style: FilledButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: c.ink,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(AppIcons.add, size: 18),
                  label: Text(
                    context.l10n.foodRegistrar((multiplierText).toString()),
                    style: const TextStyle(fontWeight: FontWeight.w700),
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
