import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'native_call.dart';

/// Capacidades del teléfono que no son permisos: modelo, marcador y vibración.
abstract interface class DeviceGateway {
  /// "Fabricante Modelo" (p. ej. "TCL T803E"), o `null` si no se sabe.
  Future<String?> deviceModel();

  /// Abre el marcador con [number] escrito; nunca llama por sí sola.
  Future<bool> dial(String number);

  /// Vibra con un patrón en milisegundos (espera, vibra, espera, vibra…).
  Future<void> vibrate(List<int> patternMs);
}

class MethodChannelDeviceGateway implements DeviceGateway {
  const MethodChannelDeviceGateway();

  static const MethodChannel _channel = MethodChannel('com.nb.selfcare/system');

  @override
  Future<String?> deviceModel() => callNative<String>(_channel, 'deviceModel');

  @override
  Future<bool> dial(String number) async =>
      await callNative<bool>(_channel, 'dial', <String, Object?>{'number': number}) ?? false;

  @override
  Future<void> vibrate(List<int> patternMs) async {
    await callNative<bool>(_channel, 'vibrate', <String, Object?>{'pattern': patternMs});
  }
}

/// Pantallas de papel conocidas (TCL NXTPAPER): solo para proponer la respuesta
/// en la bienvenida; la persona siempre decide.
bool looksLikePaperScreen(String? model) {
  final String m = (model ?? '').toLowerCase();
  return m.contains('nxtpaper') || m.startsWith('tcl');
}

final deviceGatewayProvider = Provider<DeviceGateway>(
  (Ref ref) => const MethodChannelDeviceGateway(),
);
