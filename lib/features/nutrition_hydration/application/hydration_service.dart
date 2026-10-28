import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock/clock.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/hydration_dao.dart';
import '../../../core/database/daos/user_profile_dao.dart';
import '../../../core/platform/health_connect_gateway.dart';
import '../../../core/platform/native_call.dart';
import '../../pet_gamification/application/reward_service.dart';
import '../../pet_gamification/domain/reward_policy.dart';

class WaterLogResult {
  const WaterLogResult({required this.logId, required this.totalMl, required this.coins});

  final int logId;
  final int totalMl;

  /// Monedas ganadas al alcanzar la meta diaria con este vaso (0 si no aplica).
  final int coins;
}

/// Caso de uso "Vaso de agua en 1 toque" (docs/05 §6): registro atómico,
/// recompensa al cumplir la meta y exportación a Health Connect.
class HydrationService {
  HydrationService(
    this._db,
    this._hydrationDao,
    this._profileDao,
    this._rewards,
    this._healthConnect,
    this._clock,
  );

  final AppDatabase _db;
  final HydrationDao _hydrationDao;
  final UserProfileDao _profileDao;
  final RewardService _rewards;
  final HealthConnectGateway _healthConnect;
  final Clock _clock;

  /// Volumen máximo de una toma (una jarra de 5 l ya es un error de tecleo).
  static const int maxGlassMl = 5000;

  Future<WaterLogResult> logGlass({required String dateKey, required int volumeMl}) async {
    if (volumeMl <= 0 || volumeMl > maxGlassMl) {
      throw ArgumentError.value(volumeMl, 'volumeMl', 'debe estar entre 1 y $maxGlassMl ml');
    }
    final UserProfile? profile = await _profileDao.getProfile();
    final WaterLogResult result = await _db.transaction(() async {
      final int id = await _hydrationDao.insertGlass(dateKey: dateKey, volumeMl: volumeMl);
      final int total = await _hydrationDao.getTotalWaterMl(dateKey);
      int coins = 0;
      if (profile != null && total >= profile.dailyWaterGoalMl) {
        coins = (await _rewards.grant(RewardAction.waterGoal, dateKey: dateKey)).coins;
      }
      return WaterLogResult(logId: id, totalMl: total, coins: coins);
    });

    final bool exported = await bestEffort(
      () => _healthConnect.writeHydration(volumeMl: volumeMl, at: _clock.now()),
      false,
    );
    if (exported) await _hydrationDao.markAsSynced(<int>[result.logId]);
    return result;
  }

  Future<void> deleteGlass(int logId) => _hydrationDao.deleteGlass(logId);

  Future<void> restoreGlass(HydrationLog log) => _hydrationDao.restoreGlass(log);
}

final hydrationServiceProvider = Provider<HydrationService>((Ref ref) {
  return HydrationService(
    ref.watch(appDatabaseProvider),
    ref.watch(hydrationDaoProvider),
    ref.watch(userProfileDaoProvider),
    ref.watch(rewardServiceProvider),
    ref.watch(healthConnectGatewayProvider),
    ref.watch(clockProvider),
  );
});
