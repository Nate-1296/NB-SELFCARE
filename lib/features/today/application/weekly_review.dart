import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/body_measurements_dao.dart';
import '../../../core/database/daos/food_dao.dart';
import '../../../core/database/daos/health_sync_dao.dart';
import '../../../core/database/daos/workout_dao.dart';
import '../../../shared/utils/date_time_extensions.dart';

/// Resumen de los últimos 7 días (incluido [WeeklyReview.toDateKey]) para el check-in dominical.
class WeeklyReview {
  const WeeklyReview({
    required this.averageKcal,
    required this.workoutCount,
    required this.averageSleepHours,
    required this.trendWeightDeltaKg,
  });

  /// Media de kcal en los días con comidas registradas (0 si no hay).
  final int averageKcal;
  final int workoutCount;

  /// Media de sueño en las noches registradas (0 si no hay).
  final double averageSleepHours;

  /// Peso Tendencia último − primero de la semana; `null` con menos de 2 pesajes.
  final double? trendWeightDeltaKg;
}

class WeeklyReviewReader {
  WeeklyReviewReader(this._ref);

  final Ref _ref;

  Future<WeeklyReview> forWeekEnding(String toDateKey) async {
    final DateTime end = DateTime.parse(toDateKey);
    final String fromDateKey = end.subtract(const Duration(days: 6)).dateKey;

    double totalKcal = 0;
    int daysWithFood = 0;
    for (int i = 0; i < 7; i++) {
      final List<FoodLog> foods = await _ref
          .read(foodDaoProvider)
          .getLogsForDate(end.subtract(Duration(days: i)).dateKey);
      if (foods.isEmpty) continue;
      totalKcal += foods.fold<double>(0, (double sum, FoodLog f) => sum + f.totalKcal);
      daysWithFood++;
    }

    final List<WorkoutBlock> workouts = await _ref
        .read(workoutDaoProvider)
        .getWorkoutsBetween(fromDateKey, toDateKey);
    final List<int> sleep =
        (await _ref.read(healthSyncDaoProvider).getSummariesBetween(fromDateKey, toDateKey))
            .map((DailySummary s) => s.sleepDurationMinutes)
            .where((int m) => m > 0)
            .toList();
    final List<BodyMeasurement> weighIns = await _ref
        .read(bodyMeasurementsDaoProvider)
        .getMeasurementsInDateRange(fromDateKey, toDateKey);

    return WeeklyReview(
      averageKcal: daysWithFood > 0 ? (totalKcal / daysWithFood).round() : 0,
      workoutCount: workouts.length,
      averageSleepHours: sleep.isEmpty
          ? 0
          : sleep.reduce((int a, int b) => a + b) / sleep.length / 60.0,
      trendWeightDeltaKg: weighIns.length >= 2
          ? weighIns.last.trendWeightKg - weighIns.first.trendWeightKg
          : null,
    );
  }
}

final weeklyReviewReaderProvider = Provider<WeeklyReviewReader>(WeeklyReviewReader.new);

/// Resumen semanal que termina en la fecha dada.
final weeklyReviewProvider = FutureProvider.autoDispose.family<WeeklyReview, String>((
  Ref ref,
  String toDateKey,
) {
  return ref.watch(weeklyReviewReaderProvider).forWeekEnding(toDateKey);
});
