import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock/clock.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/health_sync_dao.dart';
import '../../../core/database/daos/user_profile_dao.dart';
import '../../../core/domain/activity_energy.dart';
import '../../../core/platform/health_connect_gateway.dart';
import '../../../shared/utils/date_time_extensions.dart';
import '../../pet_gamification/application/reward_service.dart';
import '../../pet_gamification/domain/reward_policy.dart';

/// Resultado de sincronizar un día con Health Connect.
enum HealthSyncOutcome { synced, noData, notConnected }

class HealthSyncResult {
  const HealthSyncResult(this.outcome, [this.snapshot]);

  final HealthSyncOutcome outcome;
  final DailyActivitySnapshot? snapshot;
}

/// Trae sueño (con fases), pasos y FC en reposo desde Health Connect al resumen
/// diario local. Es la fuente del multiplicador de sueño, el Readiness Score,
/// el NEAT y las correlaciones de sueño.
class HealthSyncService {
  HealthSyncService(this._db, this._gateway, this._healthSyncDao, this._profileDao, this._rewards,
      this._clock);

  final AppDatabase _db;
  final HealthConnectGateway _gateway;
  final HealthSyncDao _healthSyncDao;
  final UserProfileDao _profileDao;
  final RewardService _rewards;
  final Clock _clock;

  /// Sincroniza hoy y ayer (el sueño de anoche puede terminar de escribirse tarde).
  Future<HealthSyncOutcome> syncRecentDays() async {
    final DateTime now = _clock.now();
    final HealthSyncResult today = await syncDay(now.dateKey);
    if (today.outcome == HealthSyncOutcome.notConnected) return today.outcome;
    await syncDay(now.subtract(const Duration(days: 1)).dateKey);
    return today.outcome;
  }

  Future<HealthSyncResult> syncDay(String dateKey) async {
    // Cada tipo de dato depende de su propio permiso: si el usuario concedió solo
    // algunos, el puente devuelve `null` en el resto en vez de fallar.
    if (await _gateway.availability() != HealthConnectAvailability.available) {
      return const HealthSyncResult(HealthSyncOutcome.notConnected);
    }
    final DailyActivitySnapshot? snapshot = await _gateway.readDailyActivity(dateKey);
    if (snapshot == null) return const HealthSyncResult(HealthSyncOutcome.notConnected);
    if (snapshot.isEmpty) return HealthSyncResult(HealthSyncOutcome.noData, snapshot);

    await _db.transaction(() async {
      final int? steps = snapshot.steps;
      final int? sleep = snapshot.sleepMinutes;
      await _healthSyncDao.upsertDailySummary(
        DailySummariesCompanion(
          dateKey: Value(dateKey),
          stepsCount: steps == null ? const Value.absent() : Value(steps),
          activeCaloriesFromSteps: steps == null
              ? const Value.absent()
              : Value(ActivityEnergy.kcalFromSteps(steps)),
          sleepDurationMinutes: sleep == null ? const Value.absent() : Value(sleep),
          sleepDeepMinutes: sleep == null ? const Value.absent() : Value(snapshot.deepSleepMinutes),
          sleepRemMinutes: sleep == null ? const Value.absent() : Value(snapshot.remSleepMinutes),
          restingHeartRateBpm: snapshot.restingHeartRateBpm == null
              ? const Value.absent()
              : Value(snapshot.restingHeartRateBpm),
        ),
      );

      if (sleep != null) {
        final UserProfile? profile = await _profileDao.getProfile();
        final double multiplier = RewardPolicy.sleepMultiplier(
          sleepMinutes: sleep,
          deepMinutes: snapshot.deepSleepMinutes,
          remMinutes: snapshot.remSleepMinutes,
          sleepGoalHours: profile?.dailySleepGoalHours ?? 7.5,
        );
        if (multiplier > 1.0) {
          await _rewards.grant(RewardAction.restorativeSleep, dateKey: dateKey);
        }
      }
      await _healthSyncDao.updateCheckpoint(
        recordType: 'daily_activity',
        timestamp: _clock.now(),
        readCount: 1,
      );
    });
    return HealthSyncResult(HealthSyncOutcome.synced, snapshot);
  }
}

final healthSyncServiceProvider = Provider<HealthSyncService>((Ref ref) {
  return HealthSyncService(
    ref.watch(appDatabaseProvider),
    ref.watch(healthConnectGatewayProvider),
    ref.watch(healthSyncDaoProvider),
    ref.watch(userProfileDaoProvider),
    ref.watch(rewardServiceProvider),
    ref.watch(clockProvider),
  );
});
