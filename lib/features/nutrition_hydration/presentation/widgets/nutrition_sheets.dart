import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/food_dao.dart';
import '../../../../core/database/daos/pet_dao.dart';
import '../../../../core/services/local_ai_service.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/widgets/app_icons.dart';
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
  late String _mealType;
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
    final String name = food?.name ?? 'Alimento registrado';

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
                      'Ajusta la cantidad consumida o cámbialo de comida',
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
                tooltip: 'Cerrar',
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
                        '${previewKcal.round()} kcal',
                        style: TextStyle(
                          fontFamily: ScFonts.display,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: c.text,
                        ),
                      ),
                      Text(
                        'Proteína ${previewP.toStringAsFixed(1)} g · '
                        'Carbos ${previewC.toStringAsFixed(1)} g · '
                        'Grasas ${previewF.toStringAsFixed(1)} g',
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
            'Gramos consumidos',
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
                child: const Text('-25 g'),
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
                child: const Text('+25 g'),
              ),
            ],
          ),

          if (_grams <= 600) ...<Widget>[
            Slider(
              value: _grams.clamp(5.0, 600.0),
              min: 5.0,
              max: 600.0,
              divisions: 119,
              label: '${_grams.round()} g',
              onChanged: _setGrams,
            ),
          ] else
            const SizedBox(height: 14),

          Text(
            'Mover a otro momento',
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
            onSelected: (String nextMeal) {
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
                label: const Text('Eliminar'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isSaving
                      ? null
                      : () async {
                          setState(() => _isSaving = true);
                          unawaited(HapticFeedback.lightImpact());
                          await ref.read(foodDaoProvider).updateFoodLogEntry(
                                existingLog: log,
                                food: food,
                                newGrams: _grams,
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
                  label: const Text(
                    'Guardar cambios',
                    style: TextStyle(fontWeight: FontWeight.w800),
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

/// Subpágina de dictado y escritura libre con IA Local (SLM offline + vista previa editable).
class AiMealDictationSheet extends ConsumerStatefulWidget {
  const AiMealDictationSheet({
    super.key,
    required this.dateKey,
    required this.initialMealType,
  });

  final String dateKey;
  final String initialMealType;

  @override
  ConsumerState<AiMealDictationSheet> createState() =>
      _AiMealDictationSheetState();
}

class _AiMealDictationSheetState extends ConsumerState<AiMealDictationSheet> {
  final TextEditingController _textController = TextEditingController();
  late String _selectedMealType;
  bool _isProcessing = false;
  List<ParsedMealItem>? _previewItems;

  static const List<String> _examples = <String>[
    '2 huevos, 80g avena y 1 plátano',
    '200g pechuga de pollo, 150g arroz y brócoli',
    '150g yogur griego y 30g almendras',
  ];

  @override
  void initState() {
    super.initState();
    _selectedMealType = widget.initialMealType;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _analyzeText() async {
    final String text = _textController.text.trim();
    if (text.isEmpty || _isProcessing) return;

    setState(() => _isProcessing = true);
    try {
      final result =
          await ref.read(localAiServiceProvider).parseMealText(text);
      if (!mounted) return;
      setState(() {
        _previewItems = List<ParsedMealItem>.of(result.items);
      });
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _adjustPreviewGrams(int index, double delta) {
    final List<ParsedMealItem>? items = _previewItems;
    if (items == null || index < 0 || index >= items.length) return;
    final ParsedMealItem old = items[index];
    final double updatedGrams = (old.grams + delta).clamp(5.0, 3000.0);
    setState(() {
      items[index] = ParsedMealItem(
        searchTerm: old.searchTerm,
        grams: updatedGrams,
        fallbackKcal: old.fallbackKcal,
        fallbackP: old.fallbackP,
        fallbackC: old.fallbackC,
        fallbackF: old.fallbackF,
      );
    });
  }

  Future<void> _confirmAndLog() async {
    final String rawText = _textController.text.trim();
    if (_isProcessing || (rawText.isEmpty && (_previewItems?.isEmpty ?? true))) {
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final LocalAiService aiService = ref.read(localAiServiceProvider);
      final FoodDao foodDao = ref.read(foodDaoProvider);

      List<ParsedMealItem> itemsToLog = _previewItems ?? <ParsedMealItem>[];
      if (itemsToLog.isEmpty) {
        final parsed = await aiService.parseMealText(rawText);
        itemsToLog = parsed.items;
      }

      if (itemsToLog.isEmpty) return;

      final List<FoodItem> logged = await aiService.logParsedItems(
        foodDao: foodDao,
        items: itemsToLog,
        mealType: _selectedMealType,
        dateKey: widget.dateKey,
      );

      if (logged.isNotEmpty) {
        await ref.read(petDaoProvider).grantDailyReward(
              dateKey: widget.dateKey,
              actionType: 'meal_log_$_selectedMealType',
              baseAmount: AppConstants.coinsMealLog,
            );
      }

      if (!mounted) return;
      final MealSlotMeta slot = MealSlotMeta.of(_selectedMealType);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${logged.length} alimentos añadidos en ${slot.title}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(AppIcons.ai, color: c.accent, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Dictado con IA Local',
                  softWrap: true,
                  style: TextStyle(
                    fontFamily: ScFonts.display,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: c.text,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Cerrar',
                icon: Icon(AppIcons.close, color: c.text2),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          Text(
            'Describe tu plato o usa el micrófono de tu teclado. Todo se procesa offline en tu dispositivo.',
            softWrap: true,
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 12.5,
              color: c.text2,
            ),
          ),

          const SizedBox(height: 12),

          // Sugerencias tocables para inspirar entrada rápida
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _examples.map((String sample) {
              return ActionChip(
                label: Text(
                  sample,
                  style: const TextStyle(fontSize: 11.5),
                ),
                onPressed: () {
                  unawaited(HapticFeedback.selectionClick());
                  setState(() {
                    _textController.text = sample;
                    _previewItems = null;
                  });
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: _textController,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText:
                  'Ej. 200g pechuga de pollo, 150g arroz blanco y 1 aguacate',
              filled: true,
              fillColor: c.bg3,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onChanged: (_) {
              if (_previewItems != null) {
                setState(() => _previewItems = null);
              }
            },
          ),

          const SizedBox(height: 14),

          Text(
            'Momento de comida',
            style: TextStyle(
              fontFamily: ScFonts.display,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: c.text,
            ),
          ),
          const SizedBox(height: 8),
          MealSlotSelectorGrid(
            selectedMealType: _selectedMealType,
            compact: true,
            onSelected: (String nextMeal) {
              setState(() => _selectedMealType = nextMeal);
            },
          ),

          if (_previewItems != null) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              _previewItems!.isEmpty
                  ? 'No se detectaron alimentos claros. Prueba indicando cantidades (ej. 150g arroz).'
                  : 'Ingredientes detectados (${_previewItems!.length}):',
              softWrap: true,
              style: TextStyle(
                fontFamily: ScFonts.display,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: c.text,
              ),
            ),
            const SizedBox(height: 8),
            for (int i = 0; i < _previewItems!.length; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: c.bg3,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: c.isFlat ? c.line2 : c.line,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _previewItems![i].searchTerm,
                        softWrap: true,
                        style: TextStyle(
                          fontFamily: ScFonts.ui,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: c.text,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.remove_circle_outline, size: 19),
                      onPressed: () => _adjustPreviewGrams(i, -25),
                    ),
                    Text(
                      '${_previewItems![i].grams.round()} g',
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: c.accent,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.add_circle_outline, size: 19),
                      onPressed: () => _adjustPreviewGrams(i, 25),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Quitar ingrediente',
                      icon: Icon(AppIcons.delete, size: 17, color: c.text3),
                      onPressed: () {
                        setState(() => _previewItems!.removeAt(i));
                      },
                    ),
                  ],
                ),
              ),
          ],

          const SizedBox(height: 16),

          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: _isProcessing ? null : _analyzeText,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Revisar porciones'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isProcessing ? null : _confirmAndLog,
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
                    _isProcessing ? 'Guardando...' : 'Registrar',
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

/// Subpágina de gestión y escalado proporcional (0.25x – 3.0x) de Combos Caseros.
class CombosModalSheet extends ConsumerStatefulWidget {
  const CombosModalSheet({
    super.key,
    required this.dateKey,
    required this.initialMealType,
  });

  final String dateKey;
  final String initialMealType;

  @override
  ConsumerState<CombosModalSheet> createState() => _CombosModalSheetState();
}

class _CombosModalSheetState extends ConsumerState<CombosModalSheet> {
  double _multiplier = 1.0;
  late String _mealType;

  static const List<double> _quickStops = <double>[
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    2.0,
  ];

  @override
  void initState() {
    super.initState();
    _mealType = widget.initialMealType;
  }

  String _formatMultiplier(double m) {
    if ((m - m.roundToDouble()).abs() < 0.01) {
      return '${m.toStringAsFixed(1)}x';
    }
    return '${m.toStringAsFixed(2)}x';
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final FoodDao foodDao = ref.watch(foodDaoProvider);

    return StreamBuilder<List<MealComboWithDetails>>(
      stream: foodDao.watchMealCombosWithDetails(),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<MealComboWithDetails>> snapshot,
      ) {
        final List<MealComboWithDetails> combos =
            snapshot.data ?? const <MealComboWithDetails>[];

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
                      'Mis Combos Caseros',
                      softWrap: true,
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
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
                    border: Border.all(
                      color: c.isFlat ? c.line2 : c.line,
                      width: c.isFlat ? 1.4 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Aún no has guardado combos',
                        style: TextStyle(
                          fontFamily: ScFonts.display,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: c.text,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Cuando registres 2 o más alimentos en Desayuno, Almuerzo, Cena o Snacks, aparecerá el botón "Guardar combo" debajo de esa comida para reutilizarla en 1 toque con cualquier tamaño de porción.',
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
                  'Elige el momento del día y escala la porción de todos los ingredientes a la vez:',
                  softWrap: true,
                  style: TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: 12.5,
                    color: c.text2,
                  ),
                ),
                const SizedBox(height: 12),

                MealSlotSelectorGrid(
                  selectedMealType: _mealType,
                  compact: true,
                  onSelected: (String nextMeal) {
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
                    border: Border.all(
                      color: c.isFlat ? c.line2 : c.line,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              'Tamaño de la porción',
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: c.bg2,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: c.isFlat ? c.line2 : c.accent,
                              ),
                            ),
                            child: Text(
                              _formatMultiplier(_multiplier),
                              style: TextStyle(
                                fontFamily: ScFonts.display,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
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
                        onChanged: (double val) =>
                            setState(() => _multiplier = val),
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
                    onDelete: () => foodDao.deleteCombo(item.combo.id),
                    onLog: () async {
                      unawaited(HapticFeedback.mediumImpact());
                      await foodDao.logCombo(
                        comboId: item.combo.id,
                        multiplier: _multiplier,
                        dateKey: widget.dateKey,
                        mealType: _mealType,
                      );
                      await ref.read(petDaoProvider).grantDailyReward(
                            dateKey: widget.dateKey,
                            actionType: 'meal_log_$_mealType',
                            baseAmount: AppConstants.coinsMealLog,
                          );
                      if (context.mounted) {
                        final MealSlotMeta slot = MealSlotMeta.of(_mealType);
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Combo "${item.combo.name}" (${_formatMultiplier(_multiplier)}) añadido a ${slot.title}',
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
          (MealComboIngredientDetail ing) =>
              '${ing.foodItem.name} (${(ing.baseGrams * multiplier).round()}g)',
        )
        .join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.bg3,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: c.isFlat ? c.line2 : c.line,
          width: c.isFlat ? 1.4 : 1.0,
        ),
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
                        fontWeight: FontWeight.w800,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Usado ${detail.combo.timesUsed} veces',
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 11.5,
                        color: c.text3,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$scaledKcal kcal',
                style: TextStyle(
                  fontFamily: ScFonts.display,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
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
              style: TextStyle(
                fontFamily: ScFonts.ui,
                fontSize: 12.5,
                color: c.text2,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'P ${scaledP.toStringAsFixed(0)}g · '
            'C ${scaledC.toStringAsFixed(0)}g · '
            'G ${scaledF.toStringAsFixed(0)}g',
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
                tooltip: 'Eliminar combo',
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(AppIcons.add, size: 18),
                  label: Text(
                    'Registrar ($multiplierText)',
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

/// Diálogo limpio y sin fugas de memoria para nombrar un nuevo combo casero.
class CreateComboDialog extends StatefulWidget {
  const CreateComboDialog({
    super.key,
    required this.suggestedName,
    required this.itemCount,
  });

  final String suggestedName;
  final int itemCount;

  @override
  State<CreateComboDialog> createState() => _CreateComboDialogState();
}

class _CreateComboDialogState extends State<CreateComboDialog> {
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.suggestedName);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return AlertDialog(
      backgroundColor: c.bg2,
      title: const Text('Guardar como combo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Se guardarán los ${widget.itemCount} alimentos actuales como plantilla reutilizable.',
            softWrap: true,
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 13,
              color: c.text2,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Nombre del combo',
              hintText: 'Ej. Desayuno proteico habitual',
              filled: true,
              fillColor: c.bg3,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onSubmitted: (String val) {
              if (val.trim().isNotEmpty) {
                Navigator.of(context).pop(val.trim());
              }
            },
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final String name = _nameCtrl.text.trim();
            if (name.isNotEmpty) {
              Navigator.of(context).pop(name);
            }
          },
          child: const Text('Guardar combo'),
        ),
      ],
    );
  }
}

/// Hoja de selección de vaso personalizado de hidratación (ml).
class CustomWaterSheet extends StatefulWidget {
  const CustomWaterSheet({super.key});

  @override
  State<CustomWaterSheet> createState() => _CustomWaterSheetState();
}

class _CustomWaterSheetState extends State<CustomWaterSheet> {
  final TextEditingController _mlCtrl = TextEditingController(text: '350');

  static const List<({int ml, String label})> _presets =
      <({int ml, String label})>[
    (ml: 150, label: 'Taza pequeña'),
    (ml: 200, label: 'Vaso corto'),
    (ml: 330, label: 'Botellín'),
    (ml: 600, label: 'Termo'),
    (ml: 750, label: 'Caramañola'),
    (ml: 1000, label: 'Botella 1 L'),
  ];

  @override
  void dispose() {
    _mlCtrl.dispose();
    super.dispose();
  }

  void _selectPreset(int ml) {
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _mlCtrl.text = ml.toString();
    });
  }

  void _submit() {
    final int? parsed = int.tryParse(_mlCtrl.text.trim());
    if (parsed != null && parsed >= 10 && parsed <= 5000) {
      Navigator.of(context).pop(parsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final int currentMl = int.tryParse(_mlCtrl.text.trim()) ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(AppIcons.gota, color: c.isFlat ? c.text : c.water, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Vaso o botella a medida',
                  softWrap: true,
                  style: TextStyle(
                    fontFamily: ScFonts.display,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: c.text,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Cerrar',
                icon: Icon(AppIcons.close, color: c.text2),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Cuadrícula 2×3 de medidas frecuentes
          for (int row = 0; row < 3; row++) ...<Widget>[
            Row(
              children: <Widget>[
                for (int col = 0; col < 2; col++) ...<Widget>[
                  if (col > 0) const SizedBox(width: 10),
                  Expanded(
                    child: Builder(
                      builder: (BuildContext context) {
                        final ({int ml, String label}) item =
                            _presets[row * 2 + col];
                        final bool selected = currentMl == item.ml;
                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _selectPreset(item.ml),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? (c.isFlat
                                      ? c.bg3
                                      : c.water.withValues(alpha: 0.16))
                                  : c.bg3,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected
                                    ? (c.isFlat ? c.text : c.water)
                                    : (c.isFlat ? c.line2 : c.line),
                                width: selected ? 1.8 : 1.0,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  '${item.ml} ml',
                                  style: TextStyle(
                                    fontFamily: ScFonts.display,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: c.text,
                                  ),
                                ),
                                Text(
                                  item.label,
                                  softWrap: true,
                                  style: TextStyle(
                                    fontFamily: ScFonts.ui,
                                    fontSize: 11.5,
                                    color: c.text2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
          ],

          const SizedBox(height: 6),
          TextField(
            controller: _mlCtrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
            style: TextStyle(
              fontFamily: ScFonts.display,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: c.text,
            ),
            decoration: InputDecoration(
              labelText: 'Volumen exacto en mililitros',
              suffixText: 'ml',
              filled: true,
              fillColor: c.bg3,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),

          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed:
                  (currentMl >= 10 && currentMl <= 5000) ? _submit : null,
              style: FilledButton.styleFrom(
                backgroundColor: c.isFlat ? c.accent : c.water,
                foregroundColor: c.isFlat ? c.ink : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(AppIcons.gota),
              label: Text(
                currentMl > 0
                    ? 'Registrar +$currentMl ml'
                    : 'Introduce un volumen válido',
                style: const TextStyle(
                  fontFamily: ScFonts.display,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
