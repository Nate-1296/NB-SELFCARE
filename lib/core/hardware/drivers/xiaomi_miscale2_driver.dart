import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../constants/ble_uuids.dart';
import '../body_scale_driver.dart';

/// Controlador de hardware para la Xiaomi Mi Body Composition Scale 2 (XMTZC05HM).
///
/// Realiza escaneo pasivo de los anuncios BLE (Service Data 0x181B) permitiendo
/// capturar el peso y la impedancia en tiempo real sin requerir emparejamiento invasivo
/// ni abrir la aplicación oficial Zepp Life.
class XiaomiMiScale2Driver implements BodyScaleDriver {
  XiaomiMiScale2Driver();

  StreamController<ScaleMeasurementEvent>? _scanController;
  bool _isScanning = false;

  @override
  String get driverName => 'Xiaomi Mi Body Composition Scale 2 (XMTZC05HM)';

  @override
  ScaleMeasurementEvent? parseRawData(Uint8List rawBytes, String deviceAddress) {
    return parseRawAdvertisement(rawBytes, deviceAddress);
  }

  /// Decodifica la trama canónica de 13 bytes emitida por la báscula Xiaomi.
  static ScaleMeasurementEvent? parseRawAdvertisement(
    Uint8List rawBytes,
    String deviceAddress,
  ) {
    if (rawBytes.length < 13) return null;

    final int ctrl0 = rawBytes[0];
    final bool isLbs = (ctrl0 & 0x01) != 0;
    final bool isCatty = (ctrl0 & 0x10) != 0;
    final String unit = isLbs ? 'lbs' : (isCatty ? 'catty' : 'kg');

    final int ctrl1 = rawBytes[1];
    final bool hasImpedance = (ctrl1 & 0x02) != 0;
    final bool isStabilized = (ctrl1 & 0x20) != 0;
    final bool isHistoricalLoad = (ctrl1 & 0x80) != 0;

    // Descartar registros marcados como carga histórica en la trama en vivo
    if (isHistoricalLoad) return null;

    // Parseo de timestamp little-endian
    final int year = rawBytes[2] | (rawBytes[3] << 8);
    final int month = rawBytes[4];
    final int day = rawBytes[5];
    final int hour = rawBytes[6];
    final int minute = rawBytes[7];
    final int second = rawBytes[8];

    DateTime timestamp;
    try {
      if (year >= 2020 &&
          month >= 1 &&
          month <= 12 &&
          day >= 1 &&
          day <= 31 &&
          hour >= 0 &&
          hour <= 23 &&
          minute >= 0 &&
          minute <= 59 &&
          second >= 0 &&
          second <= 59) {
        timestamp = DateTime(year, month, day, hour, minute, second);
      } else {
        timestamp = DateTime.now();
      }
    } catch (_) {
      timestamp = DateTime.now();
    }

    // Parseo de impedancia en ohmios (Bytes 9 y 10 little-endian)
    final int rawImpedance = rawBytes[9] | (rawBytes[10] << 8);
    final int? impedanceOhms =
        (hasImpedance && rawImpedance >= 100 && rawImpedance <= 3000)
            ? rawImpedance
            : null;

    // Parseo de peso bruto (Bytes 11 y 12 little-endian)
    final int rawWeight = rawBytes[11] | (rawBytes[12] << 8);
    final double weightKg;

    if (isLbs) {
      weightKg = (rawWeight / 100.0) * 0.45359237;
    } else if (isCatty) {
      weightKg = (rawWeight / 100.0) * 0.5;
    } else {
      weightKg = rawWeight / 200.0;
    }

    // Filtro de ruido o valores anómalos
    if (weightKg <= 1.0 || weightKg > 350.0) return null;

    return ScaleMeasurementEvent(
      weightKg: weightKg,
      isStabilized: isStabilized,
      hasImpedance: impedanceOhms != null,
      impedanceOhms: impedanceOhms,
      timestamp: timestamp,
      deviceAddress: deviceAddress,
      unit: unit,
    );
  }

  @override
  Stream<ScaleMeasurementEvent> scanAndStreamMeasurements({
    String? targetMacAddress,
  }) {
    if (_isScanning && _scanController != null) {
      return _scanController!.stream;
    }

    _scanController = StreamController<ScaleMeasurementEvent>.broadcast(
      onCancel: _handleScanCancel,
    );

    _isScanning = true;

    UniversalBle.onScanResult = (BleDevice device) {
      // Si el usuario fijó una MAC específica, filtrar
      if (targetMacAddress != null &&
          device.deviceId.toUpperCase() != targetMacAddress.toUpperCase()) {
        return;
      }

      // 1. Verificar si incluye Service Data 0x181B
      final Uint8List? serviceData = _extractServiceData(device);
      if (serviceData != null) {
        final ScaleMeasurementEvent? event =
            parseRawAdvertisement(serviceData, device.deviceId);
        if (event != null && !_scanController!.isClosed) {
          _scanController!.add(event);
          return;
        }
      }

      // 2. Si el fabricante o el nombre coincide, inspeccionar datos de fabricante
      final String? name = device.name;
      final bool matchesKnownName = name != null &&
          BleUuids.knownMiScale2Names.any(
            (known) => name.toUpperCase().contains(known),
          );

      if (matchesKnownName && device.manufacturerDataList.isNotEmpty) {
        final Uint8List bytes = device.manufacturerDataList.first.payload;
        final ScaleMeasurementEvent? event =
            parseRawAdvertisement(bytes, device.deviceId);
        if (event != null && !_scanController!.isClosed) {
          _scanController!.add(event);
        }
      }
    };

    unawaited(UniversalBle.startScan());
    return _scanController!.stream;
  }

  void _handleScanCancel() {
    unawaited(stopScan());
  }

  Uint8List? _extractServiceData(BleDevice device) {
    for (final service in device.services) {
      if (service.toLowerCase().contains('181b')) {
        if (device.manufacturerDataList.isNotEmpty) {
          final Uint8List payload = device.manufacturerDataList.first.payload;
          if (payload.length >= 13) {
            return payload;
          }
        }
      }
    }
    return null;
  }

  @override
  Future<void> stopScan() async {
    if (!_isScanning) return;
    _isScanning = false;
    try {
      await UniversalBle.stopScan();
    } catch (_) {
      // Manejo silencioso de desconexión previa
    }
    await _scanController?.close();
    _scanController = null;
  }
}

/// Provider de Riverpod para inyectar el controlador de la báscula Xiaomi.
final xiaomiMiScale2DriverProvider = Provider<XiaomiMiScale2Driver>((ref) {
  final driver = XiaomiMiScale2Driver();
  ref.onDispose(() {
    unawaited(driver.stopScan());
  });
  return driver;
});
