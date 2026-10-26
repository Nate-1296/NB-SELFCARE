import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_database.dart';

/// DAO para seguimiento de salud gastrointestinal, síntomas y Escala de Bristol (1 a 7).
class DigestiveDao {
  DigestiveDao(this._db);

  final AppDatabase _db;

  /// Emite los registros digestivos para una fecha dada ('YYYY-MM-DD').
  Stream<List<DigestiveLog>> watchLogsForDate(String dateKey) {
    return (_db.select(_db.digestiveLogs)
          ..where((tbl) => tbl.dateKey.equals(dateKey))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.loggedAt, mode: OrderingMode.desc)]))
        .watch();
  }

  /// Obtiene los registros digestivos para una fecha dada.
  Future<List<DigestiveLog>> getLogsForDate(String dateKey) {
    return (_db.select(_db.digestiveLogs)
          ..where((tbl) => tbl.dateKey.equals(dateKey))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.loggedAt, mode: OrderingMode.desc)]))
        .get();
  }

  /// Registra una deposición o síntoma gastrointestinal.
  Future<int> logDigestiveEvent({
    required String dateKey,
    required int bristolType,
    int discomfortLevel = 1,
    String symptomsJson = '[]',
    String? notes,
  }) {
    if (bristolType < 1 || bristolType > 7) {
      throw ArgumentError('bristolType debe estar entre 1 y 7');
    }

    return _db.into(_db.digestiveLogs).insert(
          DigestiveLogsCompanion(
            dateKey: Value(dateKey),
            bristolType: Value(bristolType),
            discomfortLevel: Value(discomfortLevel),
            symptomsJson: Value(symptomsJson),
            notes: Value(notes),
            loggedAt: Value(DateTime.now()),
          ),
        );
  }

  /// Elimina un registro digestivo.
  Future<int> deleteLog(int id) {
    return (_db.delete(_db.digestiveLogs)..where((tbl) => tbl.id.equals(id))).go();
  }

  /// Obtiene los registros con malestar significativo (discomfort >= 3)
  /// en los últimos [days] para el motor de correlaciones cruzadas.
  Future<List<DigestiveLog>> getRecentDiscomfortLogs(int days) async {
    final DateTime cutoff = DateTime.now().subtract(Duration(days: days));
    return (_db.select(_db.digestiveLogs)
          ..where((tbl) => tbl.loggedAt.isBiggerOrEqualValue(cutoff) & tbl.discomfortLevel.isBiggerOrEqualValue(3))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.loggedAt, mode: OrderingMode.desc)]))
        .get();
  }
}

/// Provider de Riverpod para inyectar DigestiveDao.
final digestiveDaoProvider = Provider<DigestiveDao>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return DigestiveDao(db);
});

