import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/platform/health_connect_gateway.dart';
import 'package:nb_selfcare/core/platform/notification_gateway.dart';
import 'package:nb_selfcare/core/platform/system_permissions.dart';

/// El puente nativo puede fallar de muchas formas: canal sin implementar (app
/// recién actualizada sin reiniciar), excepciones de Android, permisos
/// revocados a mitad de la llamada o respuestas con un tipo inesperado. Ninguna
/// de ellas debe llegar a la interfaz como excepción.
const MethodChannel _health = MethodChannel('com.nb.selfcare/health_connect');
const MethodChannel _notifications = MethodChannel('com.nb.selfcare/notifications');
const MethodChannel _system = MethodChannel('com.nb.selfcare/system');

void _respond(MethodChannel channel, Object? Function(MethodCall call) handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    channel,
    (MethodCall call) async => handler(call),
  );
}

void _unimplemented(MethodChannel channel) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    channel,
    null,
  );
}

/// Respuestas hostiles: excepción de Android y tipos equivocados.
final Map<String, Object? Function(MethodCall)> _hostile = <String, Object? Function(MethodCall)>{
  'PlatformException': (MethodCall c) =>
      throw PlatformException(code: 'SecurityException', message: 'revoked'),
  'cadena en vez de bool/mapa': (MethodCall c) => 'yes',
  'número en vez de bool/mapa': (MethodCall c) => 42,
  'lista en vez de mapa': (MethodCall c) => <Object?>[1, 2, 3],
  'mapa vacío': (MethodCall c) => <String, Object?>{},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    for (final MethodChannel c in <MethodChannel>[_health, _notifications, _system]) {
      _respond(c, (MethodCall call) => null);
    }
  });

  group('Health Connect: degradación sin excepciones', () {
    const MethodChannelHealthConnectGateway gateway = MethodChannelHealthConnectGateway();

    Future<void> exerciseAll() async {
      await gateway.availability();
      expect(await gateway.hasPermissions(), isA<bool>());
      expect(await gateway.requestPermissions(), isA<bool>());
      expect(await gateway.openSettings(), isA<bool>());
      expect(await gateway.supportsBackgroundReads(), isA<bool>());
      expect(await gateway.hasBackgroundReadPermission(), isA<bool>());
      await gateway.readDailyActivity('2026-10-27');
      expect(
        await gateway.writeWeight(weightKg: 80, at: DateTime(2026), fromScale: true),
        isA<bool>(),
      );
      expect(await gateway.writeHydration(volumeMl: 250, at: DateTime(2026)), isA<bool>());
    }

    for (final MapEntry<String, Object? Function(MethodCall)> e in _hostile.entries) {
      test('respuesta: ${e.key}', () async {
        _respond(_health, e.value);
        await expectLater(exerciseAll(), completes);
        expect(await gateway.availability(), HealthConnectAvailability.unsupported);
        expect(await gateway.hasPermissions(), isFalse);
      });
    }

    test('canal sin implementar (MissingPluginException)', () async {
      _unimplemented(_health);
      await expectLater(exerciseAll(), completes);
      expect(await gateway.readDailyActivity('2026-10-27'), isNull);
    });

    test('datos de actividad con valores imposibles se descartan o se acotan', () async {
      _respond(
        _health,
        (MethodCall call) => <String, Object?>{
          'steps': -500,
          'sleepMinutes': 5000,
          'deepMinutes': 9000,
          'remMinutes': -3,
          'restingHeartRate': double.nan,
        },
      );
      final DailyActivitySnapshot? s = await gateway.readDailyActivity('2026-10-27');
      expect(s, isNotNull);
      expect(s!.steps, isNull, reason: 'pasos negativos no son un dato');
      expect(s.sleepMinutes, lessThanOrEqualTo(24 * 60));
      expect(s.deepSleepMinutes, inInclusiveRange(0, s.sleepMinutes ?? 0));
      expect(s.remSleepMinutes, inInclusiveRange(0, s.sleepMinutes ?? 0));
      expect(s.restingHeartRateBpm, isNull, reason: 'NaN no es una frecuencia cardiaca');
    });

    test('datos con decimales, cadenas e infinitos', () async {
      _respond(
        _health,
        (MethodCall call) => <String, Object?>{
          'steps': 1234.7,
          'sleepMinutes': '420',
          'restingHeartRate': double.infinity,
        },
      );
      final DailyActivitySnapshot? s = await gateway.readDailyActivity('2026-10-27');
      expect(s!.steps, 1234);
      expect(s.sleepMinutes, isNull);
      expect(s.restingHeartRateBpm, isNull);
    });

    test('FC en reposo fuera de rango fisiológico (sensor mal colocado)', () async {
      _respond(
        _health,
        (MethodCall call) => <String, Object?>{'steps': 8000, 'restingHeartRate': 4},
      );
      expect((await gateway.readDailyActivity('2026-10-27'))!.restingHeartRateBpm, isNull);
      _respond(
        _health,
        (MethodCall call) => <String, Object?>{'steps': 8000, 'restingHeartRate': 400},
      );
      expect((await gateway.readDailyActivity('2026-10-27'))!.restingHeartRateBpm, isNull);
    });
  });

  group('Notificaciones: nunca rompen el flujo que las pide', () {
    const MethodChannelNotificationGateway gateway = MethodChannelNotificationGateway();

    Future<void> exerciseAll() async {
      await gateway.showFastingTimer(startedAt: DateTime(2026), targetHours: 16, protocol: '16:8');
      await gateway.cancelFastingTimer();
      await gateway.setReminders(const <ScheduledReminder>[]);
      await gateway.setMovementNudges(enabled: true);
    }

    for (final MapEntry<String, Object? Function(MethodCall)> e in _hostile.entries) {
      test('respuesta: ${e.key}', () async {
        _respond(_notifications, e.value);
        await expectLater(exerciseAll(), completes);
      });
    }

    test('canal sin implementar', () async {
      _unimplemented(_notifications);
      await expectLater(exerciseAll(), completes);
    });
  });

  group('Permisos del sistema', () {
    const MethodChannelSystemPermissions gateway = MethodChannelSystemPermissions();

    for (final MapEntry<String, Object? Function(MethodCall)> e in _hostile.entries) {
      test('respuesta: ${e.key}', () async {
        _respond(_system, e.value);
        for (final AppPermission p in AppPermission.values) {
          expect(await gateway.isGranted(p), isFalse);
          expect(await gateway.request(p), isFalse);
        }
        expect(await gateway.openAppSettings(), isFalse);
        expect(await gateway.consumeLaunchAction(), anyOf(isNull, isA<String>()));
      });
    }

    test('canal sin implementar', () async {
      _unimplemented(_system);
      expect(await gateway.isGranted(AppPermission.values.first), isFalse);
      expect(await gateway.consumeLaunchAction(), isNull);
    });
  });
}
