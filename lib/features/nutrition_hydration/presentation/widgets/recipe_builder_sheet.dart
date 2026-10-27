import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/models/recipe_models.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/sheet.dart';
import '../../application/food_catalog_service.dart';
import '../../application/food_logging_service.dart';
import 'ingredient_picker_sheet.dart';
import 'meal_slot_selector.dart';

/// Borrador en memoria de un ingrediente seleccionado para una receta.
class _RecipeIngredientItem {
  _RecipeIngredientItem({
    required this.food,
    required this.rawGrams,
  });

  final FoodItem food;
  double rawGrams;

  double get ratio => rawGrams / 100.0;
  double get kcal => food.kcalPer100g * ratio;
  double get proteinG => food.proteinPer100g * ratio;
  double get carbsG => food.carbsPer100g * ratio;
  double get fatG => food.fatPer100g * ratio;
  double get fiberG => food.fiberPer100g * ratio;
  double get sodiumMg => food.sodiumMgPer100g * ratio;
}

/// Hoja modal para la creación de recetas caseras multiración (Batch Cooking & Meal Prep).
class RecipeBuilderSheet extends ConsumerStatefulWidget {
  const RecipeBuilderSheet({
    super.key,
    required this.targetDateKey,
    this.initialMealType = MealType.lunch,
  });

  final String targetDateKey;
  final MealType initialMealType;

  static Future<Recipe?> show(
    BuildContext context, {
    required String targetDateKey,
    MealType initialMealType = MealType.lunch,
  }) {
    return mostrarHojaMenu<Recipe?>(
      context,
      builder: (_) => RecipeBuilderSheet(
        targetDateKey: targetDateKey,
        initialMealType: initialMealType,
      ),
    );
  }

  @override
  ConsumerState<RecipeBuilderSheet> createState() => _RecipeBuilderSheetState();
}

