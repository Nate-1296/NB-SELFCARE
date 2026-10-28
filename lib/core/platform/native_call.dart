import 'package:flutter/services.dart';

/// Llama a un método del puente nativo sin lanzar nunca.
///
/// Devuelve `null` si el canal no existe (app actualizada sin reiniciar), si
/// Android lanza una excepción (permiso revocado, servicio caído) o si la
/// respuesta no es del tipo esperado: `invokeMethod<T>` haría un `as T` que,
/// con un tipo inesperado, rompería la pantalla con un `TypeError`.
Future<T?> callNative<T>(MethodChannel channel, String method, [Object? arguments]) async {
  try {
    final Object? raw = await channel.invokeMethod<Object?>(method, arguments);
    return raw is T ? raw : null;
  } on PlatformException {
    return null;
  } on MissingPluginException {
    return null;
  }
}

/// Ejecuta un efecto secundario nativo (exportar a Health Connect, mostrar una
/// notificación) después de haber guardado en local. Si falla por cualquier
/// motivo devuelve [fallback]: lo registrado por el usuario ya está a salvo y
/// la pantalla no debe mostrar un error por algo que no depende de la app.
Future<T> bestEffort<T>(Future<T> Function() action, T fallback) async {
  try {
    return await action();
  } on Object {
    return fallback;
  }
}
