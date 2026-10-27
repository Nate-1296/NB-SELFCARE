import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/platform/health_connect_gateway.dart';
import '../../../core/platform/notification_gateway.dart';

/// Estado del aviso de pausas activas.
enum MovementNudgeStatus { enabled, disabled, needsHealthConnect, unsupported }

/// Pomodoro de sedentarismo (docs/14 Fase 5): invitación a moverse tras ~60 min
/// sin pasos, calculado en el dispositivo con Health Connect.
class MovementNudgeService {
  MovementNudgeService(this._db, this._healthConnect, this._notifications);

  static const String preferenceKey = 'movement_nudges_enabled';

  final AppDatabase _db;
  final HealthConnectGateway _healthConnect;
  final NotificationGateway _notifications;

  Future<MovementNudgeStatus> status() async {
    if (await _healthConnect.availability() != HealthConnectAvailability.available ||
        !await _healthConnect.supportsBackgroundReads()) {
      return MovementNudgeStatus.unsupported;
    }
    final bool enabled = await _db.readUiPreference(preferenceKey) == 'true';
    if (!enabled) return MovementNudgeStatus.disabled;
    return await _healthConnect.hasBackgroundReadPermission()
        ? MovementNudgeStatus.enabled
        : MovementNudgeStatus.needsHealthConnect;
  }

  Future<MovementNudgeStatus> setEnabled(bool enabled) async {
    await _db.writeUiPreference(preferenceKey, enabled.toString());
    if (enabled && !await _healthConnect.hasBackgroundReadPermission()) {
      await _healthConnect.requestPermissions();
    }
    await _notifications.setMovementNudges(enabled: enabled);
    return status();
  }
}

final movementNudgeServiceProvider = Provider<MovementNudgeService>((Ref ref) {
  return MovementNudgeService(
    ref.watch(appDatabaseProvider),
    ref.watch(healthConnectGatewayProvider),
    ref.watch(notificationGatewayProvider),
  );
});
