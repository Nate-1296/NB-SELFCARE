import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/health_sync_dao.dart';
import '../../../core/database/daos/pet_dao.dart';
import '../../../core/database/daos/user_profile_dao.dart';
import '../domain/reward_policy.dart';

/// Resultado de intentar otorgar una recompensa.
class RewardGrant {
  const RewardGrant({required this.granted, required this.coins, required this.multiplier});

  const RewardGrant.alreadyClaimed() : this(granted: false, coins: 0, multiplier: 1.0);

  final bool granted;
  final int coins;
  final double multiplier;
}

/// Punto único para otorgar monedas: aplica [RewardPolicy] (montos y
/// multiplicador de sueño del día) y persiste vía [PetDao].
class RewardService {
  RewardService(this._petDao, this._healthSyncDao, this._profileDao);

  final PetDao _petDao;
  final HealthSyncDao _healthSyncDao;
  final UserProfileDao _profileDao;

  Future<RewardGrant> grant(RewardAction action, {required String dateKey}) async {
    final double multiplier = await _sleepMultiplierFor(dateKey);
    final int coins = RewardPolicy.amountFor(action, multiplier);
    final bool granted = await _petDao.recordReward(
      dateKey: dateKey,
      ledgerKey: action.ledgerKey,
      amount: coins,
      multiplierApplied: multiplier,
    );
    return granted
        ? RewardGrant(granted: true, coins: coins, multiplier: multiplier)
        : const RewardGrant.alreadyClaimed();
  }

  Future<double> _sleepMultiplierFor(String dateKey) async {
    final DailySummary? summary = await _healthSyncDao.getSummaryForDate(dateKey);
    if (summary == null) return 1.0;
    final UserProfile? profile = await _profileDao.getProfile();
    return RewardPolicy.sleepMultiplier(
      sleepMinutes: summary.sleepDurationMinutes,
      deepMinutes: summary.sleepDeepMinutes,
      remMinutes: summary.sleepRemMinutes,
      sleepGoalHours: profile?.dailySleepGoalHours ?? 7.5,
    );
  }
}

final rewardServiceProvider = Provider<RewardService>((Ref ref) {
  return RewardService(
    ref.watch(petDaoProvider),
    ref.watch(healthSyncDaoProvider),
    ref.watch(userProfileDaoProvider),
  );
});
