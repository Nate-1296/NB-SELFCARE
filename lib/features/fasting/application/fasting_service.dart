import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock/clock.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/fasting_dao.dart';
import '../../../core/database/daos/user_profile_dao.dart';
import '../../../core/platform/notification_gateway.dart';
import '../../../core/services/fasting_dosage_advisor.dart';
import '../../../shared/utils/date_time_extensions.dart';
import '../../pet_gamification/application/reward_service.dart';
import '../../pet_gamification/domain/reward_policy.dart';

class FastFinishResult {
  const FastFinishResult({required this.session, required this.hours, required this.coins});

  final FastingSession session;
  final double hours;
  final int coins;

  /// Ayunos ≥ 18 h muestran la guía de re-alimentación segura (docs/14 Fase 5).
  bool get suggestsRefeedingGuide => hours >= FastingService.refeedingGuideMinHours;
}

/// Casos de uso del cronómetro de ayuno (docs/09).
class FastingService {
  FastingService(this._db, this._fastingDao, this._profileDao, this._rewards, this._notifications,
      this._clock);

  /// Ayuno mínimo que otorga monedas (docs/08 §4).
  static const double rewardMinHours = 14.0;
  static const double refeedingGuideMinHours = 18.0;

  final AppDatabase _db;
  final FastingDao _fastingDao;
  final UserProfileDao _profileDao;
  final RewardService _rewards;
  final NotificationGateway _notifications;
  final Clock _clock;

  /// Seguridad personal (respuestas del onboarding) y dosificación semanal que
  /// limita protocolos agresivos encadenados (docs/14 Fase 5).
  Future<FastingSafetyVerdict> checkSafety(int targetHours) async {
    final UserProfile? profile = await _profileDao.getProfile();
    if (profile != null) {
      final FastingSafetyVerdict personal = FastingDosageAdvisor.evaluatePersonalSafety(
        proposedTargetHours: targetHours,
        hasEatingDisorderHistory: profile.hasEatingDisorderHistory,
        takesHypoglycemicMedication: profile.takesHypoglycemicMedication,
      );
      if (!personal.isSafe) return personal;
    }
    return FastingDosageAdvisor.evaluateProtocolSafety(
      proposedTargetHours: targetHours,
      recentSessions: await _fastingDao.getRecentSessions(limit: 10),
      now: _clock.now(),
    );
  }

  Future<int> start({
    required String protocolName,
    required int targetHours,
    DateTime? startedAt,
  }) async {
    final DateTime start = startedAt ?? _clock.now();
    final int id = await _fastingDao.startFast(
      protocolName: protocolName,
      targetHours: targetHours,
      startedAt: start,
    );
    await _notifications.showFastingTimer(
      startedAt: start,
      targetHours: targetHours,
      protocol: protocolName,
    );
    return id;
  }

  /// Alinea la notificación del cronómetro con la base de datos (arranque de la
  /// app, restauración de un respaldo, sesión editada desde otra pantalla).
  Future<void> reconcileTimerNotification() async {
    final FastingSession? active = await _fastingDao.getActiveSession();
    if (active == null) {
      await _notifications.cancelFastingTimer();
    } else {
      await _notifications.showFastingTimer(
        startedAt: active.startedAt,
        targetHours: active.targetHours,
        protocol: active.protocolName,
      );
    }
  }

  Future<FastFinishResult?> finish(int sessionId) async {
    final FastFinishResult? result = await _db.transaction(() async {
      final FastingSession? closed =
          await _fastingDao.endFast(sessionId: sessionId, notes: 'Sesión registrada.');
      if (closed == null) return null;

      final DateTime end = closed.actualEndedAt ?? _clock.now();
      final double hours = end.difference(closed.startedAt).inMinutes / 60.0;
      int coins = 0;
      if (hours >= rewardMinHours) {
        coins = (await _rewards.grant(RewardAction.fastDone, dateKey: end.dateKey)).coins;
      }
      return FastFinishResult(session: closed, hours: hours, coins: coins);
    });
    await _notifications.cancelFastingTimer();
    return result;
  }

  Future<bool> adjustStart({required int sessionId, required DateTime newStartedAt}) async {
    final bool updated =
        await _fastingDao.updateActiveFastStart(sessionId: sessionId, newStartedAt: newStartedAt);
    if (updated) await reconcileTimerNotification();
    return updated;
  }

  Future<void> delete(int sessionId) async {
    await _fastingDao.deleteSession(sessionId);
    await reconcileTimerNotification();
  }

  Future<void> restore(FastingSession session) async {
    await _fastingDao.restoreSession(session);
    await reconcileTimerNotification();
  }
}

final fastingServiceProvider = Provider<FastingService>((Ref ref) {
  return FastingService(
    ref.watch(appDatabaseProvider),
    ref.watch(fastingDaoProvider),
    ref.watch(userProfileDaoProvider),
    ref.watch(rewardServiceProvider),
    ref.watch(notificationGatewayProvider),
    ref.watch(clockProvider),
  );
});
