import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/enums.dart';
import '../app_database.dart';

/// DAO especializado en la configuración de recordatorios locales y rutinas diarias.
class RemindersDao {
  RemindersDao(this._db);

  final AppDatabase _db;

  /// Emite la lista completa de recordatorios configurados ordenados por hora.
  Stream<List<Reminder>> watchAllReminders() {
    return (_db.select(
      _db.reminders,
    )..orderBy([(tbl) => OrderingTerm.asc(tbl.timeOfDayMinutes)])).watch();
  }

  Future<List<Reminder>> getAllReminders() => _db.select(_db.reminders).get();

  /// Obtiene los recordatorios habilitados para programación con SCHEDULE_EXACT_ALARM.
  Future<List<Reminder>> getEnabledReminders() {
    return (_db.select(_db.reminders)..where((tbl) => tbl.isEnabled.equals(true))).get();
  }

  /// Inserta los 4 recordatorios canónicos del santuario si la tabla está vacía.
  Future<void> seedDefaultRemindersIfEmpty() async {
    final existing = await (_db.select(_db.reminders)..limit(1)).get();
    if (existing.isNotEmpty) return;

    await _db.batch((b) {
      b.insertAll(_db.reminders, [
        RemindersCompanion.insert(
          reminderType: ReminderType.morningWeighIn,
          timeOfDayMinutes: 7 * 60 + 30, // 07:30
          isEnabled: const Value(true),
        ),
        RemindersCompanion.insert(
          reminderType: ReminderType.hydration,
          timeOfDayMinutes: 11 * 60, // 11:00
          intervalMinutes: const Value(120),
          isEnabled: const Value(true),
        ),
        RemindersCompanion.insert(
          reminderType: ReminderType.fastingClose,
          timeOfDayMinutes: 20 * 60, // 20:00
          isEnabled: const Value(false),
        ),
        RemindersCompanion.insert(
          reminderType: ReminderType.journal,
          timeOfDayMinutes: 21 * 60 + 30, // 21:30
          isEnabled: const Value(true),
        ),
      ]);
    });
  }

  /// Añade, apagados, los tipos de recordatorio que llegaron en versiones
  /// posteriores (v7: desconectar, suelo pélvico, descanso visual).
  Future<void> ensureReminderTypes() async {
    final Set<ReminderType> existing = (await _db.select(_db.reminders).get())
        .map((Reminder r) => r.reminderType)
        .toSet();
    final List<RemindersCompanion> missing = <RemindersCompanion>[
      if (!existing.contains(ReminderType.windDown))
        RemindersCompanion.insert(
          reminderType: ReminderType.windDown,
          timeOfDayMinutes: 22 * 60 + 30, // 22:30
          isEnabled: const Value(false),
        ),
      if (!existing.contains(ReminderType.pelvicFloor))
        RemindersCompanion.insert(
          reminderType: ReminderType.pelvicFloor,
          timeOfDayMinutes: 13 * 60, // 13:00
          isEnabled: const Value(false),
        ),
      if (!existing.contains(ReminderType.eyeRest))
        RemindersCompanion.insert(
          reminderType: ReminderType.eyeRest,
          timeOfDayMinutes: 9 * 60 + 30, // 09:30, luego cada hora
          intervalMinutes: const Value(60),
          isEnabled: const Value(false),
        ),
    ];
    if (missing.isEmpty) return;
    await _db.batch((Batch b) => b.insertAll(_db.reminders, missing));
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

  /// Actualiza la hora del día (en minutos desde medianoche) de un recordatorio.
  Future<void> updateReminderTime(int id, int timeOfDayMinutes) async {
    final query = _db.update(_db.reminders)..where((tbl) => tbl.id.equals(id));
    await query.write(RemindersCompanion(timeOfDayMinutes: Value(timeOfDayMinutes.clamp(0, 1439))));
  }
}

/// Provider de Riverpod para inyectar RemindersDao.
final remindersDaoProvider = Provider<RemindersDao>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return RemindersDao(db);
});
