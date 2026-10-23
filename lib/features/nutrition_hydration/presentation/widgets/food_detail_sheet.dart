import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/food_dao.dart';
import '../../../../core/database/daos/pet_dao.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/widgets/health_card.dart';

/// Modal interactivo estilo MyFitnessPal / Samsung Health para revisar y personalizar
/// el tamaño de porción, macros y micronutrientes antes de registrar el alimento.
class FoodDetailSheet extends ConsumerStatefulWidget {
  const FoodDetailSheet({
    super.key,
    required this.foodItem,
    required this.dateKey,
    this.initialMealType = 'lunch',
  });

  final FoodItem foodItem;
  final String dateKey;
  final String initialMealType;

  static Future<bool?> show({
    required BuildContext context,
    required FoodItem foodItem,
    required String dateKey,
    String initialMealType = 'lunch',
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FoodDetailSheet(
        foodItem: foodItem,
        dateKey: dateKey,
        initialMealType: initialMealType,
      ),
    );
  }

  @override
  ConsumerState<FoodDetailSheet> createState() => _FoodDetailSheetState();
}

class _FoodDetailSheetState extends ConsumerState<FoodDetailSheet> {
  late double _grams;
  late String _mealType;
  late final TextEditingController _gramsController;

  final List<double> _quickPortions = [50, 100, 150, 200, 250];

  @override
  void initState() {
    super.initState();
    _grams = widget.foodItem.defaultServingGrams > 0
        ? widget.foodItem.defaultServingGrams
        : 100.0;
    _mealType = widget.initialMealType;
    _gramsController = TextEditingController(text: _grams.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _gramsController.dispose();
    super.dispose();
  }

  void _updateGrams(double val) {
    setState(() {
      _grams = val.clamp(1.0, 2000.0);
      _gramsController.text = _grams.toStringAsFixed(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final food = widget.foodItem;
    final double factor = _grams / 100.0;

    final double totalKcal = food.kcalPer100g * factor;
    final double totalProtein = food.proteinPer100g * factor;
    final double totalCarbs = food.carbsPer100g * factor;
    final double totalFat = food.fatPer100g * factor;
    final double totalFiber = food.fiberPer100g * factor;
    final double totalSodium = food.sodiumMgPer100g * factor;
    final double totalPotassium = food.potassiumMgPer100g * factor;
    final double totalMagnesium = food.magnesiumMgPer100g * factor;

    final Map<String, String> mealLabels = {
      'breakfast': 'Desayuno',
      'lunch': 'Almuerzo',
      'dinner': 'Cena',
      'snack': 'Snack',
    };

    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: c.isFlat ? c.line2 : c.line, width: c.isFlat ? 1.5 : 1.0),
        ),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.text3.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Encabezado del Alimento
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        food.name,
                        style: const TextStyle(
                          fontFamily: ScFonts.display,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (food.brand != null && food.brand!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          food.brand!,
                          style: TextStyle(
                            fontFamily: ScFonts.ui,
                            fontSize: 13,
                            color: c.text2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Resumen de Calorías y Macros en Tarjeta Destacada
            HealthCard(
              backgroundColor: c.bg2,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        totalKcal.toStringAsFixed(0),
                        style: TextStyle(
                          fontFamily: ScFonts.display,
                          fontSize: 44,
                          fontWeight: FontWeight.w900,
                          color: c.accent,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'kcal',
                        style: TextStyle(
                          fontFamily: ScFonts.ui,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: c.text2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _MacroItem(label: 'Proteína', value: '${totalProtein.toStringAsFixed(1)}g', color: c.protein),
                      _MacroItem(label: 'Carbos', value: '${totalCarbs.toStringAsFixed(1)}g', color: const Color(0xFFFFB300)),
                      _MacroItem(label: 'Grasas', value: '${totalFat.toStringAsFixed(1)}g', color: const Color(0xFFFF7043)),
                      _MacroItem(label: 'Fibra', value: '${totalFiber.toStringAsFixed(1)}g', color: c.text2),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Selector de Porción en Gramos
            const Text(
              'Cantidad consumida',
              style: TextStyle(fontFamily: ScFonts.ui, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _gramsController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      suffixText: 'gramos',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (val) {
                      final parsed = double.tryParse(val.trim());
                      if (parsed != null && parsed > 0) {
                        setState(() => _grams = parsed);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _quickPortions.map((p) {
                  final isSelected = (_grams - p).abs() < 1;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('${p.toInt()}g'),
                      selected: isSelected,
                      onSelected: (_) => _updateGrams(p),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Momento de Comida
            const Text(
              'Comida del día',
              style: TextStyle(fontFamily: ScFonts.ui, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: mealLabels.entries.map((entry) {
                final isSelected = _mealType == entry.key;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: FilterChip(
                      label: FittedBox(child: Text(entry.value)),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _mealType = entry.key),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Minerales y Electrolitos Clave
            if (totalSodium > 0 || totalPotassium > 0 || totalMagnesium > 0) ...[
              HealthCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _MicroItem(label: 'Sodio', value: '${totalSodium.toStringAsFixed(0)} mg'),
                    _MicroItem(label: 'Potasio', value: '${totalPotassium.toStringAsFixed(0)} mg'),
                    _MicroItem(label: 'Magnesio', value: '${totalMagnesium.toStringAsFixed(0)} mg'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Botón de Confirmación
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: () async {
                  await HapticFeedback.mediumImpact();
                  final foodDao = ref.read(foodDaoProvider);
                  await foodDao.logFood(
                    FoodLogsCompanion.insert(
                      dateKey: widget.dateKey,
                      mealType: _mealType,
                      foodItemId: food.id,
                      gramsConsumed: _grams,
                      totalKcal: totalKcal,
                      totalProteinG: totalProtein,
                      totalCarbsG: totalCarbs,
                      totalFatG: totalFat,
                      totalFiberG: totalFiber,
                      totalSodiumMg: totalSodium,
                      totalPotassiumMg: totalPotassium,
                      totalMagnesiumMg: totalMagnesium,
                      loggedAt: drift.Value(DateTime.now()),
                    ),
                  );

                  // Recompensa en Nibi
                  await ref.read(petDaoProvider).grantDailyReward(
                        dateKey: widget.dateKey,
                        actionType: 'meal_log',
                        baseAmount: 10,
                      );

                  if (context.mounted) {
                    Navigator.of(context).pop(true);
                  }
                },
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text(
                  'Registrar en mi día',
                  style: TextStyle(fontFamily: ScFonts.display, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroItem extends StatelessWidget {
  const _MacroItem({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontFamily: ScFonts.display, fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontFamily: ScFonts.ui, fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

class _MicroItem extends StatelessWidget {
  const _MicroItem({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontFamily: ScFonts.ui, fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontFamily: ScFonts.display, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
