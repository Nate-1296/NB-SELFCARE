import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_database.dart';
import '../core/database/daos/user_profile_dao.dart';
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
      await _ref.read(reminderServiceProvider).syncSchedules();
      await _ref.read(healthSyncServiceProvider).syncRecentDays();
    } finally {
      _running = false;
    }
  }
}

final appSyncCoordinatorProvider = Provider<AppSyncCoordinator>(AppSyncCoordinator.new);
