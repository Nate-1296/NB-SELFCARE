import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/clock/clock.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/user_profile_dao.dart';
import '../../../core/domain/enums.dart';

/// Casos de uso de edición del perfil vivo (docs/01 §4, página 5).
class ProfileService {
  ProfileService(this._profileDao, this._clock);

  final UserProfileDao _profileDao;
  final Clock _clock;

  /// Actualiza los campos presentes en [changes]. Si cambia la fase de dieta,
  /// se registra su fecha de inicio (reverse diet y diet break dependen de ella).
  Future<void> update(UserProfilesCompanion changes) async {
    final UserProfile? current = await _profileDao.getProfile();
    if (current == null) return;

    UserProfilesCompanion effective = changes;
    final Value<DietPhase> phase = changes.activeDietPhase;
    if (phase.present && phase.value != current.activeDietPhase) {
      effective = changes.copyWith(activeDietPhaseStartedAt: Value(_clock.now()));
    }
    await _profileDao.updateProfile(effective);
  }

  /// Copia la foto elegida a la carpeta privada de la app y la fija como avatar.
  /// Usa un nombre nuevo cada vez para que la imagen no quede en caché, y borra la anterior.
  Future<void> saveAvatar(String sourcePath) async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final String ext = p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath);
    final File saved = await File(sourcePath)
        .copy(p.join(dir.path, 'profile_avatar_${_clock.now().millisecondsSinceEpoch}$ext'));
    final String? previous = (await _profileDao.getProfile())?.avatarPath;
    await update(UserProfilesCompanion(avatarPath: Value(saved.path)));
    if (previous != null && previous != saved.path) {
      final File old = File(previous);
      if (old.existsSync()) await old.delete();
    }
  }

  Future<void> setDietPhase(DietPhase phase) =>
      _profileDao.updateDietPhase(phase, startedAt: _clock.now());

  Future<void> setDietArchetype(DietArchetype archetype) =>
      _profileDao.updateDietArchetype(archetype);

  Future<void> setFastingEnabled(bool enabled) => _profileDao.updateFastingEnabled(enabled);

  Future<void> setCycleTrackingEnabled(bool enabled) =>
      _profileDao.updateCycleTrackingEnabled(enabled);

  Future<void> setThemeKey(String themeKey) => _profileDao.updateThemeMode(themeKey);

  /// Vincula la báscula por su MAC; una cadena vacía vuelve al escaneo automático.
  Future<void> setScaleMacAddress(String? macAddress) {
    final String? normalized =
        macAddress == null || macAddress.trim().isEmpty ? null : macAddress.trim().toUpperCase();
    return _profileDao.updateProfile(UserProfilesCompanion(scaleMacAddress: Value(normalized)));
  }

  Future<void> setManualMacroMode({
    required bool enabled,
    int? kcal,
    int? proteinG,
    int? carbsG,
    int? fatG,
  }) {
    return _profileDao.updateManualMacroMode(
      isManual: enabled,
      manualKcal: kcal,
      manualProteinG: proteinG,
      manualCarbsG: carbsG,
      manualFatG: fatG,
    );
  }
}

final profileServiceProvider = Provider<ProfileService>((Ref ref) {
  return ProfileService(ref.watch(userProfileDaoProvider), ref.watch(clockProvider));
});
