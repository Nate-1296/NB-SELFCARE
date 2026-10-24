import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/utils/date_time_extensions.dart';
import '../database/daos/health_sync_dao.dart';
import '../database/daos/pet_dao.dart';

/// Datos de sueño extraídos de Health Connect.
class HealthSleepSummary {
  const HealthSleepSummary({
    required this.totalDurationHours,
    required this.deepSleepDurationHours,
    required this.remSleepDurationHours,
    required this.qualityScore,
  });

  final double totalDurationHours;
  final double deepSleepDurationHours;
  final double remSleepDurationHours;
  final int qualityScore;

  /// Multiplicador de monedas: si el sueño reparador (REM + Profundo) >= 1.5 horas o calidad >= 85 -> 1.5x
  double get coinsMultiplier {
    if ((deepSleepDurationHours + remSleepDurationHours) >= 1.5 ||
        qualityScore >= 85) {
      return 1.5;
    }
    return 1.0;
  }
}

/// Servicio de sincronización bidireccional con Health Connect en Android 16 (API 36).
///
/// Implementa degradación elegante: si el servicio no está disponible o el usuario
/// no ha concedido permisos, la aplicación opera al 100% de forma local e independiente.
class HealthConnectService {
  HealthConnectService(this._syncDao, this._petDao);

  final HealthSyncDao _syncDao;
  final PetDao _petDao;

  static const MethodChannel _channel =
      MethodChannel('com.nb.selfcare/health_connect');

  /// Determina si Health Connect está disponible e instalado en el dispositivo.
  Future<bool> isAvailable() async {
    try {
      final bool? available =
          await _channel.invokeMethod<bool>('isHealthConnectAvailable');
      return available ?? false;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Verifica si la aplicación posee los permisos necesarios de lectura y escritura.
  Future<bool> checkPermissions() async {
    try {
      final bool? granted =
          await _channel.invokeMethod<bool>('hasHealthPermissions');
      return granted ?? false;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Solicita los permisos necesarios de Health Connect mediante el diálogo nativo de Android 16.
  Future<bool> requestPermissions() async {
    try {
      final bool? result =
          await _channel.invokeMethod<bool>('requestHealthPermissions');
      return result ?? false;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Verifica si un permiso de Android específico está concedido.
  Future<bool> checkAppPermission(String permission) async {
    try {
      final bool? granted = await _channel.invokeMethod<bool>(
        'checkAppPermission',
        <String, dynamic>{'permission': permission},
      );
      return granted ?? false;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Solicita un permiso de Android específico mediante el diálogo nativo o pantalla del sistema.
  Future<bool> requestAppPermission(String permission) async {
    try {
      final bool? result = await _channel.invokeMethod<bool>(
        'requestAppPermission',
        <String, dynamic>{'permission': permission},
      );
      return result ?? false;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Abre la pantalla de ajustes del sistema de la aplicación para gestión de permisos.
  Future<bool> openAppSettings() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('openAppSettings');
      return result ?? false;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Exporta una medición de peso y grasa a Health Connect tras la captura en la báscula BLE.
  Future<bool> writeWeightAndBodyFat({
    required double weightKg,
    required DateTime timestamp,
    double? bodyFatPercentage,
  }) async {
    try {
      final bool? success = await _channel.invokeMethod<bool>(
        'writeWeightAndBodyFat',
        {
          'weightKg': weightKg,
          'bodyFatPercentage': bodyFatPercentage,
          'timestampEpochMs': timestamp.millisecondsSinceEpoch,
        },
      );

      if (success == true) {
        await _syncDao.updateCheckpoint(
          recordType: 'weight_body_fat',
          timestamp: DateTime.now(),
          writeCount: 1,
        );
        return true;
      }
      return false;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Exporta un registro de hidratación a Health Connect.
  Future<bool> writeHydration({
    required int amountMl,
    required DateTime timestamp,
  }) async {
    try {
      final bool? success = await _channel.invokeMethod<bool>(
        'writeHydration',
        {
          'amountMl': amountMl,
          'timestampEpochMs': timestamp.millisecondsSinceEpoch,
        },
      );

      if (success == true) {
        await _syncDao.updateCheckpoint(
          recordType: 'hydration',
          timestamp: DateTime.now(),
          writeCount: 1,
        );
        return true;
      }
      return false;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Lee el resumen de sueño para una fecha determinada.
  Future<HealthSleepSummary?> readSleepForDate(DateTime date) async {
    try {
      final Map<dynamic, dynamic>? data =
          await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'readSleepForDate',
        {'dateKey': date.dateKey},
      );

      if (data == null) return null;

      final summary = HealthSleepSummary(
        totalDurationHours: (data['totalDurationHours'] as num?)?.toDouble() ?? 0.0,
        deepSleepDurationHours:
            (data['deepSleepDurationHours'] as num?)?.toDouble() ?? 0.0,
        remSleepDurationHours:
            (data['remSleepDurationHours'] as num?)?.toDouble() ?? 0.0,
        qualityScore: (data['qualityScore'] as num?)?.toInt() ?? 75,
      );

      // Si el sueño fue reparador, evaluar multiplicador para la mascota Nibi
      if (summary.coinsMultiplier > 1.0) {
        await _petDao.grantDailyReward(
          dateKey: date.dateKey,
          actionType: 'restorative_sleep',
          baseAmount: 15,
          sleepMultiplier: summary.coinsMultiplier,
        );
      }

      await _syncDao.updateCheckpoint(
        recordType: 'sleep',
        timestamp: DateTime.now(),
        readCount: 1,
      );

      return summary;
    } on MissingPluginException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Lee los pasos registrados en Health Connect para una fecha determinada (NEAT).
  Future<int> readStepsForDate(DateTime date) async {
    try {
      final int? steps = await _channel.invokeMethod<int>(
        'readStepsForDate',
        {'dateKey': date.dateKey},
      );
      if (steps != null) {
        await _syncDao.updateCheckpoint(
          recordType: 'steps',
          timestamp: DateTime.now(),
          readCount: steps,
        );
      }
      return steps ?? 0;
    } on MissingPluginException {
      return 0;
    } catch (_) {
      return 0;
    }
  }
}

/// Provider de Riverpod para inyectar HealthConnectService.
final healthConnectServiceProvider = Provider<HealthConnectService>((ref) {
  final syncDao = ref.watch(healthSyncDaoProvider);
  final petDao = ref.watch(petDaoProvider);
  return HealthConnectService(syncDao, petDao);
});
