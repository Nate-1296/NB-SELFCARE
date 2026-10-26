import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_database.dart';

/// DAO para seguimiento farmacocinético de la cafeína y su impacto en el sueño.
class CaffeineDao {
  CaffeineDao(this._db);

  final AppDatabase _db;

  /// Vida media promedio estándar de la cafeína en plasma sanguíneo (5.5 horas).
  static const double defaultHalfLifeHours = 5.5;

  /// Emite los registros de cafeína para una fecha dada ('YYYY-MM-DD').
  Stream<List<CaffeineLog>> watchLogsForDate(String dateKey) {
    return (_db.select(_db.caffeineLogs)
          ..where((tbl) => tbl.dateKey.equals(dateKey))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.loggedAt, mode: OrderingMode.desc)]))
        .watch();
  }

  /// Obtiene los registros de cafeína para una fecha dada.
  Future<List<CaffeineLog>> getLogsForDate(String dateKey) {
    return (_db.select(_db.caffeineLogs)
          ..where((tbl) => tbl.dateKey.equals(dateKey))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.loggedAt, mode: OrderingMode.desc)]))
        .get();
  }

  /// Registra una ingesta de cafeína.
  Future<int> logCaffeine({
    required String dateKey,
    required String sourceName,
    required double caffeineMg,
    DateTime? loggedAt,
  }) {
    if (caffeineMg <= 0) {
      throw ArgumentError('caffeineMg debe ser mayor a 0');
    }

    return _db.into(_db.caffeineLogs).insert(
          CaffeineLogsCompanion(
            dateKey: Value(dateKey),
            sourceName: Value(sourceName),
            caffeineMg: Value(caffeineMg),
            loggedAt: Value(loggedAt ?? DateTime.now()),
          ),
        );
  }

  /// Elimina un registro de cafeína.
  Future<int> deleteLog(int id) {
    return (_db.delete(_db.caffeineLogs)..where((tbl) => tbl.id.equals(id))).go();
  }

  /// Calcula la cantidad de cafeína residual activa en miligramos en un instante objetivo
  /// (por ejemplo, a la hora de acostarse a dormir), sumando el decaimiento exponencial de cada toma.
  static double calculateResidualCaffeineAt(
    DateTime targetTime,
    List<CaffeineLog> logs, {
    double halfLifeHours = defaultHalfLifeHours,
  }) {
    double totalResidualMg = 0.0;

    for (final log in logs) {
      final double elapsedHours =
          targetTime.difference(log.loggedAt).inMinutes / 60.0;

      if (elapsedHours > 0) {
        // C(t) = C0 * 0.5^(elapsed / halfLife)
        final double residual =
            log.caffeineMg * math.pow(0.5, elapsedHours / halfLifeHours);
        totalResidualMg += residual;
      } else {
        // Si el objetivo es antes de la toma, la toma aún no ha ocurrido
        totalResidualMg += log.caffeineMg;
      }
    }

    return double.parse(totalResidualMg.toStringAsFixed(1));
  }
}

/// Provider de Riverpod para inyectar CaffeineDao.
final caffeineDaoProvider = Provider<CaffeineDao>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return CaffeineDao(db);
});

