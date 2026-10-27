import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/utils/cycle_phase_calculator.dart';
import '../app_database.dart';

/// DAO para seguimiento del ciclo hormonal femenino y ajuste metabólico lúteo.
class FemaleCycleDao {
  FemaleCycleDao(this._db);

  final AppDatabase _db;

  /// Emite el último registro de ciclo ovárico.
  Stream<FemaleCycleLog?> watchLatestCycle() {
    return (_db.select(_db.femaleCycleLogs)
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.cycleStartDate, mode: OrderingMode.desc)])
          ..limit(1))
        .watchSingleOrNull();
  }

  /// Obtiene el registro de ciclo más reciente.
  Future<FemaleCycleLog?> getLatestCycle() {
    return (_db.select(_db.femaleCycleLogs)
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.cycleStartDate, mode: OrderingMode.desc)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Emite el historial completo de ciclos.
  Stream<List<FemaleCycleLog>> watchAllCycles() {
    return (_db.select(_db.femaleCycleLogs)
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.cycleStartDate, mode: OrderingMode.desc)]))
        .watch();
  }

  /// Registra el inicio de un nuevo período menstrual.
  Future<int> logCycleStart({
    required DateTime cycleStartDate,
    int cycleLengthDays = 28,
    String? flowIntensity,
    String symptomsJson = '[]',
    String? notes,
  }) {
    return _db.into(_db.femaleCycleLogs).insert(
          FemaleCycleLogsCompanion(
            cycleStartDate: Value(cycleStartDate),
            cycleLengthDays: Value(cycleLengthDays),
            flowIntensity: Value(flowIntensity),
            symptomsJson: Value(symptomsJson),
            notes: Value(notes),
          ),
        );
  }

  /// Actualiza los síntomas o la fecha de cierre de un ciclo existente.
  Future<bool> updateCycle(FemaleCycleLogsCompanion companion) async {
    final query = _db.update(_db.femaleCycleLogs)
      ..where((tbl) => tbl.id.equals(companion.id.value));
    final int rows = await query.write(companion);
    return rows > 0;
  }

  /// Elimina un registro de ciclo.
  Future<int> deleteCycle(int id) {
    return (_db.delete(_db.femaleCycleLogs)..where((tbl) => tbl.id.equals(id))).go();
  }

  /// Calcula la fase del ciclo en [today] a partir del último registro.
  Future<CyclePhaseInfo> calculateCurrentPhase(DateTime today) async {
    final FemaleCycleLog? latest = await getLatestCycle();
    if (latest == null) return CyclePhaseInfo.unknown;
    return CyclePhaseCalculator.phaseFor(
      cycleStart: latest.cycleStartDate,
      cycleLengthDays: latest.cycleLengthDays,
      date: today,
    );
  }
}

/// Provider de Riverpod para inyectar FemaleCycleDao.
final femaleCycleDaoProvider = Provider<FemaleCycleDao>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return FemaleCycleDao(db);
});
