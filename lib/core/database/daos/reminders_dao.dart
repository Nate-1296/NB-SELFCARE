import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_database.dart';

/// DAO especializado en la configuración de recordatorios y alarmas exactas.
class RemindersDao {
  RemindersDao(this._db);

  final AppDatabase _db;

  /// Emite la lista completa de recordatorios configurados.
  Stream<List<Reminder>> watchAllReminders() {
    return (_db.select(_db.reminders)..orderBy([(tbl) => OrderingTerm.asc(tbl.timeOfDayMinutes)])).watch();
  }

  /// Obtiene los recordatorios habilitados para programación con SCHEDULE_EXACT_ALARM.
  Future<List<Reminder>> getEnabledReminders() {
    return (_db.select(_db.reminders)..where((tbl) => tbl.isEnabled.equals(true))).get();
  }

  /// Inserta o actualiza un recordatorio.
  Future<int> upsertReminder(RemindersCompanion companion) {
    return _db.into(_db.reminders).insertOnConflictUpdate(companion);
  }

  /// Activa o desactiva un recordatorio específico.
  Future<void> toggleReminder(int id, bool isEnabled) async {
    final query = _db.update(_db.reminders)..where((tbl) => tbl.id.equals(id));
    await query.write(RemindersCompanion(isEnabled: Value(isEnabled)));
  }
}

/// Provider de Riverpod para inyectar RemindersDao.
final remindersDaoProvider = Provider<RemindersDao>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return RemindersDao(db);
});
