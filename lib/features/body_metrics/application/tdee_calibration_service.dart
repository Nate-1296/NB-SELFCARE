import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock/clock.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/tdee_dao.dart';
import '../../../core/database/daos/user_profile_dao.dart';

/// Orquesta la recalibración quincenal del TDEE adaptativo (docs/04 §5, ADR-11).
class TdeeCalibrationService {
  TdeeCalibrationService(this._tdeeDao, this._profileDao, this._clock);

  final TdeeDao _tdeeDao;
  final UserProfileDao _profileDao;
  final Clock _clock;

  /// La calibración automática corre cada 14 días, salvo en modo manual/médico,
  /// donde las metas quedan congeladas por decisión del usuario.
  static bool isDue(UserProfile profile, DateTime now) {
    if (profile.isManualMacroMode) return false;
    final DateTime? last = profile.lastTdeeCalibration;
    return last == null ||
        now.difference(last).inDays >= AppConstants.adaptiveTdeeWindowDays;
  }

  /// Calibra solo si toca; devuelve `null` si no correspondía intentarlo.
  Future<TdeeCalibrationOutcome?> calibrateIfDue() async {
    final UserProfile? profile = await _profileDao.getProfile();
    final DateTime now = _clock.now();
    if (profile == null || !isDue(profile, now)) return null;
    return _tdeeDao.calibrateFromLast14Days(
      profile: profile,
      profileDao: _profileDao,
      referenceDate: now,
    );
  }

  /// Calibración solicitada explícitamente por el usuario desde su perfil.
  Future<TdeeCalibrationOutcome?> calibrateNow() async {
    final UserProfile? profile = await _profileDao.getProfile();
    if (profile == null) return null;
    return _tdeeDao.calibrateFromLast14Days(
      profile: profile,
      profileDao: _profileDao,
      referenceDate: _clock.now(),
    );
  }
}

final tdeeCalibrationServiceProvider = Provider<TdeeCalibrationService>((Ref ref) {
  return TdeeCalibrationService(
    ref.watch(tdeeDaoProvider),
    ref.watch(userProfileDaoProvider),
    ref.watch(clockProvider),
  );
});
