import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/hardware/drivers/xiaomi_miscale2_driver.dart';
import 'package:nb_selfcare/shared/utils/biometric_formulas.dart';

void main() {
  group('Xiaomi Mi Body Composition Scale 2 (Parser 13 bytes)', () {
    test('Decodifica correctamente trama estabilizada con impedancia en kg', () {
      // Trama simulada:
      // Byte 0: 0x02 (kg, no lbs, no catty)
      // Byte 1: 0x22 (bit 1 hasImpedance=1, bit 5 isStabilized=1)
      // Bytes 2..8: 2026-10-23 08:30:15 -> Year 2026 = 0x07EA -> [0xEA, 0x07], Month=10, Day=23, H=8, M=30, S=15
      // Bytes 9..10: Impedancia 500 Ohms -> 0x01F4 -> [0xF4, 0x01]
      // Bytes 11..12: Peso 72.5 kg -> raw = 72.5 * 200 = 14500 -> 0x38A4 -> [0xA4, 0x38]
      final rawBytes = Uint8List.fromList([
        0x02, // Ctrl 0 (kg)
        0x22, // Ctrl 1 (stabilized + hasImpedance)
        0xEA, 0x07, // 2026
        10, 23, 8, 30, 15, // Oct 23, 08:30:15
        0xF4, 0x01, // 500 Ohms
        0xA4, 0x38, // 14500 (72.5 kg)
      ]);

      final event = XiaomiMiScale2Driver.parseRawAdvertisement(rawBytes, 'AA:BB:CC:DD:EE:FF');

      expect(event, isNotNull);
      expect(event!.weightKg, closeTo(72.5, 0.01));
      expect(event.isStabilized, isTrue);
      expect(event.hasImpedance, isTrue);
      expect(event.impedanceOhms, equals(500));
      expect(event.unit, equals('kg'));
      expect(event.timestamp.year, equals(2026));
      expect(event.timestamp.month, equals(10));
      expect(event.timestamp.day, equals(23));
      expect(event.deviceAddress, equals('AA:BB:CC:DD:EE:FF'));
    });

    test('Descarta tramas históricas o menores a 13 bytes', () {
      // Trama histórica (bit 7 = 0x80)
      final historicalBytes = Uint8List.fromList([
        0x02,
        0xA2, // bit 7 activo (0x80 | 0x20 | 0x02)
        0xEA, 0x07, 10, 23, 8, 30, 15,
        0xF4, 0x01,
        0xA4, 0x38,
      ]);

      final event = XiaomiMiScale2Driver.parseRawAdvertisement(historicalBytes, 'AA:BB:CC:DD:EE:FF');
      expect(event, isNull);

      // Trama truncada (< 13 bytes)
      final truncatedBytes = Uint8List.fromList([0x02, 0x22, 0xEA]);
      expect(XiaomiMiScale2Driver.parseRawAdvertisement(truncatedBytes, 'AA:BB:CC:DD:EE:FF'), isNull);
    });
  });

  group('Fórmulas Biométricas y Fisiológicas (BiometricFormulas)', () {
    test('Cálculo de BMI y Derivación de las 13 métricas', () {
      final bmi = BiometricFormulas.calculateBmi(weightKg: 70.0, heightCm: 175.0);
      expect(bmi, closeTo(22.86, 0.05));

      final metrics = BiometricFormulas.deriveAllMetrics(
        weightKg: 70.0,
        heightCm: 175.0,
        ageYears: 28.0,
        isMale: true,
        impedanceOhms: 480,
      );

      expect(metrics.weightKg, equals(70.0));
      expect(metrics.bmi, closeTo(22.86, 0.05));
      expect(metrics.bodyFatPercentage, inInclusiveRange(10.0, 25.0));
      expect(metrics.muscleMassKg, greaterThan(45.0));
      expect(metrics.waterPercentage, inInclusiveRange(50.0, 70.0));
      expect(metrics.boneMassKg, inInclusiveRange(2.0, 4.0));
      expect(metrics.visceralFatIndex, inInclusiveRange(1, 15));
      expect(metrics.basalMetabolicRateKcal, inInclusiveRange(1400, 1900));
      expect(metrics.leanBodyMassKg, greaterThan(50.0));
      expect(metrics.bodyScore, inInclusiveRange(50, 100));
      expect(metrics.bodyType, isNotEmpty);
    });

    test('Ecuación US Navy y Fusión Validada (60% BIA + 40% Navy)', () {
      // Hombre: altura 178 cm, cintura 82 cm, cuello 38 cm
      final navyFat = BiometricFormulas.calculateNavyBodyFatPercentage(
        heightCm: 178.0,
        waistCm: 82.0,
        neckCm: 38.0,
        isMale: true,
      );
      expect(navyFat, inInclusiveRange(12.0, 18.0));

      final validated = BiometricFormulas.calculateValidatedBodyFat(
        biaBodyFatPercentage: 15.0,
        navyBodyFatPercentage: navyFat,
      );
      // Validated = 0.60 * 15.0 + 0.40 * navyFat
      expect(validated, closeTo(0.60 * 15.0 + 0.40 * navyFat, 0.1));
    });

    test('Peso Tendencia (EMA alpha = 0.1)', () {
      final ema1 = BiometricFormulas.calculateWeightEma(
        currentWeightKg: 75.0,
        previousEmaKg: null,
      );
      expect(ema1, equals(75.0));

      // Segundo pesaje sube a 76.0 kg: EMA = 75.0 + 0.1 * (76.0 - 75.0) = 75.10
      final ema2 = BiometricFormulas.calculateWeightEma(
        currentWeightKg: 76.0,
        previousEmaKg: 75.0,
      );
      expect(ema2, equals(75.10));
    });

    test('Detector de Falsa Subida por retención de agua / sodio / carbos', () {
      // Subida de +0.5 kg tras cena alta en sodio (> 2500 mg)
      final isSpikeSodium = BiometricFormulas.detectWaterRetentionSpike(
        currentWeightKg: 75.5,
        previousWeightKg: 75.0,
        yesterdaySodiumMg: 3200,
      );
      expect(isSpikeSodium, isTrue);

      // Subida de +0.5 kg por supercompensación de glucógeno (carbos > 1.3x promedio)
      final isSpikeCarbs = BiometricFormulas.detectWaterRetentionSpike(
        currentWeightKg: 75.5,
        previousWeightKg: 75.0,
        yesterdayCarbsGrams: 350.0,
        avg7dCarbsGrams: 200.0,
      );
      expect(isSpikeCarbs, isTrue);

      // Subida pequeña (< 0.4 kg) no dispara falsa subida
      final isNotSpike = BiometricFormulas.detectWaterRetentionSpike(
        currentWeightKg: 75.2,
        previousWeightKg: 75.0,
        yesterdaySodiumMg: 4000,
      );
      expect(isNotSpike, isFalse);
    });

    test('Calibrador de TDEE Adaptativo (14 días)', () {
      // Consumo diario promedio: 2200 kcal.
      // Peso EMA estable (delta = 0 kg): TDEE = 2200 kcal
      final tdeeStable = BiometricFormulas.calibrateAdaptiveTdee(
        avgDailyIntakeKcal: 2200.0,
        startEmaKg: 75.0,
        endEmaKg: 75.0,
        previousTdeeKcal: 2200,
        userBmrKcal: 1600,
      );
      expect(tdeeStable, equals(2200));

      // Pérdida de 0.5 kg en 14 días (déficit de 7700 * 0.5 / 14 = 275 kcal/día)
      // TDEE = 2200 - (-275) = 2475 kcal
      final tdeeLoss = BiometricFormulas.calibrateAdaptiveTdee(
        avgDailyIntakeKcal: 2200.0,
        startEmaKg: 75.5,
        endEmaKg: 75.0,
        previousTdeeKcal: 2300,
        userBmrKcal: 1600,
      );
      expect(tdeeLoss, equals(2475));
    });

    test('Gasto Calórico Neto de Ejercicio (METs con descuento 1.0 MET basal)', () {
      // Fuerza/Pesas (MET = 5.0). Peso 75 kg. 60 minutos.
      // Kcal netas = (5.0 - 1.0) * 75 * 1.0 = 300.0 kcal
      final netKcal = BiometricFormulas.calculateNetExerciseCalories(
        met: 5.0,
        weightKg: 75.0,
        durationMinutes: 60,
      );
      expect(netKcal, equals(300.0));
    });
  });
}
