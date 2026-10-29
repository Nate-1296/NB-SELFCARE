import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_database.dart';
import '../core/database/daos/user_profile_dao.dart';
import '../features/care/application/checkup_service.dart';
import '../features/care/application/health_log_services.dart';
import '../features/care/application/treatment_service.dart';
import '../features/fasting/application/fasting_service.dart';
import '../features/profile_goals/application/reminder_service.dart';
import '../features/today/application/health_sync_service.dart';

/// Mantiene alineado lo que vive fuera de la base de datos (notificaciones,
/// alarmas, Health Connect) al abrir o reanudar la app y tras restaurar un respaldo.
class AppSyncCoordinator {
  AppSyncCoordinator(this._ref);

  final Ref _ref;
  bool _running = false;

  Future<void> sync() async {
    if (_running) return;
    _running = true;
    try {
      final UserProfile? profile = await _ref.read(userProfileDaoProvider).getProfile();
      if (profile == null) return;
      await _ref.read(fastingServiceProvider).reconcileTimerNotification();
      // Los "Hecho" pulsados en notificaciones con la app cerrada.
      await _ref.read(treatmentServiceProvider).applyNotificationActions();
      // Siembra + tipos nuevos de recordatorio + reprogramación.
      await _ref.read(reminderServiceProvider).seedDefaults();
      await _ref.read(checkupServiceProvider).seedIfEmpty();
      await _ref.read(healthSyncServiceProvider).syncRecentDays();
      await _ref.read(vitalServiceProvider).syncFromHealthConnect();
    } finally {
      _running = false;
    }
  }
}

final appSyncCoordinatorProvider = Provider<AppSyncCoordinator>(AppSyncCoordinator.new);
