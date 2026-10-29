import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/reminders_dao.dart';
import '../../../core/database/daos/user_profile_dao.dart';
import '../../../core/domain/care_enums.dart';
import '../../../core/domain/enums.dart';
import '../../../core/platform/health_connect_gateway.dart';
import '../../../core/platform/native_call.dart';
import '../../../shared/theme/sc_theme.dart';
import '../../../shared/theme/theme_controller.dart';
import '../../profile_goals/application/reminder_service.dart';
import 'health_log_services.dart';

/// Equipos declarados y módulos visibles: lo que no se usa, no aparece.
class CarePreferencesService {
  CarePreferencesService(
    this._profileDao,
    this._remindersDao,
    this._reminders,
    this._health,
    this._vitals,
  );

  final UserProfileDao _profileDao;
  final RemindersDao _remindersDao;
  final ReminderService _reminders;
  final HealthConnectGateway _health;
  final VitalService _vitals;

  Future<UserProfile?> _profile() => _profileDao.getProfile();

  /// Pantalla de papel (NXTPAPER u otra e-ink). Si se apaga estando en un tema
  /// de papel, se vuelve al tema de color por defecto.
  Future<void> setEinkScreen(bool hasEink) async {
    final UserProfile? profile = await _profile();
    if (profile == null) return;
    final bool onPaperTheme =
        scThemeByKey(profile.themeMode).colors.isFlat || profile.themeMode.startsWith('nxtpaper');
    await _profileDao.updateProfile(
      UserProfilesCompanion(
        hasEinkScreen: Value(hasEink),
        themeMode: !hasEink && onPaperTheme ? const Value(kDefaultThemeKey) : const Value.absent(),
      ),
    );
  }

  Future<void> setSmartScale(bool hasScale) =>
      _profileDao.updateProfile(UserProfilesCompanion(hasSmartScale: Value(hasScale)));

  /// Aparatos de signos vitales. Para los nuevos se pide leer Health Connect
  /// (si se niega, el registro manual sigue funcionando).
  Future<void> setVitalDevices(Set<VitalKind> kinds) async {
    final UserProfile? profile = await _profile();
    if (profile == null) return;
    final Set<VitalKind> before = ProfileSets.vitalDevices(profile.vitalDevicesJson);
    await _profileDao.updateProfile(
      UserProfilesCompanion(vitalDevicesJson: Value(ProfileSets.encodeVitals(kinds))),
    );
    final Set<VitalKind> added = kinds.difference(before);
    if (added.isEmpty) return;
    final HealthConnectAvailability availability = await bestEffort(
      _health.availability,
      HealthConnectAvailability.unsupported,
    );
    if (availability != HealthConnectAvailability.available) return;
    await bestEffort(() => _health.requestVitalPermissions(added), false);
    await _vitals.syncFromHealthConnect();
  }

  Future<void> setCareModule(CareModule module, {required bool enabled}) async {
    final UserProfile? profile = await _profile();
    if (profile == null) return;
    final Set<CareModule> modules = ProfileSets.careModules(profile.careModulesJson);
    if (enabled) {
      modules.add(module);
    } else {
      modules.remove(module);
    }
    await _profileDao.updateProfile(
      UserProfilesCompanion(careModulesJson: Value(ProfileSets.encodeModules(modules))),
    );
    await _reminders.syncSchedules();
  }

  Future<void> setDiscreetNotifications(bool discreet) async {
    await _profileDao.updateProfile(UserProfilesCompanion(discreetNotifications: Value(discreet)));
    await _reminders.syncSchedules();
  }

  /// Hora habitual de dormir: mueve también el aviso de "desconectar" (30 min antes).
  Future<void> setTargetBedtime(int minutesOfDay) async {
    final int bedtime = minutesOfDay % (24 * 60);
    await _profileDao.updateProfile(UserProfilesCompanion(targetBedtimeMinutes: Value(bedtime)));
    final List<Reminder> all = await _remindersDao.getAllReminders();
    for (final Reminder r in all.where((Reminder r) => r.reminderType == ReminderType.windDown)) {
      await _remindersDao.updateReminderTime(r.id, (bedtime - 30) % (24 * 60));
    }
    await _reminders.syncSchedules();
  }
}

final carePreferencesServiceProvider = Provider<CarePreferencesService>((Ref ref) {
  return CarePreferencesService(
    ref.watch(userProfileDaoProvider),
    ref.watch(remindersDaoProvider),
    ref.watch(reminderServiceProvider),
    ref.watch(healthConnectGatewayProvider),
    ref.watch(vitalServiceProvider),
  );
});
