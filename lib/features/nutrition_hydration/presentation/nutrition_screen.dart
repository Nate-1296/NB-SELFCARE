import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/food_dao.dart';
import '../../../core/database/daos/hydration_dao.dart';
import '../../../core/database/daos/user_profile_dao.dart';
import '../../../core/services/health_connect_service.dart';
import '../../../core/services/local_ai_service.dart';
import '../../../core/services/open_food_facts_service.dart';
import '../../../shared/utils/date_time_extensions.dart';
import '../../../shared/widgets/nxtpaper_card.dart';

/// Pantalla principal de Nutrición, Micronutrientes e Hidratación.
class NutritionScreen extends ConsumerStatefulWidget {
  const NutritionScreen({super.key});

  @override
  ConsumerState<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends ConsumerState<NutritionScreen> {
  DateTime _selectedDate = DateTime.now();

  String get _dateKey => _selectedDate.dateKey;
  String get _yesterdayDateKey =>
      _selectedDate.subtract(const Duration(days: 1)).dateKey;

  void _openBarcodeScannerModal(UserProfile profile, String mealType) {
    final barcodeController = TextEditingController();
    final gramsController = TextEditingController(text: '100');
    bool isSearching = false;
    FoodItem? foundFood;
    String? searchError;

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: EdgeInsets.only(
                  left: 20.0,
                  right: 20.0,
                  top: 20.0,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Escanear Código / Open Food Facts',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12.0),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: barcodeController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Código de barras EAN / UPC',
                              hintText: 'Ej. 7702001041400',
                              prefixIcon: Icon(Icons.qr_code_scanner_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        FilledButton(
                          onPressed: isSearching
                              ? null
                              : () async {
                                  final code = barcodeController.text.trim();
                                  if (code.isEmpty) return;

                                  setModalState(() {
                                    isSearching = true;
                                    searchError = null;
                                    foundFood = null;
                                  });

                                  final offService =
                                      ref.read(openFoodFactsServiceProvider);
                                  final result =
                                      await offService.resolveBarcode(code);

                                  setModalState(() {
                                    isSearching = false;
                                    if (result != null) {
                                      foundFood = result;
                                    } else {
                                      searchError =
                                          'No encontrado en Open Food Facts ni en caché local. Puedes crearlo manualmente abajo.';
                                    }
                                  });
                                },
                          child: isSearching
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Buscar'),
                        ),
                      ],
                    ),
                    if (searchError != null) ...[
                      const SizedBox(height: 12.0),
                      Text(
                        searchError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _openQuickManualFoodModal(
                            barcodeController.text.trim(),
                            mealType,
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Alta Rápida Offline (4 Macros)'),
                      ),
                    ],
                    if (foundFood != null) ...[
                      const SizedBox(height: 16.0),
                      NxtpaperCard(
                        color: Colors.green.withValues(alpha: 0.1),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    foundFood!.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                if (foundFood!.nutriScore != null)
                                  Chip(
                                    label: Text('NutriScore ${foundFood!.nutriScore}'),
                                    backgroundColor: Colors.teal.shade100,
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                            ),
                            if (foundFood!.brand != null)
                              Text(
                                foundFood!.brand!,
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            const SizedBox(height: 8.0),
                            Text(
                              'Por 100g: ${foundFood!.kcalPer100g} kcal · P: ${foundFood!.proteinPer100g}g · C: ${foundFood!.carbsPer100g}g · G: ${foundFood!.fatPer100g}g',
                              style: const TextStyle(fontSize: 13),
                            ),
                            if (foundFood!.sodiumMgPer100g > 0)
                              Text(
                                'Electrolitos: Na: ${foundFood!.sodiumMgPer100g.toStringAsFixed(0)}mg'
                                '${foundFood!.potassiumMgPer100g > 0 ? " · K: ${foundFood!.potassiumMgPer100g.toStringAsFixed(0)}mg" : ""}'
                                '${foundFood!.magnesiumMgPer100g > 0 ? " · Mg: ${foundFood!.magnesiumMgPer100g.toStringAsFixed(0)}mg" : ""}',
                                style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      TextField(
                        controller: gramsController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Gramos consumidos',
                          suffixText: 'g',
                          prefixIcon: Icon(Icons.scale_rounded),
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      FilledButton.icon(
                        onPressed: () async {
                          final double grams =
                              double.tryParse(gramsController.text.trim()) ?? 100.0;
                          final double ratio = grams / 100.0;

                          final companion = FoodLogsCompanion(
                            dateKey: drift.Value(_dateKey),
                            loggedAt: drift.Value(DateTime.now()),
                            mealType: drift.Value(mealType),
                            foodItemId: drift.Value(foundFood!.id),
                            gramsConsumed: drift.Value(grams),
                            portionMultiplier: const drift.Value(1.0),
                            totalKcal: drift.Value(double.parse((foundFood!.kcalPer100g * ratio).toStringAsFixed(1))),
                            totalProteinG: drift.Value(double.parse((foundFood!.proteinPer100g * ratio).toStringAsFixed(1))),
                            totalCarbsG: drift.Value(double.parse((foundFood!.carbsPer100g * ratio).toStringAsFixed(1))),
                            totalFatG: drift.Value(double.parse((foundFood!.fatPer100g * ratio).toStringAsFixed(1))),
                            totalFiberG: drift.Value(double.parse((foundFood!.fiberPer100g * ratio).toStringAsFixed(1))),
                            totalSodiumMg: drift.Value(double.parse((foundFood!.sodiumMgPer100g * ratio).toStringAsFixed(1))),
                            totalPotassiumMg: drift.Value(double.parse((foundFood!.potassiumMgPer100g * ratio).toStringAsFixed(1))),
                            totalMagnesiumMg: drift.Value(double.parse((foundFood!.magnesiumMgPer100g * ratio).toStringAsFixed(1))),
                          );

                          await ref.read(foodDaoProvider).logFood(companion);

                          if (context.mounted) {
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('¡${foundFood!.name} registrado en $mealType!'),
                                backgroundColor: Colors.teal,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Registrar Alimento'),
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openQuickManualFoodModal(String? barcode, String mealType) {
    final nameCtrl = TextEditingController();
    final kcalCtrl = TextEditingController(text: '150');
    final pCtrl = TextEditingController(text: '10');
    final cCtrl = TextEditingController(text: '15');
    final fCtrl = TextEditingController(text: '5');
    final gramsCtrl = TextEditingController(text: '100');

    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Alta Rápida Offline (4 Macros)'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre del Alimento'),
                ),
                const SizedBox(height: 8.0),
                TextField(
                  controller: kcalCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Kcal por 100g', suffixText: 'kcal'),
                ),
                const SizedBox(height: 8.0),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: pCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Proteína (g)'),
                      ),
                    ),
                    const SizedBox(width: 6.0),
                    Expanded(
                      child: TextField(
                        controller: cCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Carbos (g)'),
                      ),
                    ),
                    const SizedBox(width: 6.0),
                    Expanded(
                      child: TextField(
                        controller: fCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Grasa (g)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                TextField(
                  controller: gramsCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Gramos que comiste', suffixText: 'g'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;

                final double kcal = double.tryParse(kcalCtrl.text) ?? 100.0;
                final double p = double.tryParse(pCtrl.text) ?? 0.0;
                final double c = double.tryParse(cCtrl.text) ?? 0.0;
                final double f = double.tryParse(fCtrl.text) ?? 0.0;
                final double grams = double.tryParse(gramsCtrl.text) ?? 100.0;
                final double ratio = grams / 100.0;

                final foodDao = ref.read(foodDaoProvider);
                final foodId = await foodDao.insertFood(
                  FoodItemsCompanion(
                    barcode: drift.Value(barcode?.isNotEmpty == true ? barcode : null),
                    name: drift.Value(name),
                    source: const drift.Value('user_custom'),
                    kcalPer100g: drift.Value(kcal),
                    proteinPer100g: drift.Value(p),
                    carbsPer100g: drift.Value(c),
                    fatPer100g: drift.Value(f),
                  ),
                );

                await foodDao.logFood(
                  FoodLogsCompanion(
                    dateKey: drift.Value(_dateKey),
                    loggedAt: drift.Value(DateTime.now()),
                    mealType: drift.Value(mealType),
                    foodItemId: drift.Value(foodId),
                    gramsConsumed: drift.Value(grams),
                    portionMultiplier: const drift.Value(1.0),
                    totalKcal: drift.Value(double.parse((kcal * ratio).toStringAsFixed(1))),
                    totalProteinG: drift.Value(double.parse((p * ratio).toStringAsFixed(1))),
                    totalCarbsG: drift.Value(double.parse((c * ratio).toStringAsFixed(1))),
                    totalFatG: drift.Value(double.parse((f * ratio).toStringAsFixed(1))),
                    totalFiberG: const drift.Value(0.0),
                    totalSodiumMg: const drift.Value(0.0),
                    totalPotassiumMg: const drift.Value(0.0),
                    totalMagnesiumMg: const drift.Value(0.0),
                  ),
                );

                if (context.mounted) {
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Guardar y Registrar'),
            ),
          ],
        ),
      ),
    );
  }

  void _openFtsSearchModal(String mealType) {
    final searchCtrl = TextEditingController();
    List<FoodItem> searchResults = [];
    bool isSearching = false;

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: EdgeInsets.only(
                  left: 20.0,
                  right: 20.0,
                  top: 20.0,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
                ),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Buscar Alimento (Catálogo USDA)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8.0),
                      TextField(
                        controller: searchCtrl,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Ej. aguacate, pechuga, huevo, avena...',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (query) async {
                          setModalState(() => isSearching = true);
                          final results = await ref.read(foodDaoProvider).searchFood(query);
                          setModalState(() {
                            searchResults = results;
                            isSearching = false;
                          });
                        },
                      ),
                      const SizedBox(height: 12.0),
                      if (isSearching)
                        const LinearProgressIndicator()
                      else
                        Expanded(
                          child: searchResults.isEmpty
                              ? const Center(
                                  child: Text('Escribe para buscar con FTS5 local (< 2ms)'),
                                )
                              : ListView.separated(
                                  itemCount: searchResults.length,
                                  separatorBuilder: (_, _) => const Divider(height: 1),
                                  itemBuilder: (c, idx) {
                                    final food = searchResults[idx];
                                    return ListTile(
                                      title: Text(food.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text(
                                        '100g: ${food.kcalPer100g} kcal · P: ${food.proteinPer100g}g · C: ${food.carbsPer100g}g · G: ${food.fatPer100g}g',
                                      ),
                                      trailing: const Icon(Icons.add_circle_outline, color: Colors.teal),
                                      onTap: () async {
                                        Navigator.of(ctx).pop();
                                        _showLogPortionDialog(food, mealType);
                                      },
                                    );
                                  },
                                ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showLogPortionDialog(FoodItem food, String mealType) {
    final gramsCtrl = TextEditingController(text: '100');

    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Porción de ${food.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Valores por 100g: ${food.kcalPer100g} kcal · P: ${food.proteinPer100g}g · C: ${food.carbsPer100g}g · G: ${food.fatPer100g}g'),
              const SizedBox(height: 16.0),
              TextField(
                controller: gramsCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Gramos consumidos',
                  suffixText: 'g',
                  prefixIcon: Icon(Icons.scale),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final double grams = double.tryParse(gramsCtrl.text.trim()) ?? 100.0;
                final double ratio = grams / 100.0;

                final companion = FoodLogsCompanion(
                  dateKey: drift.Value(_dateKey),
                  loggedAt: drift.Value(DateTime.now()),
                  mealType: drift.Value(mealType),
                  foodItemId: drift.Value(food.id),
                  gramsConsumed: drift.Value(grams),
                  portionMultiplier: const drift.Value(1.0),
                  totalKcal: drift.Value(double.parse((food.kcalPer100g * ratio).toStringAsFixed(1))),
                  totalProteinG: drift.Value(double.parse((food.proteinPer100g * ratio).toStringAsFixed(1))),
                  totalCarbsG: drift.Value(double.parse((food.carbsPer100g * ratio).toStringAsFixed(1))),
                  totalFatG: drift.Value(double.parse((food.fatPer100g * ratio).toStringAsFixed(1))),
                  totalFiberG: drift.Value(double.parse((food.fiberPer100g * ratio).toStringAsFixed(1))),
                  totalSodiumMg: drift.Value(double.parse((food.sodiumMgPer100g * ratio).toStringAsFixed(1))),
                  totalPotassiumMg: drift.Value(double.parse((food.potassiumMgPer100g * ratio).toStringAsFixed(1))),
                  totalMagnesiumMg: drift.Value(double.parse((food.magnesiumMgPer100g * ratio).toStringAsFixed(1))),
                );

                await ref.read(foodDaoProvider).logFood(companion);

                if (context.mounted) {
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Registrar'),
            ),
          ],
        ),
      ),
    );
  }

  void _openAiMealModal(BuildContext context) {
    final textController = TextEditingController();
    String selectedMealType = 'lunch';
    bool isProcessing = false;

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: EdgeInsets.only(
                  left: 20.0,
                  right: 20.0,
                  top: 20.0,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome, color: Colors.teal),
                            const SizedBox(width: 8.0),
                            Text(
                              'Dictado / Registro con IA Local',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      'Escribe o dicta libremente lo que comiste. El motor local extraerá '
                      'los alimentos y porciones para contrastarlos con la base USDA/FTS5.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12.0),
                    TextField(
                      controller: textController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Ej. 200g pechuga de pollo, 150g arroz y 1 huevo cocido',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12.0),
                    DropdownButtonFormField<String>(
                      initialValue: selectedMealType,
                      decoration: const InputDecoration(
                        labelText: 'Momento de comida',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'breakfast', child: Text('Desayuno')),
                        DropdownMenuItem(value: 'lunch', child: Text('Almuerzo')),
                        DropdownMenuItem(value: 'dinner', child: Text('Cena')),
                        DropdownMenuItem(value: 'snack', child: Text('Snack / Colación')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedMealType = val);
                      },
                    ),
                    const SizedBox(height: 16.0),
                    FilledButton.icon(
                      onPressed: isProcessing
                          ? null
                          : () async {
                              final text = textController.text.trim();
                              if (text.isEmpty) return;

                              setModalState(() => isProcessing = true);
                              try {
                                final aiService = ref.read(localAiServiceProvider);
                                final foodDao = ref.read(foodDaoProvider);
                                final logged = await aiService.resolveAndLogMeal(
                                  foodDao: foodDao,
                                  text: text,
                                  mealType: selectedMealType,
                                  dateKey: _dateKey,
                                );

                                if (context.mounted) {
                                  Navigator.of(ctx).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('¡${logged.length} alimentos registrados con éxito con IA Local!'),
                                      backgroundColor: Colors.teal,
                                    ),
                                  );
                                }
                              } finally {
                                setModalState(() => isProcessing = false);
                              }
                            },
                      icon: isProcessing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.bolt_rounded),
                      label: Text(isProcessing ? 'Procesando...' : 'Interpretar y Registrar en SQLite'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: Colors.teal,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openCombosModal(String mealType) {
    double multiplier = 1.0;
    int? selectedComboId;

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              final foodDao = ref.read(foodDaoProvider);

              return StreamBuilder<List<MealCombo>>(
                stream: foodDao.watchMealCombos(),
                builder: (c, snapshot) {
                  final combos = snapshot.data ?? [];

                  return Padding(
                    padding: EdgeInsets.only(
                      left: 20.0,
                      right: 20.0,
                      top: 20.0,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Combos Caseros con Escalador',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.of(ctx).pop(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12.0),
                        if (combos.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Center(
                              child: Text(
                                'Aún no tienes combos creados.\nPuedes registrar tus platos habituales como combo.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        else ...[
                          const Text('Selecciona el combo habitual:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8.0),
                          DropdownButtonFormField<int>(
                            initialValue: selectedComboId ?? combos.first.id,
                            items: combos.map((cb) {
                              return DropdownMenuItem<int>(
                                value: cb.id,
                                child: Text('${cb.name} (usado ${cb.timesUsed}x)'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setModalState(() => selectedComboId = val);
                            },
                          ),
                          const SizedBox(height: 16.0),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Escalador de Porción:', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('${multiplier.toStringAsFixed(2)}x', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal)),
                            ],
                          ),
                          Slider(
                            value: multiplier,
                            min: 0.25,
                            max: 3.0,
                            divisions: 11,
                            label: '${multiplier.toStringAsFixed(2)}x',
                            onChanged: (val) => setModalState(() => multiplier = val),
                          ),
                          const SizedBox(height: 16.0),
                          FilledButton.icon(
                            onPressed: () async {
                              final idToLog = selectedComboId ?? combos.first.id;
                              await foodDao.logCombo(
                                comboId: idToLog,
                                multiplier: multiplier,
                                dateKey: _dateKey,
                                mealType: mealType,
                              );

                              if (context.mounted) {
                                Navigator.of(ctx).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('¡Combo registrado (${multiplier.toStringAsFixed(2)}x)!'),
                                    backgroundColor: Colors.teal,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.check),
                            label: const Text('Registrar Combo Escalado'),
                            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _repeatYesterday(String mealType) async {
    final foodDao = ref.read(foodDaoProvider);
    final List<int> inserted = await foodDao.repeatMealFromYesterday(
      fromDateKey: _yesterdayDateKey,
      toDateKey: _dateKey,
      mealType: mealType,
    );

    if (inserted.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No hay registros de $mealType en el día anterior')),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Repetido $mealType de ayer (${inserted.length} alimentos)!'),
          action: SnackBarAction(
            label: 'Deshacer',
            onPressed: () async {
              for (final id in inserted) {
                await foodDao.deleteFoodLog(id);
              }
            },
          ),
        ),
      );
    }
  }

  Future<void> _logWaterGlass(int volumeMl, int goalMl) async {
    final hydrationDao = ref.read(hydrationDaoProvider);
    await hydrationDao.logGlass(
      dateKey: _dateKey,
      volumeMl: volumeMl,
      dailyGoalMl: goalMl,
    );

    // Exportar asíncronamente a Health Connect
    final healthConnect = ref.read(healthConnectServiceProvider);
    unawaited(
      healthConnect.writeHydration(
        amountMl: volumeMl,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<UserProfile?> profileAsync = ref.watch(userProfileStreamProvider);
    final foodDao = ref.watch(foodDaoProvider);
    final hydrationDao = ref.watch(hydrationDaoProvider);

    return profileAsync.when(
      data: (UserProfile? profile) {
        if (profile == null) {
          return const Scaffold(body: Center(child: Text('Perfil no encontrado')));
        }

        final int calorieGoal = profile.currentAdaptiveTdeeKcal;
        final int waterGoal = profile.dailyWaterGoalMl;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Nutrición e Hidratación'),
            actions: [
              IconButton(
                tooltip: 'Día anterior',
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                  });
                },
              ),
              Center(
                child: Text(
                  _dateKey == DateTime.now().dateKey ? 'Hoy' : _dateKey,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: 'Día siguiente',
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    _selectedDate = _selectedDate.add(const Duration(days: 1));
                  });
                },
              ),
              IconButton(
                tooltip: 'Dictado con IA Local',
                icon: const Icon(Icons.auto_awesome),
                onPressed: () => _openAiMealModal(context),
              ),
            ],
          ),
          body: StreamBuilder<List<FoodLog>>(
            stream: foodDao.watchLogsForDate(_dateKey),
            builder: (context, logsSnapshot) {
              final logs = logsSnapshot.data ?? [];

              double totalKcal = 0;
              double totalP = 0;
              double totalC = 0;
              double totalF = 0;
              double totalFiber = 0;
              double totalNa = 0;
              double totalK = 0;
              double totalMg = 0;

              for (final l in logs) {
                totalKcal += l.totalKcal;
                totalP += l.totalProteinG;
                totalC += l.totalCarbsG;
                totalF += l.totalFatG;
                totalFiber += l.totalFiberG;
                totalNa += l.totalSodiumMg;
                totalK += l.totalPotassiumMg;
                totalMg += l.totalMagnesiumMg;
              }

              final double remainingKcal = calorieGoal - totalKcal;

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                children: [
                  // Anillo / Tarjeta Principal de Calorías
                  NxtpaperCard(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text(
                                  totalKcal.toStringAsFixed(0),
                                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const Text('Consumidas', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                            Container(height: 36, width: 1, color: theme.colorScheme.outlineVariant),
                            Column(
                              children: [
                                Text(
                                  remainingKcal.toStringAsFixed(0),
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: remainingKcal >= 0 ? Colors.teal : Colors.deepOrange,
                                  ),
                                ),
                                const Text('Restantes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Container(height: 36, width: 1, color: theme.colorScheme.outlineVariant),
                            Column(
                              children: [
                                Text(
                                  '$calorieGoal',
                                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const Text('Meta TDEE', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 24.0),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _MacroChip(label: 'Proteína', amount: '${totalP.toStringAsFixed(0)}g', color: Colors.blue),
                            _MacroChip(label: 'Carbos', amount: '${totalC.toStringAsFixed(0)}g', color: Colors.amber.shade800),
                            _MacroChip(label: 'Grasa', amount: '${totalF.toStringAsFixed(0)}g', color: Colors.purple),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16.0),

                  // Semáforo de Electrolitos (ADR-02)
                  NxtpaperCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.bolt_rounded, color: Colors.amber, size: 22),
                            const SizedBox(width: 6.0),
                            Text(
                              'Triángulo de Electrolitos y Minerales',
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12.0),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _ElectrolyteItem(name: 'Sodio', value: '${totalNa.toStringAsFixed(0)} mg', target: '2300 mg'),
                            _ElectrolyteItem(name: 'Potasio', value: '${totalK.toStringAsFixed(0)} mg', target: '3500 mg'),
                            _ElectrolyteItem(name: 'Magnesio', value: '${totalMg.toStringAsFixed(0)} mg', target: '400 mg'),
                            _ElectrolyteItem(name: 'Fibra', value: '${totalFiber.toStringAsFixed(0)} g', target: '30 g'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16.0),

                  // Registro Atómico de Hidratación
                  StreamBuilder<int>(
                    stream: hydrationDao.watchTotalWaterMl(_dateKey),
                    builder: (context, waterSnapshot) {
                      final int totalWater = waterSnapshot.data ?? 0;
                      final double waterRatio = (totalWater / waterGoal).clamp(0.0, 1.0);

                      return NxtpaperCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.water_drop, color: Colors.blue),
                                    const SizedBox(width: 8.0),
                                    Text(
                                      'Hidratación: $totalWater / $waterGoal ml',
                                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                Text('${(waterRatio * 100).toStringAsFixed(0)}%'),
                              ],
                            ),
                            const SizedBox(height: 8.0),
                            LinearProgressIndicator(value: waterRatio, minHeight: 8),
                            const SizedBox(height: 12.0),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _logWaterGlass(250, waterGoal),
                                  icon: const Icon(Icons.local_drink, size: 16),
                                  label: const Text('+250 ml'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _logWaterGlass(500, waterGoal),
                                  icon: const Icon(Icons.local_drink, size: 16),
                                  label: const Text('+500 ml'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16.0),

                  // Bloques Horarios de Comida
                  _MealBlockWidget(
                    title: 'Desayuno',
                    mealType: 'breakfast',
                    logs: logs.where((l) => l.mealType == 'breakfast').toList(),
                    onAddBarcode: () => _openBarcodeScannerModal(profile, 'breakfast'),
                    onAddFts: () => _openFtsSearchModal('breakfast'),
                    onAddCombo: () => _openCombosModal('breakfast'),
                    onRepeatYesterday: () => _repeatYesterday('breakfast'),
                    onDeleteLog: foodDao.deleteFoodLog,
                  ),
                  const SizedBox(height: 12.0),
                  _MealBlockWidget(
                    title: 'Almuerzo',
                    mealType: 'lunch',
                    logs: logs.where((l) => l.mealType == 'lunch').toList(),
                    onAddBarcode: () => _openBarcodeScannerModal(profile, 'lunch'),
                    onAddFts: () => _openFtsSearchModal('lunch'),
                    onAddCombo: () => _openCombosModal('lunch'),
                    onRepeatYesterday: () => _repeatYesterday('lunch'),
                    onDeleteLog: foodDao.deleteFoodLog,
                  ),
                  const SizedBox(height: 12.0),
                  _MealBlockWidget(
                    title: 'Cena',
                    mealType: 'dinner',
                    logs: logs.where((l) => l.mealType == 'dinner').toList(),
                    onAddBarcode: () => _openBarcodeScannerModal(profile, 'dinner'),
                    onAddFts: () => _openFtsSearchModal('dinner'),
                    onAddCombo: () => _openCombosModal('dinner'),
                    onRepeatYesterday: () => _repeatYesterday('dinner'),
                    onDeleteLog: foodDao.deleteFoodLog,
                  ),
                  const SizedBox(height: 12.0),
                  _MealBlockWidget(
                    title: 'Snacks / Otros',
                    mealType: 'snack',
                    logs: logs.where((l) => l.mealType == 'snack').toList(),
                    onAddBarcode: () => _openBarcodeScannerModal(profile, 'snack'),
                    onAddFts: () => _openFtsSearchModal('snack'),
                    onAddCombo: () => _openCombosModal('snack'),
                    onRepeatYesterday: () => _repeatYesterday('snack'),
                    onDeleteLog: foodDao.deleteFoodLog,
                  ),
                  const SizedBox(height: 32.0),
                ],
              );
            },
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}

class _MacroChip extends StatelessWidget {
  const _MacroChip({required this.label, required this.amount, required this.color});

  final String label;
  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(amount, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _ElectrolyteItem extends StatelessWidget {
  const _ElectrolyteItem({required this.name, required this.value, required this.target});

  final String name;
  final String value;
  final String target;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Text(name, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text('meta $target', style: const TextStyle(fontSize: 9, color: Colors.blueGrey)),
      ],
    );
  }
}

class _MealBlockWidget extends StatelessWidget {
  const _MealBlockWidget({
    required this.title,
    required this.mealType,
    required this.logs,
    required this.onAddBarcode,
    required this.onAddFts,
    required this.onAddCombo,
    required this.onRepeatYesterday,
    required this.onDeleteLog,
  });

  final String title;
  final String mealType;
  final List<FoodLog> logs;
  final VoidCallback onAddBarcode;
  final VoidCallback onAddFts;
  final VoidCallback onAddCombo;
  final VoidCallback onRepeatYesterday;
  final ValueChanged<int> onDeleteLog;

  @override
  Widget build(BuildContext context) {
    final double blockKcal = logs.fold(0.0, (acc, item) => acc + item.totalKcal);

    return NxtpaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$title (${blockKcal.toStringAsFixed(0)} kcal)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Repetir de ayer en 1 toque',
                    icon: const Icon(Icons.history_rounded, size: 20),
                    onPressed: onRepeatYesterday,
                  ),
                  IconButton(
                    tooltip: 'Escanear código de barras',
                    icon: const Icon(Icons.qr_code_scanner, size: 20),
                    onPressed: onAddBarcode,
                  ),
                  IconButton(
                    tooltip: 'Buscar en catálogo USDA',
                    icon: const Icon(Icons.search, size: 20),
                    onPressed: onAddFts,
                  ),
                  IconButton(
                    tooltip: 'Combos caseros con escalador',
                    icon: const Icon(Icons.tune_rounded, size: 20),
                    onPressed: onAddCombo,
                  ),
                ],
              ),
            ],
          ),
          if (logs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('Sin alimentos registrados', style: TextStyle(color: Colors.grey, fontSize: 13)),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: logs.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (c, idx) {
                final l = logs[idx];
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${l.gramsConsumed.toStringAsFixed(0)}g - ${l.totalKcal.toStringAsFixed(0)} kcal', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('P: ${l.totalProteinG}g · C: ${l.totalCarbsG}g · G: ${l.totalFatG}g'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () => onDeleteLog(l.id),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
