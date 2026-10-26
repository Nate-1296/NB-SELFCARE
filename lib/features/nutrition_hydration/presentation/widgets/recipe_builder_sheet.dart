import 'dart:async';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/food_dao.dart';
import '../../../../core/database/daos/pet_dao.dart';
import '../../../../core/database/daos/recipe_dao.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/health_card.dart';
import '../../../../shared/widgets/sheet.dart';
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
    this.initialMealType = 'lunch',
  });

  final String targetDateKey;
  final String initialMealType;

  static Future<Recipe?> show(
    BuildContext context, {
    required String targetDateKey,
    String initialMealType = 'lunch',
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

  late String _mealType;
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
    final FoodDao foodDao = ref.read(foodDaoProvider);
    final FoodItem? selected = await showModalBottomSheet<FoodItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickIngredientDialog(foodDao: foodDao),
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
          title: Text('Cantidad de ${food.name}'),
          content: TextField(
            controller: gramsCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Gramos crudos',
              suffixText: 'g',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final double? g = double.tryParse(
                  gramsCtrl.text.trim().replaceAll(',', '.'),
                );
                Navigator.of(ctx).pop(g);
              },
              child: const Text('Añadir'),
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
        const SnackBar(
          content: Text('Añade al menos un ingrediente a la receta.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    unawaited(HapticFeedback.mediumImpact());

    try {
      final RecipeDao recipeDao = ref.read(recipeDaoProvider);
      final FoodDao foodDao = ref.read(foodDaoProvider);
      final PetDao petDao = ref.read(petDaoProvider);

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

      final int recipeId = await recipeDao.createRecipe(
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim().isNotEmpty
            ? _descCtrl.text.trim()
            : null,
        defaultMealType: _mealType,
        totalYieldServings: _servings,
        cookedTotalWeightGrams: cookedGrams,
        ingredients: drafts,
      );

      final Recipe? createdRecipe = await recipeDao.getRecipeById(recipeId);

      // Si el usuario marcó registrar 1 porción hoy
      if (_logImmediately && createdRecipe != null) {
        // También creamos el FoodItem representativo si es necesario, o registramos
        // un food item consolidado de la receta
        final FoodItem? recipeFood = await foodDao.getByBarcode('RECIPE_$recipeId');
        if (recipeFood != null) {
          await foodDao.logFoodItemPortion(
            food: recipeFood,
            grams: recipeFood.defaultServingGrams,
            dateKey: widget.targetDateKey,
            mealType: _mealType,
          );
        } else {
          // Crear alimento correspondiente a la ración de la receta
          final int foodItemId = await foodDao.insertFood(
            FoodItemsCompanion.insert(
              barcode: drift.Value('RECIPE_$recipeId'),
              name: createdRecipe.name,
              brand: const drift.Value('Receta Casera'),
              source: 'user_custom',
              defaultServingGrams: const drift.Value(100.0),
              servingLabel: const drift.Value('1 ración'),
              kcalPer100g: createdRecipe.kcalPerServing,
              proteinPer100g: createdRecipe.proteinPerServing,
              carbsPer100g: createdRecipe.carbsPerServing,
              fatPer100g: createdRecipe.fatPerServing,
              fiberPer100g: drift.Value(createdRecipe.fiberPerServing),
              sodiumMgPer100g: drift.Value(createdRecipe.sodiumMgPerServing),
            ),
          );
          final FoodItem? newFood = await foodDao.getById(foodItemId);
          if (newFood != null) {
            await foodDao.logFoodItemPortion(
              food: newFood,
              grams: 100.0,
              dateKey: widget.targetDateKey,
              mealType: _mealType,
            );
          }
        }

        await petDao.grantDailyReward(
          dateKey: widget.targetDateKey,
          actionType: 'meal_log_$_mealType',
          baseAmount: AppConstants.coinsMealLog,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(createdRecipe);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '¡Receta "${_nameCtrl.text.trim()}" guardada exitosamente! 🍲',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar la receta: $e')),
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
                    'Nueva Receta (Batch Cooking)',
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
                decoration: const InputDecoration(
                  labelText: 'Nombre de la receta (ej. Arroz con Pollo)',
                  prefixIcon: Icon(Icons.soup_kitchen_rounded),
                ),
                validator: (String? val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Introduce un nombre para la receta';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Comida destino predeterminada
              MealSlotSelectorGrid(
                selectedMealType: _mealType,
                compact: true,
                onSelected: (String m) => setState(() => _mealType = m),
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
                          'Rendimiento y Raciones',
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
                              _useCookedWeightMode ? 'Por peso' : 'Por platos',
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
                              decoration: const InputDecoration(
                                labelText: 'Número de raciones iguales',
                                suffixText: 'platos',
                              ),
                              onChanged: (_) => setState(() {}),
                              validator: (String? val) {
                                final int? n = int.tryParse(val ?? '');
                                if (n == null || n <= 0) {
                                  return 'Debe ser al menos 1';
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
                              decoration: const InputDecoration(
                                labelText: 'Raciones estimadas',
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
                              decoration: const InputDecoration(
                                labelText: 'Peso total cocinado',
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
                    'Ingredientes Crudos (${_ingredients.length})',
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
                    label: const Text('Ingrediente'),
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
                      'Toca "+ Ingrediente" para añadir alimentos crudos del catálogo.',
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
                                '${item.rawGrams.toStringAsFixed(0)}g • ${item.kcal.toStringAsFixed(0)} kcal (P: ${item.proteinG.toStringAsFixed(1)}g | C: ${item.carbsG.toStringAsFixed(1)}g | G: ${item.fatG.toStringAsFixed(1)}g)',
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
                      'Nutrición por Ración (1 de $_servings):',
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
                          label: 'Calorías',
                          value: '${_servingKcal.round()} kcal',
                          color: c.calories,
                        ),
                        _MacroSummaryChip(
                          label: 'Proteínas',
                          value: '${_servingProtein.toStringAsFixed(1)} g',
                          color: c.protein,
                        ),
                        _MacroSummaryChip(
                          label: 'Carbos',
                          value: '${_servingCarbs.toStringAsFixed(1)} g',
                          color: c.carbs,
                        ),
                        _MacroSummaryChip(
                          label: 'Grasas',
                          value: '${_servingFat.toStringAsFixed(1)} g',
                          color: c.fat,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Total de la olla: ${_totalKcal.round()} kcal • Peso crudo: ${_totalRawWeight.round()}g',
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
                title: const Text(
                  'Registrar 1 ración en el diario de hoy',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
                    _isSaving ? 'Guardando...' : 'Guardar Receta en Catálogo',
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

/// Selector de ingredientes crudos desde el catálogo local para RecipeBuilderSheet.
class _PickIngredientDialog extends StatefulWidget {
  const _PickIngredientDialog({required this.foodDao});

  final FoodDao foodDao;

  @override
  State<_PickIngredientDialog> createState() => _PickIngredientDialogState();
}

class _PickIngredientDialogState extends State<_PickIngredientDialog> {
  final TextEditingController _ctrl = TextEditingController();
  List<FoodItem> _items = <FoodItem>[];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    unawaited(_search(''));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    final List<FoodItem> res = await widget.foodDao.filterCatalog(
      query: q,
      limit: 30,
    );
    if (mounted) {
      setState(() {
        _items = res;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Seleccionar Ingrediente',
                style: TextStyle(
                  fontFamily: ScFonts.display,
                  fontSize: 17,
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
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Buscar ingrediente (ej. Pollo, Arroz, Aceite...)',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: _search,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? Center(
                        child: Text(
                          'No se encontraron alimentos.',
                          style: TextStyle(color: c.text2),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (BuildContext ctx, int i) {
                          final FoodItem f = _items[i];
                          return ListTile(
                            title: Text(
                              f.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                              ),
                            ),
                            subtitle: Text(
                              '${f.kcalPer100g.round()} kcal / 100g • P:${f.proteinPer100g.toStringAsFixed(1)} C:${f.carbsPer100g.toStringAsFixed(1)} G:${f.fatPer100g.toStringAsFixed(1)}',
                              style: TextStyle(
                                color: c.text2,
                                fontSize: 11,
                              ),
                            ),
                            trailing: Icon(
                              Icons.add_circle_outline_rounded,
                              color: c.accent,
                            ),
                            onTap: () => Navigator.of(ctx).pop(f),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

/// Hoja modal que lista las recetas guardadas para registro rápido en 1 toque.
class SavedRecipesSheet extends ConsumerWidget {
  const SavedRecipesSheet({
    super.key,
    required this.targetDateKey,
    this.initialMealType = 'lunch',
  });

  final String targetDateKey;
  final String initialMealType;

  static Future<void> show(
    BuildContext context, {
    required String targetDateKey,
    String initialMealType = 'lunch',
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
    final FoodDao foodDao = ref.read(foodDaoProvider);
    final PetDao petDao = ref.read(petDaoProvider);

    final FoodItem? recipeFood =
        await foodDao.getByBarcode('RECIPE_${recipe.id}');
    if (recipeFood != null) {
      await foodDao.logFoodItemPortion(
        food: recipeFood,
        grams: recipeFood.defaultServingGrams,
        dateKey: targetDateKey,
        mealType: initialMealType,
      );
    } else {
      final int foodId = await foodDao.insertFood(
        FoodItemsCompanion.insert(
          barcode: drift.Value('RECIPE_${recipe.id}'),
          name: recipe.name,
          brand: const drift.Value('Receta Casera'),
          source: 'user_custom',
          defaultServingGrams: const drift.Value(100.0),
          servingLabel: const drift.Value('1 ración'),
          kcalPer100g: recipe.kcalPerServing,
          proteinPer100g: recipe.proteinPerServing,
          carbsPer100g: recipe.carbsPerServing,
          fatPer100g: recipe.fatPerServing,
          fiberPer100g: drift.Value(recipe.fiberPerServing),
          sodiumMgPer100g: drift.Value(recipe.sodiumMgPerServing),
        ),
      );
      final FoodItem? newFood = await foodDao.getById(foodId);
      if (newFood != null) {
        await foodDao.logFoodItemPortion(
          food: newFood,
          grams: 100.0,
          dateKey: targetDateKey,
          mealType: initialMealType,
        );
      }
    }

    await petDao.grantDailyReward(
      dateKey: targetDateKey,
      actionType: 'meal_log_$initialMealType',
      baseAmount: AppConstants.coinsMealLog,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '¡1 ración de "${recipe.name}" registrada en $initialMealType! 🍲',
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
                    'Mis Recetas Caseras',
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
            'Batch Cooking y recetas multiración calculadas exactamente por porción.',
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
              label: const Text('Crear Nueva Receta Multiración'),
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
                          'Aún no has creado recetas caseras',
                          style: TextStyle(
                            fontFamily: ScFonts.display,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: c.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Crea platos multiración para porcionar tu Batch Cooking sin recalcular a mano.',
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
                              color: c.isFlat ? c.line2 : c.soft,
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
                                  '${r.kcalPerServing.round()} kcal • Rinde ${r.totalYieldServings} raciones',
                                  style: TextStyle(
                                    fontFamily: ScFonts.ui,
                                    fontSize: 11.5,
                                    color: c.text2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'P: ${r.proteinPerServing.toStringAsFixed(1)}g | C: ${r.carbsPerServing.toStringAsFixed(1)}g | G: ${r.fatPerServing.toStringAsFixed(1)}g',
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
                            child: const Text(
                              '+ 1 Ración',
                              style: TextStyle(fontSize: 11.5),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object e, _) => Text('Error: $e'),
            ),
          ),
        ],
      ),
    );
  }
}
