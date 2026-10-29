import 'package:nb_selfcare/core/domain/care_enums.dart';
import 'package:nb_selfcare/core/platform/health_connect_gateway.dart';
import 'package:nb_selfcare/core/platform/notification_gateway.dart';

class FakeHealthConnectGateway implements HealthConnectGateway {
  FakeHealthConnectGateway({
    this.status = HealthConnectAvailability.available,
    this.snapshot,
    this.granted = true,
  });

  HealthConnectAvailability status;
  DailyActivitySnapshot? snapshot;
  bool granted;
  final List<double> writtenWeights = <double>[];
  final List<int> writtenWaterMl = <int>[];

  @override
  Future<HealthConnectAvailability> availability() async => status;

  @override
  Future<bool> hasPermissions() async => granted;

  @override
  Future<bool> requestPermissions() async => granted;

  @override
  Future<bool> openSettings() async => true;

  @override
  Future<bool> supportsBackgroundReads() async => true;

  @override
  Future<bool> hasBackgroundReadPermission() async => granted;

  @override
  Future<DailyActivitySnapshot?> readDailyActivity(String dateKey) async =>
      status == HealthConnectAvailability.available ? snapshot : null;

  @override
  Future<bool> writeWeight({
    required double weightKg,
    required DateTime at,
    required bool fromScale,
    double? bodyFatPercentage,
  }) async {
    writtenWeights.add(weightKg);
    return granted;
  }

  @override
  Future<bool> writeHydration({required int volumeMl, required DateTime at}) async {
    writtenWaterMl.add(volumeMl);
    return granted;
  }

  /// Lecturas que devolverá `readVitals` (filtradas por tipo y fecha).
  List<VitalSample> vitals = <VitalSample>[];
  final List<Set<VitalKind>> requestedVitals = <Set<VitalKind>>[];
  final List<({DateTime start, DateTime end, String title})> mindfulness =
      <({DateTime start, DateTime end, String title})>[];

  @override
  Future<bool> requestVitalPermissions(Set<VitalKind> kinds) async {
    requestedVitals.add(kinds);
    return granted;
  }

  @override
  Future<List<VitalSample>> readVitals({
    required Set<VitalKind> kinds,
    required DateTime since,
  }) async =>
      vitals.where((VitalSample v) => kinds.contains(v.kind) && !v.at.isBefore(since)).toList();

  @override
  Future<bool> writeMindfulness({
    required DateTime start,
    required DateTime end,
    required String title,
  }) async {
    mindfulness.add((start: start, end: end, title: title));
    return granted;
  }
}

class FakeNotificationGateway implements NotificationGateway {
  ({DateTime startedAt, int targetHours, String protocol})? fastingTimer;
  List<ScheduledReminder> reminders = <ScheduledReminder>[];
  bool movementNudges = false;

  @override
  Future<void> showFastingTimer({
    required DateTime startedAt,
    required int targetHours,
    required String protocol,
  }) async {
    fastingTimer = (startedAt: startedAt, targetHours: targetHours, protocol: protocol);
  }

  @override
  Future<void> cancelFastingTimer() async => fastingTimer = null;

  @override
  Future<void> setReminders(List<ScheduledReminder> reminders) async => this.reminders = reminders;

  @override
  Future<void> setMovementNudges({
    required bool enabled,
    int startMinutes = 9 * 60,
    int endMinutes = 21 * 60,
  }) async => movementNudges = enabled;

  /// "Hecho" pulsados en notificaciones pendientes de aplicar.
  List<ReminderActionEvent> pendingActions = <ReminderActionEvent>[];

  @override
  Future<List<ReminderActionEvent>> consumeReminderActions() async {
    final List<ReminderActionEvent> out = pendingActions;
    pendingActions = <ReminderActionEvent>[];
    return out;
  }
}

/// Health Connect que falla en todo: servicio del sistema caído o actualizado a
/// mitad de la sesión. Los casos de uso deben guardar igualmente en local.
class ThrowingHealthConnectGateway implements HealthConnectGateway {
  int calls = 0;

  Never _fail() {
    calls++;
    throw StateError('Health Connect no responde');
  }

  @override
  Future<HealthConnectAvailability> availability() async => _fail();

  @override
  Future<bool> hasPermissions() async => _fail();

  @override
  Future<bool> requestPermissions() async => _fail();

  @override
  Future<bool> openSettings() async => _fail();

  @override
  Future<bool> supportsBackgroundReads() async => _fail();

  @override
  Future<bool> hasBackgroundReadPermission() async => _fail();

  @override
  Future<DailyActivitySnapshot?> readDailyActivity(String dateKey) async => _fail();

  @override
  Future<bool> writeWeight({
    required double weightKg,
    required DateTime at,
    required bool fromScale,
    double? bodyFatPercentage,
  }) async => _fail();

  @override
  Future<bool> writeHydration({required int volumeMl, required DateTime at}) async => _fail();

  @override
  Future<bool> requestVitalPermissions(Set<VitalKind> kinds) async => _fail();

  @override
  Future<List<VitalSample>> readVitals({
    required Set<VitalKind> kinds,
    required DateTime since,
  }) async => _fail();

  @override
  Future<bool> writeMindfulness({
    required DateTime start,
    required DateTime end,
    required String title,
  }) async => _fail();
}

/// Notificaciones que fallan (permiso revocado, canal del sistema caído).
class ThrowingNotificationGateway implements NotificationGateway {
  int calls = 0;

  Never _fail() {
    calls++;
    throw StateError('NotificationManager no responde');
  }

  @override
  Future<void> showFastingTimer({
    required DateTime startedAt,
    required int targetHours,
    required String protocol,
  }) async => _fail();

  @override
  Future<void> cancelFastingTimer() async => _fail();

  @override
  Future<void> setReminders(List<ScheduledReminder> reminders) async => _fail();

  @override
  Future<void> setMovementNudges({
    required bool enabled,
    int startMinutes = 9 * 60,
    int endMinutes = 21 * 60,
  }) async => _fail();

  @override
  Future<List<ReminderActionEvent>> consumeReminderActions() async => _fail();
}
