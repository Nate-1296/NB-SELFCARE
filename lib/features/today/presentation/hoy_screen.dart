import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_shell.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/services/text_assistant.dart';
import '../../../shared/theme/sc_colors.dart';
import '../../../shared/theme/sc_tokens.dart';
import '../../../shared/utils/current_date_provider.dart';
import '../../../shared/utils/date_time_extensions.dart';
import '../../../shared/widgets/entrance.dart';
import '../../pet_gamification/application/nibi_overview.dart';
import '../application/hoy_layout_controller.dart';
import '../application/today_overview.dart';
import '../domain/hoy_widget_config.dart';
import 'today_actions.dart';
import 'widgets/cards/body_card.dart';
import 'widgets/cards/fasting_card.dart';
import 'widgets/cards/hydration_card.dart';
import 'widgets/cards/nibi_card.dart';
import 'widgets/cards/nutrition_card.dart';
import 'widgets/cards/sleep_card.dart';
import 'widgets/cards/steps_card.dart';
import 'widgets/cards/workout_card.dart';
import 'widgets/daily_rhythm_banner.dart';
import 'widgets/hoy_journal_4x4_widget.dart';
import 'widgets/layout_editing/customization_banner.dart';
import 'widgets/layout_editing/editable_bento_tile.dart';
import 'widgets/layout_editing/hidden_widgets_tray.dart';
import 'widgets/readiness_card.dart';
import 'widgets/steps_sleep_sheet.dart';
import 'widgets/sunday_ceremony_banner.dart';
import 'widgets/sunday_check_in_sheet.dart';
import 'widgets/today_bento_grid.dart';
import 'widgets/today_header.dart';

/// Pestaña "Hoy": tablero de tarjetas que el usuario ordena, redimensiona y
/// oculta (pulsación larga o "Editar tarjetas"). Toda la información llega ya
/// combinada en [todayOverviewProvider].
class HoyScreen extends ConsumerStatefulWidget {
  const HoyScreen({super.key});

  @override
  ConsumerState<HoyScreen> createState() => _HoyScreenState();
}

class _HoyScreenState extends ConsumerState<HoyScreen> {
  bool _isCustomizing = false;
  int _nibiThoughtOffset = 0;

  HoyLayoutController get _layout => ref.read(hoyLayoutControllerProvider.notifier);

  void _toggleCustomizing() {
    unawaited(HapticFeedback.selectionClick());
    setState(() => _isCustomizing = !_isCustomizing);
  }

