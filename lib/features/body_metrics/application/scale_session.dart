import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/hardware/body_scale_driver.dart';
import '../../../core/hardware/drivers/xiaomi_miscale2_driver.dart';

/// Báscula activa. Hoy solo la Mi Scale 2; el contrato permite añadir otras.
final bodyScaleDriverProvider = Provider<BodyScaleDriver>((Ref ref) {
  return ref.watch(xiaomiMiScale2DriverProvider);
});

enum ScalePhase {
  idle,

  /// Escaneando sin tramas todavía.
  searching,

  /// Llegan tramas pero el peso aún no se estabiliza.
  measuring,

  /// Peso estable; esperando a que los electrodos terminen la bioimpedancia.
  awaitingImpedance,

  error,
}

class ScaleSessionState {
  const ScaleSessionState({
    this.phase = ScalePhase.idle,
    this.live,
    this.capture,
    this.error,
  });

  final ScalePhase phase;

  /// Última trama recibida (para mostrar el peso en vivo).
  final ScaleMeasurementEvent? live;

  /// Lectura final lista para guardar. La UI la consume con
  /// [ScaleSession.consumeCapture] tras confirmarla.
  final ScaleMeasurementEvent? capture;

  final Object? error;

  bool get isScanning =>
      phase == ScalePhase.searching || phase == ScalePhase.measuring || phase == ScalePhase.awaitingImpedance;
}

/// Sesión de pesaje con la báscula BLE (docs/04 §1).
///
/// Con el peso estable espera hasta [impedanceGrace] a que llegue la
/// bioimpedancia; si no llega, entrega solo el peso. Con contraindicación de
/// impedancia (marcapasos, embarazo) entrega el peso en cuanto se estabiliza.
class ScaleSession extends Notifier<ScaleSessionState> {
  static const Duration impedanceGrace = Duration(seconds: 10);

  StreamSubscription<ScaleMeasurementEvent>? _subscription;
  Timer? _graceTimer;
  bool _weightOnly = false;
  bool _captured = false;

  @override
  ScaleSessionState build() {
    ref.onDispose(_release);
    return const ScaleSessionState();
  }

  void start({String? targetMacAddress, required bool weightOnly}) {
    _release();
    _weightOnly = weightOnly;
    _captured = false;
    state = const ScaleSessionState(phase: ScalePhase.searching);
    _subscription = ref
        .read(bodyScaleDriverProvider)
        .scanAndStreamMeasurements(targetMacAddress: targetMacAddress)
        .listen(_onEvent, onError: _onError);
  }

  Future<void> stop() async {
    _release();
    await ref.read(bodyScaleDriverProvider).stopScan();
    state = ScaleSessionState(live: state.live);
  }

  /// Guarda el peso estable sin esperar a la bioimpedancia.
  void acceptWeightOnly() {
    final ScaleMeasurementEvent? live = state.live;
    if (live != null && live.isStabilized) unawaited(_capture(live));
  }

  void consumeCapture() {
    if (state.capture != null) state = ScaleSessionState(phase: state.phase, live: state.live);
  }

  void _onEvent(ScaleMeasurementEvent event) {
    if (_captured) return;
    if (!event.isStabilized) {
      state = ScaleSessionState(phase: ScalePhase.measuring, live: event);
      return;
    }
    final bool hasImpedance = event.hasImpedance && (event.impedanceOhms ?? 0) > 0;
    if (_weightOnly || hasImpedance) {
      unawaited(_capture(event));
      return;
    }
    state = ScaleSessionState(phase: ScalePhase.awaitingImpedance, live: event);
    _graceTimer ??= Timer(impedanceGrace, () {
      final ScaleMeasurementEvent? latest = state.live;
      if (latest != null) unawaited(_capture(latest));
    });
  }

  void _onError(Object error) {
    _release();
    state = ScaleSessionState(phase: ScalePhase.error, live: state.live, error: error);
  }

  Future<void> _capture(ScaleMeasurementEvent event) async {
    if (_captured) return;
    _captured = true;
    _release();
    await ref.read(bodyScaleDriverProvider).stopScan();
    state = ScaleSessionState(live: event, capture: event);
  }

  void _release() {
    _graceTimer?.cancel();
    _graceTimer = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
  }
}

final scaleSessionProvider = NotifierProvider<ScaleSession, ScaleSessionState>(ScaleSession.new);
