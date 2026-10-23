/// Identificadores GATT y UUIDs para periféricos de salud (básculas corporales).
abstract final class BleUuids {
  // Servicio estándar de Composición Corporal (Body Composition Service)
  static const String bodyCompositionService = '0000181b-0000-1000-8000-00805f9b34fb';
  static const int bodyCompositionServiceShort = 0x181B;

  // Característica estándar de Medición de Composición Corporal
  static const String bodyCompositionMeasurement = '00002a9c-0000-1000-8000-00805f9b34fb';
  static const int bodyCompositionMeasurementShort = 0x2A9C;

  // Servicio estándar de Peso (Weight Scale Service)
  static const String weightScaleService = '0000181d-0000-1000-8000-00805f9b34fb';
  static const int weightScaleServiceShort = 0x181D;

  // Característica estándar de Medición de Peso
  static const String weightMeasurement = '00002a9d-0000-1000-8000-00805f9b34fb';
  static const int weightMeasurementShort = 0x2A9D;

  // Vendor characteristic para sincronización histórica de Xiaomi
  static const String miScaleHistory = '00002a2f-0000-3512-2118-0009af100700';

  // Nombres publicitarios conocidos de la Xiaomi Mi Body Composition Scale 2
  static const List<String> knownMiScale2Names = [
    'MIBFS',
    'MIBCS',
    'MI SCALE2',
    'XMTZC05HM',
  ];
}

