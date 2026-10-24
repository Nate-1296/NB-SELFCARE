import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/food_dao.dart';
import '../../../../core/database/daos/pet_dao.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/widgets/app_icons.dart';
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
  final String initialMealType;
  final String targetDateKey;
  final VoidCallback? onLogged;

  @override
  ConsumerState<FoodDetailSheet> createState() => _FoodDetailSheetState();
}

class _FoodDetailSheetState extends ConsumerState<FoodDetailSheet> {
  late double _grams;
  late String _mealType;
  late bool _isFavorite;
  late final TextEditingController _gramsController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _grams = widget.food.defaultServingGrams > 0
        ? widget.food.defaultServingGrams
        : 100.0;
    _mealType = widget.initialMealType;
    _isFavorite = widget.food.isFavorite;
    _gramsController = TextEditingController(text: _grams.toStringAsFixed(0));
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
      widget.food.source == 'open_food_facts' ||
      widget.food.source == 'user_custom';

  void _updateGrams(double newVal) {
    final double clamped = newVal.clamp(1.0, 5000.0);
    setState(() {
      _grams = clamped;
      _gramsController.text = clamped.toStringAsFixed(0);
    });
  }

  Future<void> _toggleFavorite() async {
    unawaited(HapticFeedback.selectionClick());
    final bool next = !_isFavorite;
    setState(() => _isFavorite = next);
    await ref.read(foodDaoProvider).toggleFavorite(widget.food.id, next);
  }

  Future<void> _saveLog() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      unawaited(HapticFeedback.mediumImpact());
      final FoodDao foodDao = ref.read(foodDaoProvider);
      final PetDao petDao = ref.read(petDaoProvider);

      await foodDao.logFoodItemPortion(
        food: widget.food,
        grams: _grams,
        dateKey: widget.targetDateKey,
        mealType: _mealType,
      );

