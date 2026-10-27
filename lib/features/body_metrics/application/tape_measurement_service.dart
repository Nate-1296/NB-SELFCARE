import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock/clock.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/body_measurements_dao.dart';
import '../../../core/database/daos/user_profile_dao.dart';
import '../../../shared/utils/biometric_formulas.dart';
import '../../../shared/utils/date_time_extensions.dart';

/// Resultado de guardar una validación con cinta métrica.
class TapeMeasurementResult {
  const TapeMeasurementResult({
    required this.saved,
    required this.navyBodyFatPercentage,
    required this.validatedBodyFatPercentage,
  });

  /// `false` si aún no existe ningún pesaje con el que combinar la cinta.
  final bool saved;
  final double navyBodyFatPercentage;
  final double validatedBodyFatPercentage;
}

/// Caso de uso "Validar con cinta métrica" (ADR-10): US Navy + fusión 60/40 con BIA.
class TapeMeasurementService {
  TapeMeasurementService(this._profileDao, this._measurementsDao, this._clock);

  final UserProfileDao _profileDao;
  final BodyMeasurementsDao _measurementsDao;
  final Clock _clock;

  Future<TapeMeasurementResult> save({
    required double waistCm,
    required double neckCm,
    double? hipCm,
  }) async {
    final UserProfile? profile = await _profileDao.getProfile();
    if (profile == null) {
      throw StateError('No se puede guardar la cinta métrica sin perfil de usuario.');
    }

    final double navyFat = BiometricFormulas.calculateNavyBodyFatPercentage(
      heightCm: profile.heightCm,
      waistCm: waistCm,
      neckCm: neckCm,
      isMale: profile.biologicalSex.isMale,
      hipCm: hipCm,
    );
    final double biaFat = await _measurementsDao.getLatestBiaBodyFat() ?? navyFat;
    final double validatedFat = BiometricFormulas.calculateValidatedBodyFat(
      biaBodyFatPercentage: biaFat,
      navyBodyFatPercentage: navyFat,
    );

    final DateTime now = _clock.now();
    final bool saved = await _measurementsDao.saveNavyTapeMeasurement(
      dateKey: now.dateKey,
      measuredAt: now,
      waistCm: waistCm,
      neckCm: neckCm,
      hipCm: hipCm,
      validatedBodyFatPercentage: validatedFat,
      navyBodyFatPercentage: navyFat,
    );

    return TapeMeasurementResult(
      saved: saved,
      navyBodyFatPercentage: navyFat,
      validatedBodyFatPercentage: validatedFat,
    );
  }
}

final tapeMeasurementServiceProvider = Provider<TapeMeasurementService>((Ref ref) {
  return TapeMeasurementService(
    ref.watch(userProfileDaoProvider),
    ref.watch(bodyMeasurementsDaoProvider),
    ref.watch(clockProvider),
  );
});
