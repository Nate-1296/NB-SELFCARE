import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/health_sync_dao.dart';
import '../../../core/database/daos/user_profile_dao.dart';
import '../../../core/domain/activity_energy.dart';
import '../../pet_gamification/application/reward_service.dart';
import '../../pet_gamification/domain/reward_policy.dart';

/// Registro manual de sueño y pasos cuando Health Connect no aporta datos
/// (degradación elegante, docs/01 §2 #7).
class DailyActivityService {
  DailyActivityService(this._db, this._healthSyncDao, this._profileDao, this._rewards);

  /// Gasto activo aproximado por paso para la estimación NEAT manual.

  final AppDatabase _db;
  final HealthSyncDao _healthSyncDao;
  final UserProfileDao _profileDao;
  final RewardService _rewards;

  /// Fija los pasos del día (atajo "+1000 pasos" y su Deshacer).
  Future<void> setSteps({required String dateKey, required int steps}) {
    final int safeSteps = steps.clamp(0, 100000);
    return _healthSyncDao.upsertDailySummary(
      DailySummariesCompanion(
        dateKey: Value(dateKey),
        stepsCount: Value(safeSteps),
        activeCaloriesFromSteps: Value(ActivityEnergy.kcalFromSteps(safeSteps)),
      ),
    );
  }

  /// Guarda pasos y horas de sueño declarados por el usuario. Las fases de
  /// sueño (REM/profundo) no se inventan: solo Health Connect puede aportarlas.
  Future<int> saveManualEntry({
    required String dateKey,
    required int steps,
    required int sleepMinutes,
  }) {
    return _db.transaction(() async {
      await _healthSyncDao.upsertDailySummary(
        DailySummariesCompanion(
          dateKey: Value(dateKey),
          stepsCount: Value(steps),
          activeCaloriesFromSteps: Value(ActivityEnergy.kcalFromSteps(steps)),
          sleepDurationMinutes: Value(sleepMinutes),
          sleepDeepMinutes: const Value(0),
          sleepRemMinutes: const Value(0),
        ),
      );

      final UserProfile? profile = await _profileDao.getProfile();
      final double goalHours = profile?.dailySleepGoalHours ?? 7.5;
      if (sleepMinutes < (goalHours * 60).round()) return 0;
      return (await _rewards.grant(RewardAction.restorativeSleep, dateKey: dateKey)).coins;
    });
  }
}

final dailyActivityServiceProvider = Provider<DailyActivityService>((Ref ref) {
  return DailyActivityService(
    ref.watch(appDatabaseProvider),
    ref.watch(healthSyncDaoProvider),
    ref.watch(userProfileDaoProvider),
    ref.watch(rewardServiceProvider),
  );
});
