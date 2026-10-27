import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/hardware/body_scale_driver.dart';
import 'package:nb_selfcare/features/body_metrics/application/scale_session.dart';

class _FakeScale implements BodyScaleDriver {
  final StreamController<ScaleMeasurementEvent> controller = StreamController<ScaleMeasurementEvent>.broadcast();
  int stops = 0;

  Future<void> close() => controller.close();

  @override
  String get driverName => 'fake';

  @override
  ScaleMeasurementEvent? parseRawData(Uint8List rawBytes, String deviceAddress) => null;

  @override
  Stream<ScaleMeasurementEvent> scanAndStreamMeasurements({String? targetMacAddress}) => controller.stream;

  @override
  Future<void> stopScan() async => stops++;
}

ScaleMeasurementEvent _event(double kg, {bool stable = true, int? ohms}) => ScaleMeasurementEvent(
      weightKg: kg,
      isStabilized: stable,
      hasImpedance: ohms != null,
      impedanceOhms: ohms,
      timestamp: DateTime(2026, 10, 26, 7),
      deviceAddress: 'AA:BB',
    );

void main() {
  late _FakeScale scale;
  late ProviderContainer c;

  setUp(() {
    scale = _FakeScale();
    c = ProviderContainer(overrides: [bodyScaleDriverProvider.overrideWithValue(scale)]);
  });

  tearDown(() async {
    c.dispose();
    await scale.close();
  });

  test('Con impedancia entrega la lectura completa y detiene el escaneo', () {
    fakeAsync((FakeAsync async) {
      c.read(scaleSessionProvider.notifier).start(weightOnly: false);
      scale.controller.add(_event(80.4, stable: false));
      async.flushMicrotasks();
      expect(c.read(scaleSessionProvider).phase, ScalePhase.measuring);

      scale.controller.add(_event(80.2, ohms: 480));
      async.flushMicrotasks();
      final ScaleSessionState s = c.read(scaleSessionProvider);
      expect(s.capture?.impedanceOhms, 480);
      expect(s.isScanning, isFalse);
      expect(scale.stops, 1);
    });
  });

  test('Sin impedancia espera 10 s y luego guarda solo el peso', () {
    fakeAsync((FakeAsync async) {
      c.read(scaleSessionProvider.notifier).start(weightOnly: false);
      scale.controller.add(_event(80.2));
      async.flushMicrotasks();
      expect(c.read(scaleSessionProvider).phase, ScalePhase.awaitingImpedance);

      async.elapse(const Duration(seconds: 9));
      expect(c.read(scaleSessionProvider).capture, isNull);
      async.elapse(const Duration(seconds: 2));
      expect(c.read(scaleSessionProvider).capture?.weightKg, 80.2);
      expect(c.read(scaleSessionProvider).capture?.impedanceOhms, isNull);
    });
  });

  test('Con contraindicación de impedancia entrega el peso al estabilizarse', () {
    fakeAsync((FakeAsync async) {
      c.read(scaleSessionProvider.notifier).start(weightOnly: true);
      scale.controller.add(_event(64));
      async.flushMicrotasks();
      expect(c.read(scaleSessionProvider).capture?.weightKg, 64);
    });
  });

  test('Las tramas que llegan tras capturar no generan un segundo pesaje', () {
    fakeAsync((FakeAsync async) {
      final ScaleSession session = c.read(scaleSessionProvider.notifier);
      session.start(weightOnly: false);
      scale.controller.add(_event(80.2, ohms: 480));
      async.flushMicrotasks();
      session.consumeCapture();
      scale.controller.add(_event(80.2, ohms: 481));
      async.flushMicrotasks();
      expect(c.read(scaleSessionProvider).capture, isNull);
    });
  });
}
