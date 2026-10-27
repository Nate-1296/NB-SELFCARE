import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/food_dao.dart';
import '../../../core/database/daos/workout_dao.dart';
import '../../../core/domain/enums.dart';
import '../../../core/services/calorie_cycling_service.dart';
import '../../../shared/utils/daily_targets_calculator.dart';
import '../../../shared/utils/date_time_extensions.dart';
import '../../profile_goals/application/daily_targets_provider.dart';
import '../../profile_goals/application/profile_queries.dart';
import '../domain/nutrient_totals.dart';
import 'nutrition_queries.dart';

/// Todo lo que muestra la pestaña Comida para una fecha.
class NutritionDay {
  const NutritionDay({
    required this.dateKey,
    required this.entries,
    required this.totals,
    required this.targets,
    required this.netWorkoutKcal,
    required this.waterLogs,
    required this.waterGoalMl,
  });

  final String dateKey;
  final List<FoodLogWithItem> entries;
  final NutrientTotals totals;
  final DailyMacroTargets targets;
  final int netWorkoutKcal;
  final List<HydrationLog> waterLogs;
  final int waterGoalMl;

  List<FoodLogWithItem> entriesFor(MealType meal) =>
      entries.where((FoodLogWithItem e) => e.log.mealType == meal).toList();

  int get totalWaterMl => waterLogs.fold<int>(0, (int acc, HydrationLog l) => acc + l.volumeMl);
}

final _foodEntriesProvider =
    StreamProvider.family<List<FoodLogWithItem>, String>((Ref ref, String dateKey) {
  return ref.watch(foodDaoProvider).watchLogsWithItemForDate(dateKey);
});

final _netWorkoutKcalProvider = StreamProvider.family<int, String>((Ref ref, String dateKey) {
  return ref.watch(workoutDaoProvider).watchNetCaloriesForDate(dateKey);
});

/// Día de nutrición reactivo; cargando mientras falten el perfil o las metas.
final nutritionDayProvider =
    Provider.family<AsyncValue<NutritionDay>, String>((Ref ref, String dateKey) {
  final AsyncValue<List<FoodLogWithItem>> entries = ref.watch(_foodEntriesProvider(dateKey));
  final DailyMacroTargets? targets = ref.watch(dailyTargetsProvider(dateKey));
  final UserProfile? profile = ref.watch(userProfileStreamProvider).value;
  if (entries.hasError) return AsyncValue<NutritionDay>.error(entries.error!, entries.stackTrace!);
  final List<FoodLogWithItem>? list = entries.value;
  if (list == null || targets == null || profile == null) {
    return const AsyncValue<NutritionDay>.loading();
  }
  return AsyncValue<NutritionDay>.data(
    NutritionDay(
      dateKey: dateKey,
      entries: list,
      totals: NutrientTotals.of(list),
      targets: targets,
      netWorkoutKcal: ref.watch(_netWorkoutKcalProvider(dateKey)).value ?? 0,
      waterLogs: ref.watch(waterLogsForDateProvider(dateKey)).value ?? const <HydrationLog>[],
      waterGoalMl: profile.dailyWaterGoalMl,
    ),
  );
});

/// Lunes de la semana de [date].
DateTime mondayOf(DateTime date) =>
    DateTime(date.year, date.month, date.day).subtract(Duration(days: date.weekday - 1));

/// Días con comidas registradas en la semana (lunes–domingo) que contiene [dateKey].
final loggedDaysInWeekProvider =
    StreamProvider.family<Set<String>, String>((Ref ref, String dateKey) {
  final DateTime monday = mondayOf(DateTime.parse(dateKey));
  return ref
      .watch(foodDaoProvider)
      .watchLoggedDateKeysInRange(monday.dateKey, monday.add(const Duration(days: 6)).dateKey);
});

final _weekKcalProvider = StreamProvider.family<Map<String, int>, String>((Ref ref, String dateKey) {
  final DateTime monday = mondayOf(DateTime.parse(dateKey));
  return ref.watch(foodDaoProvider).watchDailyKcalInRange(monday.dateKey, dateKey);
});

/// Banco semanal: compara lo comido con la meta en los días ya cerrados
/// (lunes hasta el día anterior a [dateKey]) que tienen registros.
final weeklyCalorieBankProvider =
    Provider.family<AsyncValue<WeeklyCalorieBank>, String>((Ref ref, String dateKey) {
  final AsyncValue<Map<String, int>> week = ref.watch(_weekKcalProvider(dateKey));
  final DailyMacroTargets? targets = ref.watch(dailyTargetsProvider(dateKey));
  final UserProfile? profile = ref.watch(userProfileStreamProvider).value;
  if (week.hasError) return AsyncValue<WeeklyCalorieBank>.error(week.error!, week.stackTrace!);
  final Map<String, int>? kcalByDay = week.value;
  if (kcalByDay == null || targets == null || profile == null) {
    return const AsyncValue<WeeklyCalorieBank>.loading();
  }
  final Map<String, int> closedDays = Map<String, int>.of(kcalByDay)..remove(dateKey);
  final bool weekendBuffer = profile.calorieCyclingScheduleJson.contains('weekendBuffer');
  return AsyncValue<WeeklyCalorieBank>.data(
    ref.watch(calorieCyclingServiceProvider).computeWeeklyBank(
          baseDailyKcal: targets.baseTdeeKcal + targets.goalAdjustmentKcal,
          today: DateTime.parse(dateKey),
          caloriesLoggedByDateKey: closedDays,
          mode: weekendBuffer ? CalorieCyclingMode.weekendBuffer : CalorieCyclingMode.flat,
        ),
  );
});
