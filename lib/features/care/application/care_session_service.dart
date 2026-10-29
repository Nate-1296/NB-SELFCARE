import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock/clock.dart';
import '../../../core/database/daos/care_dao.dart';
import '../../../core/platform/health_connect_gateway.dart';
import '../../../core/platform/native_call.dart';
import '../../../shared/utils/date_time_extensions.dart';
import '../../pet_gamification/application/reward_service.dart';
import '../../pet_gamification/domain/reward_policy.dart';

/// Tipos de sesión guiada que se guardan en `care_sessions`.
enum CareSessionKind {
  pelvicFloor('pelvic_floor'),
  activeBreak('active_break'),
  breathing('breathing');

  const CareSessionKind(this.key);

  final String key;
}

/// Cierra una sesión guiada: la guarda, da las monedas del día y, si es de
/// respiración, la comparte con Health Connect (en el teléfono, nunca en la nube).
class CareSessionService {
  CareSessionService(this._dao, this._rewards, this._health, this._clock);

  final CareDao _dao;
  final RewardService _rewards;
  final HealthConnectGateway _health;
  final Clock _clock;

  /// Una sesión de menos de [minimumSeconds] no cuenta (se cerró al empezar).
  static const int minimumSeconds = 20;

  Future<RewardGrant> complete({
    required CareSessionKind kind,
    required String variant,
    required int durationSeconds,
    String? healthTitle,
  }) async {
    if (durationSeconds < minimumSeconds) return const RewardGrant.alreadyClaimed();
    final DateTime end = _clock.now();
    final String dateKey = end.dateKey;
    await _dao.insertSession(
      dateKey: dateKey,
      kind: kind.key,
      variant: variant,
      durationSeconds: durationSeconds,
      completedAt: end,
    );
    final RewardGrant grant = await _rewards.grant(switch (kind) {
      CareSessionKind.pelvicFloor => RewardAction.pelvicFloor,
      CareSessionKind.activeBreak => RewardAction.activeBreak,
      CareSessionKind.breathing => RewardAction.mindfulBreath,
    }, dateKey: dateKey);
    if (kind == CareSessionKind.breathing) {
      await bestEffort(
        () => _health.writeMindfulness(
          start: end.subtract(Duration(seconds: durationSeconds)),
          end: end,
          title: healthTitle ?? '',
        ),
        false,
      );
    }
    return grant;
  }
}

final careSessionServiceProvider = Provider<CareSessionService>((Ref ref) {
  return CareSessionService(
    ref.watch(careDaoProvider),
    ref.watch(rewardServiceProvider),
    ref.watch(healthConnectGatewayProvider),
    ref.watch(clockProvider),
  );
});
