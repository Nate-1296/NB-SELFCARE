import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock/clock.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/care_dao.dart';
import '../../../core/database/daos/user_profile_dao.dart';
import '../../../shared/utils/biometric_formulas.dart';
import '../../../shared/utils/date_time_extensions.dart';
import '../../pet_gamification/application/reward_service.dart';
import '../../pet_gamification/domain/reward_policy.dart';
import '../domain/checkup_catalog.dart';

/// Chequeos preventivos: la lista se propone según edad y sexo la primera vez
/// y luego es de la persona (activar, cambiar intervalo, añadir propios).
class CheckupService {
  CheckupService(this._dao, this._profileDao, this._rewards, this._clock);

  final CareDao _dao;
  final UserProfileDao _profileDao;
  final RewardService _rewards;
  final Clock _clock;

  /// Crea la lista propuesta si todavía no existe ninguna fila.
  Future<void> seedIfEmpty() async {
    if ((await _dao.getCheckups()).isNotEmpty) return;
    final UserProfile? profile = await _profileDao.getProfile();
    if (profile == null) return;
    final int age = BiometricFormulas.calculateDynamicAge(profile.birthDate, _clock.now()).floor();
    final List<CheckupSpec> suggested = CheckupCatalog.suggestedFor(profile.biologicalSex, age);
    for (final CheckupSpec spec in CheckupCatalog.all) {
      if (spec.sex != null && spec.sex != profile.biologicalSex) continue;
      await _dao.insertCheckup(
        catalogKey: spec.key,
        intervalMonths: spec.intervalFor(age),
        enabled: suggested.contains(spec),
      );
    }
  }

  Future<RewardGrant> markDone(int checkupId, {required DateTime doneAt, String? notes}) async {
    final DateTime now = _clock.now();
    final DateTime when = doneAt.isAfter(now) ? now : doneAt;
    await _dao.insertCheckupLog(checkupId: checkupId, doneAt: when, notes: notes);
    return _rewards.grant(RewardAction.checkupDone, dateKey: now.dateKey);
  }

  Future<void> deleteLog(int id) => _dao.deleteCheckupLog(id);

  Future<void> restoreLog(CheckupLog log) => _dao.restoreCheckupLog(log);

  Future<void> setEnabled(int id, {required bool enabled}) =>
      _dao.updateCheckup(id, enabled: enabled);

  Future<void> setInterval(int id, int months) =>
      _dao.updateCheckup(id, intervalMonths: months.clamp(1, 240));

  Future<int?> addCustom({required String name, required int intervalMonths}) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) return Future<int?>.value();
    return _dao.insertCheckup(
      catalogKey: CheckupCatalog.custom,
      customName: trimmed.length > 60 ? trimmed.substring(0, 60) : trimmed,
      intervalMonths: intervalMonths.clamp(1, 240),
    );
  }

  Future<void> remove(int id) => _dao.deleteCheckup(id);
}

final checkupServiceProvider = Provider<CheckupService>((Ref ref) {
  return CheckupService(
    ref.watch(careDaoProvider),
    ref.watch(userProfileDaoProvider),
    ref.watch(rewardServiceProvider),
    ref.watch(clockProvider),
  );
});
