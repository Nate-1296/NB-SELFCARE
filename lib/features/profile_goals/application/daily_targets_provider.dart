import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock/clock.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/workout_dao.dart';
import '../../../shared/utils/cycle_phase_calculator.dart';
import '../../../shared/utils/daily_targets_calculator.dart';
import '../../body_metrics/application/body_queries.dart';
import 'profile_queries.dart';

/// Gasto neto de los entrenamientos registrados en un día.
final netWorkoutKcalProvider = StreamProvider.family<int, String>((Ref ref, String dateKey) {
  return ref.watch(workoutDaoProvider).watchNetCaloriesForDate(dateKey);
});

/// Metas calóricas, de macros y electrolitos de [dateKey], idénticas en Hoy,
/// Nutrición y Perfil. Combina perfil, Peso Tendencia, ejercicio del día y la
/// compensación lútea cuando el seguimiento del ciclo está activo.
///
/// Devuelve `null` mientras el perfil no esté disponible.
final dailyTargetsProvider =
    Provider.family<DailyMacroTargets?, String>((Ref ref, String dateKey) {
  final UserProfile? profile = ref.watch(userProfileStreamProvider).value;
  if (profile == null) return null;

  final DateTime date = DateTime.tryParse(dateKey) ?? ref.watch(clockProvider).now();
  final BodyMeasurement? latest = ref.watch(latestMeasurementStreamProvider).value;
  final int netWorkoutKcal = ref.watch(netWorkoutKcalProvider(dateKey)).value ?? 0;

  int lutealSurgeKcal = 0;
  if (profile.biologicalSex.isFemale && profile.isCycleTrackingEnabled) {
    final FemaleCycleLog? cycle = ref.watch(latestFemaleCycleStreamProvider).value;
    if (cycle != null) {
      lutealSurgeKcal = CyclePhaseCalculator.phaseFor(
        cycleStart: cycle.cycleStartDate,
        cycleLengthDays: cycle.cycleLengthDays,
        date: date,
      ).recommendedCaloricSurgeKcal;
    }
  }

  return DailyTargetsCalculator.compute(
    profile: profile,
    now: date,
    currentWeightKg: latest?.trendWeightKg,
    netWorkoutKcal: netWorkoutKcal,
    lutealCaloricSurgeKcal: lutealSurgeKcal,
  );
});
