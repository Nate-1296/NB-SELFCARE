import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/health_sync_dao.dart';
import '../../../core/database/daos/user_profile_dao.dart';
import '../../../core/database/daos/workout_dao.dart';
import '../../../core/services/readiness_engine.dart';
import '../../../shared/utils/date_time_extensions.dart';
import '../../profile_goals/application/profile_queries.dart';

/// Días previos que forman la línea base de FC en reposo.
const int readinessBaselineDays = 14;

/// Lecturas mínimas de FC previas para comparar contra una línea base.
const int readinessMinBaselineSamples = 3;

/// Ventana de carga de entrenamiento considerada por el motor.
const int readinessStrainDays = 3;

/// Rango de fechas (inclusive) que necesita la disposición de [dateKey].
({String from, String to}) readinessWindow(String dateKey) => (
  from: DateTime.parse(dateKey).subtract(const Duration(days: readinessBaselineDays)).dateKey,
  to: dateKey,
);

/// Evalúa la disposición del día con datos reales. Devuelve `null` mientras no
/// haya sueño registrado para ese día: sin él no hay puntuación honesta.
DailyReadinessResult? evaluateReadiness({
  required ReadinessEngine engine,
  required String dateKey,
  required double targetSleepHours,
  required List<DailySummary> summaries,
  required List<WorkoutBlock> workouts,
}) {
  DailySummary? today;
  final List<int> baselineRhr = <int>[];
  for (final DailySummary s in summaries) {
    if (s.dateKey == dateKey) {
      today = s;
    } else if (s.dateKey.compareTo(dateKey) < 0 && (s.restingHeartRateBpm ?? 0) > 0) {
      baselineRhr.add(s.restingHeartRateBpm!);
    }
  }
  if (today == null || today.sleepDurationMinutes <= 0) return null;

  final String strainFrom = DateTime.parse(dateKey)
      .subtract(const Duration(days: readinessStrainDays - 1))
      .dateKey;
  int strainMinutes = 0;
  double weightedRpe = 0;
  for (final WorkoutBlock w in workouts) {
    if (w.dateKey.compareTo(strainFrom) < 0 || w.dateKey.compareTo(dateKey) > 0) continue;
    strainMinutes += w.durationMinutes;
    weightedRpe += w.rpeIntensity.representativeRpe * w.durationMinutes;
  }

  final int? currentRhr = today.restingHeartRateBpm;
  return engine.compute(
    actualSleepHours: today.sleepDurationMinutes / 60.0,
    targetSleepHours: targetSleepHours,
    deepSleepMinutes: today.sleepDeepMinutes > 0 ? today.sleepDeepMinutes.toDouble() : null,
    currentRhrBpm: currentRhr != null && currentRhr > 0 ? currentRhr : null,
    baselineRhrBpm: baselineRhr.length >= readinessMinBaselineSamples
        ? (baselineRhr.reduce((int a, int b) => a + b) / baselineRhr.length).round()
        : null,
    recent3DayWorkoutHours: strainMinutes / 60.0,
    averageRecentRpe: strainMinutes > 0 ? weightedRpe / strainMinutes : 0,
  );
}

final _readinessSummariesProvider = StreamProvider.family<List<DailySummary>, String>((
  Ref ref,
  String dateKey,
) {
  final ({String from, String to}) window = readinessWindow(dateKey);
  return ref.watch(healthSyncDaoProvider).watchSummariesBetween(window.from, window.to);
});

final _readinessWorkoutsProvider = StreamProvider.family<List<WorkoutBlock>, String>((
  Ref ref,
  String dateKey,
) {
  final ({String from, String to}) window = readinessWindow(dateKey);
  return ref.watch(workoutDaoProvider).watchWorkoutsBetween(window.from, window.to);
});

/// Disposición reactiva del día; `data(null)` si falta el sueño de esa noche.
final readinessProvider = Provider.family<AsyncValue<DailyReadinessResult?>, String>((
  Ref ref,
  String dateKey,
) {
  final AsyncValue<List<DailySummary>> summaries = ref.watch(_readinessSummariesProvider(dateKey));
  final AsyncValue<List<WorkoutBlock>> workouts = ref.watch(_readinessWorkoutsProvider(dateKey));
  final AsyncValue<UserProfile?> profile = ref.watch(userProfileStreamProvider);
  if (summaries.hasError) {
    return AsyncValue<DailyReadinessResult?>.error(summaries.error!, summaries.stackTrace!);
  }
  if (workouts.hasError) {
    return AsyncValue<DailyReadinessResult?>.error(workouts.error!, workouts.stackTrace!);
  }
  final List<DailySummary>? s = summaries.value;
  final List<WorkoutBlock>? w = workouts.value;
  final UserProfile? p = profile.value;
  if (s == null || w == null || p == null) return const AsyncValue<DailyReadinessResult?>.loading();
  return AsyncValue<DailyReadinessResult?>.data(
    evaluateReadiness(
      engine: ref.watch(readinessEngineProvider),
      dateKey: dateKey,
      targetSleepHours: p.dailySleepGoalHours,
      summaries: s,
      workouts: w,
    ),
  );
});

/// Lectura puntual para informes (PDF clínico).
class ReadinessReader {
  ReadinessReader(this._ref);

  final Ref _ref;

  Future<DailyReadinessResult?> forDate(String dateKey) async {
    final ({String from, String to}) window = readinessWindow(dateKey);
    final UserProfile? profile = await _ref.read(userProfileDaoProvider).getProfile();
    return evaluateReadiness(
      engine: _ref.read(readinessEngineProvider),
      dateKey: dateKey,
      targetSleepHours: profile?.dailySleepGoalHours ?? 7.5,
      summaries: await _ref.read(healthSyncDaoProvider).getSummariesBetween(window.from, window.to),
      workouts: await _ref.read(workoutDaoProvider).getWorkoutsBetween(window.from, window.to),
    );
  }
}

final readinessReaderProvider = Provider<ReadinessReader>(ReadinessReader.new);
