import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Recordatorio listo para programarse en el sistema.
class ScheduledReminder {
  const ScheduledReminder({
    required this.id,
    required this.title,
    required this.body,
    required this.minutesOfDay,
    required this.daysMask,
    this.intervalMinutes,
    this.windowEndMinutes = 21 * 60,
  });

  final int id;
  final String title;
  final String body;

  /// Minutos desde medianoche de la primera aparición del día.
  final int minutesOfDay;

  /// Bit 0 = lunes … bit 6 = domingo.
  final int daysMask;

  /// Repetición dentro del día (hidratación) hasta [windowEndMinutes].
  final int? intervalMinutes;
  final int windowEndMinutes;

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'title': title,
        'body': body,
        'minutesOfDay': minutesOfDay,
        'daysMask': daysMask,
        'intervalMinutes': intervalMinutes,
        'windowEndMinutes': windowEndMinutes,
      };
}

/// Notificaciones 100 % locales: cronómetro de ayuno, recordatorios y pausas activas.
abstract interface class NotificationGateway {
  Future<void> showFastingTimer({
    required DateTime startedAt,
    required int targetHours,
    required String protocol,
  });

  Future<void> cancelFastingTimer();

  /// Reemplaza todos los recordatorios programados por [reminders].
  Future<void> setReminders(List<ScheduledReminder> reminders);

  Future<void> setMovementNudges({
    required bool enabled,
    int startMinutes = 9 * 60,
    int endMinutes = 21 * 60,
  });
}

class MethodChannelNotificationGateway implements NotificationGateway {
  const MethodChannelNotificationGateway();

  static const MethodChannel _channel = MethodChannel('com.nb.selfcare/notifications');

  Future<void> _invoke(String method, Map<String, Object?> args) async {
    try {
      await _channel.invokeMethod<bool>(method, args);
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }

  @override
  Future<void> showFastingTimer({
    required DateTime startedAt,
    required int targetHours,
    required String protocol,
  }) {
    return _invoke('showFastingTimer', <String, Object?>{
      'startedAtEpochMs': startedAt.millisecondsSinceEpoch,
      'targetHours': targetHours,
      'protocol': protocol,
    });
  }

  @override
  Future<void> cancelFastingTimer() => _invoke('cancelFastingTimer', const <String, Object?>{});

  @override
  Future<void> setReminders(List<ScheduledReminder> reminders) {
    return _invoke('setReminders', <String, Object?>{
      'reminders': reminders.map((ScheduledReminder r) => r.toMap()).toList(),
    });
  }

  @override
  Future<void> setMovementNudges({
    required bool enabled,
    int startMinutes = 9 * 60,
    int endMinutes = 21 * 60,
  }) {
    return _invoke('setMovementNudges', <String, Object?>{
      'enabled': enabled,
      'startMinutes': startMinutes,
      'endMinutes': endMinutes,
    });
  }
}

final notificationGatewayProvider =
    Provider<NotificationGateway>((Ref ref) => const MethodChannelNotificationGateway());
