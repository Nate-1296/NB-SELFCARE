import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/enums.dart';
import '../app_database.dart';

/// DAO especializado en el registro y consulta de biometría corporal y báscula BLE.
class BodyMeasurementsDao {
  BodyMeasurementsDao(this._db);

  final AppDatabase _db;

  /// Emite la medición biométrica más reciente.
  Stream<BodyMeasurement?> watchLatestMeasurement() {
    return (_db.select(_db.bodyMeasurements)
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.measuredAt)])
          ..limit(1))
        .watchSingleOrNull();
  }

  /// Obtiene la última medición registrada.
  Future<BodyMeasurement?> getLatestMeasurement() {
    return (_db.select(_db.bodyMeasurements)
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.measuredAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Último pesaje real (excluye las filas creadas solo para la cinta métrica).
  Future<BodyMeasurement?> getLatestWeighIn() {
    return (_db.select(_db.bodyMeasurements)
          ..where((tbl) => tbl.source.equalsValue(MeasurementSource.navyTape).not())
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.measuredAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Emite la serie temporal de mediciones para gráficas de peso y tendencia.
  Stream<List<BodyMeasurement>> watchRecentMeasurements({int limit = 60}) {
    return (_db.select(_db.bodyMeasurements)
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.measuredAt)])
          ..limit(limit))
        .watch()
        .map((list) => list.reversed.toList());
  }

  /// Obtiene la lista de mediciones recientes para cálculos clínicos y reportes.
  Future<List<BodyMeasurement>> getRecentMeasurements({int limit = 30}) async {
    final list = await (_db.select(_db.bodyMeasurements)
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.measuredAt)])
          ..limit(limit))
        .get();
    return list.reversed.toList();
  }

  /// Guarda una nueva medición (desde báscula BLE, Health Connect o manual).
  Future<int> insertMeasurement(BodyMeasurementsCompanion companion) {
    return _db.into(_db.bodyMeasurements).insert(companion);
  }

  /// Elimina una medición corporal por su ID.
  Future<int> deleteMeasurement(int id) {
    return (_db.delete(_db.bodyMeasurements)..where((tbl) => tbl.id.equals(id)))
        .go();
  }

  /// Restaura una medición corporal previamente eliminada (flujo Deshacer).
  Future<int> restoreMeasurement(BodyMeasurement m) {
    return _db.into(_db.bodyMeasurements).insert(
          BodyMeasurementsCompanion.insert(
            measuredAt: Value(m.measuredAt),
            dateKey: m.dateKey,
            source: m.source,
            weightKg: m.weightKg,
            trendWeightKg: m.trendWeightKg,
            impedanceOhms: Value(m.impedanceOhms),
            bmi: m.bmi,
            bodyFatPercentage: Value(m.bodyFatPercentage),
            muscleMassKg: Value(m.muscleMassKg),
            waterPercentage: Value(m.waterPercentage),
            visceralFatIndex: Value(m.visceralFatIndex),
            boneMassKg: Value(m.boneMassKg),
            proteinPercentage: Value(m.proteinPercentage),
            basalMetabolicRateKcal: Value(m.basalMetabolicRateKcal),
            metabolicAge: Value(m.metabolicAge),
            leanBodyMassKg: Value(m.leanBodyMassKg),
            bodyScore: Value(m.bodyScore),
            somatotype: Value(m.somatotype),
            isWaterRetentionSpike: Value(m.isWaterRetentionSpike),
            spikeExplanation: Value(m.spikeExplanation),
            waistCm: Value(m.waistCm),
            neckCm: Value(m.neckCm),
            hipCm: Value(m.hipCm),
            validatedBodyFatPercentage: Value(m.validatedBodyFatPercentage),
          ),
        );
  }

  /// Obtiene la medición registrada en una fecha específica (si existe).
  Future<BodyMeasurement?> getMeasurementForDate(String dateKey) {
    return (_db.select(_db.bodyMeasurements)
          ..where((tbl) => tbl.dateKey.equals(dateKey))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.measuredAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Obtiene las mediciones de los últimos N días para cálculos de TDEE o EMA.
  Future<List<BodyMeasurement>> getMeasurementsInDateRange(String fromDateKey, String toDateKey) {
    return (_db.select(_db.bodyMeasurements)
          ..where((tbl) => tbl.dateKey.isBiggerOrEqualValue(fromDateKey) & tbl.dateKey.isSmallerOrEqualValue(toDateKey))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.measuredAt)]))
        .get();
  }

  /// % de grasa por bioimpedancia del último pesaje real (excluye filas de cinta).
  Future<double?> getLatestBiaBodyFat() async {
    final BodyMeasurement? row = await (_db.select(_db.bodyMeasurements)
          ..where((tbl) =>
              tbl.source.equalsValue(MeasurementSource.navyTape).not() & tbl.bodyFatPercentage.isNotNull())
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.measuredAt)])
          ..limit(1))
        .getSingleOrNull();
    return row?.bodyFatPercentage;
  }

  /// Guarda las medidas de cinta (cintura, cuello, cadera) y la grasa validada US Navy.
  ///
  /// * Si ya hay un pesaje en [dateKey], se completan sus columnas de cinta.
  /// * Si no, se crea una fila de cinta que arrastra el último peso real y su
  ///   Peso Tendencia (EMA) sin modificarlos, y **no** otorga monedas de pesaje.
  /// * Si nunca se ha registrado un peso, no hay peso que arrastrar: devuelve `false`.
  Future<bool> saveNavyTapeMeasurement({
    required String dateKey,
    required DateTime measuredAt,
    required double waistCm,
    required double neckCm,
    double? hipCm,
    required double validatedBodyFatPercentage,
    required double navyBodyFatPercentage,
  }) async {
    return _db.transaction(() async {
      final BodyMeasurement? sameDay = await getMeasurementForDate(dateKey);
      if (sameDay != null) {
        await (_db.update(_db.bodyMeasurements)..where((tbl) => tbl.id.equals(sameDay.id)))
            .write(
          BodyMeasurementsCompanion(
            waistCm: Value(waistCm),
            neckCm: Value(neckCm),
            hipCm: Value(hipCm),
            validatedBodyFatPercentage: Value(validatedBodyFatPercentage),
          ),
        );
        return true;
      }

      final BodyMeasurement? latest = await getLatestMeasurement();
      if (latest == null) return false;

      await _db.into(_db.bodyMeasurements).insert(
            BodyMeasurementsCompanion.insert(
              dateKey: dateKey,
              measuredAt: Value(measuredAt),
              source: MeasurementSource.navyTape,
              weightKg: latest.weightKg,
              trendWeightKg: latest.trendWeightKg,
              bmi: latest.bmi,
              bodyFatPercentage: Value(navyBodyFatPercentage),
              waistCm: Value(waistCm),
              neckCm: Value(neckCm),
              hipCm: Value(hipCm),
              validatedBodyFatPercentage: Value(validatedBodyFatPercentage),
            ),
          );
      return true;
    });
  }
}

/// Provider de Riverpod para inyectar BodyMeasurementsDao.
final bodyMeasurementsDaoProvider = Provider<BodyMeasurementsDao>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return BodyMeasurementsDao(db);
});
