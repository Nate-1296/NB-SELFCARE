import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_database.dart';

/// DAO para la subdivisión psicológica de metas de peso en mini-hitos (estilo Happy Scale).
class MilestoneDao {
  MilestoneDao(this._db);

  final AppDatabase _db;

  /// Emite la lista completa de mini-hitos ordenada correlativamente.
  Stream<List<MilestoneGoal>> watchMilestones() {
    return (_db.select(_db.milestoneGoals)
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.milestoneOrder)]))
        .watch();
  }

  /// Obtiene todos los mini-hitos persistidos.
  Future<List<MilestoneGoal>> getMilestones() {
    return (_db.select(_db.milestoneGoals)
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.milestoneOrder)]))
        .get();
  }

  /// Genera o recalcula los mini-hitos espaciados en bloques de [stepKg] (por defecto 1.5 kg)
  /// desde el peso actual hasta el peso meta.
  Future<void> generateMilestones({
    required double currentWeightKg,
    required double targetWeightKg,
    double stepKg = 1.5,
  }) async {
    await _db.delete(_db.milestoneGoals).go();

    final double safeStepKg = stepKg > 0 ? stepKg : 1.5;
    final bool isLosing = targetWeightKg < currentWeightKg;
    final double totalDiff = (currentWeightKg - targetWeightKg).abs();

    if (totalDiff < 0.5) {
      // Diferencia mínima insignificante: 1 solo hito
      await _db.into(_db.milestoneGoals).insert(
            MilestoneGoalsCompanion(
              milestoneOrder: const Value(1),
              targetWeightKg: Value(targetWeightKg),
              isCompleted: const Value(false),
            ),
          );
      return;
    }

    final int stepsCount = (totalDiff / safeStepKg).ceil();
    for (int i = 1; i <= stepsCount; i++) {
      double milestoneWeight;
      if (i == stepsCount) {
        milestoneWeight = targetWeightKg;
      } else {
        if (isLosing) {
          milestoneWeight = currentWeightKg - (safeStepKg * i);
        } else {
          milestoneWeight = currentWeightKg + (safeStepKg * i);
        }
      }

      await _db.into(_db.milestoneGoals).insert(
            MilestoneGoalsCompanion(
              milestoneOrder: Value(i),
              targetWeightKg: Value(double.parse(milestoneWeight.toStringAsFixed(1))),
              isCompleted: const Value(false),
            ),
          );
    }
  }

  /// Marca un hito como completado y registra la fecha de logro.
  Future<void> markCompleted(int id, DateTime completedAt) async {
    final query = _db.update(_db.milestoneGoals)..where((tbl) => tbl.id.equals(id));
    await query.write(
      MilestoneGoalsCompanion(
        isCompleted: const Value(true),
        completedAt: Value(completedAt),
      ),
    );
  }
}

/// Provider de Riverpod para inyectar MilestoneDao.
final milestoneDaoProvider = Provider<MilestoneDao>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return MilestoneDao(db);
});