      await petDao.grantDailyReward(
        dateKey: widget.targetDateKey,
        actionType: 'meal_log_$_mealType',
        baseAmount: AppConstants.coinsMealLog,
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
    final List<({String label, double grams})> presets =
        <({String label, double grams})>[];
    final double baseGrams = widget.food.defaultServingGrams;
    final String baseLabel = widget.food.servingLabel.trim();

    if (baseGrams > 0 &&
        (baseGrams != 100.0 ||
            (baseLabel.isNotEmpty && baseLabel.toLowerCase() != '100g'))) {
      presets.add((
        label: baseLabel.isNotEmpty
            ? '$baseLabel (${baseGrams.round()}g)'
            : '${baseGrams.round()} g',
        grams: baseGrams,
      ));
    }

    for (final double g in const <double>[50, 100, 150, 200, 250, 300]) {
      final bool duplicate =
          presets.any((p) => (p.grams - g).abs() < 0.5);
      if (!duplicate) {
        presets.add((label: '${g.toInt()} g', grams: g));
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

    final bool unreportedPotassium =
        _isLabelSource && widget.food.potassiumMgPer100g <= 0.0;
    final bool unreportedMagnesium =
        _isLabelSource && widget.food.magnesiumMgPer100g <= 0.0;

    return Container(
      decoration: BoxDecoration(
        color: c.bg2,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: c.isFlat
            ? Border(top: BorderSide(color: c.line2, width: 1.5))
            : null,
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
                  decoration: BoxDecoration(
                    color: c.line2,
                    borderRadius: BorderRadius.circular(2),
                  ),
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
                            fontWeight: FontWeight.w800,
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
                        ? 'Quitar de favoritos'
                        : 'Guardar en favoritos',
                    onPressed: _toggleFavorite,
                    icon: Icon(
                      _isFavorite ? AppIcons.starFilled : AppIcons.star,
                      color: _isFavorite ? c.carbs : c.text2,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
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
                  border: Border.all(
                    color: c.isFlat ? c.line2 : c.line,
                    width: c.isFlat ? 1.5 : 1.0,
                  ),
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
                                'Energía de la porción',
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
                                    fontWeight: FontWeight.w800,
                                    color: c.isFlat ? c.text : c.calories,
                                  ),
                                  children: <InlineSpan>[
                                    TextSpan(
                                      text: ' kcal',
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: c.bg2,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: c.isFlat ? c.line2 : c.line,
                            ),
                          ),
                          child: Text(
                            'Para ${_grams.round()} g',
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
                                  child: Container(
                                    color: c.isFlat ? c.text : c.protein,
                                  ),
                                ),
                              if (cPct > 0)
                                Expanded(
                                  flex: cPct,
                                  child: Container(
                                    color: c.isFlat ? c.text2 : c.carbs,
                                  ),
                                ),
                              if (fPct > 0)
                                Expanded(
                                  flex: fPct,
                                  child: Container(
                                    color: c.isFlat ? c.line2 : c.fat,
                                  ),
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
                          _LegendDot(
                            color: c.isFlat ? c.text : c.protein,
                            label: 'Proteína $pPct%',
                          ),
                          _LegendDot(
                            color: c.isFlat ? c.text2 : c.carbs,
                            label: 'Carbos $cPct%',
                          ),
                          _LegendDot(
                            color: c.isFlat ? c.line2 : c.fat,
                            label: 'Grasas $fPct%',
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Cuadrícula 2×2 amplia de macros (cero texto cortado)
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _MacroDetailBox(
                            title: 'Proteína',
                            value: '${_protein.toStringAsFixed(1)} g',
                            sublabel:
                                '${widget.food.proteinPer100g.toStringAsFixed(1)} g / 100g',
                            accentColor: c.isFlat ? c.text : c.protein,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MacroDetailBox(
                            title: 'Carbohidratos',
                            value: '${_carbs.toStringAsFixed(1)} g',
                            sublabel:
                                'Netos: ${_netCarbs.toStringAsFixed(1)} g',
                            accentColor: c.isFlat ? c.text : c.carbs,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _MacroDetailBox(
                            title: 'Grasas totales',
                            value: '${_fat.toStringAsFixed(1)} g',
                            sublabel:
                                '${widget.food.fatPer100g.toStringAsFixed(1)} g / 100g',
                            accentColor: c.isFlat ? c.text : c.fat,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MacroDetailBox(
                            title: 'Fibra y Azúcar',
                            value: '${_fiber.toStringAsFixed(1)} g fibra',
                            sublabel:
                                '${_sugar.toStringAsFixed(1)} g azúcares',
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
                'Cantidad a registrar',
                style: TextStyle(
                  fontFamily: ScFonts.display,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  _GramStepButton(
                    label: '-25',
                    onTap: () => _updateGrams(_grams - 25),
                  ),
                  const SizedBox(width: 6),
                  _GramStepButton(
                    label: '-10',
                    onTap: () => _updateGrams(_grams - 10),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _gramsController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 19,
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
                      onChanged: (String val) {
                        final double? parsed =
                            double.tryParse(val.replaceAll(',', '.'));
                        if (parsed != null && parsed > 0) {
                          setState(() => _grams = parsed.clamp(1.0, 5000.0));
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  _GramStepButton(
                    label: '+10',
                    onTap: () => _updateGrams(_grams + 10),
                  ),
                  const SizedBox(width: 6),
                  _GramStepButton(
                    label: '+25',
                    onTap: () => _updateGrams(_grams + 25),
                  ),
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
                'Momento de comida',
                style: TextStyle(
                  fontFamily: ScFonts.display,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 10),
              MealSlotSelectorGrid(
                selectedMealType: _mealType,
                onSelected: (String nextMeal) {
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
                  border: Border.all(
                    color: c.isFlat ? c.line2 : c.line,
                    width: c.isFlat ? 1.4 : 1.0,
                  ),
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
                            'Electrolitos en esta porción',
                            softWrap: true,
                            style: TextStyle(
                              fontFamily: ScFonts.display,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: c.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _ElectrolyteDetailRow(
                      label: 'Sodio (Na)',
                      valueText: '${_sodium.round()} mg',
                      isReported: true,
                    ),
                    const SizedBox(height: 6),
                    _ElectrolyteDetailRow(
                      label: 'Potasio (K)',
                      valueText: unreportedPotassium
                          ? 'Dato no reportado'
                          : '${_potassium.round()} mg',
                      isReported: !unreportedPotassium,
                    ),
                    const SizedBox(height: 6),
                    _ElectrolyteDetailRow(
                      label: 'Magnesio (Mg)',
                      valueText: unreportedMagnesium
                          ? 'Dato no reportado'
                          : '${_magnesium.round()} mg',
                      isReported: !unreportedMagnesium,
                    ),
                    if (unreportedPotassium || unreportedMagnesium) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        'Las etiquetas comerciales suelen declarar sodio pero omiten potasio o magnesio.',
                        softWrap: true,
                        style: TextStyle(
                          fontFamily: ScFonts.ui,
                          fontSize: 11.5,
                          color: c.text3,
                        ),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: _isSaving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: c.ink,
                          ),
                        )
                      : const Icon(AppIcons.check),
                  label: Text(
                    'Registrar en ${selectedSlot.title} · ${_kcal.round()} kcal',
                    style: const TextStyle(
                      fontFamily: ScFonts.display,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
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

class _MacroDetailBox extends StatelessWidget {
  const _MacroDetailBox({
    required this.title,
    required this.value,
    required this.sublabel,
    required this.accentColor,
  });

  final String title;
  final String value;
  final String sublabel;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: c.isFlat ? c.line2 : c.line,
          width: c.isFlat ? 1.3 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            softWrap: true,
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: c.text2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            softWrap: true,
            style: TextStyle(
              fontFamily: ScFonts.display,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sublabel,
            softWrap: true,
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 11,
              color: c.text3,
            ),
          ),
        ],
      ),
    );
  }
}

class _GramStepButton extends StatelessWidget {
  const _GramStepButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Material(
      color: c.bg3,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          unawaited(HapticFeedback.selectionClick());
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: c.isFlat ? c.line2 : c.line,
              width: c.isFlat ? 1.4 : 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: ScFonts.display,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: c.text,
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontFamily: ScFonts.ui,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: c.text2,
          ),
        ),
      ],
    );
  }
}

class _ElectrolyteDetailRow extends StatelessWidget {
  const _ElectrolyteDetailRow({
    required this.label,
    required this.valueText,
    required this.isReported,
  });

  final String label;
  final String valueText;
  final bool isReported;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            softWrap: true,
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: c.text2,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          valueText,
          style: TextStyle(
            fontFamily: ScFonts.display,
            fontSize: 12.5,
            fontWeight: isReported ? FontWeight.w800 : FontWeight.w600,
            fontStyle: isReported ? FontStyle.normal : FontStyle.italic,
            color: isReported ? c.text : c.text3,
          ),
        ),
      ],
    );
  }
}
