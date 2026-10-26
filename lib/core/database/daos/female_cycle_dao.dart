import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_database.dart';

enum FemaleCyclePhase {
  menstrual,
  follicular,
  ovulatory,
  luteal,
  unknown,
}

class CyclePhaseInfo {
  const CyclePhaseInfo({
    required this.phase,
    required this.cycleDay,
    required this.totalCycleLengthDays,
    required this.isLutealMetabolicSurge,
    required this.recommendedCaloricSurgeKcal,
  });

  final FemaleCyclePhase phase;
  final int cycleDay;
  final int totalCycleLengthDays;
  final bool isLutealMetabolicSurge;
  final int recommendedCaloricSurgeKcal;

  String get displayName {
    switch (phase) {
      case FemaleCyclePhase.menstrual:
        return 'Menstrual';
      case FemaleCyclePhase.follicular:
        return 'Folicular';
      case FemaleCyclePhase.ovulatory:
        return 'Ovulación';
      case FemaleCyclePhase.luteal:
        return 'Lútea (Premenstrual)';
      case FemaleCyclePhase.unknown:
        return 'No configurado';
    }
  }
}

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

  /// Calcula la fase actual del ciclo ovárico a partir del último registro.
  Future<CyclePhaseInfo> calculateCurrentPhase(DateTime today) async {
    final FemaleCycleLog? latest = await getLatestCycle();
    if (latest == null) {
      return const CyclePhaseInfo(
        phase: FemaleCyclePhase.unknown,
        cycleDay: 0,
        totalCycleLengthDays: 28,
        isLutealMetabolicSurge: false,
        recommendedCaloricSurgeKcal: 0,
      );
    }

    final int diffDays = today.difference(latest.cycleStartDate).inDays;
    final int cycleLength = latest.cycleLengthDays > 0 ? latest.cycleLengthDays : 28;
    final int currentCycleDay = (diffDays % cycleLength) + 1;

    FemaleCyclePhase phase;
    bool isLutealSurge = false;
    int caloricSurge = 0;

    if (currentCycleDay <= 5) {
      phase = FemaleCyclePhase.menstrual;
    } else if (currentCycleDay <= 13) {
      phase = FemaleCyclePhase.follicular;
    } else if (currentCycleDay <= 16) {
      phase = FemaleCyclePhase.ovulatory;
    } else {
      phase = FemaleCyclePhase.luteal;
      isLutealSurge = true;
      caloricSurge = 150; // Compensación sugerida por elevación de temperatura basal
    }

    return CyclePhaseInfo(
      phase: phase,
      cycleDay: currentCycleDay,
      totalCycleLengthDays: cycleLength,
      isLutealMetabolicSurge: isLutealSurge,
      recommendedCaloricSurgeKcal: caloricSurge,
    );
  }
}

/// Provider de Riverpod para inyectar FemaleCycleDao.
final femaleCycleDaoProvider = Provider<FemaleCycleDao>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return FemaleCycleDao(db);
});

/// StreamProvider que expone reactivamente el último ciclo ovárico registrado.
final latestFemaleCycleStreamProvider = StreamProvider<FemaleCycleLog?>((ref) {
  final FemaleCycleDao dao = ref.watch(femaleCycleDaoProvider);
  return dao.watchLatestCycle();
});

