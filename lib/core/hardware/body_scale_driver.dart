import 'dart:typed_data';

/// Evento emitido durante la lectura pasiva de una báscula corporal BLE.
class ScaleMeasurementEvent {
  const ScaleMeasurementEvent({
    required this.weightKg,
    required this.isStabilized,
    required this.hasImpedance,
    required this.timestamp,
    required this.deviceAddress,
    this.impedanceOhms,
    this.unit = 'kg',
  });

  /// Peso medido en kilogramos.
  final double weightKg;

  /// Indica si el peso se ha estabilizado (el usuario permanece inmóvil).
  final bool isStabilized;

  /// Indica si la báscula completó el análisis de bioimpedancia eléctrica (BIA).
  final bool hasImpedance;

  /// Resistencia eléctrica en ohmios (Ω) medida a través de los 4 electrodos.
  final int? impedanceOhms;

  /// Fecha y hora reportada en la trama BLE o al momento de la captura.
  final DateTime timestamp;

  /// Dirección MAC o identificador BLE del dispositivo.
  final String deviceAddress;

  /// Unidad de medida detectada ('kg', 'lbs', 'catty').
  final String unit;

  @override
  String toString() {
    return 'ScaleMeasurementEvent(weight: ${weightKg.toStringAsFixed(2)} $unit, '
        'stabilized: $isStabilized, impedance: $impedanceOhms Ω, device: $deviceAddress)';
  }
}

/// Contrato abstracto para controladores de básculas corporales.
///
/// Permite que la comunidad integre nuevos modelos de básculas manteniendo
/// la separación entre el protocolo de hardware y la lógica de negocio.
abstract interface class BodyScaleDriver {
  /// Nombre legible del modelo de báscula que implementa el controlador.
  String get driverName;

  /// Emite un stream reactivo de mediciones mientras el escaneo esté activo.
  Stream<ScaleMeasurementEvent> scanAndStreamMeasurements({String? targetMacAddress});

  /// Detiene el escaneo BLE y libera recursos de radio.
  Future<void> stopScan();

  /// Decodifica una trama cruda de bytes recibida por anuncio publicitario (Advertisement)
  /// o notificación GATT. Retorna null si la trama no corresponde a este controlador.
  ScaleMeasurementEvent? parseRawData(Uint8List rawBytes, String deviceAddress);
}
