import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/food_dao.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/widgets/app_icons.dart';

/// Subpágina guiada para crear alimentos propios o productos locales sin código en caché.
class CustomFoodSheet extends ConsumerStatefulWidget {
  const CustomFoodSheet({
    super.key,
    this.initialBarcode,
    this.initialName,
  });

  final String? initialBarcode;
  final String? initialName;

  @override
  ConsumerState<CustomFoodSheet> createState() => _CustomFoodSheetState();
}

class _CustomFoodSheetState extends ConsumerState<CustomFoodSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  final TextEditingController _brandController = TextEditingController();
  late final TextEditingController _barcodeController;
  final TextEditingController _servingGramsController =
      TextEditingController(text: '100');
  final TextEditingController _servingLabelController =
      TextEditingController(text: '100g');

  final TextEditingController _kcalController = TextEditingController();
  final TextEditingController _proteinController =
      TextEditingController(text: '0');
  final TextEditingController _carbsController =
      TextEditingController(text: '0');
  final TextEditingController _fatController = TextEditingController(text: '0');
  final TextEditingController _fiberController =
      TextEditingController(text: '0');
  final TextEditingController _sugarController =
      TextEditingController(text: '0');

  final TextEditingController _sodiumController =
      TextEditingController(text: '0');
  final TextEditingController _potassiumController =
      TextEditingController(text: '0');
  final TextEditingController _magnesiumController =
      TextEditingController(text: '0');

  String? _selectedNutriScore;
  bool _showAdvanced = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _barcodeController =
        TextEditingController(text: widget.initialBarcode ?? '');

    for (final TextEditingController ctrl in <TextEditingController>[
      _kcalController,
      _proteinController,
      _carbsController,
      _fatController,
    ]) {
      ctrl.addListener(_onMacroChanged);
    }
  }

  void _onMacroChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _barcodeController.dispose();
    _servingGramsController.dispose();
    _servingLabelController.dispose();
    _kcalController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _fiberController.dispose();
    _sugarController.dispose();
    _sodiumController.dispose();
    _potassiumController.dispose();
    _magnesiumController.dispose();
    super.dispose();
  }

  double _parseDouble(String text, {double fallback = 0.0}) {
    final String cleaned = text.trim().replaceAll(',', '.');
    if (cleaned.isEmpty) return fallback;
    return double.tryParse(cleaned) ?? fallback;
  }

  double get _liveProtein => _parseDouble(_proteinController.text);
  double get _liveCarbs => _parseDouble(_carbsController.text);
  double get _liveFat => _parseDouble(_fatController.text);
  double get _formula449Kcal =>
      (_liveProtein * 4.0) + (_liveCarbs * 4.0) + (_liveFat * 9.0);

  double get _effectiveKcal {
    final String raw = _kcalController.text.trim();
    if (raw.isEmpty) return _formula449Kcal;
    return _parseDouble(raw);
  }

  void _applyFormula449() {
    unawaited(HapticFeedback.selectionClick());
    _kcalController.text = _formula449Kcal.round().toString();
  }

  Future<void> _saveCustomFood() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);
    unawaited(HapticFeedback.mediumImpact());

    try {
      final FoodDao foodDao = ref.read(foodDaoProvider);

      final String name = _nameController.text.trim();
      final String brand = _brandController.text.trim();
      final String barcode = _barcodeController.text.trim();
      final double servingGrams = _parseDouble(
        _servingGramsController.text,
        fallback: 100.0,
      ).clamp(1.0, 5000.0);
      final String servingLabel = _servingLabelController.text.trim().isEmpty
          ? '${servingGrams.round()}g'
          : _servingLabelController.text.trim();

      final double protein = _liveProtein.clamp(0.0, 100.0);
      final double carbs = _liveCarbs.clamp(0.0, 100.0);
      final double fat = _liveFat.clamp(0.0, 100.0);
      final double fiber =
          _parseDouble(_fiberController.text).clamp(0.0, 100.0);
      final double sugar =
          _parseDouble(_sugarController.text).clamp(0.0, 100.0);
      final double kcal = _effectiveKcal.clamp(0.0, 950.0);

      final double sodium =
          _parseDouble(_sodiumController.text).clamp(0.0, 50000.0);
      final double potassium =
          _parseDouble(_potassiumController.text).clamp(0.0, 50000.0);
      final double magnesium =
          _parseDouble(_magnesiumController.text).clamp(0.0, 50000.0);

      final FoodItemsCompanion companion = FoodItemsCompanion(
        name: drift.Value(name),
        brand:
            brand.isEmpty ? const drift.Value.absent() : drift.Value(brand),
        barcode:
            barcode.isEmpty ? const drift.Value.absent() : drift.Value(barcode),
        source: const drift.Value('user_custom'),
        nutriScore: _selectedNutriScore == null
            ? const drift.Value.absent()
            : drift.Value(_selectedNutriScore),
        defaultServingGrams: drift.Value(servingGrams),
        servingLabel: drift.Value(servingLabel),
        kcalPer100g: drift.Value(kcal),
        proteinPer100g: drift.Value(protein),
        carbsPer100g: drift.Value(carbs),
        fatPer100g: drift.Value(fat),
        fiberPer100g: drift.Value(fiber),
        sugarPer100g: drift.Value(sugar),
        sodiumMgPer100g: drift.Value(sodium),
        potassiumMgPer100g: drift.Value(potassium),
        magnesiumMgPer100g: drift.Value(magnesium),
        isFavorite: const drift.Value(true),
        lastUsedAt: drift.Value(DateTime.now()),
      );

      final int newId = await foodDao.insertFood(companion);
      final FoodItem? created = await foodDao.getById(newId);

      if (!mounted) return;
      Navigator.of(context).pop(created);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo guardar el alimento: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;

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
          child: Form(
            key: _formKey,
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

                // Encabezado limpio
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Crear alimento propio',
                            softWrap: true,
                            style: TextStyle(
                              fontFamily: ScFonts.display,
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: c.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Se guarda como favorito en tu catálogo offline',
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
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(AppIcons.close, color: c.text2),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Vista previa en vivo de energía (4-4-9)
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
                              '${_effectiveKcal.round()} kcal / 100 g',
                              softWrap: true,
                              style: TextStyle(
                                fontFamily: ScFonts.display,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: c.text,
                              ),
                            ),
                            Text(
                              'P ${_liveProtein.toStringAsFixed(0)}g · C ${_liveCarbs.toStringAsFixed(0)}g · G ${_liveFat.toStringAsFixed(0)}g',
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
                      if (_formula449Kcal > 0)
                        TextButton(
                          onPressed: _applyFormula449,
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          child: Text(
                            'Auto ${_formula449Kcal.round()} kcal',
                            style: TextStyle(
                              fontFamily: ScFonts.ui,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: c.accent,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 1. Identidad básica
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Nombre del alimento o receta *',
                    hintText: 'Ej. Arepa de maíz asada',
                    filled: true,
                    fillColor: c.bg3,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  validator: (String? val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Escribe un nombre descriptivo';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextFormField(
                        controller: _brandController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'Marca (opcional)',
                          hintText: 'Ej. Casero',
                          filled: true,
                          fillColor: c.bg3,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _NumericInputField(
                        controller: _servingGramsController,
                        label: 'Porción base (g)',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextFormField(
                        controller: _servingLabelController,
                        decoration: InputDecoration(
                          labelText: 'Etiqueta de porción',
                          hintText: 'Ej. 1 unidad, 1 taza',
                          filled: true,
                          fillColor: c.bg3,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    if (widget.initialBarcode != null &&
                        widget.initialBarcode!.isNotEmpty) ...<Widget>[
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _barcodeController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Código EAN',
                            filled: true,
                            fillColor: c.bg3,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 18),

                // 2. Macronutrientes por 100g (cuadrícula 2×2 sin etiquetas cortadas)
                Text(
                  'Valores por cada 100 g',
                  style: TextStyle(
                    fontFamily: ScFonts.display,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Si dejas calorías vacío, se calcula automáticamente con 4-4-9.',
                  softWrap: true,
                  style: TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: 12,
                    color: c.text3,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _NumericInputField(
                        controller: _kcalController,
                        label: 'Calorías (kcal)',
                        hint: _formula449Kcal > 0
                            ? '${_formula449Kcal.round()}'
                            : '0',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _NumericInputField(
                        controller: _proteinController,
                        label: 'Proteína (g)',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _NumericInputField(
                        controller: _carbsController,
                        label: 'Carbohidratos (g)',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _NumericInputField(
                        controller: _fatController,
                        label: 'Grasas (g)',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _NumericInputField(
                        controller: _fiberController,
                        label: 'Fibra (g)',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _NumericInputField(
                        controller: _sugarController,
                        label: 'Azúcares (g)',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // 3. Sección expandible: Electrolitos, Código de Barras y Nutri-Score
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    unawaited(HapticFeedback.selectionClick());
                    setState(() => _showAdvanced = !_showAdvanced);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: c.bg3,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: c.isFlat ? c.line2 : c.line,
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(AppIcons.bolt, size: 18, color: c.accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Electrolitos, EAN y Nutri-Score (opcional)',
                            softWrap: true,
                            style: TextStyle(
                              fontFamily: ScFonts.ui,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: c.text,
                            ),
                          ),
                        ),
                        Icon(
                          _showAdvanced
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: c.text2,
                        ),
                      ],
                    ),
                  ),
                ),

                if (_showAdvanced) ...<Widget>[
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _NumericInputField(
                          controller: _sodiumController,
                          label: 'Sodio (mg / 100g)',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _NumericInputField(
                          controller: _potassiumController,
                          label: 'Potasio (mg / 100g)',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _NumericInputField(
                          controller: _magnesiumController,
                          label: 'Magnesio (mg / 100g)',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _barcodeController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Código EAN (opcional)',
                            filled: true,
                            fillColor: c.bg3,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Nutri-Score (si aparece en el envase)',
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: c.text2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const <String>['A', 'B', 'C', 'D', 'E']
                        .map((String grade) {
                      final bool active = _selectedNutriScore == grade;
                      return ChoiceChip(
                        label: Text('Grado $grade'),
                        selected: active,
                        onSelected: (bool v) {
                          unawaited(HapticFeedback.selectionClick());
                          setState(() {
                            _selectedNutriScore = v ? grade : null;
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 22),

                // 4. Botón principal de guardado
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _saveCustomFood,
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
                      _isSaving
                          ? 'Guardando alimento...'
                          : 'Guardar en mi catálogo',
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
      ),
    );
  }
}

class _NumericInputField extends StatelessWidget {
  const _NumericInputField({
    required this.controller,
    required this.label,
    this.hint,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: c.bg3,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}
