import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock/clock.dart';
import '../../../core/database/app_database.dart';
import '../../../core/domain/metabolic_phase.dart';
import '../../../shared/utils/daily_targets_calculator.dart';
import '../../body_metrics/application/body_queries.dart';
import '../../fasting/application/fasting_queries.dart';
import '../../journal/application/journal_queries.dart';
import '../../nutrition_hydration/application/nutrition_queries.dart';
import '../../pet_gamification/application/pet_queries.dart';
import '../../pet_gamification/domain/reward_policy.dart';
import '../../profile_goals/application/daily_targets_provider.dart';
import '../../profile_goals/application/profile_queries.dart';
import 'today_queries.dart';

/// Totales nutricionales consumidos en el día.
class NutritionTotals {
  const NutritionTotals({
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.entries,
  });

  factory NutritionTotals.from(List<FoodLog> logs) {
    double sum(double Function(FoodLog l) f) => logs.fold<double>(0, (double a, FoodLog l) => a + f(l));
    return NutritionTotals(
      kcal: sum((FoodLog l) => l.totalKcal),
      proteinG: sum((FoodLog l) => l.totalProteinG),
      carbsG: sum((FoodLog l) => l.totalCarbsG),
      fatG: sum((FoodLog l) => l.totalFatG),
      entries: logs.length,
    );
  }

  final double kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final int entries;
}

/// Todo lo que muestra la pantalla Hoy, ya combinado.
class TodayOverview {
  const TodayOverview({
    required this.dateKey,
    required this.now,
    required this.profile,
    required this.targets,
    required this.pet,
    required this.latestMeasurement,
    required this.recentMeasurements,
    required this.activeFast,
    required this.summary,
    required this.waterLogs,
    required this.nutrition,
    required this.workouts,
    required this.hasJournalToday,
  });

  final String dateKey;
  final DateTime now;
  final UserProfile profile;
  final DailyMacroTargets targets;
  final PetStatusData? pet;
  final BodyMeasurement? latestMeasurement;
  final List<BodyMeasurement> recentMeasurements;
  final FastingSession? activeFast;
  final DailySummary? summary;
  final List<HydrationLog> waterLogs;
  final NutritionTotals nutrition;
  final List<WorkoutBlock> workouts;
  final bool hasJournalToday;

  int get totalWaterMl => waterLogs.fold<int>(0, (int sum, HydrationLog l) => sum + l.volumeMl);
  int get steps => summary?.stepsCount ?? 0;
  double get sleepHours => (summary?.sleepDurationMinutes ?? 0) / 60.0;

  bool get hasSleepBonus =>
      summary != null &&
      RewardPolicy.sleepMultiplier(
            sleepMinutes: summary!.sleepDurationMinutes,
            deepMinutes: summary!.sleepDeepMinutes,
            remMinutes: summary!.sleepRemMinutes,
            sleepGoalHours: profile.dailySleepGoalHours,
          ) >
          1.0;

  double get fastingHours => activeFast == null
      ? 0
      : (now.difference(activeFast!.startedAt).inMinutes / 60.0).clamp(0.0, 999.0);

  /// Fase metabólica del ayuno activo, o `null` sin ayuno en curso.
  MetabolicPhase? get fastingPhase => activeFast == null ? null : MetabolicPhase.forHours(fastingHours);

  /// Hábitos tocados hoy (comida, agua, movimiento, sueño, diario).
  int get activePillars => <bool>[
        nutrition.entries > 0,
        totalWaterMl > 0,
        steps >= 1000 || workouts.isNotEmpty,
        sleepHours > 0,
        hasJournalToday,
      ].where((bool v) => v).length;

  /// Variación del Peso Tendencia en los últimos ~7 días.
  double? get weightTrendDelta7d {
    final List<BodyMeasurement> recent = recentMeasurements;
    if (recent.length < 2) return null;
    final BodyMeasurement latest = recent.last;
    final DateTime cutoff = latest.measuredAt.subtract(const Duration(days: 7));
    final BodyMeasurement baseline = recent.firstWhere(
      (BodyMeasurement m) => !m.measuredAt.isBefore(cutoff),
      orElse: () => recent.first,
    );
    final BodyMeasurement reference =
        identical(baseline, latest) ? recent[recent.length - 2] : baseline;
    return latest.trendWeightKg - reference.trendWeightKg;
  }
}

/// Combina todas las lecturas de Hoy. Está cargando mientras falte el perfil.
final todayOverviewProvider =
    Provider.family<AsyncValue<TodayOverview>, String>((Ref ref, String dateKey) {
  final AsyncValue<UserProfile?> profile = ref.watch(userProfileStreamProvider);
  final DailyMacroTargets? targets = ref.watch(dailyTargetsProvider(dateKey));
  if (profile.hasError) return AsyncValue<TodayOverview>.error(profile.error!, profile.stackTrace!);
  final UserProfile? p = profile.value;
  if (p == null || targets == null) return const AsyncValue<TodayOverview>.loading();

  final List<JournalEntry> journal =
      ref.watch(recentJournalEntriesProvider).value ?? const <JournalEntry>[];
  return AsyncValue<TodayOverview>.data(
    TodayOverview(
      dateKey: dateKey,
      now: ref.watch(clockProvider).now(),
      profile: p,
      targets: targets,
      pet: ref.watch(petStatusStreamProvider).value,
      latestMeasurement: ref.watch(latestMeasurementStreamProvider).value,
      recentMeasurements:
          ref.watch(recentMeasurementsStreamProvider).value ?? const <BodyMeasurement>[],
      activeFast: ref.watch(activeFastingSessionStreamProvider).value,
      summary: ref.watch(dailySummaryProvider(dateKey)).value,
      waterLogs: ref.watch(waterLogsForDateProvider(dateKey)).value ?? const <HydrationLog>[],
      nutrition: NutritionTotals.from(
        ref.watch(foodLogsForDateProvider(dateKey)).value ?? const <FoodLog>[],
      ),
      workouts: ref.watch(workoutsForDateProvider(dateKey)).value ?? const <WorkoutBlock>[],
      hasJournalToday: journal.any((JournalEntry e) => e.dateKey == dateKey),
    ),
  );
});
