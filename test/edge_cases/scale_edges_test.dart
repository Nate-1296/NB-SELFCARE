import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/hardware/body_scale_driver.dart';
import 'package:nb_selfcare/core/hardware/drivers/xiaomi_miscale2_driver.dart';
import 'package:nb_selfcare/features/body_metrics/application/scale_session.dart';

/// Báscula simulada con fallos de radio configurables.
class _FlakyScale implements BodyScaleDriver {
  _FlakyScale({this.stopThrows = false});

  final bool stopThrows;
  // ignore: close_sinks — lo cierra cada test (simula que el Bluetooth se apaga) o el GC.
  StreamController<ScaleMeasurementEvent> controller = StreamController<ScaleMeasurementEvent>();
  bool _scanned = false;

  @override
  String get driverName => 'flaky';

  @override
  ScaleMeasurementEvent? parseRawData(Uint8List rawBytes, String deviceAddress) => null;

  @override
  Stream<ScaleMeasurementEvent> scanAndStreamMeasurements({String? targetMacAddress}) {
    // Cada escaneo es un flujo nuevo, como en el controlador real.
    if (_scanned) controller = StreamController<ScaleMeasurementEvent>();
    _scanned = true;
    return controller.stream;
  }

  @override
  Future<void> stopScan() async {
    if (stopThrows) throw StateError('Bluetooth apagado');
  }
}

ScaleMeasurementEvent _event(double kg, {bool stable = true, int? ohms}) => ScaleMeasurementEvent(
  weightKg: kg,
  isStabilized: stable,
  hasImpedance: ohms != null,
  impedanceOhms: ohms,
  timestamp: DateTime(2026, 10, 27, 7),
  deviceAddress: 'AA:BB:CC:DD:EE:FF',
);

/// Trama de 13 bytes de la Mi Scale 2 en kg.
Uint8List _frame({
  required int raw200,
  int ohms = 0,
  bool stable = true,
  bool impedance = false,
  int ctrl0 = 0x02,
}) {
  final int ctrl1 = (stable ? 0x20 : 0) | (impedance ? 0x02 : 0);
  return Uint8List.fromList(<int>[
    ctrl0, ctrl1, 0xEA, 0x07, 10, 27, 7, 15, 0, //
    ohms & 0xFF, ohms >> 8, raw200 & 0xFF, raw200 >> 8,
  ]);
}

