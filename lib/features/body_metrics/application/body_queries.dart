import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/body_measurements_dao.dart';
import '../../../core/database/daos/female_cycle_dao.dart';
import '../../../core/database/daos/milestone_dao.dart';
import '../../../core/database/daos/workout_dao.dart';

/// Consultas reactivas de lectura para la capa de presentación.

/// StreamProvider que expone reactivamente el último ciclo ovárico registrado.
final latestFemaleCycleStreamProvider = StreamProvider<FemaleCycleLog?>((ref) {
  final FemaleCycleDao dao = ref.watch(femaleCycleDaoProvider);
  return dao.watchLatestCycle();
});

/// StreamProvider con la última medición registrada.
final latestMeasurementStreamProvider = StreamProvider<BodyMeasurement?>((ref) {
  final BodyMeasurementsDao dao = ref.watch(bodyMeasurementsDaoProvider);
  return dao.watchLatestMeasurement();
});

/// StreamProvider con el historial temporal de mediciones corporales para gráficas y tendencias.
final recentMeasurementsStreamProvider =
    StreamProvider.autoDispose<List<BodyMeasurement>>((ref) {
  final BodyMeasurementsDao dao = ref.watch(bodyMeasurementsDaoProvider);
  return dao.watchRecentMeasurements(limit: 90);
});

/// Bloques de entrenamiento registrados en un día.
final workoutsForDateProvider =
    StreamProvider.family<List<WorkoutBlock>, String>((Ref ref, String dateKey) {
  return ref.watch(workoutDaoProvider).watchWorkoutsForDate(dateKey);
});

/// Mini-metas de peso generadas para el camino hacia la meta.
final milestonesProvider = StreamProvider<List<MilestoneGoal>>((Ref ref) {
  return ref.watch(milestoneDaoProvider).watchMilestones();
});
