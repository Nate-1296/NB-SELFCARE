import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_shell.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/body_measurements_dao.dart';
import '../../../core/database/daos/fasting_dao.dart';
import '../../../core/database/daos/food_dao.dart';
import '../../../core/database/daos/health_sync_dao.dart';
import '../../../core/database/daos/hydration_dao.dart';
import '../../../core/database/daos/journal_dao.dart';
import '../../../core/database/daos/pet_dao.dart';
import '../../../core/database/daos/user_profile_dao.dart';
import '../../../core/database/daos/workout_dao.dart';
import '../../../core/services/health_connect_service.dart';
import '../../../core/services/local_ai_service.dart';
import '../../../shared/theme/sc_colors.dart';
import '../../../shared/theme/sc_theme.dart';
import '../../../shared/utils/current_date_provider.dart';
import '../../../shared/utils/daily_targets_calculator.dart';
import '../../../shared/utils/date_time_extensions.dart';
import '../../../shared/widgets/app_icons.dart';
import '../../../shared/widgets/health_card.dart';
import '../../../shared/widgets/top_bar.dart';
import '../domain/hoy_widget_config.dart';
import 'widgets/hoy_bento_cards.dart';
import 'widgets/hoy_journal_4x4_widget.dart';
import 'widgets/readiness_card.dart';
import 'widgets/sunday_check_in_sheet.dart';

/// Pestaña "Hoy": Tablero modular tipo Bento inspirado en Samsung Health / Apple Health.
///
/// Características clave:
/// - Tarjetas de resumen redimensionables (`2×2` cuadrado ↔ `4×2` panorámico),
///   reordenables (subir/bajar) y conmutables (mostrar/ocultar), persistidas 100% offline.
/// - Cero botones sueltos de acción rápida: cada tarjeta incorpora sus acciones directas.
/// - Cero textos truncados: alturas adaptables con `IntrinsicHeight` y envoltura fluida.
/// - Saludo dinámico variado según la hora del día + fecha natural debajo del saludo
///   (sin leyendas de "Santuario Offline").
/// - Saludo de Nibi generado por IA local que varía cada vez que el usuario entra a "Hoy".
/// - Único widget gigante `4×4` dedicado exclusivamente al Diario Personal (eliminado de Perfil).
class HoyScreen extends ConsumerStatefulWidget {
  const HoyScreen({super.key});

  @override
  ConsumerState<HoyScreen> createState() => _HoyScreenState();
}

class _HoyScreenState extends ConsumerState<HoyScreen> {
  bool _isCustomizing = false;
  int _manualAiSeedOffset = 0;

  /// Genera el saludo horario fijo para toda la sesión actual de la aplicación
  /// (solo varía al cerrar y volver a abrir la app).
  static String _saludoDeSesion({
    required String firstName,
    required int sessionSeed,
    required int sessionHour,
  }) {
    final int idx = sessionSeed.abs();

    if (sessionHour >= 5 && sessionHour < 12) {
      final List<String> manana = <String>[
        'Buenos días, $firstName',
        'Buen día, $firstName',
        'Feliz mañana, $firstName',
      ];
      return manana[idx % manana.length];
    }
    if (sessionHour >= 12 && sessionHour < 19) {
      final List<String> tarde = <String>[
        'Buenas tardes, $firstName',
        'Feliz tarde, $firstName',
        'Qué buena tarde, $firstName',
      ];
      return tarde[idx % tarde.length];
    }
    final List<String> noche = <String>[
      'Buenas noches, $firstName',
      'Feliz noche, $firstName',
      'Linda noche, $firstName',
    ];
    return noche[idx % noche.length];
  }

  /// Formatea la fecha corta DD/MM/YYYY (ej. 24/10/2026) para mostrar debajo del saludo.
  static String _formatearFechaCorta(DateTime date) {
    final String dd = date.day.toString().padLeft(2, '0');
    final String mm = date.month.toString().padLeft(2, '0');
    final String yyyy = date.year.toString().padLeft(4, '0');
    return '$dd/$mm/$yyyy';
  }

