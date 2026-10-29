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
    return _db
        .into(_db.supplementsTracker)
        .insert(
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
  ///
  /// [slotMinutes] identifica la toma del horario (`null` = toma única del día).
  /// Si el tratamiento lleva la cuenta de su reserva, marcar una toma descuenta
  /// sus unidades y desmarcarla las devuelve.
  Future<void> toggleSupplementIntake({
    required String dateKey,
    required int supplementId,
    required bool wasTaken,
    int? slotMinutes,
    DateTime? at,
  }) {
    return _db.transaction(() async {
      final SupplementLog? existing =
          await (_db.select(_db.supplementLogs)
                ..where(
                  (tbl) =>
                      tbl.dateKey.equals(dateKey) &
                      tbl.supplementId.equals(supplementId) &
                      (slotMinutes == null
                          ? tbl.slotMinutes.isNull()
                          : tbl.slotMinutes.equals(slotMinutes)),
                )
                ..limit(1))
              .getSingleOrNull();
      final bool wasTakenBefore = existing?.wasTaken ?? false;
      final DateTime when = at ?? _clock.now();

      if (existing != null) {
        await (_db.update(_db.supplementLogs)..where((tbl) => tbl.id.equals(existing.id))).write(
          SupplementLogsCompanion(wasTaken: Value(wasTaken), takenAt: Value(when)),
        );
      } else {
        await _db
            .into(_db.supplementLogs)
            .insert(
              SupplementLogsCompanion(
                dateKey: Value(dateKey),
                supplementId: Value(supplementId),
                wasTaken: Value(wasTaken),
                takenAt: Value(when),
                slotMinutes: Value(slotMinutes),
              ),
            );
      }
      if (wasTaken != wasTakenBefore) {
        await _adjustStock(supplementId, taken: wasTaken);
      }
    });
  }

  /// Quita la marca de una toma (Deshacer): vuelve a "pendiente" y devuelve la reserva.
  Future<void> clearIntake({required String dateKey, required int supplementId, int? slotMinutes}) {
    return _db.transaction(() async {
      final List<SupplementLog> rows =
          await (_db.select(_db.supplementLogs)..where(
                (tbl) =>
                    tbl.dateKey.equals(dateKey) &
                    tbl.supplementId.equals(supplementId) &
                    (slotMinutes == null
                        ? tbl.slotMinutes.isNull()
                        : tbl.slotMinutes.equals(slotMinutes)),
              ))
              .get();
      for (final SupplementLog row in rows) {
        if (row.wasTaken) await _adjustStock(supplementId, taken: false);
        await (_db.delete(_db.supplementLogs)..where((tbl) => tbl.id.equals(row.id))).go();
      }
    });
  }

  Future<void> _adjustStock(int supplementId, {required bool taken}) async {
    final SupplementsTrackerData? item = await (_db.select(
      _db.supplementsTracker,
    )..where((tbl) => tbl.id.equals(supplementId))).getSingleOrNull();
    final double? stock = item?.stockUnits;
    if (item == null || stock == null) return;
    final double next = taken ? stock - item.unitsPerDose : stock + item.unitsPerDose;
    await (_db.update(_db.supplementsTracker)..where((tbl) => tbl.id.equals(supplementId))).write(
      SupplementsTrackerCompanion(stockUnits: Value(next < 0 ? 0 : next)),
    );
  }

  /// Todos los tratamientos (activos y pausados) por nombre.
  Stream<List<SupplementsTrackerData>> watchAllSupplements() {
    return (_db.select(
      _db.supplementsTracker,
    )..orderBy([(tbl) => OrderingTerm(expression: tbl.name.lower())])).watch();
  }

  /// Registros de tomas en un rango de fechas (adherencia e informe).
  Future<List<SupplementLog>> getLogsBetween(String fromDateKey, String toDateKey) {
    return (_db.select(_db.supplementLogs)..where(
          (tbl) =>
              tbl.dateKey.isBiggerOrEqualValue(fromDateKey) &
              tbl.dateKey.isSmallerOrEqualValue(toDateKey),
        ))
        .get();
  }

  /// Si algún tratamiento activo puede bajar la glucosa (aviso antes de ayunar).
  Future<bool> hasActiveGlucoseLowering() async {
    final List<SupplementsTrackerData> rows =
        await (_db.select(_db.supplementsTracker)
              ..where((tbl) => tbl.lowersGlucose.equals(true) & tbl.isEnabled.equals(true))
              ..limit(1))
            .get();
    return rows.isNotEmpty;
  }

  /// Inserta o reemplaza un tratamiento completo (alta, edición y Deshacer).
  Future<int> upsertSupplement(SupplementsTrackerCompanion companion) {
    return _db.into(_db.supplementsTracker).insertOnConflictUpdate(companion);
  }

  /// Evalúa si el usuario está tomando creatina (u otro suplemento que afecte el agua corporal)
  /// en los últimos 7 días con adherencia para justificar retención hídrica en la báscula.
  Future<bool> hasActiveWaterRetentionSupplement(String currentDateKey) async {
    // 1. Buscar si hay suplementos con affectsWaterRetention = true
    final waterSupplements = await (_db.select(
      _db.supplementsTracker,
    )..where((tbl) => tbl.affectsWaterRetention.equals(true) & tbl.isEnabled.equals(true))).get();

    if (waterSupplements.isEmpty) return false;

    // 2. Verificar si hubo al menos 3 tomas en los últimos 7 días (incluido hoy)
    final DateTime? today = DateTime.tryParse(currentDateKey);
    if (today == null) return false;
    final String fromDateKey = today.addDays(-6).dateKey;
    final supplementIds = waterSupplements.map((s) => s.id).toList();
    final logs =
        await (_db.select(_db.supplementLogs)
              ..where(
                (tbl) =>
                    tbl.supplementId.isIn(supplementIds) &
                    tbl.wasTaken.equals(true) &
                    tbl.dateKey.isBiggerOrEqualValue(fromDateKey) &
                    tbl.dateKey.isSmallerOrEqualValue(currentDateKey),
              )
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
