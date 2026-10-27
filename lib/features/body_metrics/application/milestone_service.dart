import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock/clock.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/milestone_dao.dart';
import '../../../shared/utils/date_time_extensions.dart';
import '../../pet_gamification/application/reward_service.dart';
import '../../pet_gamification/domain/reward_policy.dart';

/// Mini-hitos psicológicos de 1,5 kg (estilo Happy Scale, docs/14 Fase 7).
class MilestoneService {
  MilestoneService(this._db, this._milestoneDao, this._rewards, this._clock);

  /// Margen para dar por alcanzado el último hito cuando ya no queda dirección que inferir.
  static const double arrivalToleranceKg = 0.25;

  final AppDatabase _db;
  final MilestoneDao _milestoneDao;
  final RewardService _rewards;
  final Clock _clock;

  Future<void> regenerate({required double currentWeightKg, required double targetWeightKg}) {
    return _milestoneDao.generateMilestones(
      currentWeightKg: currentWeightKg,
      targetWeightKg: targetWeightKg,
    );
  }

  /// Marca como logrados los hitos que el Peso Tendencia ya alcanzó y otorga la
  /// recompensa. Usa la tendencia (no el peso del día) para no celebrar ni
  /// "perder" hitos por fluctuaciones de agua.
  Future<List<MilestoneGoal>> checkProgress({required double trendWeightKg}) {
    return _db.transaction(() async {
      final List<MilestoneGoal> pending =
          (await _milestoneDao.getMilestones()).where((MilestoneGoal m) => !m.isCompleted).toList();
      if (pending.isEmpty) return const <MilestoneGoal>[];

      final List<MilestoneGoal> reached =
          pending.where((MilestoneGoal m) => _isReached(m, pending, trendWeightKg)).toList();
      if (reached.isEmpty) return const <MilestoneGoal>[];

      final DateTime now = _clock.now();
      for (final MilestoneGoal m in reached) {
        await _milestoneDao.markCompleted(m.id, now);
      }
      await _rewards.grant(RewardAction.milestoneReached, dateKey: now.dateKey);
      return reached;
    });
  }
}

/// Los hitos se generan en orden desde el peso inicial hacia la meta; la
/// dirección (bajar o subir) se deduce de ese orden.
bool _isReached(MilestoneGoal milestone, List<MilestoneGoal> pending, double trendWeightKg) {
  if (pending.length < 2) {
    return (trendWeightKg - milestone.targetWeightKg).abs() <= MilestoneService.arrivalToleranceKg;
  }
  final bool isLosing = pending[0].targetWeightKg > pending[1].targetWeightKg;
  return isLosing
      ? trendWeightKg <= milestone.targetWeightKg
      : trendWeightKg >= milestone.targetWeightKg;
}

final milestoneServiceProvider = Provider<MilestoneService>((Ref ref) {
  return MilestoneService(
    ref.watch(appDatabaseProvider),
    ref.watch(milestoneDaoProvider),
    ref.watch(rewardServiceProvider),
    ref.watch(clockProvider),
  );
});
