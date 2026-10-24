import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/body_measurements_dao.dart';
import '../../../core/database/daos/fasting_dao.dart';
import '../../../core/database/daos/food_dao.dart';
import '../../../core/database/daos/hydration_dao.dart';
import '../../../core/database/daos/pet_dao.dart';
import '../../../core/database/daos/user_profile_dao.dart';
import '../../../core/database/daos/workout_dao.dart';
import '../../../core/services/health_connect_service.dart';
import '../../../shared/theme/sc_colors.dart';
import '../../../shared/theme/sc_theme.dart';
import '../../../shared/utils/current_date_provider.dart';
import '../../../shared/utils/daily_targets_calculator.dart';
import '../../../shared/utils/date_time_extensions.dart';
import '../../../shared/widgets/app_icons.dart';
import '../../../shared/widgets/health_card.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../shared/widgets/top_bar.dart';
import 'widgets/barcode_scanner_sheet.dart';
import 'widgets/custom_food_sheet.dart';
import 'widgets/food_detail_sheet.dart';
import 'widgets/food_search_modal.dart';
import 'widgets/meal_slot_selector.dart';
import 'widgets/nutrition_sheets.dart';

/// Pestaña "Comer": centro integral de nutrición, hidratación, electrolitos y combos.
///
/// Diseñada bajo los estándares UX/UI de NB Selfcare:
/// - Encabezado limpio con fecha corta DD/MM/YYYY debajo del título y selector semanal táctil.
/// - Cero textos truncados: cuadrículas 2×2 y filas amplias con envoltura natural.
/// - Cero duplicidad de controles: flujo unificado con subpáginas modales cohesivas.
/// - Fidelidad dual en Material You OLED y TCL NXTPAPER Modo Papel (E-Ink).
class NutricionScreen extends ConsumerStatefulWidget {
  const NutricionScreen({super.key});

  @override
  ConsumerState<NutricionScreen> createState() => _NutricionScreenState();
}

class _NutricionScreenState extends ConsumerState<NutricionScreen> {
  DateTime? _customSelectedDate;

  DateTime _effectiveDate(DateTime currentDay) =>
      _customSelectedDate ?? currentDay;

  static String _formatearFechaCorta(DateTime date) {
    final String dd = date.day.toString().padLeft(2, '0');
    final String mm = date.month.toString().padLeft(2, '0');
    final String yyyy = date.year.toString().padLeft(4, '0');
    return '$dd/$mm/$yyyy';
  }

