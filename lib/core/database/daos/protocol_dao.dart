import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_database.dart';

/// DAO para el tablero de planificación semanal estratégica "Mi Protocolo".
class ProtocolDao {
  ProtocolDao(this._db);

  final AppDatabase _db;

  /// Emite el protocolo semanal actualmente activo.
  Stream<ProtocolPlan?> watchActiveProtocol() {
    return (_db.select(_db.protocolPlans)
          ..where((tbl) => tbl.isCurrentActive.equals(true))
          ..limit(1))
        .watchSingleOrNull();
  }

  /// Obtiene el protocolo semanal activo en una sola llamada.
  Future<ProtocolPlan?> getActiveProtocol() {
    return (_db.select(_db.protocolPlans)
          ..where((tbl) => tbl.isCurrentActive.equals(true))
          ..limit(1))
        .getSingleOrNull();
  }

  /// Crea o actualiza el protocolo semanal activo.
  Future<int> saveActiveProtocol({
    required String planName,
    required String fastingDaysBitmask,
    required String workoutSlotsJson,
    required String dietArchetype,
  }) async {
    final existing = await getActiveProtocol();

    if (existing != null) {
      final query = _db.update(_db.protocolPlans)
        ..where((tbl) => tbl.id.equals(existing.id));
      await query.write(
        ProtocolPlansCompanion(
          planName: Value(planName),
          fastingDaysBitmask: Value(fastingDaysBitmask),
          workoutSlotsJson: Value(workoutSlotsJson),
          dietArchetype: Value(dietArchetype),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return existing.id;
    } else {
      return _db.into(_db.protocolPlans).insert(
            ProtocolPlansCompanion(
              planName: Value(planName),
              fastingDaysBitmask: Value(fastingDaysBitmask),
              workoutSlotsJson: Value(workoutSlotsJson),
              dietArchetype: Value(dietArchetype),
              isCurrentActive: const Value(true),
              updatedAt: Value(DateTime.now()),
            ),
          );
    }
  }
}

/// Provider de Riverpod para inyectar ProtocolDao.
final protocolDaoProvider = Provider<ProtocolDao>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return ProtocolDao(db);
});