void main() {
  group('Protocolo BLE de la Mi Scale 2', () {
    test('50 000 tramas aleatorias: nunca lanza y nunca da un peso imposible', () {
      final Random rng = Random(20261027);
      int accepted = 0;
      for (int i = 0; i < 50000; i++) {
        final Uint8List bytes = Uint8List.fromList(
          List<int>.generate(rng.nextInt(24), (_) => rng.nextInt(256)),
        );
        final ScaleMeasurementEvent? e = XiaomiMiScale2Driver.parseRawAdvertisement(
          bytes,
          'AA',
          receivedAt: DateTime(2026, 10, 27),
        );
        if (e == null) continue;
        accepted++;
        expect(e.weightKg, inExclusiveRange(1.0, 350.01));
        expect(e.weightKg.isFinite, isTrue);
        if (e.impedanceOhms != null) expect(e.impedanceOhms, inInclusiveRange(100, 3000));
      }
      expect(accepted, greaterThan(0), reason: 'la prueba también debe ejercitar tramas válidas');
    });

    test('tramas cortas, vacías y de carga histórica se ignoran', () {
      final DateTime t = DateTime(2026, 10, 27);
      expect(XiaomiMiScale2Driver.parseRawAdvertisement(Uint8List(0), 'AA', receivedAt: t), isNull);
      expect(
        XiaomiMiScale2Driver.parseRawAdvertisement(Uint8List(12), 'AA', receivedAt: t),
        isNull,
      );
      final Uint8List historical = _frame(raw200: 16000)..[1] |= 0x80;
      expect(XiaomiMiScale2Driver.parseRawAdvertisement(historical, 'AA', receivedAt: t), isNull);
    });

    test('fecha de la báscula inválida (pila cambiada): se usa la hora del teléfono', () {
      final DateTime t = DateTime(2026, 10, 27, 7, 20);
      final Uint8List bad = _frame(raw200: 16000)
        ..[2] = 0xD0
        ..[3] =
            0x07 // año 2000
        ..[4] = 13; // mes 13
      expect(XiaomiMiScale2Driver.parseRawAdvertisement(bad, 'AA', receivedAt: t)!.timestamp, t);
      final Uint8List feb30 = _frame(raw200: 16000)
        ..[4] = 2
        ..[5] = 31;
      final ScaleMeasurementEvent e = XiaomiMiScale2Driver.parseRawAdvertisement(
        feb30,
        'AA',
        receivedAt: t,
      )!;
      expect(
        e.timestamp.month == 2 || e.timestamp == t,
        isTrue,
        reason: 'un 31 de febrero no puede saltar a marzo',
      );
    });

    test('unidades: kg, libras y catties dan el mismo peso', () {
      final DateTime t = DateTime(2026, 10, 27);
      final double kg = XiaomiMiScale2Driver.parseRawAdvertisement(
        _frame(raw200: 16000),
        'AA',
        receivedAt: t,
      )!.weightKg;
      final double lbs = XiaomiMiScale2Driver.parseRawAdvertisement(
        _frame(raw200: 17637, ctrl0: 0x03),
        'AA',
        receivedAt: t,
      )!.weightKg;
      final double catty = XiaomiMiScale2Driver.parseRawAdvertisement(
        _frame(raw200: 16000, ctrl0: 0x12),
        'AA',
        receivedAt: t,
      )!.weightKg;
      expect(kg, closeTo(80, 0.01));
      expect(lbs, closeTo(80, 0.01));
      expect(catty, closeTo(80, 0.01));
    });

    test('bioimpedancia fuera de rango (pies mojados, calcetines) se descarta', () {
      final DateTime t = DateTime(2026, 10, 27);
      for (final int ohms in <int>[0, 50, 99, 3001, 65535]) {
        expect(
          XiaomiMiScale2Driver.parseRawAdvertisement(
            _frame(raw200: 16000, ohms: ohms, impedance: true),
            'AA',
            receivedAt: t,
          )!.impedanceOhms,
          isNull,
          reason: '$ohms Ω',
        );
      }
    });
  });

  group('Sesión de pesaje con fallos de radio', () {
    test('Bluetooth se apaga en mitad de la búsqueda: no se queda "buscando" para siempre', () {
      fakeAsync((FakeAsync async) {
        final _FlakyScale scale = _FlakyScale();
        final ProviderContainer c = ProviderContainer(
          overrides: [bodyScaleDriverProvider.overrideWithValue(scale)],
        );
        c.read(scaleSessionProvider.notifier).start(weightOnly: false);
        unawaited(scale.controller.close());
        async.flushMicrotasks();
        expect(c.read(scaleSessionProvider).phase, ScalePhase.error);
        c.dispose();
      });
    });

    test('se apaga después de un peso estable: el peso se guarda', () {
      fakeAsync((FakeAsync async) {
        final _FlakyScale scale = _FlakyScale();
        final ProviderContainer c = ProviderContainer(
          overrides: [bodyScaleDriverProvider.overrideWithValue(scale)],
        );
        c.read(scaleSessionProvider.notifier).start(weightOnly: false);
        scale.controller.add(_event(72.3));
        async.flushMicrotasks();
        expect(c.read(scaleSessionProvider).phase, ScalePhase.awaitingImpedance);
        unawaited(scale.controller.close());
        async.flushMicrotasks();
        expect(c.read(scaleSessionProvider).capture?.weightKg, 72.3);
        c.dispose();
      });
    });

    test('detener la radio falla: la lectura igualmente se entrega', () {
      fakeAsync((FakeAsync async) {
        final _FlakyScale scale = _FlakyScale(stopThrows: true);
        final ProviderContainer c = ProviderContainer(
          overrides: [bodyScaleDriverProvider.overrideWithValue(scale)],
        );
        c.read(scaleSessionProvider.notifier).start(weightOnly: false);
        scale.controller.add(_event(72.3, ohms: 480));
        async.flushMicrotasks();
        expect(c.read(scaleSessionProvider).capture?.impedanceOhms, 480);
        unawaited(c.read(scaleSessionProvider.notifier).stop());
        async.flushMicrotasks();
        expect(c.read(scaleSessionProvider).phase, ScalePhase.idle);
        c.dispose();
      });
    });

    test('error del escáner y reintento inmediato', () {
      fakeAsync((FakeAsync async) {
        final _FlakyScale first = _FlakyScale();
        final ProviderContainer c = ProviderContainer(
          overrides: [bodyScaleDriverProvider.overrideWithValue(first)],
        );
        c.read(scaleSessionProvider.notifier).start(weightOnly: true);
        first.controller.addError(StateError('GATT 133'));
        async.flushMicrotasks();
        expect(c.read(scaleSessionProvider).phase, ScalePhase.error);
        c.read(scaleSessionProvider.notifier).start(weightOnly: true);
        expect(c.read(scaleSessionProvider).phase, ScalePhase.searching);
        c.dispose();
      });
    });

    test('muchas tramas inestables y luego estable con impedancia tardía', () {
      fakeAsync((FakeAsync async) {
        final _FlakyScale scale = _FlakyScale();
        final ProviderContainer c = ProviderContainer(
          overrides: [bodyScaleDriverProvider.overrideWithValue(scale)],
        );
        c.read(scaleSessionProvider.notifier).start(weightOnly: false);
        for (int i = 0; i < 200; i++) {
          scale.controller.add(_event(70 + (i % 7) / 10, stable: false));
        }
        scale.controller.add(_event(70.4));
        async.elapse(const Duration(seconds: 4));
        scale.controller.add(_event(70.4, ohms: 505));
        async.flushMicrotasks();
        expect(c.read(scaleSessionProvider).capture?.impedanceOhms, 505);
        // Tramas que llegan después de capturar no cambian nada.
        scale.controller.add(_event(95));
        async.flushMicrotasks();
        expect(c.read(scaleSessionProvider).capture?.weightKg, 70.4);
        c.dispose();
      });
    });
  });
}