class _RecipeBuilderSheetState extends ConsumerState<RecipeBuilderSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _servingsCtrl = TextEditingController(text: '4');
  final TextEditingController _cookedWeightCtrl = TextEditingController();

  late MealType _mealType;
  bool _useCookedWeightMode = false;
  bool _logImmediately = true;
  bool _isSaving = false;

  final List<_RecipeIngredientItem> _ingredients = <_RecipeIngredientItem>[];

  @override
  void initState() {
    super.initState();
    _mealType = widget.initialMealType;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _servingsCtrl.dispose();
    _cookedWeightCtrl.dispose();
    super.dispose();
  }

  int get _servings => int.tryParse(_servingsCtrl.text) ?? 1;

  double get _totalKcal =>
      _ingredients.fold(0.0, (double sum, _RecipeIngredientItem i) => sum + i.kcal);
  double get _totalProtein =>
      _ingredients.fold(0.0, (double sum, _RecipeIngredientItem i) => sum + i.proteinG);
  double get _totalCarbs =>
      _ingredients.fold(0.0, (double sum, _RecipeIngredientItem i) => sum + i.carbsG);
  double get _totalFat =>
      _ingredients.fold(0.0, (double sum, _RecipeIngredientItem i) => sum + i.fatG);
  double get _totalRawWeight =>
      _ingredients.fold(0.0, (double sum, _RecipeIngredientItem i) => sum + i.rawGrams);

  double get _servingKcal => _servings > 0 ? _totalKcal / _servings : 0.0;
  double get _servingProtein => _servings > 0 ? _totalProtein / _servings : 0.0;
  double get _servingCarbs => _servings > 0 ? _totalCarbs / _servings : 0.0;
  double get _servingFat => _servings > 0 ? _totalFat / _servings : 0.0;

  Future<void> _pickIngredient() async {
    final FoodItem? selected = await showModalBottomSheet<FoodItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const IngredientPickerSheet(),
    );

    if (selected != null && mounted) {
      final double? grams = await _promptIngredientGrams(selected);
      if (grams != null && grams > 0 && mounted) {
        setState(() {
          _ingredients.add(
            _RecipeIngredientItem(food: selected, rawGrams: grams),
          );
        });
      }
    }
  }

  Future<double?> _promptIngredientGrams(FoodItem food) async {
    final TextEditingController gramsCtrl = TextEditingController(
      text: food.defaultServingGrams > 0
          ? food.defaultServingGrams.toStringAsFixed(0)
          : '100',
    );
    return showDialog<double>(
      context: context,
      builder: (BuildContext ctx) {
        final ScColors c = ctx.sc;
        return AlertDialog(
          backgroundColor: c.bg2,
          title: Text(context.l10n.foodCantidadDe(food.name.toString())),
          content: TextField(
            controller: gramsCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              labelText: context.l10n.foodGramosCrudos,
              suffixText: 'g',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(context.l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () {
                final double? g = double.tryParse(
                  gramsCtrl.text.trim().replaceAll(',', '.'),
                );
                Navigator.of(ctx).pop(g);
              },
              child: Text(context.l10n.comerAnadir),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) return;
    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.foodAnadeAlMenosUnIngrediente),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    unawaited(HapticFeedback.mediumImpact());

    try {
      final double? cookedGrams = _useCookedWeightMode
          ? double.tryParse(
              _cookedWeightCtrl.text.trim().replaceAll(',', '.'),
            )
          : null;

      final List<RecipeIngredientDraft> drafts = _ingredients.map((_RecipeIngredientItem i) {
        return RecipeIngredientDraft(
          foodItemId: i.food.id,
          rawGrams: i.rawGrams,
        );
      }).toList();

      final Recipe? createdRecipe = await ref.read(foodCatalogServiceProvider).createRecipe(
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
        defaultMealType: _mealType,
        servings: _servings,
        cookedTotalWeightGrams: cookedGrams,
        ingredients: drafts,
      );

      // Si el usuario marcó registrar 1 porción hoy
      if (_logImmediately && createdRecipe != null) {
        await ref.read(foodLoggingServiceProvider).logRecipeServing(
              recipe: createdRecipe,
              mealType: _mealType,
              dateKey: widget.targetDateKey,
            );
      }

      if (mounted) {
        Navigator.of(context).pop(createdRecipe);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.foodRecetaGuardadaExitosamente(_nameCtrl.text.trim().toString()),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.foodErrorAlGuardarLaReceta((e).toString()))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Encabezado
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    context.l10n.foodNuevaRecetaBatchCooking,
                    style: TextStyle(
                      fontFamily: ScFonts.display,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: c.text,
                    ),
                  ),
                  IconButton(
                    icon: Icon(AppIcons.close, color: c.text2),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Nombre de la receta
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: context.l10n.foodNombreDeLaRecetaEj,
                  prefixIcon: const Icon(Icons.soup_kitchen_rounded),
                ),
                validator: (String? val) {
                  if (val == null || val.trim().isEmpty) {
                    return context.l10n.foodIntroduceUnNombreParaLa;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Comida destino predeterminada
              MealSlotSelectorGrid(
                selectedMealType: _mealType,
                compact: true,
                onSelected: (MealType m) => setState(() => _mealType = m),
              ),
              const SizedBox(height: 14),

              // Modo de Rendimiento / Porciones
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.bg3,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: c.isFlat ? c.line2 : c.line,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          context.l10n.foodRendimientoYRaciones,
                          style: TextStyle(
                            fontFamily: ScFonts.display,
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: c.text,
                          ),
                        ),
                        Row(
                          children: <Widget>[
                            Text(
                              _useCookedWeightMode ? context.l10n.foodPorPeso: context.l10n.foodPorPlatos,
                              style: TextStyle(
                                fontFamily: ScFonts.ui,
                                fontSize: 11,
                                color: c.text2,
                              ),
                            ),
                            Switch(
                              value: _useCookedWeightMode,
                              onChanged: (bool v) {
                                setState(() => _useCookedWeightMode = v);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (!_useCookedWeightMode) ...<Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextFormField(
                              controller: _servingsCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: context.l10n.foodNumeroDeRacionesIguales,
                                suffixText: 'platos',
                              ),
                              onChanged: (_) => setState(() {}),
                              validator: (String? val) {
                                final int? n = int.tryParse(val ?? '');
                                if (n == null || n <= 0) {
                                  return context.l10n.foodDebeSerAlMenos1;
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ] else ...<Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextFormField(
                              controller: _servingsCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: context.l10n.foodRacionesEstimadas,
                                suffixText: 'porciones',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _cookedWeightCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                labelText: context.l10n.foodPesoTotalCocinado,
                                suffixText: 'g',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Lista de Ingredientes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    context.l10n.foodIngredientesCrudos(_ingredients.length.toString()),
                    style: TextStyle(
                      fontFamily: ScFonts.display,
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: c.text,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pickIngredient,
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      side: BorderSide(color: c.isFlat ? c.line2 : c.accent),
                    ),
                    icon: const Icon(AppIcons.add, size: 16),
                    label: Text(context.l10n.foodIngrediente),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_ingredients.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.bg3,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: c.isFlat ? c.line2 : c.line,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      context.l10n.foodTocaIngredienteParaAnadirAlimentos,
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 12,
                        color: c.text2,
                      ),
                    ),
                  ),
                )
              else
                ..._ingredients.asMap().entries.map((MapEntry<int, _RecipeIngredientItem> entry) {
                  final int index = entry.key;
                  final _RecipeIngredientItem item = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: c.bg3,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: c.isFlat ? c.line2 : c.line,
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                item.food.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: ScFonts.ui,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: c.text,
                                ),
                              ),
                              Text(
                                context.l10n.foodGKcalPGC2(item.rawGrams.toStringAsFixed(0).toString(), item.kcal.toStringAsFixed(0).toString(), item.proteinG.toStringAsFixed(1).toString(), item.carbsG.toStringAsFixed(1).toString(), item.fatG.toStringAsFixed(1).toString()),
                                style: TextStyle(
                                  fontFamily: ScFonts.ui,
                                  fontSize: 11,
                                  color: c.text2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.remove_circle_outline_rounded,
                            size: 18,
                            color: c.fasting,
                          ),
                          onPressed: () {
                            setState(() => _ingredients.removeAt(index));
                          },
                        ),
                      ],
                    ),
                  );
                }),

              const SizedBox(height: 16),

              // Resumen nutricional por ración
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.isFlat ? c.bg3 : c.soft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: c.isFlat
                        ? c.line2
                        : c.accent.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.l10n.foodNutricionPorRacion1De((_servings).toString()),
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        _MacroSummaryChip(
                          label: context.l10n.foodCalorias,
                          value: context.l10n.foodKcal2(_servingKcal.round().toString()),
                          color: c.calories,
                        ),
                        _MacroSummaryChip(
                          label: context.l10n.foodProteinas,
                          value: context.l10n.foodG7(_servingProtein.toStringAsFixed(1).toString()),
                          color: c.protein,
                        ),
                        _MacroSummaryChip(
                          label: context.l10n.todayCarbos,
                          value: context.l10n.foodG8(_servingCarbs.toStringAsFixed(1).toString()),
                          color: c.carbs,
                        ),
                        _MacroSummaryChip(
                          label: context.l10n.todayGrasas,
                          value: context.l10n.foodG9(_servingFat.toStringAsFixed(1).toString()),
                          color: c.fat,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.l10n.foodTotalDeLaOllaKcal(_totalKcal.round().toString(), _totalRawWeight.round().toString()),
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 10.5,
                        color: c.text3,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Checkbox para registrar 1 ración inmediatamente hoy
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _logImmediately,
                onChanged: (bool? v) =>
                    setState(() => _logImmediately = v ?? true),
                title: Text(
                  context.l10n.foodRegistrar1RacionEnEl,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),

              const SizedBox(height: 14),

              // Botón Guardar
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _isSaving ? null : _saveRecipe,
                  child: Text(
                    _isSaving ? context.l10n.foodGuardando: context.l10n.foodGuardarRecetaEnCatalogo,
                    style: const TextStyle(fontWeight: FontWeight.bold),
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

class _MacroSummaryChip extends StatelessWidget {
  const _MacroSummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Column(
      children: <Widget>[
        Text(
          value,
          style: TextStyle(
            fontFamily: ScFonts.display,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: c.isFlat ? c.text : color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontFamily: ScFonts.ui,
            fontSize: 10,
            color: c.text2,
          ),
        ),
      ],
    );
  }
}

