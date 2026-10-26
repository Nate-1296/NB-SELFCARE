import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_database.dart';

/// DAO especializado para el perfil de usuario único y configuración biométrica.
class UserProfileDao {
  UserProfileDao(this._db);

  final AppDatabase _db;

  /// Emite en tiempo real cualquier cambio en el perfil de usuario.
  Stream<UserProfile?> watchProfile() {
    return (_db.select(_db.userProfiles)..limit(1)).watchSingleOrNull();
  }

  /// Obtiene el perfil de usuario actual en una llamada única.
  Future<UserProfile?> getProfile() {
    return (_db.select(_db.userProfiles)..limit(1)).getSingleOrNull();
  }

  /// Determina si el usuario ya completó el onboarding inicial.
  Future<bool> hasCompletedOnboarding() async {
    final UserProfile? profile = await getProfile();
    return profile != null;
  }

  /// Inserta el perfil inicial durante el flujo de Onboarding.
  Future<int> createProfile(UserProfilesCompanion companion) {
    return _db.into(_db.userProfiles).insert(companion);
  }

  /// Actualiza los datos del perfil activo.
  Future<bool> updateProfile(UserProfilesCompanion companion) async {
    final UserProfile? current = await getProfile();
    if (current == null) return false;

    final query = _db.update(_db.userProfiles)..where((tbl) => tbl.id.equals(current.id));
    final int rows = await query.write(companion);
    return rows > 0;
  }

  /// Actualiza exclusivamente el tema visual ('material_you' o 'nxtpaper_eink').
  Future<void> updateThemeMode(String themeMode) async {
    final UserProfile? current = await getProfile();
    if (current == null) return;

    final query = _db.update(_db.userProfiles)..where((tbl) => tbl.id.equals(current.id));
    await query.write(UserProfilesCompanion(themeMode: Value(themeMode)));
  }

  /// Actualiza el TDEE adaptativo tras la calibración quincenal.
  Future<void> updateAdaptiveTdee(int newTdeeKcal, DateTime calibrationDate) async {
    final UserProfile? current = await getProfile();
    if (current == null) return;

    final query = _db.update(_db.userProfiles)..where((tbl) => tbl.id.equals(current.id));
    await query.write(
      UserProfilesCompanion(
        currentAdaptiveTdeeKcal: Value(newTdeeKcal),
        lastTdeeCalibration: Value(calibrationDate),
      ),
    );
  }

  /// Configura el modo de macronutrientes manual (prescripción médica o deportiva).
  Future<void> updateManualMacroMode({
    required bool isManual,
    int? manualKcal,
    int? manualProteinG,
    int? manualCarbsG,
    int? manualFatG,
  }) async {
    final UserProfile? current = await getProfile();
    if (current == null) return;

    final query = _db.update(_db.userProfiles)..where((tbl) => tbl.id.equals(current.id));
    await query.write(
      UserProfilesCompanion(
        isManualMacroMode: Value(isManual),
        manualKcalTarget: Value(manualKcal),
        manualProteinG: Value(manualProteinG),
        manualCarbsG: Value(manualCarbsG),
        manualFatG: Value(manualFatG),
      ),
    );
  }

  /// Actualiza el arquetipo de dieta activo (ej. 'mediterranean', 'keto', 'flexible').
  Future<void> updateDietArchetype(String archetype) async {
    final UserProfile? current = await getProfile();
    if (current == null) return;

    final query = _db.update(_db.userProfiles)..where((tbl) => tbl.id.equals(current.id));
    await query.write(UserProfilesCompanion(activeDietArchetype: Value(archetype)));
  }

  /// Actualiza la fase de dieta activa ('deficit', 'maintenance', 'diet_break', 'reverse_diet').
  Future<void> updateDietPhase(String phase) async {
    final UserProfile? current = await getProfile();
    if (current == null) return;

    final query = _db.update(_db.userProfiles)..where((tbl) => tbl.id.equals(current.id));
    await query.write(UserProfilesCompanion(activeDietPhase: Value(phase)));
  }

  /// Configura la activación del seguimiento del ciclo menstrual femenino.
  Future<void> updateCycleTrackingEnabled(bool enabled) async {
    final UserProfile? current = await getProfile();
    if (current == null) return;

    final query = _db.update(_db.userProfiles)..where((tbl) => tbl.id.equals(current.id));
    await query.write(UserProfilesCompanion(isCycleTrackingEnabled: Value(enabled)));
  }

  /// Configura la activación del módulo de ayuno intermitente.
  Future<void> updateFastingEnabled(bool enabled) async {
    final UserProfile? current = await getProfile();
    if (current == null) return;

    final query = _db.update(_db.userProfiles)..where((tbl) => tbl.id.equals(current.id));
    await query.write(UserProfilesCompanion(isFastingEnabled: Value(enabled)));
  }
}

/// Provider de Riverpod para inyectar UserProfileDao.
final userProfileDaoProvider = Provider<UserProfileDao>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return UserProfileDao(db);
});

/// StreamProvider que expone el perfil actual de forma reactiva a la UI.
final userProfileStreamProvider = StreamProvider<UserProfile?>((ref) {
  final UserProfileDao dao = ref.watch(userProfileDaoProvider);
  return dao.watchProfile();
});
