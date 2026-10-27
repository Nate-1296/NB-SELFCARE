import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../clock/clock.dart';
import '../app_database.dart';

/// DAO especializado en el registro atómico de vasos de agua y sincronización de hidratación.
class HydrationDao {
  HydrationDao(this._db, {this._clock = const Clock()});

  final Clock _clock;

  final AppDatabase _db;

  /// Emite todos los registros individuales de agua del día.
  Stream<List<HydrationLog>> watchLogsForDate(String dateKey) {
    return (_db.select(_db.hydrationLogs)
          ..where((tbl) => tbl.dateKey.equals(dateKey))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.loggedAt)]))
        .watch();
  }

  /// Emite la suma total en mililitros consumidos en una fecha dada.
  Stream<int> watchTotalWaterMl(String dateKey) {
    final query = _db.selectOnly(_db.hydrationLogs)
      ..addColumns([_db.hydrationLogs.volumeMl.sum()])
      ..where(_db.hydrationLogs.dateKey.equals(dateKey));

    return query.watchSingle().map((row) => row.read(_db.hydrationLogs.volumeMl.sum()) ?? 0);
  }

  /// Inserta un vaso de agua (ej. +250ml, +500ml).
  Future<int> insertGlass({required String dateKey, required int volumeMl}) {
    return _db.into(_db.hydrationLogs).insert(
          HydrationLogsCompanion(
            dateKey: Value(dateKey),
            volumeMl: Value(volumeMl),
            loggedAt: Value(_clock.now()),
          ),
        );
  }

  /// Suma de mililitros registrados en [dateKey].
  Future<int> getTotalWaterMl(String dateKey) async {
    final query = _db.selectOnly(_db.hydrationLogs)
      ..addColumns([_db.hydrationLogs.volumeMl.sum()])
      ..where(_db.hydrationLogs.dateKey.equals(dateKey));
    return (await query.getSingle()).read(_db.hydrationLogs.volumeMl.sum()) ?? 0;
  }

  /// Restaura un vaso eliminado (flujo Deshacer).
  Future<int> restoreGlass(HydrationLog log) {
    return _db.into(_db.hydrationLogs).insert(
          HydrationLogsCompanion(
            dateKey: Value(log.dateKey),
            volumeMl: Value(log.volumeMl),
            loggedAt: Value(log.loggedAt),
            syncedToHealthConnect: Value(log.syncedToHealthConnect),
          ),
        );
  }

  /// Elimina un registro de vaso de agua por su ID.
  Future<int> deleteGlass(int logId) {
    return (_db.delete(_db.hydrationLogs)..where((tbl) => tbl.id.equals(logId))).go();
  }

  /// Obtiene los registros pendientes de sincronizar con Health Connect.
  Future<List<HydrationLog>> getUnsyncedLogs() {
    return (_db.select(_db.hydrationLogs)
          ..where((tbl) => tbl.syncedToHealthConnect.equals(false)))
        .get();
  }

  /// Marca registros como sincronizados con Health Connect.
  Future<void> markAsSynced(List<int> ids) async {
    if (ids.isEmpty) return;
    final query = _db.update(_db.hydrationLogs)..where((tbl) => tbl.id.isIn(ids));
    await query.write(const HydrationLogsCompanion(syncedToHealthConnect: Value(true)));
  }
}

/// Provider de Riverpod para inyectar HydrationDao.
final hydrationDaoProvider = Provider<HydrationDao>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return HydrationDao(db, clock: ref.watch(clockProvider));
});
