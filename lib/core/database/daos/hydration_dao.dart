import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_database.dart';
import 'pet_dao.dart';

/// DAO especializado en el registro atómico de vasos de agua y sincronización de hidratación.
class HydrationDao {
  HydrationDao(this._db, this._petDao);

  final AppDatabase _db;
  final PetDao _petDao;

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

  /// Registra un vaso de agua (ej. +250ml, +500ml) de forma atómica.
  ///
  /// Si se alcanza la meta de agua del usuario, otorga la recompensa en monedas.
  Future<int> logGlass({
    required String dateKey,
    required int volumeMl,
    int? dailyGoalMl,
  }) async {
    return _db.transaction(() async {
      final int id = await _db.into(_db.hydrationLogs).insert(
            HydrationLogsCompanion(
              dateKey: Value(dateKey),
              volumeMl: Value(volumeMl),
              loggedAt: Value(DateTime.now()),
            ),
          );

      // Calcular nuevo total acumulado
      final query = _db.selectOnly(_db.hydrationLogs)
        ..addColumns([_db.hydrationLogs.volumeMl.sum()])
        ..where(_db.hydrationLogs.dateKey.equals(dateKey));
      final int totalMl = (await query.getSingle()).read(_db.hydrationLogs.volumeMl.sum()) ?? 0;

      // Si se alcanzó la meta diaria (ej. 2500ml), otorgar recompensa de +15 monedas
      if (dailyGoalMl != null && totalMl >= dailyGoalMl) {
        await _petDao.grantDailyReward(
          dateKey: dateKey,
          actionType: 'water_goal',
          baseAmount: 15,
        );
      }

      return id;
    });
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
  final PetDao petDao = ref.watch(petDaoProvider);
  return HydrationDao(db, petDao);
});
