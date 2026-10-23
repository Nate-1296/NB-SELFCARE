import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/food_dao.dart';
import '../../../core/database/daos/user_profile_dao.dart';
import '../../../core/services/local_ai_service.dart';
import '../../../shared/theme/sc_colors.dart';
import '../../../shared/theme/sc_theme.dart';
import '../../../shared/utils/date_time_extensions.dart';
import '../../../shared/widgets/app_icons.dart';
import '../../../shared/widgets/chip_pill.dart';
import '../../../shared/widgets/health_card.dart';
import '../../../shared/widgets/section_head.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../shared/widgets/top_bar.dart';
import 'widgets/barcode_scanner_sheet.dart';
import 'widgets/food_search_modal.dart';

/// Pestaña "Comer / Nutrición": registro de comidas, macros y electrolitos
/// con estética limpia inspirada en Samsung Health y NB Sound.
class NutricionScreen extends ConsumerStatefulWidget {
  const NutricionScreen({super.key});

  @override
  ConsumerState<NutricionScreen> createState() => _NutricionScreenState();
}

class _NutricionScreenState extends ConsumerState<NutricionScreen> {
  DateTime _selectedDate = DateTime.now();

  String get _dateKey => _selectedDate.dateKey;
  String get _yesterdayDateKey =>
      _selectedDate.subtract(const Duration(days: 1)).dateKey;

  Future<void> _repeatYesterdayMeal(String mealType) async {
    final foodDao = ref.read(foodDaoProvider);
    final repeated = await foodDao.repeatMealFromYesterday(
      fromDateKey: _yesterdayDateKey,
      toDateKey: _dateKey,
      mealType: mealType,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(repeated.isNotEmpty
              ? '¡Se repitieron ${repeated.length} alimentos de ayer!'
              : 'No había registros de ayer para esta comida.'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _openAiMealModal() {
    final textController = TextEditingController();
    String selectedMealType = 'lunch';
    bool isProcessing = false;

    unawaited(mostrarHojaMenu<void>(
      context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(AppIcons.ai, color: context.sc.accent, size: 22),
                          const SizedBox(width: 8),
                          const Text(
                            'Dictado con IA Local',
                            style: TextStyle(
                              fontFamily: ScFonts.display,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
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
                  const SizedBox(height: 8),
                  const Text(
                    'Escribe o dicta libremente tu comida. El modelo extraerá las porciones y macros.',
                    style: TextStyle(fontFamily: ScFonts.ui, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: textController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Ej. 200g pechuga de pollo, 150g arroz y 1 huevo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 16),
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
                                    content: Text('¡${logged.length} alimentos registrados con IA Local!'),
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
                        : const Icon(AppIcons.check),
                    label: Text(isProcessing ? 'Procesando...' : 'Registrar en SQLite'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  ),
                ],
              ),
            );
          },
        );
      },
    ));
  }

