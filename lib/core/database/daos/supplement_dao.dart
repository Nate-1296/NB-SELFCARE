import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/utils/date_time_extensions.dart';
import '../../clock/clock.dart';
import '../app_database.dart';

/// DAO para seguimiento de suplementación, creatina y medicación prescrita.
class SupplementDao {
  SupplementDao(this._db, {this._clock = const Clock()});

  final Clock _clock;

  final AppDatabase _db;

  /// Emite en tiempo real los suplementos activos configurados por el usuario.
  Stream<List<SupplementsTrackerData>> watchActiveSupplements() {
    return (_db.select(_db.supplementsTracker)
          ..where((tbl) => tbl.isEnabled.equals(true))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.targetTimeOfDayMinutes)]))
        .watch();
  }

  /// Obtiene todos los suplementos configurados.
  Future<List<SupplementsTrackerData>> getAllSupplements() {
    return _db.select(_db.supplementsTracker).get();
  }

  /// Obtiene todos los suplementos actualmente habilitados.
  Future<List<SupplementsTrackerData>> getActiveSupplements() {
    return (_db.select(_db.supplementsTracker)
          ..where((tbl) => tbl.isEnabled.equals(true))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.targetTimeOfDayMinutes)]))
        .get();
  }

  /// Registra un nuevo suplemento o fármaco en la lista maestra.
  Future<int> createSupplement({
    required String name,
    required String dosage,
    int? targetTimeOfDayMinutes,
    bool affectsWaterRetention = false,
  }) {
    return _db.into(_db.supplementsTracker).insert(
          SupplementsTrackerCompanion(
            name: Value(name),
            dosage: Value(dosage),
            targetTimeOfDayMinutes: Value(targetTimeOfDayMinutes),
            affectsWaterRetention: Value(affectsWaterRetention),
            isEnabled: const Value(true),
          ),
        );
  }

  /// Actualiza los parámetros de un suplemento existente.
  Future<bool> updateSupplement(SupplementsTrackerCompanion companion) async {
    final query = _db.update(_db.supplementsTracker)
      ..where((tbl) => tbl.id.equals(companion.id.value));
    final int rows = await query.write(companion);
    return rows > 0;
  }

  /// Elimina un suplemento de la lista maestra.
  Future<int> deleteSupplement(int id) {
    return (_db.delete(_db.supplementsTracker)..where((tbl) => tbl.id.equals(id))).go();
  }

  /// Emite los registros de toma de suplementos para una fecha dada ('YYYY-MM-DD').
  Stream<List<SupplementLog>> watchLogsForDate(String dateKey) {
    return (_db.select(_db.supplementLogs)..where((tbl) => tbl.dateKey.equals(dateKey))).watch();
  }

  /// Obtiene los registros de toma de suplementos para una fecha dada.
  Future<List<SupplementLog>> getLogsForDate(String dateKey) {
    return (_db.select(_db.supplementLogs)..where((tbl) => tbl.dateKey.equals(dateKey))).get();
  }

  /// Registra o alterna la toma de un suplemento en una fecha determinada.
  Future<void> toggleSupplementIntake({
    required String dateKey,
    required int supplementId,
    required bool wasTaken,
  }) async {
    final existing = await (_db.select(_db.supplementLogs)
          ..where((tbl) => tbl.dateKey.equals(dateKey) & tbl.supplementId.equals(supplementId)))
        .getSingleOrNull();

    if (existing != null) {
      final query = _db.update(_db.supplementLogs)
        ..where((tbl) => tbl.id.equals(existing.id));
      await query.write(
        SupplementLogsCompanion(
          wasTaken: Value(wasTaken),
          takenAt: Value(_clock.now()),
        ),
      );
    } else {
      await _db.into(_db.supplementLogs).insert(
            SupplementLogsCompanion(
              dateKey: Value(dateKey),
              supplementId: Value(supplementId),
              wasTaken: Value(wasTaken),
              takenAt: Value(_clock.now()),
            ),
          );
    }
  }

  /// Evalúa si el usuario está tomando creatina (u otro suplemento que afecte el agua corporal)
  /// en los últimos 7 días con adherencia para justificar retención hídrica en la báscula.
  Future<bool> hasActiveWaterRetentionSupplement(String currentDateKey) async {
    // 1. Buscar si hay suplementos con affectsWaterRetention = true
    final waterSupplements = await (_db.select(_db.supplementsTracker)
          ..where((tbl) => tbl.affectsWaterRetention.equals(true) & tbl.isEnabled.equals(true)))
        .get();

    if (waterSupplements.isEmpty) return false;

    // 2. Verificar si hubo al menos 3 tomas en los últimos 7 días (incluido hoy)
    final DateTime? today = DateTime.tryParse(currentDateKey);
    if (today == null) return false;
    final String fromDateKey = today.subtract(const Duration(days: 6)).dateKey;
    final supplementIds = waterSupplements.map((s) => s.id).toList();
    final logs = await (_db.select(_db.supplementLogs)
          ..where((tbl) =>
              tbl.supplementId.isIn(supplementIds) &
              tbl.wasTaken.equals(true) &
              tbl.dateKey.isBiggerOrEqualValue(fromDateKey) &
              tbl.dateKey.isSmallerOrEqualValue(currentDateKey))
          ..limit(3))
        .get();

    return logs.length >= 3;
  }
}

/// Provider de Riverpod para inyectar SupplementDao.
final supplementDaoProvider = Provider<SupplementDao>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return SupplementDao(db, clock: ref.watch(clockProvider));
});

