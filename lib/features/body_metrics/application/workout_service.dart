import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock/clock.dart';
import '../../../core/constants/met_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/body_measurements_dao.dart';
import '../../../core/database/daos/user_profile_dao.dart';
import '../../../core/database/daos/workout_dao.dart';
import '../../../core/domain/enums.dart';
import '../../../shared/utils/date_time_extensions.dart';
import '../../pet_gamification/application/reward_service.dart';
import '../../pet_gamification/domain/reward_policy.dart';

/// Estimación previa al registro (para mostrarla en la hoja de 5 segundos).
class WorkoutEstimate {
  const WorkoutEstimate({required this.met, required this.netKcal, required this.weightKg});

  final double met;
  final int netKcal;
  final double weightKg;
}

class WorkoutLogResult {
  const WorkoutLogResult({required this.workoutId, required this.netKcal, required this.reward});

  final int workoutId;
  final int netKcal;
  final RewardGrant reward;
}

/// Caso de uso "Bloque de entrenamiento en 5 segundos" (ADR-01, docs/06).
class WorkoutService {
  WorkoutService(this._db, this._workoutDao, this._measurementsDao, this._profileDao, this._rewards,
      this._clock);

  final AppDatabase _db;
  final WorkoutDao _workoutDao;
  final BodyMeasurementsDao _measurementsDao;
  final UserProfileDao _profileDao;
  final RewardService _rewards;
  final Clock _clock;

  /// Usa el último peso real de la báscula; sin pesajes, el peso meta del perfil.
  static WorkoutEstimate estimate({
    required WorkoutCategory category,
    required RpeIntensity intensity,
    required int durationMinutes,
    required double weightKg,
  }) {
    final double met = MetConstants.getMet(category, intensity);
    return WorkoutEstimate(
      met: met,
      weightKg: weightKg,
      netKcal: MetConstants.calculateNetCalories(
        met: met,
        userWeightKg: weightKg,
        durationMinutes: durationMinutes,
      ),
    );
  }

  Future<void> delete(int workoutId) => _workoutDao.deleteWorkout(workoutId);

  Future<void> restore(WorkoutBlock block) => _workoutDao.restoreWorkout(block);

  Future<WorkoutLogResult> log({
    required WorkoutCategory category,
    required RpeIntensity intensity,
    required int durationMinutes,
  }) async {
    final BodyMeasurement? latest = await _measurementsDao.getLatestWeighIn();
    final UserProfile? profile = await _profileDao.getProfile();
    final double weightKg = latest?.weightKg ?? profile?.targetWeightKg ?? 70.0;
    final WorkoutEstimate e = estimate(
      category: category,
      intensity: intensity,
      durationMinutes: durationMinutes,
      weightKg: weightKg,
    );
    final DateTime now = _clock.now();

    return _db.transaction(() async {
      final int id = await _workoutDao.insertWorkout(
        WorkoutBlocksCompanion.insert(
          dateKey: now.dateKey,
          performedAt: Value(now),
          category: category,
          durationMinutes: durationMinutes,
          rpeIntensity: intensity,
          appliedMet: e.met,
          userWeightAtTimeKg: weightKg,
          netCaloriesBurned: e.netKcal,
        ),
      );
      final RewardGrant reward =
          await _rewards.grant(RewardAction.workoutDone, dateKey: now.dateKey);
      return WorkoutLogResult(workoutId: id, netKcal: e.netKcal, reward: reward);
    });
  }
}

final workoutServiceProvider = Provider<WorkoutService>((Ref ref) {
  return WorkoutService(
    ref.watch(appDatabaseProvider),
    ref.watch(workoutDaoProvider),
    ref.watch(bodyMeasurementsDaoProvider),
    ref.watch(userProfileDaoProvider),
    ref.watch(rewardServiceProvider),
    ref.watch(clockProvider),
  );
});