  void _openCombosModal(String mealType) {
    double multiplier = 1.0;
    unawaited(mostrarHojaMenu<void>(
      context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final foodDao = ref.watch(foodDaoProvider);

            return StreamBuilder<List<MealCombo>>(
              stream: foodDao.watchMealCombos(),
              builder: (context, snapshot) {
                final combos = snapshot.data ?? [];
                if (combos.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(child: Text('No tienes combos creados todavía.')),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Combos Caseros Escalables',
                        style: TextStyle(
                          fontFamily: ScFonts.display,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('Selecciona un combo y ajusta su multiplicador (0.25x – 3.0x):',
                          style: TextStyle(fontFamily: ScFonts.ui, fontSize: 13)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Porción:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('${multiplier.toStringAsFixed(2)}x',
                              style: const TextStyle(fontFamily: ScFonts.display, fontWeight: FontWeight.bold)),
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
                      const SizedBox(height: 12),
                      for (final combo in combos)
                        ListTile(
                          title: Text(combo.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Usado ${combo.timesUsed} veces'),
                          trailing: FilledButton.tonal(
                            onPressed: () async {
                              await foodDao.logCombo(
                                comboId: combo.id,
                                multiplier: multiplier,
                                dateKey: _dateKey,
                                mealType: mealType,
                              );
                              if (context.mounted) {
                                Navigator.of(ctx).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('¡Combo "${combo.name}" registrado (${multiplier}x)!')),
                                );
                              }
                            },
                            child: const Text('Registrar'),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final foodDao = ref.watch(foodDaoProvider);
    final profile = ref.watch(userProfileStreamProvider).value;
    final isToday = _dateKey == DateTime.now().dateKey;
    final String initial = (profile != null && profile.name.isNotEmpty) ? profile.name[0].toUpperCase() : 'N';

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          TopBar(
            title: 'Nutrición & Macros',
            subtitle: isToday ? 'HOY' : _dateKey,
            avatarInicial: initial,
            avatarFoto: () {
              final path = profile?.avatarPath;
              return (path != null && File(path).existsSync()) ? FileImage(File(path)) : null;
            }(),
            onProfile: () => context.go('/perfil'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Día anterior',
                  icon: const Icon(AppIcons.chevronLeft),
                  onPressed: () {
                    setState(() {
                      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                    });
                  },
                ),
                IconButton(
                  tooltip: 'Día siguiente',
                  icon: const Icon(AppIcons.chevronRight),
                  onPressed: () {
                    setState(() {
                      _selectedDate = _selectedDate.add(const Duration(days: 1));
                    });
                  },
                ),
              ],
            ),
          ),

          // Barra de búsqueda rápida estilo MyFitnessPal / Samsung Health
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: InkWell(
              onTap: () => FoodSearchModal.show(context: context, dateKey: _dateKey, mealType: 'lunch'),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: c.bg2,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: c.isFlat ? c.line2 : c.line,
                    width: c.isFlat ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: c.accent, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Buscar alimento (ej. manzana, avena, pollo)...',
                        style: TextStyle(fontFamily: ScFonts.ui, fontSize: 13.5, color: c.text3),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.qr_code_scanner_rounded, color: c.accent),
                      tooltip: 'Escanear con cámara',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => BarcodeScannerSheet.show(context: context, dateKey: _dateKey, mealType: 'lunch'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Acciones directas
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: ChipPill(
                    label: 'Buscar',
                    icon: Icons.search,
                    activeColor: c.accent,
                    onTap: () => FoodSearchModal.show(context: context, dateKey: _dateKey, mealType: 'lunch'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChipPill(
                    label: 'Escanear',
                    icon: AppIcons.barcode,
                    onTap: () => BarcodeScannerSheet.show(context: context, dateKey: _dateKey, mealType: 'lunch'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChipPill(
                    label: 'Dictado IA',
                    icon: AppIcons.ai,
                    onTap: _openAiMealModal,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChipPill(
                    label: 'Combos',
                    icon: AppIcons.combos,
                    onTap: () => _openCombosModal('lunch'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Resumen de Macronutrientes y Triángulo de Electrolitos
          StreamBuilder<List<FoodLogWithItem>>(
            stream: foodDao.watchLogsWithItemForDate(_dateKey),
            builder: (context, snapshot) {
              final logsWithItems = snapshot.data ?? [];
              final double totalKcal = logsWithItems.fold(0.0, (acc, item) => acc + item.log.totalKcal);
              final double totalP = logsWithItems.fold(0.0, (acc, item) => acc + item.log.totalProteinG);
              final double totalC = logsWithItems.fold(0.0, (acc, item) => acc + item.log.totalCarbsG);
              final double totalF = logsWithItems.fold(0.0, (acc, item) => acc + item.log.totalFatG);
              final double totalSodium = logsWithItems.fold(0.0, (acc, item) => acc + item.log.totalSodiumMg);
              final double totalPotassium = logsWithItems.fold(0.0, (acc, item) => acc + item.log.totalPotassiumMg);
              final double totalMagnesium = logsWithItems.fold(0.0, (acc, item) => acc + item.log.totalMagnesiumMg);
              final double totalFiber = logsWithItems.fold(0.0, (acc, item) => acc + item.log.totalFiberG);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HealthCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Macronutrientes Consumidos',
                          style: TextStyle(
                            fontFamily: ScFonts.display,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: c.text,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _MacroCol(label: 'Calorías', value: '${totalKcal.toInt()} kcal', color: c.calories),
                            _MacroCol(label: 'Proteína', value: '${totalP.toInt()} g', color: c.protein),
                            _MacroCol(label: 'Carbos', value: '${totalC.toInt()} g', color: Colors.amber),
                            _MacroCol(label: 'Grasas', value: '${totalF.toInt()} g', color: Colors.deepOrange),
                          ],
                        ),
                        const Divider(height: 24),
                        Text(
                          'Triángulo de Electrolitos y Fibra',
                          style: TextStyle(
                            fontFamily: ScFonts.ui,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: c.text2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _MicroCol(label: 'Sodio', value: '${totalSodium.toInt()} mg'),
                            _MicroCol(label: 'Potasio', value: '${totalPotassium.toInt()} mg'),
                            _MicroCol(label: 'Magnesio', value: '${totalMagnesium.toInt()} mg'),
                            _MicroCol(label: 'Fibra', value: '${totalFiber.toInt()} g'),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Bloques de Comida
                  _buildMealSection(context, foodDao, logsWithItems, 'Desayuno', 'breakfast'),
                  _buildMealSection(context, foodDao, logsWithItems, 'Almuerzo', 'lunch'),
                  _buildMealSection(context, foodDao, logsWithItems, 'Cena', 'dinner'),
                  _buildMealSection(context, foodDao, logsWithItems, 'Snacks & Colaciones', 'snack'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMealSection(
    BuildContext context,
    FoodDao foodDao,
    List<FoodLogWithItem> allLogsWithItems,
    String title,
    String mealType,
  ) {
    final ScColors c = context.sc;
    final mealItems = allLogsWithItems.where((l) => l.log.mealType == mealType).toList();
    final double mealKcal = mealItems.fold(0.0, (acc, item) => acc + item.log.totalKcal);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHead(
          title: title,
          subtitle: '${mealKcal.toInt()} kcal',
          actionLabel: '+ Añadir',
          onAction: () => FoodSearchModal.show(context: context, dateKey: _dateKey, mealType: mealType),
        ),
        if (mealItems.isEmpty)
          HealthCard(
            margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sin alimentos en $title.',
                  style: TextStyle(fontFamily: ScFonts.ui, fontSize: 13, color: c.text3),
                ),
                TextButton.icon(
                  onPressed: () => _repeatYesterdayMeal(mealType),
                  icon: const Icon(AppIcons.repeat, size: 14),
                  label: const Text('Repetir ayer', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          )
        else
          HealthCard(
            margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            padding: EdgeInsets.zero,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: mealItems.length,
              separatorBuilder: (_, _) => Divider(height: 1, color: c.line),
              itemBuilder: (ctx, idx) {
                final item = mealItems[idx];
                final foodLog = item.log;
                final name = item.foodItem?.name ?? 'Alimento';

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  title: Text(
                    name,
                    style: TextStyle(fontFamily: ScFonts.ui, fontSize: 14, fontWeight: FontWeight.w600, color: c.text),
                  ),
                  subtitle: Text(
                    '${foodLog.gramsConsumed.toInt()}g · ${foodLog.totalKcal.toInt()} kcal · P: ${foodLog.totalProteinG.toInt()}g',
                    style: TextStyle(fontSize: 12, color: c.text2),
                  ),
                  trailing: IconButton(
                    icon: const Icon(AppIcons.delete, size: 18),
                    onPressed: () => foodDao.deleteFoodLog(foodLog.id),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _MacroCol extends StatelessWidget {
  const _MacroCol({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontFamily: ScFonts.display, fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

class _MicroCol extends StatelessWidget {
  const _MicroCol({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