  static double? _computeWeightTrendDelta7d(List<BodyMeasurement> recent) {
    if (recent.length < 2) return null;
    final BodyMeasurement latest = recent.last;
    final DateTime cutoff =
        latest.measuredAt.subtract(const Duration(days: 7));
    BodyMeasurement baseline = recent.first;
    for (final BodyMeasurement m in recent) {
      if (!m.measuredAt.isBefore(cutoff)) {
        baseline = m;
        break;
      }
    }
    if (identical(baseline, latest)) {
      baseline = recent[recent.length - 2];
    }
    return latest.trendWeightKg - baseline.trendWeightKg;
  }

  void _toggleCustomizeMode() {
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _isCustomizing = !_isCustomizing;
    });
  }

  void _refreshNibiThought() {
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _manualAiSeedOffset += 1;
    });
  }

  Future<void> _logWaterGlass({
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

    final HealthConnectService healthConnect =
        ref.read(healthConnectServiceProvider);
    unawaited(
      healthConnect.writeHydration(
        amountMl: volumeMl,
        timestamp: DateTime.now(),
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('+$volumeMl ml de agua registrados 💧'),
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
  }

  Future<void> _undoLastWaterGlass(HydrationLog lastLog) async {
    unawaited(HapticFeedback.selectionClick());
    final HydrationDao hydrationDao = ref.read(hydrationDaoProvider);
    await hydrationDao.deleteGlass(lastLog.id);
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Eliminado vaso de ${lastLog.volumeMl} ml'),
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  Future<void> _quickAdd1000Steps({
    required String dateKey,
    required DailySummary? currentSummary,
  }) async {
    unawaited(HapticFeedback.lightImpact());
    final HealthSyncDao healthSyncDao = ref.read(healthSyncDaoProvider);
    final int previousSteps = currentSummary?.stepsCount ?? 0;
    final int updatedSteps = (previousSteps + 1000).clamp(0, 100000);
    final int activeKcal = (updatedSteps * 0.04).round();

    await healthSyncDao.upsertDailySummary(
      DailySummariesCompanion(
        dateKey: drift.Value(dateKey),
        stepsCount: drift.Value(updatedSteps),
        activeCaloriesFromSteps: drift.Value(activeKcal),
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Sumados +1,000 pasos ($updatedSteps hoy) 👟'),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Deshacer',
              onPressed: () {
                unawaited(
                  healthSyncDao.upsertDailySummary(
                    DailySummariesCompanion(
                      dateKey: drift.Value(dateKey),
                      stepsCount: drift.Value(previousSteps),
                      activeCaloriesFromSteps:
                          drift.Value((previousSteps * 0.04).round()),
                    ),
                  ),
                );
              },
            ),
          ),
        );
    }
  }

  Future<void> _repeatYesterday({
    required String yesterdayDateKey,
    required String todayDateKey,
  }) async {
    unawaited(HapticFeedback.lightImpact());
    final FoodDao foodDao = ref.read(foodDaoProvider);
    final List<int> allInsertedIds = <int>[];
    for (final String meal in const <String>[
      'breakfast',
      'lunch',
      'dinner',
      'snack',
    ]) {
      final List<int> inserted = await foodDao.repeatMealFromYesterday(
        fromDateKey: yesterdayDateKey,
        toDateKey: todayDateKey,
        mealType: meal,
      );
      allInsertedIds.addAll(inserted);
    }

    if (allInsertedIds.isNotEmpty) {
      await ref.read(petDaoProvider).grantDailyReward(
            dateKey: todayDateKey,
            actionType: 'meal_log_repeat',
            baseAmount: 10,
          );
    }

    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              allInsertedIds.isNotEmpty
                  ? '¡Repetidas las comidas de ayer (${allInsertedIds.length} alimentos)!'
                  : 'No hay comidas registradas ayer para repetir',
            ),
            duration: const Duration(seconds: 3),
            action: allInsertedIds.isNotEmpty
                ? SnackBarAction(
                    label: 'Deshacer',
                    onPressed: () {
                      for (final int id in allInsertedIds) {
                        unawaited(foodDao.deleteFoodLog(id));
                      }
                    },
                  )
                : null,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final DateTime today = ref.watch(currentDateProvider);
    final String dateKey = today.dateKey;
    final String yesterdayDateKey =
        today.subtract(const Duration(days: 1)).dateKey;

    final ({int seed, int startupHour}) sessionGreeting =
        ref.watch(hoySessionSeedProvider);
    final int visitSeed = ref.watch(hoyVisitSeedProvider);
    final List<HoyWidgetItemConfig> layoutConfig =
        ref.watch(hoyLayoutControllerProvider);

    final AsyncValue<UserProfile?> profileAsync =
        ref.watch(userProfileStreamProvider);
    final AsyncValue<PetStatusData?> petAsync =
        ref.watch(petStatusStreamProvider);
    final AsyncValue<BodyMeasurement?> latestMeasAsync =
        ref.watch(latestMeasurementStreamProvider);
    final AsyncValue<List<BodyMeasurement>> recentMeasAsync =
        ref.watch(recentMeasurementsStreamProvider);
    final AsyncValue<FastingSession?> activeFastAsync =
        ref.watch(activeFastingSessionStreamProvider);

    final FoodDao foodDao = ref.watch(foodDaoProvider);
    final HydrationDao hydrationDao = ref.watch(hydrationDaoProvider);
    final WorkoutDao workoutDao = ref.watch(workoutDaoProvider);
    final HealthSyncDao healthSyncDao = ref.watch(healthSyncDaoProvider);
    final JournalDao journalDao = ref.watch(journalDaoProvider);

    return profileAsync.when(
      data: (UserProfile? profile) {
        if (profile == null) {
          return const Scaffold(
            body: Center(child: Text('Perfil no inicializado')),
          );
        }

        final PetStatusData? pet = petAsync.value;
        final BodyMeasurement? latestMeas = latestMeasAsync.value;
        final List<BodyMeasurement> recentMeas =
            recentMeasAsync.value ?? const <BodyMeasurement>[];
        final FastingSession? activeFast = activeFastAsync.value;
        final bool isFasting = activeFast != null;
        final double elapsedFastingHours = isFasting
            ? (DateTime.now().difference(activeFast.startedAt).inMinutes / 60.0)
                .clamp(0.0, 999.0)
            : 0.0;
        final bool isKetosis = elapsedFastingHours >= 12.0;

        final String firstName = profile.name.trim().isNotEmpty
            ? profile.name.trim().split(' ').first
            : 'Hola';
        final String saludo = _saludoDeSesion(
          firstName: firstName,
          sessionSeed: sessionGreeting.seed,
          sessionHour: sessionGreeting.startupHour,
        );
        final String fechaCorta = _formatearFechaCorta(today);

        return StreamBuilder<DailySummary?>(
          stream: healthSyncDao.watchDailySummary(dateKey),
          builder: (BuildContext context, AsyncSnapshot<DailySummary?> summarySnap) {
            final DailySummary? summary = summarySnap.data;
            final int steps = summary?.stepsCount ?? 0;
            final double sleepHours =
                (summary?.sleepDurationMinutes ?? 0) / 60.0;
            final int restorativeMin = (summary?.sleepDeepMinutes ?? 0) +
                (summary?.sleepRemMinutes ?? 0);
            final bool hasSleepBonus =
                restorativeMin >= 90 || sleepHours >= 7.5;

            return StreamBuilder<List<HydrationLog>>(
              stream: hydrationDao.watchLogsForDate(dateKey),
              builder: (
                BuildContext context,
                AsyncSnapshot<List<HydrationLog>> waterLogsSnap,
              ) {
                final List<HydrationLog> waterLogs =
                    waterLogsSnap.data ?? const <HydrationLog>[];
                final int totalWaterMl = waterLogs.fold<int>(
                  0,
                  (int sum, HydrationLog l) => sum + l.volumeMl,
                );

                return StreamBuilder<List<FoodLog>>(
                  stream: foodDao.watchLogsForDate(dateKey),
                  builder: (
                    BuildContext context,
                    AsyncSnapshot<List<FoodLog>> foodSnap,
                  ) {
                    final List<FoodLog> foodLogs =
                        foodSnap.data ?? const <FoodLog>[];
                    final double consumedKcal = foodLogs.fold<double>(
                      0.0,
                      (double acc, FoodLog item) => acc + item.totalKcal,
                    );
                    final double consumedProtein = foodLogs.fold<double>(
                      0.0,
                      (double acc, FoodLog item) => acc + item.totalProteinG,
                    );
                    final double consumedCarbs = foodLogs.fold<double>(
                      0.0,
                      (double acc, FoodLog item) => acc + item.totalCarbsG,
                    );
                    final double consumedFat = foodLogs.fold<double>(
                      0.0,
                      (double acc, FoodLog item) => acc + item.totalFatG,
                    );

                    return StreamBuilder<List<WorkoutBlock>>(
                      stream: workoutDao.watchWorkoutsForDate(dateKey),
                      builder: (
                        BuildContext context,
                        AsyncSnapshot<List<WorkoutBlock>> workoutsSnap,
                      ) {
                        final List<WorkoutBlock> workoutsToday =
                            workoutsSnap.data ?? const <WorkoutBlock>[];
                        final int netBurnedKcal = workoutsToday.fold<int>(
                          0,
                          (int sum, WorkoutBlock w) =>
                              sum + w.netCaloriesBurned,
                        );

                        final DailyMacroTargets targets =
                            DailyTargetsCalculator.compute(
                          profile: profile,
                          currentWeightKg: latestMeas?.trendWeightKg,
                          netWorkoutKcal: netBurnedKcal,
                        );

                        return StreamBuilder<List<JournalEntry>>(
                          stream: journalDao.watchRecentEntries(limit: 5),
                          builder: (
                            BuildContext context,
                            AsyncSnapshot<List<JournalEntry>> journalSnap,
                          ) {
                            final List<JournalEntry> recentJournals =
                                journalSnap.data ?? const <JournalEntry>[];
                            final bool hasJournalToday = recentJournals
                                .any((JournalEntry e) => e.dateKey == dateKey);

                            final int activePillars = <bool>[
                              foodLogs.isNotEmpty,
                              totalWaterMl > 0,
                              steps >= 1000 || workoutsToday.isNotEmpty,
                              sleepHours > 0,
                              hasJournalToday,
                            ].where((bool v) => v).length;

                            final String nibiGreeting =
                                LocalAiService.buildInstantGreeting(
                              petName: pet?.petName ?? 'Nibi',
                              sleepHours: sleepHours > 0 ? sleepHours : null,
                              fastingHours:
                                  isFasting ? elapsedFastingHours : null,
                              waterMl: totalWaterMl,
                              waterGoalMl: profile.dailyWaterGoalMl,
                              weightTrendDelta7d:
                                  _computeWeightTrendDelta7d(recentMeas),
                              streak: pet?.currentStreakDays,
                              variationSeed: visitSeed + _manualAiSeedOffset,
                              hourOfDay: DateTime.now().hour,
                            );

                            final List<HoyWidgetItemConfig> visibleItems =
                                layoutConfig
                                    .where((HoyWidgetItemConfig w) => w.visible)
                                    .toList();
                            final List<HoyWidgetItemConfig> hiddenItems =
                                layoutConfig
                                    .where(
                                        (HoyWidgetItemConfig w) => !w.visible)
                                    .toList();

                            Widget buildConcreteWidget(
                              HoyWidgetItemConfig cfg,
                            ) {
                              switch (cfg.id) {
                                case HoyWidgetId.nibiCompanion:
                                  return HoyNibiBentoCard(
                                    size: cfg.size,
                                    petName: pet?.petName ?? 'Nibi',
                                    coinsBalance: pet?.coinsBalance ?? 0,
                                    streakDays: pet?.currentStreakDays ?? 0,
                                    aiGreeting: nibiGreeting,
                                    isKetosis: isKetosis,
                                    hasSleepBonus: hasSleepBonus,
                                    onRefreshGreeting: _refreshNibiThought,
                                  );
                                case HoyWidgetId.nutritionEnergy:
                                  return HoyNutritionBentoCard(
                                    size: cfg.size,
                                    consumedKcal: consumedKcal,
                                    consumedProtein: consumedProtein,
                                    consumedCarbs: consumedCarbs,
                                    consumedFat: consumedFat,
                                    targets: targets,
                                    onRepeatYesterday: () => _repeatYesterday(
                                      yesterdayDateKey: yesterdayDateKey,
                                      todayDateKey: dateKey,
                                    ),
                                  );
                                case HoyWidgetId.hydration:
                                  return HoyHydrationBentoCard(
                                    size: cfg.size,
                                    totalWaterMl: totalWaterMl,
                                    goalMl: profile.dailyWaterGoalMl,
                                    glassesCount: waterLogs.length,
                                    canUndo: waterLogs.isNotEmpty,
                                    onAdd250: () => _logWaterGlass(
                                      dateKey: dateKey,
                                      volumeMl: 250,
                                      goalMl: profile.dailyWaterGoalMl,
                                    ),
                                    onAdd500: () => _logWaterGlass(
                                      dateKey: dateKey,
                                      volumeMl: 500,
                                      goalMl: profile.dailyWaterGoalMl,
                                    ),
                                    onUndoLast: () {
                                      if (waterLogs.isNotEmpty) {
                                        unawaited(
                                          _undoLastWaterGlass(waterLogs.first),
                                        );
                                      }
                                    },
                                  );
                                case HoyWidgetId.bodyWeight:
                                  return HoyBodyBentoCard(
                                    size: cfg.size,
                                    latestMeasurement: latestMeas,
                                    recentMeasurements: recentMeas,
                                    targetWeightKg: profile.targetWeightKg,
                                  );
                                case HoyWidgetId.stepsNeat:
                                  return HoyStepsBentoCard(
                                    size: cfg.size,
                                    steps: steps,
                                    goalSteps: profile.dailyStepsGoal,
                                    onQuickAdd1000: () => _quickAdd1000Steps(
                                      dateKey: dateKey,
                                      currentSummary: summary,
                                    ),
                                    onOpenSheet: () => HoyStepsSleepSheet.show(
                                      context: context,
                                      dateKey: dateKey,
                                      profile: profile,
                                      currentSummary: summary,
                                    ),
                                  );
                                case HoyWidgetId.sleepRecovery:
                                  return HoySleepBentoCard(
                                    size: cfg.size,
                                    sleepHours: sleepHours,
                                    goalHours: profile.dailySleepGoalHours,
                                    hasSleepBonus: hasSleepBonus,
                                    onOpenSheet: () => HoyStepsSleepSheet.show(
                                      context: context,
                                      dateKey: dateKey,
                                      profile: profile,
                                      currentSummary: summary,
                                    ),
                                  );
                                case HoyWidgetId.workoutRpe:
                                  return HoyWorkoutBentoCard(
                                    size: cfg.size,
                                    workoutsToday: workoutsToday,
                                    profile: profile,
                                  );
                                case HoyWidgetId.fastingMetabolic:
                                  return HoyFastingBentoCard(
                                    size: cfg.size,
                                    activeFast: activeFast,
                                  );
                                case HoyWidgetId.dailyJournal:
                                  return HoyJournal4x4Widget(
                                    dateKey: dateKey,
                                  );
                              }
                            }

                            Widget wrapTile(
                              HoyWidgetItemConfig cfg,
                              int visibleIdx,
                            ) {
                              final Widget coreCard = buildConcreteWidget(cfg);
                              if (!_isCustomizing) {
                                return GestureDetector(
                                  onLongPress: _toggleCustomizeMode,
                                  child: coreCard,
                                );
                              }
                              return _EditableBentoTile(
                                key: ValueKey<String>(
                                  'editable_${cfg.id.key}_${cfg.size.storageKey}',
                                ),
                                item: cfg,
                                canMoveUp: visibleIdx > 0,
                                canMoveDown:
                                    visibleIdx < visibleItems.length - 1,
                                canHide: visibleItems.length > 1,
                                onToggleSize: () {
                                  unawaited(HapticFeedback.selectionClick());
                                  unawaited(
                                    ref
                                        .read(hoyLayoutControllerProvider
                                            .notifier)
                                        .toggleSize(cfg.id),
                                  );
                                },
                                onMoveUp: () {
                                  unawaited(HapticFeedback.selectionClick());
                                  unawaited(
                                    ref
                                        .read(hoyLayoutControllerProvider
                                            .notifier)
                                        .moveUp(cfg.id),
                                  );
                                },
                                onMoveDown: () {
                                  unawaited(HapticFeedback.selectionClick());
                                  unawaited(
                                    ref
                                        .read(hoyLayoutControllerProvider
                                            .notifier)
                                        .moveDown(cfg.id),
                                  );
                                },
                                onHide: () {
                                  unawaited(HapticFeedback.selectionClick());
                                  unawaited(
                                    ref
                                        .read(hoyLayoutControllerProvider
                                            .notifier)
                                        .setVisible(cfg.id, false),
                                  );
                                },
                                child: coreCard,
                              );
                            }

                            final List<Widget> bentoRows = <Widget>[];
                            int i = 0;
                            while (i < visibleItems.length) {
                              final HoyWidgetItemConfig current =
                                  visibleItems[i];
                              if (current.size == HoyWidgetSize.w2x2) {
                                if (i + 1 < visibleItems.length &&
                                    visibleItems[i + 1].size ==
                                        HoyWidgetSize.w2x2) {
                                  final HoyWidgetItemConfig next =
                                      visibleItems[i + 1];
                                  final int firstIdx = i;
                                  final int secondIdx = i + 1;
                                  bentoRows.add(
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 6,
                                      ),
                                      child: IntrinsicHeight(
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: <Widget>[
                                            Expanded(
                                              child:
                                                  wrapTile(current, firstIdx),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: wrapTile(next, secondIdx),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                  i += 2;
                                } else {
                                  final int soloIdx = i;
                                  bentoRows.add(
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 6,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Expanded(
                                            child: wrapTile(current, soloIdx),
                                          ),
                                          const SizedBox(width: 12),
                                          const Expanded(
                                            child: SizedBox.shrink(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                  i += 1;
                                }
                              } else {
                                final int fullIdx = i;
                                bentoRows.add(
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 6,
                                    ),
                                    child: wrapTile(current, fullIdx),
                                  ),
                                );
                                i += 1;
                              }
                            }

                            return Scaffold(
                              backgroundColor: c.bg,
                              body: ListView(
                                padding: const EdgeInsets.only(bottom: 28),
                                children: <Widget>[
                                  TopBar(
                                    title: saludo,
                                    subtitle: fechaCorta,
                                    subtitleBelowTitle: true,
                                    uppercaseSubtitle: false,
                                    pageIcon: Icons.flare_rounded,
                                    large: true,
                                    onProfile: () => context.go('/perfil'),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.calendar_month_rounded),
                                      tooltip: 'Mi Protocolo Semanal',
                                      onPressed: () {
                                        unawaited(HapticFeedback.lightImpact());
                                        unawaited(context.push('/protocolo'));
                                      },
                                    ),
                                  ),

                                  // Banner Ceremonial Dominical de Nibi
                                  if (today.weekday == DateTime.sunday)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                                      child: InkWell(
                                        onTap: () {
                                          unawaited(HapticFeedback.selectionClick());
                                          unawaited(SundayCheckInSheet.show(context));
                                        },
                                        borderRadius: BorderRadius.circular(16),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: c.isFlat ? c.bg3 : c.soft,
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: c.isFlat ? c.line2 : c.accent.withValues(alpha: 0.35),
                                              width: c.isFlat ? 1.5 : 1.2,
                                            ),
                                          ),
                                          child: Row(
                                            children: <Widget>[
                                              const Text('✨', style: TextStyle(fontSize: 22)),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: <Widget>[
                                                    Text(
                                                      'Ceremonia Dominical de Nibi',
                                                      style: TextStyle(
                                                        fontFamily: ScFonts.display,
                                                        fontSize: 13.5,
                                                        fontWeight: FontWeight.bold,
                                                        color: c.text,
                                                      ),
                                                    ),
                                                    Text(
                                                      'Revisa tu semana, calibra tu protocolo y gana +15 monedas',
                                                      style: TextStyle(
                                                        fontFamily: ScFonts.ui,
                                                        fontSize: 11.5,
                                                        color: c.text2,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Icon(Icons.chevron_right_rounded, color: c.accent),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),

                                  // Pulso diario sutil cuando no está en modo edición
                                  if (!_isCustomizing)
                                    _DailyRhythmBanner(
                                      activePillars: activePillars,
                                      hiddenCount: hiddenItems.length,
                                      onCustomizeTap: _toggleCustomizeMode,
                                    )
                                  else
                                    _CustomizationBanner(
                                      onReset: () {
                                        unawaited(
                                            HapticFeedback.mediumImpact());
                                        unawaited(
                                          ref
                                              .read(hoyLayoutControllerProvider
                                                  .notifier)
                                              .resetToDefaults(),
                                        );
                                      },
                                    ),

                                  const SizedBox(height: 4),

                                  // Tarjeta de Disposición y Cronobiología de Cafeína
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 6,
                                    ),
                                    child: ReadinessCard(dateKey: dateKey),
                                  ),

                                  // Cuadrícula Bento adaptable (2×2, 4×2 y único 4×4 de Diario)
                                  ...bentoRows,

                                  // Bandeja de tarjetas ocultas en modo Personalizar
                                  if (_isCustomizing && hiddenItems.isNotEmpty)
                                    _HiddenWidgetsTray(
                                      hiddenItems: hiddenItems,
                                      onShowWidget: (HoyWidgetId id) {
                                        unawaited(
                                            HapticFeedback.selectionClick());
                                        unawaited(
                                          ref
                                              .read(hoyLayoutControllerProvider
                                                  .notifier)
                                              .setVisible(id, true),
                                        );
                                      },
                                    ),

                                  // Pie estilo Samsung Health / Apple Health para editar la vista Hoy
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        18, 14, 18, 8),
                                    child: Center(
                                      child: OutlinedButton.icon(
                                        onPressed: _toggleCustomizeMode,
                                        icon: Icon(
                                          _isCustomizing
                                              ? Icons.check_circle_outline
                                              : Icons
                                                  .dashboard_customize_outlined,
                                          size: 17,
                                          color: c.accent,
                                        ),
                                        label: Text(
                                          _isCustomizing
                                              ? 'Guardar diseño de Hoy'
                                              : 'Editar tarjetas de Hoy',
                                          softWrap: true,
                                          style: TextStyle(
                                            fontFamily: ScFonts.ui,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: c.text,
                                          ),
                                        ),
                                      ),
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
                );
              },
            );
          },
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (Object err, StackTrace _) => Scaffold(
        body: Center(child: Text('Error al cargar Hoy: $err')),
      ),
    );
  }
}

class _DailyRhythmBanner extends StatelessWidget {
  const _DailyRhythmBanner({
    required this.activePillars,
    required this.hiddenCount,
    required this.onCustomizeTap,
  });

  final int activePillars;
  final int hiddenCount;
  final VoidCallback onCustomizeTap;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final String rhythmMessage;
    if (activePillars == 0) {
      rhythmMessage = 'Tu día empieza en blanco · Elige por dónde comenzar';
    } else if (activePillars < 4) {
      rhythmMessage = '$activePillars de 5 hábitos con movimiento hoy';
    } else {
      rhythmMessage = '¡Día redondo! $activePillars de 5 hábitos activos hoy';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: c.bg2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: c.isFlat ? c.line2 : c.line,
            width: c.isFlat ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List<Widget>.generate(5, (int idx) {
                final bool active = idx < activePillars;
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? c.accent : c.bg3,
                    border: c.isFlat
                        ? Border.all(color: c.line2, width: 1.0)
                        : null,
                  ),
                );
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hiddenCount > 0
                    ? '$rhythmMessage · $hiddenCount oculta(s)'
                    : rhythmMessage,
                softWrap: true,
                style: TextStyle(
                  fontFamily: ScFonts.ui,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.text2,
                ),
              ),
            ),
            if (hiddenCount > 0)
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onCustomizeTap,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    'Mostrar',
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: c.accent,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CustomizationBanner extends StatelessWidget {
  const _CustomizationBanner({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.isFlat ? c.bg2 : c.soft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: c.isFlat ? c.line2 : c.accent.withValues(alpha: 0.45),
            width: 1.5,
          ),
        ),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: c.accent,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Personaliza Hoy: alterna tamaño 2×2 o 4×2, ordena u oculta tarjetas.',
                    softWrap: true,
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                ),
              ],
            ),
            OutlinedButton.icon(
              onPressed: onReset,
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              icon: const Icon(AppIcons.refresh, size: 15),
              label: const Text('Restaurar orden'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditableBentoTile extends StatelessWidget {
  const _EditableBentoTile({
    super.key,
    required this.item,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.canHide,
    required this.onToggleSize,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onHide,
    required this.child,
  });

  final HoyWidgetItemConfig item;
  final bool canMoveUp;
  final bool canMoveDown;
  final bool canHide;
  final VoidCallback onToggleSize;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onHide;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final bool canResize = item.id.canResize;
    final String nextSizeLabel =
        item.size == HoyWidgetSize.w2x2 ? 'Ampliar 4×2' : 'Reducir 2×2';

    return Container(
      decoration: BoxDecoration(
        color: c.bg3,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: c.isFlat ? c.line2 : c.accent.withValues(alpha: 0.55),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 6, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        item.id.title,
                        softWrap: true,
                        style: TextStyle(
                          fontFamily: ScFonts.display,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: c.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: c.bg2,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: c.line2, width: 1.0),
                      ),
                      child: Text(
                        item.size.label,
                        style: TextStyle(
                          fontFamily: ScFonts.display,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: c.accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    if (canResize)
                      _MiniEditButton(
                        tooltip: 'Cambiar tamaño (${item.id.title})',
                        icon: item.size == HoyWidgetSize.w2x2
                            ? Icons.open_in_full_rounded
                            : Icons.close_fullscreen_rounded,
                        label: nextSizeLabel,
                        onTap: onToggleSize,
                        accent: true,
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: c.bg2,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: c.line, width: 1.0),
                        ),
                        child: Text(
                          'Bloque 4×4 único',
                          style: TextStyle(
                            fontFamily: ScFonts.ui,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: c.text2,
                          ),
                        ),
                      ),
                    _MiniEditIconButton(
                      tooltip: 'Subir (${item.id.title})',
                      icon: Icons.arrow_upward_rounded,
                      onTap: canMoveUp ? onMoveUp : null,
                    ),
                    _MiniEditIconButton(
                      tooltip: 'Bajar (${item.id.title})',
                      icon: Icons.arrow_downward_rounded,
                      onTap: canMoveDown ? onMoveDown : null,
                    ),
                    _MiniEditIconButton(
                      tooltip: 'Ocultar (${item.id.title})',
                      icon: Icons.visibility_off_outlined,
                      onTap: canHide ? onHide : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _MiniEditButton extends StatelessWidget {
  const _MiniEditButton({
    required this.tooltip,
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = false,
  });

  final String tooltip;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: c.bg2,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: accent ? c.accent : c.line2,
                width: 1.1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 13, color: accent ? c.accent : c.text),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: c.text,
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

class _MiniEditIconButton extends StatelessWidget {
  const _MiniEditIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final bool enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: c.bg2,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: enabled ? c.line2 : c.line,
                width: 1.0,
              ),
            ),
            child: Icon(
              icon,
              size: 15,
              color: enabled ? c.text : c.text3,
            ),
          ),
        ),
      ),
    );
  }
}

class _HiddenWidgetsTray extends StatelessWidget {
  const _HiddenWidgetsTray({
    required this.hiddenItems,
    required this.onShowWidget,
  });

  final List<HoyWidgetItemConfig> hiddenItems;
  final ValueChanged<HoyWidgetId> onShowWidget;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return HealthCard(
      margin: const EdgeInsets.fromLTRB(18, 12, 18, 6),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.visibility_outlined, size: 18, color: c.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tarjetas ocultas (${hiddenItems.length})',
                  softWrap: true,
                  style: TextStyle(
                    fontFamily: ScFonts.display,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: c.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Toca para volver a añadir cualquier tarjeta a tu resumen de Hoy.',
            softWrap: true,
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 12,
              color: c.text2,
            ),
          ),
          const SizedBox(height: 12),
          ...hiddenItems.map(
            (HoyWidgetItemConfig item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: c.bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: c.isFlat ? c.line2 : c.line,
                    width: c.isFlat ? 1.3 : 1.0,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${item.id.title} (${item.size.label})',
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
                    FilledButton.tonalIcon(
                      onPressed: () => onShowWidget(item.id),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Mostrar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
