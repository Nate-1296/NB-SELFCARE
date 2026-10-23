import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_database.dart';

/// DAO especializado en el registro y auditoría histórica de las calibraciones del TDEE Adaptativo.
class TdeeDao {
  TdeeDao(this._db);

  final AppDatabase _db;

  /// Emite la última calibración registrada del TDEE adaptativo.
  Stream<TdeeCalibration?> watchLatestCalibration() {
    return (_db.select(_db.tdeeCalibrations)
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.calibratedAt)])
          ..limit(1))
        .watchSingleOrNull();
  }

  /// Registra el resultado de una calibración quincenal.
  Future<int> insertCalibration(TdeeCalibrationsCompanion companion) {
    return _db.into(_db.tdeeCalibrations).insert(companion);
  }

  /// Obtiene el historial de calibraciones para visualización en el perfil.
  Future<List<TdeeCalibration>> getCalibrationHistory({int limit = 12}) {
    return (_db.select(_db.tdeeCalibrations)
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.calibratedAt)])
          ..limit(limit))
        .get();
  }
}

/// Provider de Riverpod para inyectar TdeeDao.
final tdeeDaoProvider = Provider<TdeeDao>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return TdeeDao(db);
});
