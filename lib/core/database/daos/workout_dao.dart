import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_database.dart';

/// DAO especializado en el registro y consulta de bloques de entrenamiento RPE.
class WorkoutDao {
  WorkoutDao(this._db);

  final AppDatabase _db;

  /// Emite en vivo los entrenamientos registrados para una fecha dada.
  Stream<List<WorkoutBlock>> watchWorkoutsForDate(String dateKey) {
    return (_db.select(_db.workoutBlocks)
          ..where((tbl) => tbl.dateKey.equals(dateKey))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.performedAt)]))
        .watch();
  }

  /// Inserta un nuevo bloque de entrenamiento RPE en 5 segundos.
  Future<int> insertWorkout(WorkoutBlocksCompanion companion) {
    return _db.into(_db.workoutBlocks).insert(companion);
  }

  /// Elimina un bloque de ejercicio por su ID.
  Future<int> deleteWorkout(int id) {
    return (_db.delete(_db.workoutBlocks)..where((tbl) => tbl.id.equals(id))).go();
  }

  /// Emite la suma total de calorías netas quemadas en el día por entrenamientos.
  Stream<int> watchNetCaloriesForDate(String dateKey) {
    final query = _db.selectOnly(_db.workoutBlocks)
      ..addColumns([_db.workoutBlocks.netCaloriesBurned.sum()])
      ..where(_db.workoutBlocks.dateKey.equals(dateKey));

    return query.watchSingle().map((row) => row.read(_db.workoutBlocks.netCaloriesBurned.sum()) ?? 0);
  }
}

/// Provider de Riverpod para inyectar WorkoutDao.
final workoutDaoProvider = Provider<WorkoutDao>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return WorkoutDao(db);
});
