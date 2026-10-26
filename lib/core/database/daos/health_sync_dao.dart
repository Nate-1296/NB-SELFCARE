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
    await _db.into(_db.healthSyncCheckpoints).insertOnConflictUpdate(
          HealthSyncCheckpointsCompanion(
            recordType: Value(recordType),
            lastSyncTimestamp: Value(timestamp),
            lastReadCount: Value(readCount),
            lastWriteCount: Value(writeCount),
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

  /// Inserta o actualiza el resumen diario proveniente de Health Connect o recálculos.
  Future<void> upsertDailySummary(DailySummariesCompanion companion) async {
    await _db.into(_db.dailySummaries).insertOnConflictUpdate(companion);
  }
}

/// Provider de Riverpod para inyectar HealthSyncDao.
final healthSyncDaoProvider = Provider<HealthSyncDao>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return HealthSyncDao(db);
});