  void _editLayout(Future<void> Function() change) {
    unawaited(HapticFeedback.selectionClick());
    unawaited(change());
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final DateTime today = ref.watch(currentDateProvider);
    final AsyncValue<TodayOverview> overview = ref.watch(todayOverviewProvider(today.dateKey));

    return Scaffold(
      backgroundColor: c.bg,
      body: overview.when(
        data: (TodayOverview data) => _buildContent(context, data),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) =>
            Center(child: Text(context.l10n.commonLoadError(error.toString()))),
      ),
    );
  }

  Widget _buildContent(BuildContext context, TodayOverview data) {
    final AppLocalizations l10n = context.l10n;
    final ({int seed, int startupHour}) session = ref.watch(hoySessionSeedProvider);
    final List<HoyWidgetItemConfig> layout = ref.watch(hoyLayoutControllerProvider);
    final List<HoyWidgetItemConfig> visible = layout
        .where((HoyWidgetItemConfig w) => w.visible)
        .toList();
    final List<HoyWidgetItemConfig> hidden = layout
        .where((HoyWidgetItemConfig w) => !w.visible)
        .toList();

    int order = 0;
    Widget enter(Widget child) => Entrance(index: order++, child: child);

    return ListView(
      padding: const EdgeInsets.only(bottom: ScSpace.bottomInset),
      children: <Widget>[
        TodayHeader(
          name: data.profile.name,
          date: data.now,
          sessionHour: session.startupHour,
          sessionSeed: session.seed,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: ScSpace.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_isCustomizing)
                CustomizationBanner(onReset: () => _editLayout(_layout.resetToDefaults))
              else
                DailyRhythmBanner(
                  activePillars: data.activePillars,
                  hiddenCount: hidden.length,
                  onCustomizeTap: _toggleCustomizing,
                ),
              const SizedBox(height: ScSpace.m),
              if (data.now.weekday == DateTime.sunday) ...<Widget>[
                enter(
                  SundayCeremonyBanner(onTap: () => unawaited(SundayCheckInSheet.show(context))),
                ),
                const SizedBox(height: ScSpace.cardGap),
              ],
              enter(
                ReadinessCard(
                  dateKey: data.dateKey,
                  onLogSleep: () => HoyStepsSleepSheet.show(
                    context: context,
                    dateKey: data.dateKey,
                    profile: data.profile,
                    currentSummary: data.summary,
                  ),
                ),
              ),
              const SizedBox(height: ScSpace.cardGap),
              enter(
                TodayBentoGrid(
                  items: visible,
                  tileBuilder: (HoyWidgetItemConfig item, int index) =>
                      _wrapTile(item, index, visible.length, _cardFor(item, data)),
                ),
              ),
              if (_isCustomizing && hidden.isNotEmpty)
                HiddenWidgetsTray(
                  hiddenItems: hidden,
                  onShowWidget: (HoyWidgetId id) => _editLayout(() => _layout.setVisible(id, true)),
                ),
              const SizedBox(height: ScSpace.s),
              Center(
                child: TextButton.icon(
                  onPressed: _toggleCustomizing,
                  icon: Icon(
                    _isCustomizing
                        ? Icons.check_circle_outline
                        : Icons.dashboard_customize_outlined,
                    size: 18,
                  ),
                  label: Text(_isCustomizing ? l10n.todaySaveLayout : l10n.todayEditCards),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _wrapTile(HoyWidgetItemConfig item, int index, int visibleCount, Widget card) {
    if (!_isCustomizing) {
      return GestureDetector(onLongPress: _toggleCustomizing, child: card);
    }
    return EditableBentoTile(
      key: ValueKey<String>('editable_${item.id.key}_${item.size.storageKey}'),
      item: item,
      canMoveUp: index > 0,
      canMoveDown: index < visibleCount - 1,
      canHide: visibleCount > 1,
      onToggleSize: () => _editLayout(() => _layout.toggleSize(item.id)),
      onMoveUp: () => _editLayout(() => _layout.moveUp(item.id)),
      onMoveDown: () => _editLayout(() => _layout.moveDown(item.id)),
      onHide: () => _editLayout(() => _layout.setVisible(item.id, false)),
      child: card,
    );
  }

  Widget _cardFor(HoyWidgetItemConfig item, TodayOverview data) {
    final TodayActions actions = TodayActions(ref, context);
    void openActivitySheet() => HoyStepsSleepSheet.show(
      context: context,
      dateKey: data.dateKey,
      profile: data.profile,
      currentSummary: data.summary,
    );

    return switch (item.id) {
      HoyWidgetId.nibiCompanion => HoyNibiBentoCard(
        size: item.size,
        petName: data.pet?.petName ?? context.l10n.todayNibi,
        look: nibiLookOf(data.pet),
        coinsBalance: data.pet?.coinsBalance ?? 0,
        streakDays: data.pet?.currentStreakDays ?? 0,
        aiGreeting: TextAssistant.buildNibiGreeting(
          petName: data.pet?.petName ?? context.l10n.todayNibi,
          sleepHours: data.sleepHours > 0 ? data.sleepHours : null,
          fastingHours: data.activeFast != null ? data.fastingHours : null,
          waterMl: data.totalWaterMl,
          waterGoalMl: data.profile.dailyWaterGoalMl,
          weightTrendDelta7d: data.weightTrendDelta7d,
          streak: data.pet?.currentStreakDays,
          variationSeed: ref.watch(hoyVisitSeedProvider) + _nibiThoughtOffset,
          hourOfDay: data.now.hour,
        ),
        fastingPhase: data.fastingPhase,
        hasSleepBonus: data.hasSleepBonus,
        onRefreshGreeting: () {
          unawaited(HapticFeedback.selectionClick());
          setState(() => _nibiThoughtOffset += 1);
        },
      ),
      HoyWidgetId.nutritionEnergy => HoyNutritionBentoCard(
        size: item.size,
        consumedKcal: data.nutrition.kcal,
        consumedProtein: data.nutrition.proteinG,
        consumedCarbs: data.nutrition.carbsG,
        consumedFat: data.nutrition.fatG,
        targets: data.targets,
        onRepeatYesterday: () => actions.repeatYesterday(data.dateKey),
      ),
      HoyWidgetId.hydration => HoyHydrationBentoCard(
        size: item.size,
        totalWaterMl: data.totalWaterMl,
        goalMl: data.profile.dailyWaterGoalMl,
        glassesCount: data.waterLogs.length,
        canUndo: data.waterLogs.isNotEmpty,
        onAdd250: () => actions.logWater(dateKey: data.dateKey, volumeMl: 250),
        onAdd500: () => actions.logWater(dateKey: data.dateKey, volumeMl: 500),
        onUndoLast: () {
          if (data.waterLogs.isNotEmpty) unawaited(actions.undoGlass(data.waterLogs.last));
        },
      ),
      HoyWidgetId.bodyWeight => HoyBodyBentoCard(
        size: item.size,
        latestMeasurement: data.latestMeasurement,
        recentMeasurements: data.recentMeasurements,
        targetWeightKg: data.profile.targetWeightKg,
      ),
      HoyWidgetId.stepsNeat => HoyStepsBentoCard(
        size: item.size,
        steps: data.steps,
        goalSteps: data.profile.dailyStepsGoal,
        onQuickAdd1000: () => actions.addSteps(dateKey: data.dateKey, currentSteps: data.steps),
        onOpenSheet: openActivitySheet,
      ),
      HoyWidgetId.sleepRecovery => HoySleepBentoCard(
        size: item.size,
        sleepHours: data.sleepHours,
        goalHours: data.profile.dailySleepGoalHours,
        hasSleepBonus: data.hasSleepBonus,
        onOpenSheet: openActivitySheet,
      ),
      HoyWidgetId.workoutRpe => HoyWorkoutBentoCard(
        size: item.size,
        workoutsToday: data.workouts,
        profile: data.profile,
      ),
      HoyWidgetId.fastingMetabolic => HoyFastingBentoCard(
        size: item.size,
        activeFast: data.activeFast,
        now: data.now,
      ),
      HoyWidgetId.dailyJournal => HoyJournal4x4Widget(dateKey: data.dateKey),
    };
  }
}
