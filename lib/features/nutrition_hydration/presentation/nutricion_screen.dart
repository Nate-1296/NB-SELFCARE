import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/clock/clock.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/models/food_models.dart';
import '../../../core/domain/enums.dart';
import '../../../core/l10n/l10n.dart';
import '../../../shared/theme/sc_colors.dart';
import '../../../shared/theme/sc_tokens.dart';
import '../../../shared/utils/current_date_provider.dart';
import '../../../shared/utils/date_formats.dart';
import '../../../shared/utils/date_time_extensions.dart';
import '../../../shared/widgets/section_head.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../shared/widgets/top_bar.dart';
import '../../../shared/widgets/undo_snackbar.dart';
import '../application/food_logging_service.dart';
import '../application/hydration_service.dart';
import '../application/nutrition_day.dart';
import '../domain/nutrient_totals.dart';
import 'widgets/barcode_scanner_sheet.dart';
import 'widgets/combos_sheet.dart';
import 'widgets/comer/calorie_bank_card.dart';
import 'widgets/comer/electrolytes_card.dart';
import 'widgets/comer/energy_macros_card.dart';
import 'widgets/comer/entry_hub_card.dart';
import 'widgets/comer/hydration_section_card.dart';
import 'widgets/comer/meal_block_card.dart';
import 'widgets/comer/nova_quality_card.dart';
import 'widgets/comer/week_strip.dart';
import 'widgets/create_combo_dialog.dart';
import 'widgets/custom_food_sheet.dart';
import 'widgets/custom_water_sheet.dart';
import 'widgets/food_detail_sheet.dart';
import 'widgets/food_search_modal.dart';
import 'widgets/meal_dictation_sheet.dart';
import 'widgets/meal_slot_selector.dart';
import 'widgets/nutrient_oracle_sheet.dart';
import 'widgets/nutrition_sheets.dart';
import 'widgets/saved_recipes_sheet.dart';
import 'widgets/smart_menu_sheet.dart';

/// Pestaña "Comida": registro del día, macros, electrolitos, balance semanal y agua.
class NutricionScreen extends ConsumerStatefulWidget {
  const NutricionScreen({super.key});

  @override
  ConsumerState<NutricionScreen> createState() => _NutricionScreenState();
}

class _NutricionScreenState extends ConsumerState<NutricionScreen> {
  DateTime? _customSelectedDate;

  DateTime _effectiveDate(DateTime currentDay) => _customSelectedDate ?? currentDay;

