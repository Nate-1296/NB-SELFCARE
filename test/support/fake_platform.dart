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
  Future<void> setReminders(List<ScheduledReminder> reminders) async =>
      this.reminders = reminders;

  @override
  Future<void> setMovementNudges({
    required bool enabled,
    int startMinutes = 9 * 60,
    int endMinutes = 21 * 60,
  }) async =>
      movementNudges = enabled;
}
