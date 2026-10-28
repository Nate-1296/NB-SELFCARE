import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_database.dart';

/// DAO especializado en los checkpoints de Health Connect y resúmenes diarios.
class HealthSyncDao {
  HealthSyncDao(this._db);

  final AppDatabase _db;

  /// Obtiene el checkpoint de sincronización para un tipo de registro específico.
  Future<HealthSyncCheckpoint?> getCheckpoint(String recordType) {
    return (_db.select(_db.healthSyncCheckpoints)
          ..where((tbl) => tbl.recordType.equals(recordType)))
        .getSingleOrNull();
  }

  /// Actualiza o crea el checkpoint de sincronización tras una lectura/escritura exitosa.
  Future<void> updateCheckpoint({
    required String recordType,
    required DateTime timestamp,
    int readCount = 0,
    int writeCount = 0,
  }) async {
    final HealthSyncCheckpointsCompanion row = HealthSyncCheckpointsCompanion(
      recordType: Value(recordType),
      lastSyncTimestamp: Value(timestamp),
      lastReadCount: Value(readCount),
      lastWriteCount: Value(writeCount),
    );
    // El conflicto es por `record_type` (único), no por el id: con
    // insertOnConflictUpdate la segunda sincronización fallaba y revertía la
    // transacción entera (los pasos y el sueño leídos no se guardaban).
    await _db.into(_db.healthSyncCheckpoints).insert(
          row,
          onConflict: DoUpdate(
            (_) => row,
            target: <Column<Object>>[_db.healthSyncCheckpoints.recordType],
          ),
        );
  }

  /// Emite el resumen diario consolidado para una fecha dada (pasos, sueño, FC, metas).
  Stream<DailySummary?> watchDailySummary(String dateKey) {
    return (_db.select(_db.dailySummaries)..where((tbl) => tbl.dateKey.equals(dateKey)))
        .watchSingleOrNull();
  }

  /// Obtiene de forma asíncrona el resumen diario consolidado para una fecha dada.
  Future<DailySummary?> getSummaryForDate(String dateKey) {
    return (_db.select(_db.dailySummaries)..where((tbl) => tbl.dateKey.equals(dateKey)))
        .getSingleOrNull();
  }

  /// Resúmenes diarios entre dos fechas (inclusive), en orden cronológico.
  Stream<List<DailySummary>> watchSummariesBetween(String fromDateKey, String toDateKey) =>
      _summariesBetween(fromDateKey, toDateKey).watch();

  Future<List<DailySummary>> getSummariesBetween(String fromDateKey, String toDateKey) =>
      _summariesBetween(fromDateKey, toDateKey).get();

  SimpleSelectStatement<$DailySummariesTable, DailySummary> _summariesBetween(String from, String to) {
    return _db.select(_db.dailySummaries)
      ..where((tbl) => tbl.dateKey.isBetweenValues(from, to))
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.dateKey)]);
  }

  /// Inserta o actualiza el resumen diario proveniente de Health Connect o del registro manual.
  ///
  /// Solo se escriben las columnas presentes en [companion]; si el día aún no
  /// existe, las metas del día se inicializan en 0 hasta que se tome su snapshot.
  Future<void> upsertDailySummary(DailySummariesCompanion companion) async {
    final String dateKey = companion.dateKey.value;
    await _db.transaction(() async {
      final DailySummary? existing = await getSummaryForDate(dateKey);
      if (existing != null) {
        await (_db.update(_db.dailySummaries)..where((tbl) => tbl.dateKey.equals(dateKey)))
            .write(companion);
        return;
      }
      await _db.into(_db.dailySummaries).insert(
            companion.copyWith(
              calorieTargetKcal: _orZero(companion.calorieTargetKcal),
              proteinTargetG: _orZero(companion.proteinTargetG),
              carbsTargetG: _orZero(companion.carbsTargetG),
              fatTargetG: _orZero(companion.fatTargetG),
            ),
          );
    });
  }

  static Value<int> _orZero(Value<int> value) => value.present ? value : const Value(0);
}

/// Provider de Riverpod para inyectar HealthSyncDao.
final healthSyncDaoProvider = Provider<HealthSyncDao>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return HealthSyncDao(db);
});
