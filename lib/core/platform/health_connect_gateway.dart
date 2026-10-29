import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/care_enums.dart';
import 'native_call.dart';

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
    this.wakeMinutes,
  });

  final int? steps;
  final int? sleepMinutes;
  final int deepSleepMinutes;
  final int remSleepMinutes;
  final int? restingHeartRateBpm;

  /// Hora de despertar (minutos desde medianoche) de la noche que termina ese día.
  final int? wakeMinutes;

  /// Construye la instantánea descartando lo que no puede ser un dato real:
  /// pasos negativos o absurdos, más de 24 h de sueño en un día, fases de sueño
  /// mayores que el sueño total y FC en reposo fuera de 25–220 lpm (sensor mal
  /// colocado, unidades erróneas de otra app que escribe en Health Connect).
  factory DailyActivitySnapshot.sanitized({
    int? steps,
    int? sleepMinutes,
    int? deepSleepMinutes,
    int? remSleepMinutes,
    int? restingHeartRateBpm,
    int? wakeMinutes,
  }) {
    final int? sleep = sleepMinutes == null || sleepMinutes < 0
        ? null
        : sleepMinutes.clamp(0, 24 * 60);
    int phase(int? v) => sleep == null || v == null || v < 0 ? 0 : v.clamp(0, sleep);
    return DailyActivitySnapshot(
      steps: steps == null || steps < 0 || steps > maxDailySteps ? null : steps,
      sleepMinutes: sleep,
      deepSleepMinutes: phase(deepSleepMinutes),
      remSleepMinutes: phase(remSleepMinutes),
      restingHeartRateBpm:
          restingHeartRateBpm == null || restingHeartRateBpm < 25 || restingHeartRateBpm > 220
          ? null
          : restingHeartRateBpm,
      wakeMinutes: sleep == null || wakeMinutes == null || wakeMinutes < 0 || wakeMinutes >= 24 * 60
          ? null
          : wakeMinutes,
    );
  }

  /// Tope de pasos diarios creíble (un ultramaratón ronda los 100 000).
  static const int maxDailySteps = 200000;

  bool get isEmpty => steps == null && sleepMinutes == null && restingHeartRateBpm == null;
}

int? _finiteInt(Object? value) => value is num && value.isFinite ? value.toInt() : null;

/// Lectura de un signo vital escrita en Health Connect por otra app (tensiómetro,
/// glucómetro, oxímetro, termómetro).
class VitalSample {
  const VitalSample({
    required this.externalId,
    required this.kind,
    required this.at,
    required this.primary,
    this.secondary,
    this.context,
  });

  final String externalId;
  final VitalKind kind;
  final DateTime at;
  final double primary;
  final double? secondary;
  final String? context;

  static VitalSample? fromMap(Map<Object?, Object?> raw) {
    final Object? id = raw['id'];
    final Object? kind = raw['kind'];
    final Object? time = raw['time'];
    final Object? primary = raw['primary'];
    if (id is! String || kind is! String || time is! num || primary is! num) return null;
    final VitalKind? parsed = VitalKind.fromKey(kind);
    if (parsed == null || !primary.isFinite) return null;
    final Object? secondary = raw['secondary'];
    final Object? context = raw['context'];
    return VitalSample(
      externalId: id,
      kind: parsed,
      at: DateTime.fromMillisecondsSinceEpoch(time.toInt()),
      primary: primary.toDouble(),
      secondary: secondary is num && secondary.isFinite ? secondary.toDouble() : null,
      context: context is String ? context : null,
    );
  }
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

  /// Pide la lectura de los signos vitales de los aparatos declarados.
  Future<bool> requestVitalPermissions(Set<VitalKind> kinds);

  Future<List<VitalSample>> readVitals({required Set<VitalKind> kinds, required DateTime since});

  /// Guarda una sesión de respiración guiada como sesión de mindfulness.
  Future<bool> writeMindfulness({
    required DateTime start,
    required DateTime end,
    required String title,
  });
}

class MethodChannelHealthConnectGateway implements HealthConnectGateway {
  const MethodChannelHealthConnectGateway();

  static const MethodChannel _channel = MethodChannel('com.nb.selfcare/health_connect');

  Future<T?> _invoke<T>(String method, [Map<String, Object?>? args]) =>
      callNative<T>(_channel, method, args);

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
    return DailyActivitySnapshot.sanitized(
      steps: _finiteInt(raw['steps']),
      sleepMinutes: _finiteInt(raw['sleepMinutes']),
      deepSleepMinutes: _finiteInt(raw['deepMinutes']),
      remSleepMinutes: _finiteInt(raw['remMinutes']),
      restingHeartRateBpm: _finiteInt(raw['restingHeartRate']),
      wakeMinutes: _finiteInt(raw['wakeMinutes']),
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

  @override
  Future<bool> requestVitalPermissions(Set<VitalKind> kinds) async {
    if (kinds.isEmpty) return false;
    return await _invoke<bool>('requestVitalPermissions', <String, Object?>{
          'kinds': kinds.map((VitalKind k) => k.key).toList(),
        }) ??
        false;
  }

  @override
  Future<List<VitalSample>> readVitals({
    required Set<VitalKind> kinds,
    required DateTime since,
  }) async {
    if (kinds.isEmpty) return const <VitalSample>[];
    final List<Object?>? raw = await _invoke<List<Object?>>('readVitals', <String, Object?>{
      'kinds': kinds.map((VitalKind k) => k.key).toList(),
      'sinceEpochMs': since.millisecondsSinceEpoch,
    });
    if (raw == null) return const <VitalSample>[];
    return raw
        .whereType<Map<Object?, Object?>>()
        .map(VitalSample.fromMap)
        .whereType<VitalSample>()
        .toList();
  }

  @override
  Future<bool> writeMindfulness({
    required DateTime start,
    required DateTime end,
    required String title,
  }) async {
    return await _invoke<bool>('writeMindfulness', <String, Object?>{
          'startEpochMs': start.millisecondsSinceEpoch,
          'endEpochMs': end.millisecondsSinceEpoch,
          'title': title,
        }) ??
        false;
  }
}

final healthConnectGatewayProvider = Provider<HealthConnectGateway>(
  (Ref ref) => const MethodChannelHealthConnectGateway(),
);
