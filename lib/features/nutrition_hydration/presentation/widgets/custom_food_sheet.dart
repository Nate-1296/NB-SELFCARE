import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/clock/clock.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/services/nutrition_label_ocr_service.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../application/food_catalog_service.dart';
import 'custom_food_extras.dart';

/// Subpágina guiada para crear alimentos propios o productos locales sin código en caché.
class CustomFoodSheet extends ConsumerStatefulWidget {
  const CustomFoodSheet({
    super.key,
    this.initialBarcode,
    this.initialName,
    this.initialOcrData,
  });

  final String? initialBarcode;
  final String? initialName;
  final OcrNutritionData? initialOcrData;

  @override
  ConsumerState<CustomFoodSheet> createState() => _CustomFoodSheetState();
}

class _CustomFoodSheetState extends ConsumerState<CustomFoodSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  final TextEditingController _brandController = TextEditingController();
  late final TextEditingController _barcodeController;
  late final TextEditingController _servingGramsController;
  final TextEditingController _servingLabelController =
      TextEditingController(text: '100g');

  late final TextEditingController _kcalController;
  late final TextEditingController _proteinController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatController;
  late final TextEditingController _fiberController;
  late final TextEditingController _sugarController;

  late final TextEditingController _sodiumController;
  final TextEditingController _potassiumController =
      TextEditingController(text: '0');
  final TextEditingController _magnesiumController =
      TextEditingController(text: '0');

  String? _selectedNutriScore;
  bool _showAdvanced = false;
  bool _isSaving = false;
  bool _isScanningOcr = false;

  @override
  void initState() {
    super.initState();
    final OcrNutritionData? ocr = widget.initialOcrData;
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _barcodeController =
        TextEditingController(text: widget.initialBarcode ?? '');
    _servingGramsController = TextEditingController(
      text: ocr?.servingGrams != null
          ? ocr!.servingGrams!.toStringAsFixed(0)
          : '100',
    );

    _kcalController = TextEditingController(
      text: ocr?.kcal != null ? ocr!.kcal!.toStringAsFixed(0) : '',
    );
    _proteinController = TextEditingController(
      text: ocr?.proteinG != null ? ocr!.proteinG!.toStringAsFixed(1) : '0',
    );
    _carbsController = TextEditingController(
      text: ocr?.carbsG != null ? ocr!.carbsG!.toStringAsFixed(1) : '0',
    );
    _fatController = TextEditingController(
      text: ocr?.fatG != null ? ocr!.fatG!.toStringAsFixed(1) : '0',
    );
    _fiberController = TextEditingController(
      text: ocr?.fiberG != null ? ocr!.fiberG!.toStringAsFixed(1) : '0',
    );
    _sugarController = TextEditingController(
      text: ocr?.sugarG != null ? ocr!.sugarG!.toStringAsFixed(1) : '0',
    );
    _sodiumController = TextEditingController(
      text: ocr?.sodiumMg != null ? ocr!.sodiumMg!.toStringAsFixed(0) : '0',
    );
    if (ocr?.sodiumMg != null && ocr!.sodiumMg! > 0) {
      _showAdvanced = true;
    }

    for (final TextEditingController ctrl in <TextEditingController>[
      _kcalController,
      _proteinController,
      _carbsController,
      _fatController,
    ]) {
      ctrl.addListener(_onMacroChanged);
    }
  }

  Future<void> _scanNutritionLabel() async {
    if (_isScanningOcr) return;
    setState(() => _isScanningOcr = true);
    unawaited(HapticFeedback.lightImpact());

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 92,
      );
      if (photo == null) return;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.foodAnalizandoTablaNutricionalConOcr),
        ),
      );

      final OcrNutritionData data =
          await ref.read(nutritionLabelOcrServiceProvider).processImage(photo);

      if (!mounted) return;
      if (data.hasAnyData) {
        if (data.kcal != null) {
          _kcalController.text = data.kcal!.toStringAsFixed(0);
        }
        if (data.proteinG != null) {
          _proteinController.text = data.proteinG!.toStringAsFixed(1);
        }
        if (data.carbsG != null) {
          _carbsController.text = data.carbsG!.toStringAsFixed(1);
        }
        if (data.fatG != null) {
          _fatController.text = data.fatG!.toStringAsFixed(1);
        }
        if (data.fiberG != null) {
          _fiberController.text = data.fiberG!.toStringAsFixed(1);
        }
        if (data.sugarG != null) {
          _sugarController.text = data.sugarG!.toStringAsFixed(1);
        }
        if (data.sodiumMg != null) {
          _sodiumController.text = data.sodiumMg!.toStringAsFixed(0);
          _showAdvanced = true;
        }
        if (data.servingGrams != null) {
          _servingGramsController.text = data.servingGrams!.toStringAsFixed(0);
        }
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.foodMacronutrientesDetectadosYRellenados),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.foodNoSeDetectaronValoresClaros,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.foodErrorAlEscanear((e).toString()))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isScanningOcr = false);
      }
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
        source: const drift.Value(FoodSource.userCustom),
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
        lastUsedAt: drift.Value(ref.read(clockProvider).now()),
      );

      final FoodItem? created = await ref.read(foodCatalogServiceProvider).createFood(companion);

      if (!mounted) return;
      Navigator.of(context).pop(created);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.foodNoSePudoGuardarEl((e).toString())),
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
                            context.l10n.foodCrearAlimentoPropio,
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
                            context.l10n.foodSeGuardaComoFavoritoEn,
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
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(AppIcons.close, color: c.text2),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Botón OCR de Escaneo con Cámara
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isScanningOcr ? null : _scanNutritionLabel,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: c.isFlat ? c.line2 : c.accent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: _isScanningOcr
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            Icons.document_scanner_rounded,
                            size: 18,
                            color: c.accent,
                          ),
                    label: Text(
                      _isScanningOcr
                          ? context.l10n.foodAnalizandoTablaConOcr: context.l10n.foodEscanearTablaNutricionalConCamara,
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                    ),
                  ),
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
                              context.l10n.foodKcal100G(_effectiveKcal.round().toString()),
                              softWrap: true,
                              style: TextStyle(
                                fontFamily: ScFonts.display,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: c.text,
                              ),
                            ),
                            Text(
                              context.l10n.foodPGCGG(_liveProtein.toStringAsFixed(0).toString(), _liveCarbs.toStringAsFixed(0).toString(), _liveFat.toStringAsFixed(0).toString()),
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
                            context.l10n.foodAutoKcal(_formula449Kcal.round().toString()),
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
                    labelText: context.l10n.foodNombreDelAlimentoOReceta,
                    hintText: context.l10n.foodEjArepaDeMaizAsada,
                    filled: true,
                    fillColor: c.bg3,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  validator: (String? val) {
                    if (val == null || val.trim().isEmpty) {
                      return context.l10n.foodEscribeUnNombreDescriptivo;
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
                          labelText: context.l10n.foodMarcaOpcional,
                          hintText: context.l10n.foodEjCasero,
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
                      child: CustomFoodNumberField(
                        controller: _servingGramsController,
                        label: context.l10n.foodPorcionBaseG,
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
                          labelText: context.l10n.foodEtiquetaDePorcion,
                          hintText: context.l10n.foodEj1Unidad1Taza,
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
                            labelText: context.l10n.foodCodigoEan,
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
                  context.l10n.foodValoresPorCada100G,
                  style: TextStyle(
                    fontFamily: ScFonts.display,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.foodSiDejasCaloriasVacioSe,
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
                      child: CustomFoodNumberField(
                        controller: _kcalController,
                        label: context.l10n.foodCaloriasKcal,
                        hint: _formula449Kcal > 0
                            ? '${_formula449Kcal.round()}'
                            : '0',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CustomFoodNumberField(
                        controller: _proteinController,
                        label: context.l10n.foodProteinaG,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: CustomFoodNumberField(
                        controller: _carbsController,
                        label: context.l10n.foodCarbohidratosG,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CustomFoodNumberField(
                        controller: _fatController,
                        label: context.l10n.foodGrasasG,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: CustomFoodNumberField(
                        controller: _fiberController,
                        label: context.l10n.foodFibraG,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CustomFoodNumberField(
                        controller: _sugarController,
                        label: context.l10n.foodAzucaresG,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // 3. Minerales, código de barras y Nutri-Score (opcional)
                CustomFoodExtras(
                  sodiumController: _sodiumController,
                  potassiumController: _potassiumController,
                  magnesiumController: _magnesiumController,
                  barcodeController: _barcodeController,
                  nutriScore: _selectedNutriScore,
                  onNutriScore: (String? grade) => setState(() => _selectedNutriScore = grade),
                  expanded: _showAdvanced,
                  onToggle: () => setState(() => _showAdvanced = !_showAdvanced),
                ),

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
                          ? context.l10n.foodGuardandoAlimento: context.l10n.foodGuardarEnMiCatalogo,
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