  static String _fmtClock(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  void _selectDate(DateTime date, DateTime today) {
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _customSelectedDate = date.dateKey == today.dateKey ? null : date;
    });
  }

  Future<void> _openFoodSearch(String dateKey, String initialMealType) async {
    unawaited(HapticFeedback.selectionClick());
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FoodSearchModal(
        initialMealType: initialMealType,
        targetDateKey: dateKey,
      ),
    );
  }

  Future<void> _openBarcodeScanner(
    String dateKey,
    String initialMealType,
  ) async {
    unawaited(HapticFeedback.selectionClick());
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BarcodeScannerSheet(
        initialMealType: initialMealType,
        targetDateKey: dateKey,
      ),
    );
  }

  void _openAiDictation(String dateKey, String initialMealType) {
    unawaited(HapticFeedback.selectionClick());
    unawaited(
      mostrarHojaMenu<void>(
        context,
        builder: (_) => AiMealDictationSheet(
          dateKey: dateKey,
          initialMealType: initialMealType,
        ),
      ),
    );
  }

  void _openCombosSheet(String dateKey, String initialMealType) {
    unawaited(HapticFeedback.selectionClick());
    unawaited(
      mostrarHojaMenu<void>(
        context,
        builder: (_) => CombosModalSheet(
          dateKey: dateKey,
          initialMealType: initialMealType,
        ),
      ),
    );
  }

  Future<void> _openCustomFoodAndLog(String dateKey, String mealType) async {
    unawaited(HapticFeedback.selectionClick());
    final FoodItem? created = await showModalBottomSheet<FoodItem>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CustomFoodSheet(),
    );
    if (!mounted || created == null) return;
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FoodDetailSheet(
        food: created,
        initialMealType: mealType,
        targetDateKey: dateKey,
      ),
    );
  }

  void _openEditLogSheet(FoodLogWithItem entry) {
    unawaited(HapticFeedback.selectionClick());
    unawaited(
      mostrarHojaMenu<void>(
        context,
        builder: (_) => EditFoodLogSheet(
          entry: entry,
          onDeleteRequested: () => _deleteFoodLogWithUndo(entry),
        ),
      ),
    );
  }

  Future<void> _deleteFoodLogWithUndo(FoodLogWithItem entry) async {
    unawaited(HapticFeedback.lightImpact());
    final FoodDao foodDao = ref.read(foodDaoProvider);
    final FoodLog snapshotLog = entry.log;
    final String itemName = entry.foodItem?.name ?? 'Alimento';

    await foodDao.deleteFoodLog(snapshotLog.id);
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Eliminado: $itemName'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Deshacer',
            onPressed: () {
              unawaited(foodDao.restoreFoodLog(snapshotLog));
            },
          ),
        ),
      );
  }

  Future<void> _repeatYesterdayMeal({
    required DateTime activeDate,
    required String mealType,
    required String mealTitle,
  }) async {
    unawaited(HapticFeedback.mediumImpact());
    final String yesterdayKey =
        activeDate.subtract(const Duration(days: 1)).dateKey;
    final String toDateKey = activeDate.dateKey;

    final List<int> copiedIds =
        await ref.read(foodDaoProvider).repeatMealFromYesterday(
              fromDateKey: yesterdayKey,
              toDateKey: toDateKey,
              mealType: mealType,
            );

    if (!mounted) return;
    if (copiedIds.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'No hay alimentos registrados ayer en $mealTitle para copiar.',
            ),
          ),
        );
      return;
    }

    await ref.read(petDaoProvider).grantDailyReward(
          dateKey: toDateKey,
          actionType: 'meal_log_$mealType',
          baseAmount: AppConstants.coinsMealLog,
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Se copiaron ${copiedIds.length} alimentos de ayer en $mealTitle',
          ),
        ),
      );
  }

  Future<void> _openCreateComboDialog(
    String mealTitle,
    String mealType,
    List<FoodLogWithItem> mealItems,
  ) async {
    final String? comboName = await showDialog<String>(
      context: context,
      builder: (_) => CreateComboDialog(
        suggestedName: 'Mi $mealTitle',
        itemCount: mealItems.length,
      ),
    );
    if (!mounted || comboName == null || comboName.isEmpty) return;

    final List<MapEntry<int, double>> itemsWithGrams = mealItems
        .map(
          (FoodLogWithItem e) =>
              MapEntry<int, double>(e.log.foodItemId, e.log.gramsConsumed),
        )
        .toList();

    await ref.read(foodDaoProvider).createCombo(
          name: comboName,
          defaultMealType: mealType,
          itemsWithGrams: itemsWithGrams,
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Combo "$comboName" guardado (${itemsWithGrams.length} alimentos)',
          ),
        ),
      );
  }

  Future<void> _logWater({
    required String dateKey,
    required int volumeMl,
    required int goalMl,
  }) async {
    unawaited(HapticFeedback.lightImpact());
    final HydrationDao hydrationDao = ref.read(hydrationDaoProvider);
    final int insertedId = await hydrationDao.logGlass(
      dateKey: dateKey,
      volumeMl: volumeMl,
      dailyGoalMl: goalMl,
    );

    unawaited(
      ref.read(healthConnectServiceProvider).writeHydration(
            amountMl: volumeMl,
            timestamp: DateTime.now(),
          ),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('+$volumeMl ml de agua registrados'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Deshacer',
            onPressed: () {
              unawaited(hydrationDao.deleteGlass(insertedId));
            },
          ),
        ),
      );
  }

  Future<void> _openCustomWaterSheet({
    required String dateKey,
    required int goalMl,
  }) async {
    unawaited(HapticFeedback.selectionClick());
    final int? customMl = await mostrarHojaMenu<int>(
      context,
      builder: (_) => const CustomWaterSheet(),
    );
    if (customMl != null && customMl > 0 && mounted) {
      await _logWater(
        dateKey: dateKey,
        volumeMl: customMl,
        goalMl: goalMl,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final DateTime today = ref.watch(currentDateProvider);
    final DateTime activeDate = _effectiveDate(today);
    final String dateKey = activeDate.dateKey;
    final bool isToday = dateKey == today.dateKey;
    final String suggestedMeal = DailyTargetsCalculator.defaultMealTypeForHour();

    final FoodDao foodDao = ref.watch(foodDaoProvider);
    final WorkoutDao workoutDao = ref.watch(workoutDaoProvider);
    final HydrationDao hydrationDao = ref.watch(hydrationDaoProvider);
    final FastingDao fastingDao = ref.watch(fastingDaoProvider);
    final UserProfile? profile = ref.watch(userProfileStreamProvider).value;
    final BodyMeasurement? latestMeas =
        ref.watch(latestMeasurementStreamProvider).value;

    final int waterGoalMl = profile?.dailyWaterGoalMl ?? 2500;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<int>(
          stream: workoutDao.watchNetCaloriesForDate(dateKey),
          builder: (BuildContext context, AsyncSnapshot<int> workoutSnap) {
            final int netWorkoutKcal = workoutSnap.data ?? 0;
            final DailyMacroTargets? targets = profile != null
                ? DailyTargetsCalculator.compute(
                    profile: profile,
                    currentWeightKg:
                        latestMeas?.trendWeightKg ?? latestMeas?.weightKg,
                    netWorkoutKcal: netWorkoutKcal,
                  )
                : null;

            return ListView(
              padding: const EdgeInsets.only(bottom: 112),
              children: <Widget>[
                // 1. Encabezado limpio (coherente con Hoy)
                TopBar(
                  title: 'Comida',
                  subtitle: _formatearFechaCorta(activeDate),
                  large: true,
                  subtitleBelowTitle: true,
                  uppercaseSubtitle: false,
                  pageIcon: Icons.local_dining_rounded,
                  onProfile: () => context.go('/perfil'),
                ),

                // 2. Franja de Navegación Semanal (7 días + puntos de actividad)
                _WeekNavigatorStrip(
                  activeDate: activeDate,
                  today: today,
                  foodDao: foodDao,
                  onSelectDate: (DateTime d) => _selectDate(d, today),
                ),

                // 3. Centro Inteligente de Entrada (Búsqueda + EAN + 2×2 Herramientas)
                _SmartEntryHubCard(
                  fastingDao: fastingDao,
                  onOpenSearch: () => _openFoodSearch(dateKey, suggestedMeal),
                  onOpenBarcode: () =>
                      _openBarcodeScanner(dateKey, suggestedMeal),
                  onOpenAiDictation: () =>
                      _openAiDictation(dateKey, suggestedMeal),
                  onOpenCombos: () => _openCombosSheet(dateKey, suggestedMeal),
                  onOpenCustomFood: () =>
                      _openCustomFoodAndLog(dateKey, suggestedMeal),
                  onOpenFasting: () {
                    unawaited(HapticFeedback.selectionClick());
                    unawaited(context.push('/ayuno'));
                  },
                ),

                // 4. Panel Reactivo de Energía, Macros, Electrolitos y Comidas
                StreamBuilder<List<FoodLogWithItem>>(
                  stream: foodDao.watchLogsWithItemForDate(dateKey),
                  builder: (
                    BuildContext context,
                    AsyncSnapshot<List<FoodLogWithItem>> snapshot,
                  ) {
                    final List<FoodLogWithItem> logsWithItems =
                        snapshot.data ?? const <FoodLogWithItem>[];

                    final double totalKcal = logsWithItems.fold(
                      0.0,
                      (double acc, FoodLogWithItem item) =>
                          acc + item.log.totalKcal,
                    );
                    final double totalP = logsWithItems.fold(
                      0.0,
                      (double acc, FoodLogWithItem item) =>
                          acc + item.log.totalProteinG,
                    );
                    final double totalC = logsWithItems.fold(
                      0.0,
                      (double acc, FoodLogWithItem item) =>
                          acc + item.log.totalCarbsG,
                    );
                    final double totalF = logsWithItems.fold(
                      0.0,
                      (double acc, FoodLogWithItem item) =>
                          acc + item.log.totalFatG,
                    );
                    final double totalFiber = logsWithItems.fold(
                      0.0,
                      (double acc, FoodLogWithItem item) =>
                          acc + item.log.totalFiberG,
                    );
                    final double totalSodium = logsWithItems.fold(
                      0.0,
                      (double acc, FoodLogWithItem item) =>
                          acc + item.log.totalSodiumMg,
                    );
                    final double totalPotassium = logsWithItems.fold(
                      0.0,
                      (double acc, FoodLogWithItem item) =>
                          acc + item.log.totalPotassiumMg,
                    );
                    final double totalMagnesium = logsWithItems.fold(
                      0.0,
                      (double acc, FoodLogWithItem item) =>
                          acc + item.log.totalMagnesiumMg,
                    );

                    final double netCarbs =
                        (totalC - totalFiber).clamp(0.0, 9999.0);

                    final int targetKcal =
                        targets?.effectiveCalorieTargetKcal ?? 2000;
                    final double targetProtein =
                        targets?.proteinTargetG ?? 140.0;
                    final double targetCarbs = targets?.carbsTargetG ?? 220.0;
                    final double targetFat = targets?.fatTargetG ?? 60.0;
                    final double targetFiber = targets?.fiberTargetG ?? 28.0;
                    final double targetSodium =
                        targets?.sodiumTargetMg ?? 2300.0;
                    final double targetPotassium =
                        targets?.potassiumTargetMg ?? 3500.0;
                    final double targetMagnesium =
                        targets?.magnesiumTargetMg ?? 400.0;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // 4A. Tarjeta Hero de Energía y Macronutrientes
                        _EnergyAndMacrosCard(
                          totalKcal: totalKcal,
                          targetKcal: targetKcal,
                          netWorkoutKcal: netWorkoutKcal,
                          totalP: totalP,
                          targetP: targetProtein,
                          totalC: totalC,
                          targetC: targetCarbs,
                          netCarbs: netCarbs,
                          totalFiber: totalFiber,
                          totalF: totalF,
                          targetF: targetFat,
                        ),

                        // 4B. Tarjeta 2×2 de Electrolitos y Fibra (cero cortes)
                        _ElectrolytesBentoCard(
                          sodiumMg: totalSodium,
                          targetSodiumMg: targetSodium,
                          potassiumMg: totalPotassium,
                          targetPotassiumMg: targetPotassium,
                          magnesiumMg: totalMagnesium,
                          targetMagnesiumMg: targetMagnesium,
                          fiberG: totalFiber,
                          targetFiberG: targetFiber,
                        ),

                        // 4C. Encabezado de Bloques de Comida
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  'Comidas del día',
                                  softWrap: true,
                                  style: TextStyle(
                                    fontFamily: ScFonts.display,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: c.text,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${logsWithItems.length} registros',
                                style: TextStyle(
                                  fontFamily: ScFonts.ui,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: c.text2,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 4D. Las 4 tarjetas de comidas (Desayuno, Almuerzo, Cena, Snacks)
                        for (final MealSlotMeta slot in MealSlotMeta.all)
                          _MealBlockCard(
                            slot: slot,
                            isSuggestedNow:
                                isToday && slot.key == suggestedMeal,
                            items: logsWithItems
                                .where(
                                  (FoodLogWithItem e) =>
                                      e.log.mealType == slot.key,
                                )
                                .toList(),
                            onAddFood: () => _openFoodSearch(dateKey, slot.key),
                            onRepeatYesterday: () => _repeatYesterdayMeal(
                              activeDate: activeDate,
                              mealType: slot.key,
                              mealTitle: slot.title,
                            ),
                            onSaveCombo: (List<FoodLogWithItem> mealItems) =>
                                _openCreateComboDialog(
                              slot.title,
                              slot.key,
                              mealItems,
                            ),
                            onTapEntry: _openEditLogSheet,
                            onDeleteEntry: _deleteFoodLogWithUndo,
                          ),
                      ],
                    );
                  },
                ),

                // 5. Sección Integrada de Hidratación del Día
                StreamBuilder<List<HydrationLog>>(
                  stream: hydrationDao.watchLogsForDate(dateKey),
                  builder: (
                    BuildContext context,
                    AsyncSnapshot<List<HydrationLog>> waterSnap,
                  ) {
                    final List<HydrationLog> waterLogs =
                        waterSnap.data ?? const <HydrationLog>[];
                    return _HydrationSectionCard(
                      logs: waterLogs,
                      goalMl: waterGoalMl,
                      formatClock: _fmtClock,
                      onAdd250: () => _logWater(
                        dateKey: dateKey,
                        volumeMl: 250,
                        goalMl: waterGoalMl,
                      ),
                      onAdd500: () => _logWater(
                        dateKey: dateKey,
                        volumeMl: 500,
                        goalMl: waterGoalMl,
                      ),
                      onOpenCustom: () => _openCustomWaterSheet(
                        dateKey: dateKey,
                        goalMl: waterGoalMl,
                      ),
                      onDeleteGlass: (HydrationLog glass) async {
                        unawaited(HapticFeedback.selectionClick());
                        await hydrationDao.deleteGlass(glass.id);
                      },
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Franja semanal interactiva (L a D) con indicadores de registro y botón rápido a Hoy.
class _WeekNavigatorStrip extends StatelessWidget {
  const _WeekNavigatorStrip({
    required this.activeDate,
    required this.today,
    required this.foodDao,
    required this.onSelectDate,
  });

  final DateTime activeDate;
  final DateTime today;
  final FoodDao foodDao;
  final ValueChanged<DateTime> onSelectDate;

  static const List<String> _weekdayInitials = <String>[
    'L',
    'M',
    'X',
    'J',
    'V',
    'S',
    'D',
  ];

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final DateTime normalized =
        DateTime(activeDate.year, activeDate.month, activeDate.day);
    final DateTime weekMonday =
        normalized.subtract(Duration(days: normalized.weekday - 1));
    final List<DateTime> weekDays = List<DateTime>.generate(
      7,
      (int i) => DateTime(weekMonday.year, weekMonday.month, weekMonday.day + i),
    );

    final String startKey = weekDays.first.dateKey;
    final String endKey = weekDays.last.dateKey;
    final bool isToday = activeDate.dateKey == today.dateKey;

    return HealthCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: StreamBuilder<Set<String>>(
        stream: foodDao.watchLoggedDateKeysInRange(startKey, endKey),
        builder: (BuildContext context, AsyncSnapshot<Set<String>> snap) {
          final Set<String> loggedKeys = snap.data ?? const <String>{};

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  IconButton(
                    tooltip: 'Día anterior',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(AppIcons.chevronLeft, color: c.text2),
                    onPressed: () => onSelectDate(
                      normalized.subtract(const Duration(days: 1)),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: isToday
                          ? Text(
                              'Semana actual',
                              style: TextStyle(
                                fontFamily: ScFonts.ui,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: c.text2,
                              ),
                            )
                          : InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => onSelectDate(today),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: c.isFlat
                                      ? c.bg3
                                      : c.accent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: c.isFlat ? c.line2 : c.accent,
                                  ),
                                ),
                                child: Text(
                                  'Volver a hoy',
                                  style: TextStyle(
                                    fontFamily: ScFonts.ui,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: c.isFlat ? c.text : c.accent,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Día siguiente',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(AppIcons.chevronRight, color: c.text2),
                    onPressed: () => onSelectDate(
                      normalized.add(const Duration(days: 1)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: List<Widget>.generate(7, (int index) {
                  final DateTime d = weekDays[index];
                  final String key = d.dateKey;
                  final bool selected = key == activeDate.dateKey;
                  final bool isCurrentToday = key == today.dateKey;
                  final bool hasLogs = loggedKeys.contains(key);

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => onSelectDate(d),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? c.accent
                                : (isCurrentToday
                                    ? c.bg3
                                    : Colors.transparent),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected
                                  ? c.accent
                                  : (isCurrentToday
                                      ? (c.isFlat ? c.line2 : c.line)
                                      : Colors.transparent),
                              width: selected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                _weekdayInitials[index],
                                style: TextStyle(
                                  fontFamily: ScFonts.ui,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: selected ? c.ink : c.text3,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${d.day}',
                                style: TextStyle(
                                  fontFamily: ScFonts.display,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: selected ? c.ink : c.text,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: hasLogs
                                      ? (selected ? c.ink : c.accent)
                                      : Colors.transparent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Centro de entrada rápida sin textos truncados: barra de búsqueda + cámara + cuadrícula 2×2.
class _SmartEntryHubCard extends StatelessWidget {
  const _SmartEntryHubCard({
    required this.fastingDao,
    required this.onOpenSearch,
    required this.onOpenBarcode,
    required this.onOpenAiDictation,
    required this.onOpenCombos,
    required this.onOpenCustomFood,
    required this.onOpenFasting,
  });

  final FastingDao fastingDao;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenBarcode;
  final VoidCallback onOpenAiDictation;
  final VoidCallback onOpenCombos;
  final VoidCallback onOpenCustomFood;
  final VoidCallback onOpenFasting;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;

    return HealthCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Barra de búsqueda táctil + escáner integrado
          Row(
            children: <Widget>[
              Expanded(
                child: Material(
                  color: c.bg3,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: onOpenSearch,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: c.isFlat ? c.line2 : c.line,
                          width: c.isFlat ? 1.4 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(AppIcons.search, size: 20, color: c.accent),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Buscar alimento o marca...',
                              softWrap: true,
                              style: TextStyle(
                                fontFamily: ScFonts.ui,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: c.text2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: c.isFlat ? c.bg3 : c.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: onOpenBarcode,
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: c.isFlat
                            ? c.line2
                            : c.accent.withValues(alpha: 0.45),
                        width: c.isFlat ? 1.4 : 1.0,
                      ),
                    ),
                    child: Icon(
                      AppIcons.barcode,
                      color: c.isFlat ? c.text : c.accent,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Fila 1: Herramientas duales (Dictado IA + Mis Combos)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: _EntryToolTile(
                    icon: AppIcons.ai,
                    iconColor: c.accent,
                    title: 'Dictado IA',
                    subtitle: 'Voz o texto libre',
                    onTap: onOpenAiDictation,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _EntryToolTile(
                    icon: AppIcons.combos,
                    iconColor: c.carbs,
                    title: 'Mis Combos',
                    subtitle: 'Escala 0.25x–3x',
                    onTap: onOpenCombos,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Fila 2: Ayuno expandido en ancho completo
          StreamBuilder<FastingSession?>(
            stream: fastingDao.watchActiveSession(),
            builder: (
              BuildContext context,
              AsyncSnapshot<FastingSession?> snap,
            ) {
              final FastingSession? active = snap.data;
              String sub = 'Ventanas y cronómetro metabólico (16:8)';
              if (active != null) {
                final int h = DateTime.now()
                    .difference(active.startedAt)
                    .inHours
                    .clamp(0, 999);
                sub = 'Sesión activa · ${h}h / ${active.targetHours}h completadas';
              }
              return _EntryToolTile(
                icon: active != null
                    ? AppIcons.ayunoFilled
                    : AppIcons.ayuno,
                iconColor: c.fasting,
                title: 'Ayuno',
                subtitle: sub,
                onTap: onOpenFasting,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (active != null) ...<Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: c.isFlat
                              ? c.line2
                              : c.fasting.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: c.isFlat ? c.text : c.fasting,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'Activo',
                          style: TextStyle(
                            fontFamily: ScFonts.ui,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: c.isFlat ? c.text : c.fasting,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Icon(
                      AppIcons.chevronRight,
                      size: 18,
                      color: c.text3,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),

          // Fila 3: Crear alimento expandido en ancho completo
          _EntryToolTile(
            icon: AppIcons.add,
            iconColor: c.protein,
            title: 'Crear alimento',
            subtitle: 'Añadir receta casera, producto o comida personalizada',
            onTap: onOpenCustomFood,
            trailing: Icon(
              AppIcons.chevronRight,
              size: 18,
              color: c.text3,
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryToolTile extends StatelessWidget {
  const _EntryToolTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Material(
      color: c.bg3,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          alignment: Alignment.centerLeft,
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: c.isFlat ? c.line2 : c.line,
              width: c.isFlat ? 1.3 : 1.0,
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                icon,
                size: 20,
                color: c.isFlat ? c.text : iconColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      softWrap: true,
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      softWrap: true,
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 11,
                        color: c.text2,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta Hero de Energía y Macronutrientes con anillo calórico y carbohidratos netos.
class _EnergyAndMacrosCard extends StatelessWidget {
  const _EnergyAndMacrosCard({
    required this.totalKcal,
    required this.targetKcal,
    required this.netWorkoutKcal,
    required this.totalP,
    required this.targetP,
    required this.totalC,
    required this.targetC,
    required this.netCarbs,
    required this.totalFiber,
    required this.totalF,
    required this.targetF,
  });

  final double totalKcal;
  final int targetKcal;
  final int netWorkoutKcal;
  final double totalP;
  final double targetP;
  final double totalC;
  final double targetC;
  final double netCarbs;
  final double totalFiber;
  final double totalF;
  final double targetF;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final int consumedInt = totalKcal.round();
    final int remaining = targetKcal - consumedInt;
    final double kcalRatio =
        targetKcal > 0 ? (totalKcal / targetKcal).clamp(0.0, 1.0) : 0.0;
    final int pct = (kcalRatio * 100).round();

    return HealthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 92,
                height: 92,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    SizedBox(
                      width: 92,
                      height: 92,
                      child: CircularProgressIndicator(
                        value: kcalRatio,
                        strokeWidth: 9.5,
                        strokeCap:
                            c.isFlat ? StrokeCap.butt : StrokeCap.round,
                        backgroundColor: c.bg3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          c.isFlat ? c.text : c.calories,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          AppIcons.fuego,
                          size: 17,
                          color: c.isFlat ? c.text : c.calories,
                        ),
                        Text(
                          '$pct%',
                          style: TextStyle(
                            fontFamily: ScFonts.display,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: c.text,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Balance energético',
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: c.text2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    RichText(
                      text: TextSpan(
                        text: '$consumedInt',
                        style: TextStyle(
                          fontFamily: ScFonts.display,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: c.text,
                        ),
                        children: <InlineSpan>[
                          TextSpan(
                            text: ' / $targetKcal kcal',
                            style: TextStyle(
                              fontFamily: ScFonts.ui,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: c.text2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: c.bg3,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: c.isFlat ? c.line2 : c.line,
                            ),
                          ),
                          child: Text(
                            remaining >= 0
                                ? 'Disponibles: $remaining kcal'
                                : '+${remaining.abs()} kcal sobre la meta',
                            softWrap: true,
                            style: TextStyle(
                              fontFamily: ScFonts.ui,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: remaining >= 0
                                  ? (c.isFlat ? c.text : c.accent)
                                  : (c.isFlat ? c.text : c.warning),
                            ),
                          ),
                        ),
                        if (netWorkoutKcal > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: c.bg3,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: c.isFlat ? c.line2 : c.steps,
                              ),
                            ),
                            child: Text(
                              '+$netWorkoutKcal kcal entreno',
                              style: TextStyle(
                                fontFamily: ScFonts.ui,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: c.isFlat ? c.text : c.steps,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: c.line),
          ),

          // 3 barras amplias de macronutrientes (cero truncamiento)
          _MacroWideRow(
            label: 'Proteína',
            currentG: totalP,
            targetG: targetP,
            badgeText: totalP >= targetP
                ? 'Meta cubierta'
                : 'Faltan ${(targetP - totalP).round()} g',
            barColor: c.isFlat ? c.text : c.protein,
          ),
          const SizedBox(height: 12),
          _MacroWideRow(
            label: 'Carbohidratos',
            currentG: totalC,
            targetG: targetC,
            badgeText:
                'Netos: ${netCarbs.round()} g · Fibra: ${totalFiber.round()} g',
            barColor: c.isFlat ? c.text : c.carbs,
          ),
          const SizedBox(height: 12),
          _MacroWideRow(
            label: 'Grasas saludables',
            currentG: totalF,
            targetG: targetF,
            badgeText: totalF >= targetF
                ? 'Meta cubierta'
                : 'Faltan ${(targetF - totalF).round()} g',
            barColor: c.isFlat ? c.text : c.fat,
          ),
        ],
      ),
    );
  }
}

class _MacroWideRow extends StatelessWidget {
  const _MacroWideRow({
    required this.label,
    required this.currentG,
    required this.targetG,
    required this.badgeText,
    required this.barColor,
  });

  final String label;
  final double currentG;
  final double targetG;
  final String badgeText;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final double ratio =
        targetG > 0 ? (currentG / targetG).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                softWrap: true,
                style: TextStyle(
                  fontFamily: ScFonts.display,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: c.text,
                ),
              ),
            ),
            RichText(
              text: TextSpan(
                text: '${currentG.round()} g',
                style: TextStyle(
                  fontFamily: ScFonts.display,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: c.text,
                ),
                children: <InlineSpan>[
                  TextSpan(
                    text: ' / ${targetG.round()} g',
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 12,
                      color: c.text3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        LinearProgressIndicator(
          value: ratio,
          backgroundColor: c.bg3,
          valueColor: AlwaysStoppedAnimation<Color>(barColor),
          borderRadius: BorderRadius.circular(5),
          minHeight: 6.5,
        ),
        const SizedBox(height: 4),
        Text(
          badgeText,
          softWrap: true,
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

/// Tarjeta Bento 2×2 para el Triángulo de Electrolitos y Fibra (cero compresión en 4 columnas).
class _ElectrolytesBentoCard extends StatelessWidget {
  const _ElectrolytesBentoCard({
    required this.sodiumMg,
    required this.targetSodiumMg,
    required this.potassiumMg,
    required this.targetPotassiumMg,
    required this.magnesiumMg,
    required this.targetMagnesiumMg,
    required this.fiberG,
    required this.targetFiberG,
  });

  final double sodiumMg;
  final double targetSodiumMg;
  final double potassiumMg;
  final double targetPotassiumMg;
  final double magnesiumMg;
  final double targetMagnesiumMg;
  final double fiberG;
  final double targetFiberG;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final bool highSodium = sodiumMg > targetSodiumMg * 1.15;

    return HealthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(AppIcons.bolt, size: 19, color: c.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Electrolitos y Fibra',
                  softWrap: true,
                  style: TextStyle(
                    fontFamily: ScFonts.display,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: c.text,
                  ),
                ),
              ),
              if (highSodium)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.bg3,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: c.isFlat ? c.line2 : c.warning,
                    ),
                  ),
                  child: Text(
                    'Sodio elevado',
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: c.isFlat ? c.text : c.warning,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _MicroCell(
                  title: 'Sodio (Na)',
                  currentText: '${sodiumMg.round()} mg',
                  targetText: 'Meta ${targetSodiumMg.round()} mg',
                  ratio: (sodiumMg / targetSodiumMg).clamp(0.0, 1.0),
                  color: c.isFlat
                      ? c.text
                      : (highSodium ? c.warning : c.water),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MicroCell(
                  title: 'Potasio (K)',
                  currentText: '${potassiumMg.round()} mg',
                  targetText: 'Meta ${targetPotassiumMg.round()} mg',
                  ratio: (potassiumMg / targetPotassiumMg).clamp(0.0, 1.0),
                  color: c.isFlat ? c.text : c.steps,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _MicroCell(
                  title: 'Magnesio (Mg)',
                  currentText: '${magnesiumMg.round()} mg',
                  targetText: 'Meta ${targetMagnesiumMg.round()} mg',
                  ratio: (magnesiumMg / targetMagnesiumMg).clamp(0.0, 1.0),
                  color: c.isFlat ? c.text : c.fasting,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MicroCell(
                  title: 'Fibra dietética',
                  currentText: '${fiberG.round()} g',
                  targetText: 'Meta ${targetFiberG.round()} g',
                  ratio: (fiberG / targetFiberG).clamp(0.0, 1.0),
                  color: c.isFlat ? c.text : c.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MicroCell extends StatelessWidget {
  const _MicroCell({
    required this.title,
    required this.currentText,
    required this.targetText,
    required this.ratio,
    required this.color,
  });

  final String title;
  final String currentText;
  final String targetText;
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.bg3,
        borderRadius: BorderRadius.circular(15),
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
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: c.text2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            currentText,
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
            targetText,
            softWrap: true,
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 11,
              color: c.text3,
            ),
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: ratio,
            backgroundColor: c.bg2,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            borderRadius: BorderRadius.circular(4),
            minHeight: 5,
          ),
        ],
      ),
    );
  }
}

/// Bloque horario individual (Desayuno, Almuerzo, Cena, Snacks) con acciones inferiores cómodas.
class _MealBlockCard extends StatelessWidget {
  const _MealBlockCard({
    required this.slot,
    required this.isSuggestedNow,
    required this.items,
    required this.onAddFood,
    required this.onRepeatYesterday,
    required this.onSaveCombo,
    required this.onTapEntry,
    required this.onDeleteEntry,
  });

  final MealSlotMeta slot;
  final bool isSuggestedNow;
  final List<FoodLogWithItem> items;
  final VoidCallback onAddFood;
  final VoidCallback onRepeatYesterday;
  final ValueChanged<List<FoodLogWithItem>> onSaveCombo;
  final ValueChanged<FoodLogWithItem> onTapEntry;
  final ValueChanged<FoodLogWithItem> onDeleteEntry;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final Color tint = slot.accentColor(c);

    final double mealKcal = items.fold(
      0.0,
      (double acc, FoodLogWithItem e) => acc + e.log.totalKcal,
    );
    final double mealP = items.fold(
      0.0,
      (double acc, FoodLogWithItem e) => acc + e.log.totalProteinG,
    );
    final double mealC = items.fold(
      0.0,
      (double acc, FoodLogWithItem e) => acc + e.log.totalCarbsG,
    );
    final double mealF = items.fold(
      0.0,
      (double acc, FoodLogWithItem e) => acc + e.log.totalFatG,
    );

    return HealthCard(
      borderColor: isSuggestedNow && !c.isFlat
          ? tint.withValues(alpha: 0.45)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Cabecera del bloque
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.isFlat ? c.bg3 : tint.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: c.isFlat ? c.line2 : tint.withValues(alpha: 0.35),
                  ),
                ),
                child: Icon(
                  slot.icon,
                  size: 20,
                  color: c.isFlat ? c.text : tint,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(
                          slot.title,
                          style: TextStyle(
                            fontFamily: ScFonts.display,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: c.text,
                          ),
                        ),
                        if (isSuggestedNow)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: c.bg3,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: c.isFlat ? c.line2 : tint,
                              ),
                            ),
                            child: Text(
                              'Ahora',
                              style: TextStyle(
                                fontFamily: ScFonts.ui,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: c.isFlat ? c.text : tint,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      items.isEmpty
                          ? slot.timeHint
                          : 'P ${mealP.round()}g · C ${mealC.round()}g · G ${mealF.round()}g',
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
              Text(
                '${mealKcal.round()} kcal',
                style: TextStyle(
                  fontFamily: ScFonts.display,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: items.isEmpty ? c.text3 : c.text,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: c.bg3.withValues(alpha: c.isFlat ? 1.0 : 0.6),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text(
                'Sin alimentos registrados todavía en ${slot.title.toLowerCase()}.',
                softWrap: true,
                style: TextStyle(
                  fontFamily: ScFonts.ui,
                  fontSize: 12.5,
                  color: c.text3,
                ),
              ),
            )
          else
            Column(
              children: <Widget>[
                for (int i = 0; i < items.length; i++) ...<Widget>[
                  if (i > 0) Divider(height: 12, color: c.line),
                  _LoggedFoodRow(
                    entry: items[i],
                    onTap: () => onTapEntry(items[i]),
                    onDelete: () => onDeleteEntry(items[i]),
                  ),
                ],
              ],
            ),

          const SizedBox(height: 12),

          // Botones inferiores cómodos (envolventes, nunca cortados)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.tonalIcon(
                onPressed: onAddFood,
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                icon: const Icon(AppIcons.add, size: 17),
                label: const Text(
                  'Añadir',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onRepeatYesterday,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                icon: const Icon(AppIcons.repeat, size: 16),
                label: const Text('Repetir ayer'),
              ),
              if (items.length >= 2)
                OutlinedButton.icon(
                  onPressed: () => onSaveCombo(items),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  icon: const Icon(AppIcons.combos, size: 16),
                  label: const Text('Guardar combo'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoggedFoodRow extends StatelessWidget {
  const _LoggedFoodRow({
    required this.entry,
    required this.onTap,
    required this.onDelete,
  });

  final FoodLogWithItem entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final FoodLog log = entry.log;
    final String name = entry.foodItem?.name ?? 'Alimento #${log.foodItemId}';

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    softWrap: true,
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${log.gramsConsumed.round()} g  •  '
                    'P ${log.totalProteinG.toStringAsFixed(0)}g · '
                    'C ${log.totalCarbsG.toStringAsFixed(0)}g · '
                    'G ${log.totalFatG.toStringAsFixed(0)}g',
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
            const SizedBox(width: 8),
            Text(
              '${log.totalKcal.round()} kcal',
              style: TextStyle(
                fontFamily: ScFonts.display,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: c.text,
              ),
            ),
            IconButton(
              tooltip: 'Eliminar registro',
              visualDensity: VisualDensity.compact,
              onPressed: onDelete,
              icon: Icon(AppIcons.delete, size: 18, color: c.text3),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta completa de Hidratación del Día (+250 ml, +500 ml, vaso personalizado e historial).
class _HydrationSectionCard extends StatelessWidget {
  const _HydrationSectionCard({
    required this.logs,
    required this.goalMl,
    required this.formatClock,
    required this.onAdd250,
    required this.onAdd500,
    required this.onOpenCustom,
    required this.onDeleteGlass,
  });

  final List<HydrationLog> logs;
  final int goalMl;
  final String Function(DateTime) formatClock;
  final VoidCallback onAdd250;
  final VoidCallback onAdd500;
  final VoidCallback onOpenCustom;
  final ValueChanged<HydrationLog> onDeleteGlass;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final int totalMl = logs.fold(
      0,
      (int sum, HydrationLog item) => sum + item.volumeMl,
    );
    final double ratio =
        goalMl > 0 ? (totalMl / goalMl).clamp(0.0, 1.0) : 0.0;
    final int pct = (ratio * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
          child: Text(
            'Hidratación',
            style: TextStyle(
              fontFamily: ScFonts.display,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: c.text,
            ),
          ),
        ),
        HealthCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.isFlat
                          ? c.bg3
                          : c.water.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: c.isFlat
                            ? c.line2
                            : c.water.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(
                      AppIcons.gota,
                      color: c.isFlat ? c.text : c.water,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Agua acumulada',
                          style: TextStyle(
                            fontFamily: ScFonts.display,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: c.text,
                          ),
                        ),
                        Text(
                          '$totalMl / $goalMl ml ($pct%)',
                          softWrap: true,
                          style: TextStyle(
                            fontFamily: ScFonts.ui,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: c.text2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: ratio,
                backgroundColor: c.bg3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  c.isFlat ? c.text : c.water,
                ),
                borderRadius: BorderRadius.circular(5),
                minHeight: 7,
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: onAdd250,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      icon: const Icon(AppIcons.add, size: 17),
                      label: const Text(
                        '250 ml',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: onAdd500,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      icon: const Icon(AppIcons.add, size: 17),
                      label: const Text(
                        '500 ml',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onOpenCustom,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: const Text(
                        'A medida',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
              if (logs.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: logs.map((HydrationLog item) {
                    return InputChip(
                      label: Text(
                        '${item.volumeMl} ml · ${formatClock(item.loggedAt)}',
                        style: TextStyle(
                          fontFamily: ScFonts.ui,
                          fontSize: 11.5,
                          color: c.text2,
                        ),
                      ),
                      visualDensity: VisualDensity.compact,
                      onDeleted: () => onDeleteGlass(item),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
