import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum HealthConnectAvailability { available, updateRequired, notInstalled, unsupported }

/// Actividad de un día leída de Health Connect. Los campos `null` significan
/// "sin permiso o sin datos", nunca cero.
class DailyActivitySnapshot {
  const DailyActivitySnapshot({
    this.steps,
    this.sleepMinutes,
    this.deepSleepMinutes = 0,
    this.remSleepMinutes = 0,
    this.restingHeartRateBpm,
  });

  final int? steps;
  final int? sleepMinutes;
  final int deepSleepMinutes;
  final int remSleepMinutes;
  final int? restingHeartRateBpm;

  bool get isEmpty => steps == null && sleepMinutes == null && restingHeartRateBpm == null;
}

/// Puerto hacia Health Connect (docs/07). Health Connect es un almacén local del
/// sistema: ningún dato sale del dispositivo. Todas las operaciones degradan a
/// "no disponible" sin lanzar excepciones (docs/01 §2 #7).
abstract interface class HealthConnectGateway {
  Future<HealthConnectAvailability> availability();
  Future<bool> hasPermissions();
  Future<bool> requestPermissions();
  Future<bool> openSettings();

  /// Lecturas en segundo plano (necesarias para el aviso de sedentarismo).
  Future<bool> supportsBackgroundReads();

  Future<bool> hasBackgroundReadPermission();

  Future<DailyActivitySnapshot?> readDailyActivity(String dateKey);

  Future<bool> writeWeight({
    required double weightKg,
    required DateTime at,
    required bool fromScale,
    double? bodyFatPercentage,
  });

  Future<bool> writeHydration({required int volumeMl, required DateTime at});
}

class MethodChannelHealthConnectGateway implements HealthConnectGateway {
  const MethodChannelHealthConnectGateway();

  static const MethodChannel _channel = MethodChannel('com.nb.selfcare/health_connect');

  Future<T?> _invoke<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<HealthConnectAvailability> availability() async {
    return switch (await _invoke<String>('availability')) {
      'available' => HealthConnectAvailability.available,
      'update_required' => HealthConnectAvailability.updateRequired,
      'not_installed' => HealthConnectAvailability.notInstalled,
      _ => HealthConnectAvailability.unsupported,
    };
  }

  @override
  Future<bool> hasPermissions() async => await _invoke<bool>('hasPermissions') ?? false;

  @override
  Future<bool> requestPermissions() async => await _invoke<bool>('requestPermissions') ?? false;

  @override
  Future<bool> openSettings() async => await _invoke<bool>('openSettings') ?? false;

  @override
  Future<bool> supportsBackgroundReads() async =>
      await _invoke<bool>('supportsBackgroundReads') ?? false;

  @override
  Future<bool> hasBackgroundReadPermission() async =>
      await _invoke<bool>('hasBackgroundReadPermission') ?? false;

  @override
  Future<DailyActivitySnapshot?> readDailyActivity(String dateKey) async {
    final Map<Object?, Object?>? raw = await _invoke<Map<Object?, Object?>>(
      'readDailyActivity',
      <String, Object?>{'dateKey': dateKey},
    );
    if (raw == null) return null;
    int? asInt(Object? value) => value is num ? value.toInt() : null;
    return DailyActivitySnapshot(
      steps: asInt(raw['steps']),
      sleepMinutes: asInt(raw['sleepMinutes']),
      deepSleepMinutes: asInt(raw['deepMinutes']) ?? 0,
      remSleepMinutes: asInt(raw['remMinutes']) ?? 0,
      restingHeartRateBpm: asInt(raw['restingHeartRate']),
    );
  }

  @override
  Future<bool> writeWeight({
    required double weightKg,
    required DateTime at,
    required bool fromScale,
    double? bodyFatPercentage,
  }) async {
    return await _invoke<bool>('writeWeight', <String, Object?>{
          'weightKg': weightKg,
          'bodyFatPercentage': bodyFatPercentage,
          'timestampEpochMs': at.millisecondsSinceEpoch,
          'fromScale': fromScale,
        }) ??
        false;
  }

  @override
  Future<bool> writeHydration({required int volumeMl, required DateTime at}) async {
    return await _invoke<bool>('writeHydration', <String, Object?>{
          'amountMl': volumeMl,
          'timestampEpochMs': at.millisecondsSinceEpoch,
        }) ??
        false;
  }
}

final healthConnectGatewayProvider =
    Provider<HealthConnectGateway>((Ref ref) => const MethodChannelHealthConnectGateway());
