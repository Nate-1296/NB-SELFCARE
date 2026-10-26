import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_constants.dart';
import '../app_database.dart';
import 'pet_dao.dart';

/// DAO especializado en el registro y consulta de biometría corporal y báscula BLE.
class BodyMeasurementsDao {
  BodyMeasurementsDao(this._db, this._petDao);

  final AppDatabase _db;
  final PetDao _petDao;

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

  /// Guarda una nueva medición (desde báscula BLE, Health Connect o manual)
  /// y otorga la recompensa diaria de +15 monedas en el libro mayor.
  Future<int> insertMeasurement(BodyMeasurementsCompanion companion) async {
    return _db.transaction(() async {
      final int id = await _db.into(_db.bodyMeasurements).insert(companion);

      // Otorgar +15 monedas por pesaje diario (con idempotencia garantizada)
      final String dateKey = companion.dateKey.value;
      await _petDao.grantDailyReward(
        dateKey: dateKey,
        actionType: 'weigh_in',
        baseAmount: AppConstants.coinsWeighIn,
      );

      return id;
    });
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

  /// Guarda o actualiza las mediciones de cinta métrica (cintura, cuello, cadera)
  /// y el porcentaje de grasa validado por la fórmula US Navy.
  Future<void> saveNavyTapeMeasurement({
    required int? existingMeasurementId,
    required String dateKey,
    required double waistCm,
    required double neckCm,
    double? hipCm,
    required double validatedBodyFatPercentage,
    required double navyBodyFatPercentage,
    required double defaultWeightKg,
    required double heightCm,
  }) async {
    if (existingMeasurementId != null) {
      await (_db.update(_db.bodyMeasurements)
            ..where((tbl) => tbl.id.equals(existingMeasurementId)))
          .write(
        BodyMeasurementsCompanion(
          waistCm: Value(waistCm),
          neckCm: Value(neckCm),
          hipCm: Value(hipCm),
          validatedBodyFatPercentage: Value(validatedBodyFatPercentage),
        ),
      );
    } else {
      final double bmi = (heightCm > 0)
          ? defaultWeightKg / ((heightCm / 100.0) * (heightCm / 100.0))
          : 22.0;

      await insertMeasurement(
        BodyMeasurementsCompanion.insert(
          dateKey: dateKey,
          source: 'manual_navy_tape',
          weightKg: defaultWeightKg,
          trendWeightKg: defaultWeightKg,
          bmi: bmi,
          bodyFatPercentage: Value(navyBodyFatPercentage),
          waistCm: Value(waistCm),
          neckCm: Value(neckCm),
          hipCm: Value(hipCm),
          validatedBodyFatPercentage: Value(validatedBodyFatPercentage),
          measuredAt: Value(DateTime.now()),
        ),
      );
    }
  }
}

/// Provider de Riverpod para inyectar BodyMeasurementsDao.
final bodyMeasurementsDaoProvider = Provider<BodyMeasurementsDao>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  final PetDao petDao = ref.watch(petDaoProvider);
  return BodyMeasurementsDao(db, petDao);
});

/// StreamProvider con la última medición registrada.
final latestMeasurementStreamProvider = StreamProvider<BodyMeasurement?>((ref) {
  final BodyMeasurementsDao dao = ref.watch(bodyMeasurementsDaoProvider);
  return dao.watchLatestMeasurement();
});

/// StreamProvider con el historial temporal de mediciones corporales para gráficas y tendencias.
final recentMeasurementsStreamProvider =
    StreamProvider.autoDispose<List<BodyMeasurement>>((ref) {
  final BodyMeasurementsDao dao = ref.watch(bodyMeasurementsDaoProvider);
  return dao.watchRecentMeasurements(limit: 90);
});
