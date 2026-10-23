import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/utils/date_time_extensions.dart';
import '../app_database.dart';
import 'pet_dao.dart';

/// DAO especializado en sesiones de ayuno intermitente y fases metabólicas.
class FastingDao {
  FastingDao(this._db, this._petDao);

  final AppDatabase _db;
  final PetDao _petDao;

  /// Emite la sesión de ayuno que se encuentra actualmente en curso (sin hora de finalización).
  Stream<FastingSession?> watchActiveSession() {
    return (_db.select(_db.fastingSessions)
          ..where((tbl) => tbl.actualEndedAt.isNull())
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.startedAt)])
          ..limit(1))
        .watchSingleOrNull();
  }

  /// Obtiene la sesión de ayuno activa en una llamada única.
  Future<FastingSession?> getActiveSession() {
    return (_db.select(_db.fastingSessions)
          ..where((tbl) => tbl.actualEndedAt.isNull())
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.startedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Inicia una nueva sesión de ayuno intermitente.
  Future<int> startFast({
    required String protocolName,
    required int targetHours,
    required DateTime startedAt,
  }) async {
    final DateTime plannedEndAt = startedAt.add(Duration(hours: targetHours));

    return _db.into(_db.fastingSessions).insert(
          FastingSessionsCompanion(
            protocolName: Value(protocolName),
            targetHours: Value(targetHours),
            startedAt: Value(startedAt),
            plannedEndAt: Value(plannedEndAt),
            isCompleted: const Value(false),
          ),
        );
  }

  /// Finaliza la sesión de ayuno activa y recompensa al usuario si cumplió ≥ 14 horas.
  Future<bool> endFast({
    required int sessionId,
    String? notes,
  }) async {
    final now = DateTime.now();

    return _db.transaction(() async {
      final sessionQuery = _db.select(_db.fastingSessions)..where((tbl) => tbl.id.equals(sessionId));
      final FastingSession? session = await sessionQuery.getSingleOrNull();
      if (session == null) return false;

      final double durationHours = now.difference(session.startedAt).inMinutes / 60.0;
      final bool completed = durationHours >= session.targetHours;

      final query = _db.update(_db.fastingSessions)..where((tbl) => tbl.id.equals(sessionId));
      await query.write(
        FastingSessionsCompanion(
          actualEndedAt: Value(now),
          isCompleted: Value(completed),
          notes: Value(notes),
        ),
      );

      // Si ayunó ≥ 14 horas, otorgar recompensa de +20 monedas
      if (durationHours >= 14.0) {
        await _petDao.grantDailyReward(
          dateKey: now.dateKey,
          actionType: 'fast_done',
          baseAmount: 20,
        );
      }

      return true;
    });
  }

  /// Emite las sesiones históricas completadas para estadísticas y gráficas.
  Stream<List<FastingSession>> watchRecentSessions({int limit = 30}) {
    return (_db.select(_db.fastingSessions)
          ..where((tbl) => tbl.actualEndedAt.isNotNull())
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.actualEndedAt)])
          ..limit(limit))
        .watch();
  }
}

/// Provider de Riverpod para inyectar FastingDao.
final fastingDaoProvider = Provider<FastingDao>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  final PetDao petDao = ref.watch(petDaoProvider);
  return FastingDao(db, petDao);
});

/// StreamProvider con la sesión de ayuno activa en tiempo real.
final activeFastingSessionStreamProvider = StreamProvider<FastingSession?>((ref) {
  final FastingDao dao = ref.watch(fastingDaoProvider);
  return dao.watchActiveSession();
});