  void _selectDate(DateTime date, DateTime today) {
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _customSelectedDate = date.dateKey == today.dateKey ? null : date;
    });
  }

  Future<void> _openFoodSearch(String dateKey, MealType initialMealType) async {
    unawaited(HapticFeedback.selectionClick());
    await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FoodSearchModal(initialMealType: initialMealType, targetDateKey: dateKey),
    );
  }

  Future<void> _openBarcodeScanner(String dateKey, MealType initialMealType) async {
    unawaited(HapticFeedback.selectionClick());
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BarcodeScannerSheet(initialMealType: initialMealType, targetDateKey: dateKey),
    );
  }

  void _openTextEntry(String dateKey, MealType initialMealType) {
    unawaited(HapticFeedback.selectionClick());
    unawaited(
      mostrarHojaMenu<void>(
        context,
        builder: (_) => AiMealDictationSheet(dateKey: dateKey, initialMealType: initialMealType),
      ),
    );
  }

  void _openCombosSheet(String dateKey, MealType initialMealType) {
    unawaited(HapticFeedback.selectionClick());
    unawaited(
      mostrarHojaMenu<void>(
        context,
        builder: (_) => CombosModalSheet(dateKey: dateKey, initialMealType: initialMealType),
      ),
    );
  }

  void _openRecipesSheet(String dateKey, MealType initialMealType) {
    unawaited(HapticFeedback.selectionClick());
    unawaited(
      SavedRecipesSheet.show(context, targetDateKey: dateKey, initialMealType: initialMealType),
    );
  }

  Future<void> _openCustomFoodAndLog(String dateKey, MealType mealType) async {
    unawaited(HapticFeedback.selectionClick());
    final FoodItem? created = await showModalBottomSheet<FoodItem>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CustomFoodSheet(),
    );
    if (!mounted || created == null) return;
    await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          FoodDetailSheet(food: created, initialMealType: mealType, targetDateKey: dateKey),
    );
  }

  void _openEditLogSheet(FoodLogWithItem entry) {
    unawaited(HapticFeedback.selectionClick());
    unawaited(
      mostrarHojaMenu<void>(
        context,
        builder: (_) =>
            EditFoodLogSheet(entry: entry, onDeleteRequested: () => _deleteFoodLogWithUndo(entry)),
      ),
    );
  }

  Future<void> _deleteFoodLogWithUndo(FoodLogWithItem entry) async {
    unawaited(HapticFeedback.lightImpact());
    final FoodLoggingService service = ref.read(foodLoggingServiceProvider);
    await service.deleteLog(entry.log.id);
    if (!mounted) return;
    showUndoSnackBar(
      context,
      message: context.l10n.comerFoodDeleted(
        entry.foodItem?.name ?? context.l10n.comerFoodFallbackName,
      ),
      onUndo: () => unawaited(service.restoreLog(entry.log)),
    );
  }

  Future<void> _repeatYesterdayMeal({
    required DateTime activeDate,
    required MealType mealType,
    required String mealTitle,
  }) async {
    unawaited(HapticFeedback.mediumImpact());
    final FoodLoggingService service = ref.read(foodLoggingServiceProvider);
    final FoodLogResult result = await service.repeatYesterday(
      toDateKey: activeDate.dateKey,
      mealTypes: <MealType>[mealType],
    );
    if (!mounted) return;
    showUndoSnackBar(
      context,
      message: result.isEmpty
          ? context.l10n.comerNothingYesterday(mealTitle.toLowerCase())
          : context.l10n.comerCopiedYesterday(result.logIds.length, mealTitle.toLowerCase()),
      onUndo: result.isEmpty ? null : () => unawaited(service.deleteLogs(result.logIds)),
    );
  }

  Future<void> _saveCombo(
    String mealTitle,
    MealType mealType,
    List<FoodLogWithItem> mealItems,
  ) async {
    final String? comboName = await showDialog<String>(
      context: context,
      builder: (_) => CreateComboDialog(
        suggestedName: context.l10n.comerComboSuggestedName(mealTitle.toLowerCase()),
        itemCount: mealItems.length,
      ),
    );
    if (!mounted || comboName == null || comboName.isEmpty) return;
    await ref
        .read(foodLoggingServiceProvider)
        .saveCombo(
          name: comboName,
          mealType: mealType,
          logs: <FoodLog>[for (final FoodLogWithItem e in mealItems) e.log],
        );
    if (!mounted) return;
    showUndoSnackBar(context, message: context.l10n.comerComboSaved(comboName, mealItems.length));
  }

  Future<void> _logWater({required String dateKey, required int volumeMl}) async {
    unawaited(HapticFeedback.lightImpact());
    final HydrationService service = ref.read(hydrationServiceProvider);
    final WaterLogResult result = await service.logGlass(dateKey: dateKey, volumeMl: volumeMl);
    if (!mounted) return;
    showUndoSnackBar(
      context,
      message: result.coins > 0
          ? context.l10n.comerWaterLoggedGoal(volumeMl, result.coins)
          : context.l10n.comerWaterLogged(volumeMl),
      onUndo: () => unawaited(service.deleteGlass(result.logId)),
    );
  }

  Future<void> _deleteGlassWithUndo(HydrationLog glass) async {
    unawaited(HapticFeedback.selectionClick());
    final HydrationService service = ref.read(hydrationServiceProvider);
    await service.deleteGlass(glass.id);
    if (!mounted) return;
    showUndoSnackBar(
      context,
      message: context.l10n.comerGlassDeleted(glass.volumeMl),
      onUndo: () => unawaited(service.restoreGlass(glass)),
    );
  }

  Future<void> _openCustomWaterSheet(String dateKey) async {
    unawaited(HapticFeedback.selectionClick());
    final int? customMl = await mostrarHojaMenu<int>(
      context,
      builder: (_) => const CustomWaterSheet(),
    );
    if (customMl != null && customMl > 0 && mounted) {
      await _logWater(dateKey: dateKey, volumeMl: customMl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final DateTime today = ref.watch(currentDateProvider);
    final DateTime activeDate = _effectiveDate(today);
    final String dateKey = activeDate.dateKey;
    final bool isToday = dateKey == today.dateKey;
    final MealType suggestedMeal = MealType.forHour(ref.read(clockProvider).now().hour);
    final NutritionDay? day = ref.watch(nutritionDayProvider(dateKey)).value;
    final String formattedDate = DateFormats.weekdayDayMonth(activeDate, l10n.localeName);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: ScSpace.bottomInset),
          children: <Widget>[
            TopBar(
              title: l10n.comerTitle,
              subtitle: formattedDate[0].toUpperCase() + formattedDate.substring(1),
              large: true,
            ),
            ComerWeekStrip(
              activeDate: activeDate,
              today: today,
              onSelectDate: (DateTime d) => _selectDate(d, today),
            ),
            ComerEntryHub(
              onOpenSearch: () => _openFoodSearch(dateKey, suggestedMeal),
              onOpenBarcode: () => _openBarcodeScanner(dateKey, suggestedMeal),
              onOpenTextEntry: () => _openTextEntry(dateKey, suggestedMeal),
              onOpenCombos: () => _openCombosSheet(dateKey, suggestedMeal),
              onOpenRecipes: () => _openRecipesSheet(dateKey, suggestedMeal),
              onOpenCustomFood: () => _openCustomFoodAndLog(dateKey, suggestedMeal),
              onOpenSmartMenu: () => SmartMealMenuSheet.show(context, targetDateKey: dateKey),
              onOpenFasting: () {
                unawaited(HapticFeedback.selectionClick());
                unawaited(context.push('/ayuno'));
              },
            ),
            if (day == null)
              const Padding(
                padding: EdgeInsets.all(ScSpace.xxl),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...<Widget>[
              _buildEnergy(day, dateKey),
              ElectrolytesCard(
                sodiumMg: day.totals.sodiumMg,
                targetSodiumMg: day.targets.sodiumTargetMg,
                potassiumMg: day.totals.potassiumMg,
                targetPotassiumMg: day.targets.potassiumTargetMg,
                magnesiumMg: day.totals.magnesiumMg,
                targetMagnesiumMg: day.targets.magnesiumTargetMg,
                fiberG: day.totals.fiberG,
                targetFiberG: day.targets.fiberTargetG,
              ),
              CalorieBankCard(dateKey: dateKey),
              if (day.totals.kcal > 0) NovaQualityCard(totals: day.totals),
              SectionHead(
                title: l10n.comerMealsTitle,
                subtitle: l10n.comerEntriesCount(day.entries.length),
              ),
              for (final MealSlotMeta slot in MealSlotMeta.all)
                MealBlockCard(
                  slot: slot,
                  isSuggestedNow: isToday && slot.key == suggestedMeal,
                  items: day.entriesFor(slot.key),
                  onAddFood: () => _openFoodSearch(dateKey, slot.key),
                  onRepeatYesterday: () => _repeatYesterdayMeal(
                    activeDate: activeDate,
                    mealType: slot.key,
                    mealTitle: slot.title(context.l10n),
                  ),
                  onSaveCombo: (List<FoodLogWithItem> items) =>
                      _saveCombo(slot.title(context.l10n), slot.key, items),
                  onTapEntry: _openEditLogSheet,
                  onDeleteEntry: _deleteFoodLogWithUndo,
                ),
              HydrationSectionCard(
                logs: day.waterLogs,
                goalMl: day.waterGoalMl,
                formatClock: (DateTime t) => DateFormats.time(t, l10n.localeName),
                onAdd250: () => _logWater(dateKey: dateKey, volumeMl: 250),
                onAdd500: () => _logWater(dateKey: dateKey, volumeMl: 500),
                onOpenCustom: () => _openCustomWaterSheet(dateKey),
                onDeleteGlass: _deleteGlassWithUndo,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEnergy(NutritionDay day, String dateKey) {
    final NutrientTotals t = day.totals;
    final int targetKcal = day.targets.effectiveCalorieTargetKcal;
    return EnergyAndMacrosCard(
      totalKcal: t.kcal,
      targetKcal: targetKcal,
      netWorkoutKcal: day.netWorkoutKcal,
      totalP: t.proteinG,
      targetP: day.targets.proteinTargetG,
      totalC: t.carbsG,
      targetC: day.targets.carbsTargetG,
      netCarbs: t.netCarbsG,
      totalFiber: t.fiberG,
      totalF: t.fatG,
      targetF: day.targets.fatTargetG,
      onOpenOracle: () => NutrientOracleSheet.show(
        context,
        remainingKcal: (targetKcal - t.kcal).clamp(0.0, 9999.0),
        remainingProteinG: (day.targets.proteinTargetG - t.proteinG).clamp(0.0, 999.0),
        remainingCarbsG: (day.targets.carbsTargetG - t.carbsG).clamp(0.0, 999.0),
        remainingFatG: (day.targets.fatTargetG - t.fatG).clamp(0.0, 999.0),
        targetDateKey: dateKey,
      ),
    );
  }
}
