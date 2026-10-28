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
import '../../application/food_catalog_service.dart';
import '../../application/food_logging_service.dart';
import 'food_detail_parts.dart';
import 'meal_slot_selector.dart';

/// Subpágina de detalle nutricional, ajuste de gramos y registro en 1 toque.
class FoodDetailSheet extends ConsumerStatefulWidget {
  const FoodDetailSheet({
    super.key,
    required this.food,
    required this.initialMealType,
    required this.targetDateKey,
    this.onLogged,
  });

  final FoodItem food;
  final MealType initialMealType;
  final String targetDateKey;
  final VoidCallback? onLogged;

  @override
  ConsumerState<FoodDetailSheet> createState() => _FoodDetailSheetState();
}

class _FoodDetailSheetState extends ConsumerState<FoodDetailSheet> {
  late double _grams;
  late MealType _mealType;
  late bool _isFavorite;
  late final TextEditingController _gramsController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _grams = widget.food.defaultServingGrams > 0 ? widget.food.defaultServingGrams : 100.0;
    _mealType = widget.initialMealType;
    _isFavorite = widget.food.isFavorite;
    _gramsController = TextEditingController(text: NumberFormats.input(_grams, maxDigits: 0));
  }

  @override
  void dispose() {
    _gramsController.dispose();
    super.dispose();
  }

  double get _ratio => _grams / 100.0;

  double get _kcal => widget.food.kcalPer100g * _ratio;
  double get _protein => widget.food.proteinPer100g * _ratio;
  double get _carbs => widget.food.carbsPer100g * _ratio;
  double get _fat => widget.food.fatPer100g * _ratio;
  double get _fiber => widget.food.fiberPer100g * _ratio;
  double get _sugar => widget.food.sugarPer100g * _ratio;
  double get _netCarbs => (_carbs - _fiber).clamp(0.0, double.infinity);

  double get _sodium => widget.food.sodiumMgPer100g * _ratio;
  double get _potassium => widget.food.potassiumMgPer100g * _ratio;
  double get _magnesium => widget.food.magnesiumMgPer100g * _ratio;

  bool get _isLabelSource =>
      widget.food.source == FoodSource.openFoodFacts || widget.food.source == FoodSource.userCustom;

  void _updateGrams(double newVal) {
    final double clamped = newVal.clamp(1.0, 5000.0);
    setState(() {
      _grams = clamped;
      _gramsController.text = NumberFormats.input(clamped, maxDigits: 0);
    });
  }

  Future<void> _toggleFavorite() async {
    unawaited(HapticFeedback.selectionClick());
    final bool next = !_isFavorite;
    setState(() => _isFavorite = next);
    await ref.read(foodCatalogServiceProvider).setFavorite(widget.food, favorite: next);
  }

  Future<void> _saveLog() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      unawaited(HapticFeedback.mediumImpact());

      await ref
          .read(foodLoggingServiceProvider)
          .logPortion(
            food: widget.food,
            grams: _grams,
            mealType: _mealType,
            dateKey: widget.targetDateKey,
          );

      if (!mounted) return;
      widget.onLogged?.call();
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  List<({String label, double grams})> _buildPortionPresets() {
    final List<({String label, double grams})> presets = <({String label, double grams})>[];
    final double baseGrams = widget.food.defaultServingGrams;
    final String baseLabel = widget.food.servingLabel.trim();

    if (baseGrams > 0 &&
        (baseGrams != 100.0 || (baseLabel.isNotEmpty && baseLabel.toLowerCase() != '100g'))) {
      presets.add((
        label: baseLabel.isNotEmpty
            ? context.l10n.foodG2((baseLabel).toString(), baseGrams.round().toString())
            : context.l10n.foodG3(NumberFormats.group(baseGrams)),
        grams: baseGrams,
      ));
    }

    for (final double g in const <double>[50, 100, 150, 200, 250, 300]) {
      final bool duplicate = presets.any((p) => (p.grams - g).abs() < 0.5);
      if (!duplicate) {
        presets.add((label: context.l10n.foodG(g.toInt().toString()), grams: g));
      }
    }
    return presets;
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final MealSlotMeta selectedSlot = MealSlotMeta.of(_mealType);

    final double pKcal = _protein * 4.0;
    final double cKcal = _carbs * 4.0;
    final double fKcal = _fat * 9.0;
    final double macroTotalKcal = pKcal + cKcal + fKcal;
    final int pPct = macroTotalKcal > 0 ? ((pKcal / macroTotalKcal) * 100).round() : 0;
    final int cPct = macroTotalKcal > 0 ? ((cKcal / macroTotalKcal) * 100).round() : 0;
    final int fPct = macroTotalKcal > 0 ? (100 - pPct - cPct).clamp(0, 100) : 0;

    final bool unreportedPotassium = _isLabelSource && widget.food.potassiumMgPer100g <= 0.0;
    final bool unreportedMagnesium = _isLabelSource && widget.food.magnesiumMgPer100g <= 0.0;

    return Container(
      decoration: BoxDecoration(
        color: c.bg2,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: c.isFlat ? Border(top: BorderSide(color: c.line2, width: 1.5)) : null,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(color: c.line2, borderRadius: BorderRadius.circular(2)),
                ),
              ),

              // 1. Encabezado sin truncamiento + Favorito + Cerrar
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.food.name,
                          softWrap: true,
                          style: TextStyle(
                            fontFamily: ScFonts.display,
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            color: c.text,
                            height: 1.2,
                          ),
                        ),
                        if (widget.food.brand != null &&
                            widget.food.brand!.trim().isNotEmpty) ...<Widget>[
                          const SizedBox(height: 4),
                          Text(
                            widget.food.brand!.trim(),
                            softWrap: true,
                            style: TextStyle(
                              fontFamily: ScFonts.ui,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: c.text2,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: <Widget>[
                            FoodSourceBadge(source: widget.food.source),
                            if (widget.food.nutriScore != null &&
                                widget.food.nutriScore!.trim().isNotEmpty)
                              NutriScoreBadge(grade: widget.food.nutriScore!),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: _isFavorite
                        ? context.l10n.foodQuitarDeFavoritos
                        : context.l10n.foodGuardarEnFavoritos,
                    onPressed: _toggleFavorite,
                    icon: Icon(
                      _isFavorite ? AppIcons.starFilled : AppIcons.star,
                      color: _isFavorite ? c.carbs : c.text2,
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.commonClose,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(AppIcons.close, color: c.text2),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // 2. Tarjeta Hero de Energía y Distribución de Macros
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: c.bg3,
                  borderRadius: BorderRadius.circular(20),
                  border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                context.l10n.foodEnergiaDeLaPorcion,
                                style: TextStyle(
                                  fontFamily: ScFonts.ui,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: c.text2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              RichText(
                                text: TextSpan(
                                  text: '${_kcal.round()}',
                                  style: TextStyle(
                                    fontFamily: ScFonts.display,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    color: c.isFlat ? c.text : c.calories,
                                  ),
                                  children: <InlineSpan>[
                                    TextSpan(
                                      text: context.l10n.foodKcal,
                                      style: TextStyle(
                                        fontFamily: ScFonts.ui,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: c.text2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: c.bg2,
                            borderRadius: BorderRadius.circular(12),
                            border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
                          ),
                          child: Text(
                            context.l10n.foodParaG(NumberFormats.group(_grams)),
                            style: TextStyle(
                              fontFamily: ScFonts.display,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: c.text,
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (macroTotalKcal > 0) ...<Widget>[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          height: 8,
                          child: Row(
                            children: <Widget>[
                              if (pPct > 0)
                                Expanded(
                                  flex: pPct,
                                  child: Container(color: c.isFlat ? c.text : c.protein),
                                ),
                              if (cPct > 0)
                                Expanded(
                                  flex: cPct,
                                  child: Container(color: c.isFlat ? c.text2 : c.carbs),
                                ),
                              if (fPct > 0)
                                Expanded(
                                  flex: fPct,
                                  child: Container(color: c.isFlat ? c.bg3 : c.fat),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: <Widget>[
                          MacroLegendDot(
                            color: c.isFlat ? c.text : c.protein,
                            label: context.l10n.foodProteina((pPct).toString()),
                          ),
                          MacroLegendDot(
                            color: c.isFlat ? c.text2 : c.carbs,
                            label: context.l10n.foodCarbos((cPct).toString()),
                          ),
                          MacroLegendDot(
                            color: c.isFlat ? c.bg3 : c.fat,
                            label: context.l10n.foodGrasas((fPct).toString()),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Cuadrícula 2×2 amplia de macros (cero texto cortado)
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: MacroDetailBox(
                            title: context.l10n.todayProteina,
                            value: context.l10n.foodG4(NumberFormats.fixed(_protein, 1)),
                            sublabel: context.l10n.foodG100g(
                              NumberFormats.fixed(widget.food.proteinPer100g, 1),
                            ),
                            accentColor: c.isFlat ? c.text : c.protein,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: MacroDetailBox(
                            title: context.l10n.todayCarbohidratos,
                            value: context.l10n.foodG5(NumberFormats.fixed(_carbs, 1)),
                            sublabel: context.l10n.foodNetosG(
                              NumberFormats.fixed(_netCarbs, 1),
                            ),
                            accentColor: c.isFlat ? c.text : c.carbs,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: MacroDetailBox(
                            title: context.l10n.foodGrasasTotales,
                            value: context.l10n.foodG6(NumberFormats.fixed(_fat, 1)),
                            sublabel: context.l10n.foodG100g(
                              NumberFormats.fixed(widget.food.fatPer100g, 1),
                            ),
                            accentColor: c.isFlat ? c.text : c.fat,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: MacroDetailBox(
                            title: context.l10n.foodFibraYAzucar,
                            value: context.l10n.foodGFibra(NumberFormats.fixed(_fiber, 1)),
                            sublabel: context.l10n.foodGAzucares(
                              NumberFormats.fixed(_sugar, 1),
                            ),
                            accentColor: c.isFlat ? c.text : c.steps,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 3. Selector Táctil de Cantidad (Gramos)
              Text(
                context.l10n.foodCantidadARegistrar,
                style: TextStyle(
                  fontFamily: ScFonts.display,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  GramStepButton(label: '-25', onTap: () => _updateGrams(_grams - 25)),
                  const SizedBox(width: 6),
                  GramStepButton(label: '-10', onTap: () => _updateGrams(_grams - 10)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _gramsController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                      decoration: InputDecoration(
                        suffixText: 'g',
                        filled: true,
                        fillColor: c.bg3,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onChanged: (String val) {
                        final double? parsed = double.tryParse(val.replaceAll(',', '.'));
                        if (parsed != null && parsed > 0) {
                          setState(() => _grams = parsed.clamp(1.0, 5000.0));
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  GramStepButton(label: '+10', onTap: () => _updateGrams(_grams + 10)),
                  const SizedBox(width: 6),
                  GramStepButton(label: '+25', onTap: () => _updateGrams(_grams + 25)),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _buildPortionPresets().map((preset) {
                  final bool isSelected = (_grams - preset.grams).abs() < 0.5;
                  return ChoiceChip(
                    label: Text(preset.label),
                    selected: isSelected,
                    onSelected: (_) {
                      unawaited(HapticFeedback.selectionClick());
                      _updateGrams(preset.grams);
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 18),

              // 4. Selector de Momento del Día (2×2 sin texto encogido)
              Text(
                context.l10n.foodMomentoDeComida,
                style: TextStyle(
                  fontFamily: ScFonts.display,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 10),
              MealSlotSelectorGrid(
                selectedMealType: _mealType,
                onSelected: (MealType nextMeal) {
                  setState(() => _mealType = nextMeal);
                },
              ),

              const SizedBox(height: 18),

              // 5. Triángulo Electrolítico con Regla de Honestidad de Datos
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.bg3.withValues(alpha: c.isFlat ? 1.0 : 0.7),
                  borderRadius: BorderRadius.circular(16),
                  border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(AppIcons.bolt, size: 17, color: c.accent),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            context.l10n.foodElectrolitosEnEstaPorcion,
                            softWrap: true,
                            style: TextStyle(
                              fontFamily: ScFonts.display,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: c.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ElectrolyteDetailRow(
                      label: context.l10n.foodSodioNa,
                      valueText: context.l10n.foodMg(NumberFormats.group(_sodium)),
                      isReported: true,
                    ),
                    const SizedBox(height: 6),
                    ElectrolyteDetailRow(
                      label: context.l10n.foodPotasioK,
                      valueText: unreportedPotassium
                          ? context.l10n.foodDatoNoReportado
                          : context.l10n.foodMg2(NumberFormats.group(_potassium)),
                      isReported: !unreportedPotassium,
                    ),
                    const SizedBox(height: 6),
                    ElectrolyteDetailRow(
                      label: context.l10n.foodMagnesioMg,
                      valueText: unreportedMagnesium
                          ? context.l10n.foodDatoNoReportado
                          : context.l10n.foodMg3(NumberFormats.group(_magnesium)),
                      isReported: !unreportedMagnesium,
                    ),
                    if (unreportedPotassium || unreportedMagnesium) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.foodLasEtiquetasComercialesSuelenDeclarar,
                        softWrap: true,
                        style: TextStyle(fontFamily: ScFonts.ui, fontSize: 11.5, color: c.text3),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 6. CTA Inferior Cómodo
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _saveLog,
                  style: FilledButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: c.ink,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: _isSaving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: c.ink),
                        )
                      : const Icon(AppIcons.check),
                  label: Text(
                    context.l10n.foodRegistrarEnKcal(
                      selectedSlot.title(context.l10n).toString(),
                      NumberFormats.group(_kcal),
                    ),
                    style: const TextStyle(
                      fontFamily: ScFonts.display,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
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
