import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/hardware/body_scale_driver.dart';
import '../../../core/hardware/drivers/xiaomi_miscale2_driver.dart';
import '../../../core/platform/native_call.dart';

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

  /// No llegó ninguna trama en [ScaleSession.searchTimeout]: la radio se apaga
  /// para no gastar batería.
  notFound,
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

  /// Búsqueda máxima sin recibir nada de la báscula.
  static const Duration searchTimeout = Duration(seconds: 90);

  StreamSubscription<ScaleMeasurementEvent>? _subscription;
  Timer? _graceTimer;
  Timer? _searchTimer;
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
    _searchTimer = Timer(searchTimeout, () {
      if (state.phase != ScalePhase.searching) return;
      _release();
      state = const ScaleSessionState(phase: ScalePhase.notFound);
      unawaited(bestEffort(ref.read(bodyScaleDriverProvider).stopScan, null));
    });
    _subscription = ref
        .read(bodyScaleDriverProvider)
        .scanAndStreamMeasurements(targetMacAddress: targetMacAddress)
        .listen(_onEvent, onError: _onError, onDone: _onDone);
  }

  Future<void> stop() async {
    _release();
    state = ScaleSessionState(live: state.live);
    await bestEffort(ref.read(bodyScaleDriverProvider).stopScan, null);
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
    _searchTimer?.cancel();
    _searchTimer = null;
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

  /// El escaneo terminó solo (Bluetooth apagado, límite de tiempo del sistema).
  /// Si ya había un peso estable se guarda; si no, se avisa en vez de quedarse
  /// "buscando" para siempre.
  void _onDone() {
    if (_captured) return;
    final ScaleMeasurementEvent? live = state.live;
    if (live != null && live.isStabilized) {
      unawaited(_capture(live));
    } else {
      _onError(StateError('scan_ended'));
    }
  }

  void _onError(Object error) {
    _release();
    state = ScaleSessionState(phase: ScalePhase.error, live: state.live, error: error);
  }

  Future<void> _capture(ScaleMeasurementEvent event) async {
    if (_captured) return;
    _captured = true;
    _release();
    // El peso se entrega antes de apagar la radio: si stopScan falla (Bluetooth
    // apagado a mitad), la lectura no se pierde.
    state = ScaleSessionState(live: event, capture: event);
    await bestEffort(ref.read(bodyScaleDriverProvider).stopScan, null);
  }

  void _release() {
    _graceTimer?.cancel();
    _graceTimer = null;
    _searchTimer?.cancel();
    _searchTimer = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
  }
}

final scaleSessionProvider = NotifierProvider<ScaleSession, ScaleSessionState>(ScaleSession.new);
