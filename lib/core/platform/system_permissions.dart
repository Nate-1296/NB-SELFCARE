import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'native_call.dart';

/// Permisos del sistema que la app solicita, siempre con un propósito local.
enum AppPermission {
  camera('android.permission.CAMERA'),
  notifications('android.permission.POST_NOTIFICATIONS'),
  exactAlarms('android.permission.SCHEDULE_EXACT_ALARM'),
  microphone('android.permission.RECORD_AUDIO');

  const AppPermission(this.androidName);

  final String androidName;
}

abstract interface class SystemPermissions {
  Future<bool> isGranted(AppPermission permission);

  /// Muestra el diálogo del sistema (o la pantalla de ajustes para alarmas exactas).
  Future<bool> request(AppPermission permission);

  Future<bool> openAppSettings();

  /// Acción con la que el sistema abrió la app (p. ej. `privacy_policy` desde Health Connect).
  Future<String?> consumeLaunchAction();
}

class MethodChannelSystemPermissions implements SystemPermissions {
  const MethodChannelSystemPermissions();

  static const MethodChannel _channel = MethodChannel('com.nb.selfcare/system');

  Future<bool> _invoke(String method, [Map<String, Object?>? args]) async =>
      await callNative<bool>(_channel, method, args) ?? false;

  @override
  Future<bool> isGranted(AppPermission permission) =>
      _invoke('checkPermission', <String, Object?>{'permission': permission.androidName});

  @override
  Future<bool> request(AppPermission permission) =>
      _invoke('requestPermission', <String, Object?>{'permission': permission.androidName});

  @override
  Future<bool> openAppSettings() => _invoke('openAppSettings');

  @override
  Future<String?> consumeLaunchAction() => callNative<String>(_channel, 'consumeLaunchAction');
}

final systemPermissionsProvider = Provider<SystemPermissions>(
  (Ref ref) => const MethodChannelSystemPermissions(),
);
