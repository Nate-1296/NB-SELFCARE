import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../clock/clock.dart';
import '../../constants/ble_uuids.dart';
import '../body_scale_driver.dart';

/// Controlador de hardware para la Xiaomi Mi Body Composition Scale 2 (XMTZC05HM).
///
/// Realiza escaneo pasivo de los anuncios BLE (Service Data 0x181B / 0x181D)
/// permitiendo capturar peso e impedancia en tiempo real sin emparejamiento invasivo
/// ni falsos positivos de otros periféricos Bluetooth cercanos.
class XiaomiMiScale2Driver implements BodyScaleDriver {
  XiaomiMiScale2Driver({this._clock = const Clock()});

  final Clock _clock;

  /// Identificador oficial Bluetooth SIG de Huami / Xiaomi Anhui Huami Information Tech.
  static const int huamiCompanyId = 0x0157;

  StreamController<ScaleMeasurementEvent>? _scanController;
  bool _isScanning = false;

  @override
  String get driverName => 'Xiaomi Mi Body Composition Scale 2 (XMTZC05HM)';

  @override
  ScaleMeasurementEvent? parseRawData(Uint8List rawBytes, String deviceAddress) {
    return parseRawAdvertisement(rawBytes, deviceAddress, receivedAt: _clock.now());
  }

  /// Extrae de forma estricta la trama de báscula únicamente si proviene del
  /// Service Data oficial (0x181B Body Composition / 0x181D Weight Scale),
  /// o de Manufacturer Data de Huami (0x0157) / dispositivo explícitamente identificado.
  static Uint8List? extractScalePayloadForDevice(
    BleDevice device, {
    String? targetMacAddress,
  }) {
    final bool macMatched = targetMacAddress != null &&
        targetMacAddress.isNotEmpty &&
        device.deviceId.toUpperCase() == targetMacAddress.toUpperCase();

    if (targetMacAddress != null &&
        targetMacAddress.isNotEmpty &&
        !macMatched) {
      return null;
    }

    // 1. Prioridad máxima: Service Data estándar 0x181B (Body Composition) o 0x181D (Weight Scale)
    for (final entry in device.serviceData.entries) {
      final String key = entry.key.toLowerCase();
      if ((key.contains('181b') || key.contains('181d')) &&
          entry.value.length >= 13) {
        return entry.value;
      }
    }

    // 2. Respaldo verificado: Manufacturer Data solo si Company ID es Huami (0x0157),
    //    la MAC fue vinculada por el usuario, o el nombre coincide con Mi Scale 2.
    final String? name = device.name;
    final bool matchesKnownName = name != null &&
        BleUuids.knownMiScale2Names.any(
          (known) => name.toUpperCase().contains(known),
        );

    for (final mfg in device.manufacturerDataList) {
      if (mfg.payload.length < 13) continue;
      if (mfg.companyId == huamiCompanyId || macMatched || matchesKnownName) {
        return mfg.payload;
      }
    }

    return null;
  }

  /// Decodifica la trama canónica de 13 bytes emitida por la báscula Xiaomi.
  /// [receivedAt] se usa como marca de tiempo cuando la trama no trae una fecha válida.
  static ScaleMeasurementEvent? parseRawAdvertisement(
    Uint8List rawBytes,
    String deviceAddress, {
    required DateTime receivedAt,
  }) {
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
        timestamp = receivedAt;
      }
    } catch (_) {
      timestamp = receivedAt;
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

    Future<void> initAndScan() async {
      try {
        final hasPerms = await UniversalBle.hasPermissions();
        if (!hasPerms) {
          await UniversalBle.requestPermissions();
        }

        final state = await UniversalBle.getBluetoothAvailabilityState();
        if (state != AvailabilityState.poweredOn) {
          await UniversalBle.enableBluetooth();
        }
      } catch (_) {
        // Continuar con el escaneo nativo si la consulta previa no es soportada
      }

      UniversalBle.onScanResult = (BleDevice device) {
        final Uint8List? payload = extractScalePayloadForDevice(
          device,
          targetMacAddress: targetMacAddress,
        );
        if (payload == null) return;

        final ScaleMeasurementEvent? event =
            parseRawAdvertisement(payload, device.deviceId, receivedAt: _clock.now());
        if (event != null &&
            _scanController != null &&
            !_scanController!.isClosed) {
          _scanController!.add(event);
        }
      };

      try {
        await UniversalBle.startScan();
      } catch (err) {
        if (_scanController != null && !_scanController!.isClosed) {
          _scanController!.addError('Error al iniciar escaneo BLE: $err');
        }
      }
    }

    unawaited(initAndScan());
    return _scanController!.stream;
  }

  void _handleScanCancel() {
    unawaited(stopScan());
  }

  @override
  Future<void> stopScan() async {
    if (!_isScanning) return;
    _isScanning = false;
    UniversalBle.onScanResult = null;
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
  final driver = XiaomiMiScale2Driver(clock: ref.watch(clockProvider));
  ref.onDispose(() {
    unawaited(driver.stopScan());
  });
  return driver;
});
