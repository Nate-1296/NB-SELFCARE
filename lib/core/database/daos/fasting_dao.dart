import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../clock/clock.dart';
import '../app_database.dart';

/// DAO especializado en sesiones de ayuno intermitente y fases metabólicas.
class FastingDao {
  FastingDao(this._db, {this._clock = const Clock()});

  final Clock _clock;

  final AppDatabase _db;

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

  /// Finaliza la sesión de ayuno y devuelve la sesión cerrada (o `null` si no existe).
  ///
  /// `isCompleted` indica si se alcanzó la meta de horas del protocolo.
  Future<FastingSession?> endFast({
    required int sessionId,
    String? notes,
  }) async {
    final now = _clock.now();

    return _db.transaction(() async {
      final sessionQuery = _db.select(_db.fastingSessions)..where((tbl) => tbl.id.equals(sessionId));
      final FastingSession? session = await sessionQuery.getSingleOrNull();
      if (session == null) return null;

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

      return session.copyWith(
        actualEndedAt: Value(now),
        isCompleted: completed,
        notes: Value(notes),
      );
    });
  }

  /// Ajusta la hora de inicio de un ayuno en curso (útil si el usuario olvidó iniciarlo anoche).
  Future<bool> updateActiveFastStart({
    required int sessionId,
    required DateTime newStartedAt,
  }) async {
    final sessionQuery = _db.select(_db.fastingSessions)
      ..where((tbl) => tbl.id.equals(sessionId));
    final FastingSession? session = await sessionQuery.getSingleOrNull();
    if (session == null || session.actualEndedAt != null) return false;

    final DateTime newPlannedEnd =
        newStartedAt.add(Duration(hours: session.targetHours));
    final query = _db.update(_db.fastingSessions)
      ..where((tbl) => tbl.id.equals(sessionId));
    final int updated = await query.write(
      FastingSessionsCompanion(
        startedAt: Value(newStartedAt),
        plannedEndAt: Value(newPlannedEnd),
      ),
    );
    return updated > 0;
  }

  /// Elimina una sesión histórica de ayuno por su ID.
  /// Reinserta una sesión borrada (flujo Deshacer).
  Future<void> restoreSession(FastingSession session) {
    return _db.into(_db.fastingSessions).insertOnConflictUpdate(session);
  }

  Future<int> deleteSession(int sessionId) {
    return (_db.delete(_db.fastingSessions)
          ..where((tbl) => tbl.id.equals(sessionId)))
        .go();
  }

  /// Emite las sesiones históricas completadas para estadísticas y gráficas.
  Stream<List<FastingSession>> watchRecentSessions({int limit = 30}) {
    return (_db.select(_db.fastingSessions)
          ..where((tbl) => tbl.actualEndedAt.isNotNull())
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.actualEndedAt)])
          ..limit(limit))
        .watch();
  }

  /// Obtiene las sesiones históricas completadas recientes en una sola llamada.
  Future<List<FastingSession>> getRecentSessions({int limit = 30}) {
    return (_db.select(_db.fastingSessions)
          ..where((tbl) => tbl.actualEndedAt.isNotNull())
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.actualEndedAt)])
          ..limit(limit))
        .get();
  }
}

/// Provider de Riverpod para inyectar FastingDao.
final fastingDaoProvider = Provider<FastingDao>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return FastingDao(db, clock: ref.watch(clockProvider));
});
