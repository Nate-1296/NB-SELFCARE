import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../clock/clock.dart';
import '../app_database.dart';

/// DAO de la pestaña Cuidado (v7): sesiones guiadas, hábitos propios, chequeos
/// preventivos, síntomas, signos vitales, alcohol y tabaco, e índice OMS-5.
class CareDao {
  CareDao(this._db, {this._clock = const Clock()});

  final AppDatabase _db;
  final Clock _clock;

  // ---------------------------------------------------------------------------
  // Sesiones guiadas
  // ---------------------------------------------------------------------------

  Future<int> insertSession({
    required String dateKey,
    required String kind,
    required String variant,
    required int durationSeconds,
    DateTime? completedAt,
  }) {
    return _db
        .into(_db.careSessions)
        .insert(
          CareSessionsCompanion.insert(
            dateKey: dateKey,
            completedAt: completedAt ?? _clock.now(),
            kind: kind,
            variant: variant,
            durationSeconds: durationSeconds,
          ),
        );
  }

  Stream<List<CareSession>> watchSessionsSince(String fromDateKey) {
    return (_db.select(_db.careSessions)
          ..where((tbl) => tbl.dateKey.isBiggerOrEqualValue(fromDateKey))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.completedAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<List<CareSession>> getSessionsOfKind(String kind) {
    return (_db.select(_db.careSessions)
          ..where((tbl) => tbl.kind.equals(kind))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.completedAt, mode: OrderingMode.desc)]))
        .get();
  }

  // ---------------------------------------------------------------------------
  // Hábitos propios
  // ---------------------------------------------------------------------------

  Stream<List<CustomHabit>> watchActiveHabits() {
    return (_db.select(_db.customHabits)
          ..where((tbl) => tbl.isArchived.equals(false))
          ..orderBy([
            (tbl) => OrderingTerm(expression: tbl.sortOrder),
            (tbl) => OrderingTerm(expression: tbl.id),
          ]))
        .watch();
  }

  Future<List<CustomHabit>> getActiveHabits() {
    return (_db.select(_db.customHabits)..where((tbl) => tbl.isArchived.equals(false))).get();
  }

  Future<int> insertHabit({
    required String name,
    required String iconKey,
    required int daysMask,
  }) async {
    final int order = (await _db.select(_db.customHabits).get()).length;
    return _db
        .into(_db.customHabits)
        .insert(
          CustomHabitsCompanion.insert(
            name: name,
            iconKey: Value(iconKey),
            daysOfWeekBitmask: Value(daysMask),
            sortOrder: Value(order),
            createdAt: _clock.now(),
          ),
        );
  }

  Future<void> archiveHabit(int id, {required bool archived}) {
    return (_db.update(
      _db.customHabits,
    )..where((tbl) => tbl.id.equals(id))).write(CustomHabitsCompanion(isArchived: Value(archived)));
  }

  Stream<List<HabitLog>> watchHabitLogs(String dateKey) {
    return (_db.select(_db.habitLogs)..where((tbl) => tbl.dateKey.equals(dateKey))).watch();
  }

  Future<List<HabitLog>> getHabitLogs(String dateKey) {
    return (_db.select(_db.habitLogs)..where((tbl) => tbl.dateKey.equals(dateKey))).get();
  }

  Future<List<HabitLog>> getHabitLogsSince(String fromDateKey) {
    return (_db.select(
      _db.habitLogs,
    )..where((tbl) => tbl.dateKey.isBiggerOrEqualValue(fromDateKey))).get();
  }

  /// Marca o desmarca un hábito en un día (idempotente).
  Future<void> setHabitDone({
    required int habitId,
    required String dateKey,
    required bool done,
  }) async {
    if (done) {
      await _db
          .into(_db.habitLogs)
          .insert(
            HabitLogsCompanion.insert(habitId: habitId, dateKey: dateKey, loggedAt: _clock.now()),
            mode: InsertMode.insertOrIgnore,
          );
    } else {
      await (_db.delete(
        _db.habitLogs,
      )..where((tbl) => tbl.habitId.equals(habitId) & tbl.dateKey.equals(dateKey))).go();
    }
  }

  // ---------------------------------------------------------------------------
  // Chequeos preventivos
  // ---------------------------------------------------------------------------

  Stream<List<Checkup>> watchCheckups() {
    return (_db.select(_db.checkups)..orderBy([(tbl) => OrderingTerm(expression: tbl.id)])).watch();
  }

  Future<List<Checkup>> getCheckups() => _db.select(_db.checkups).get();

  Future<int> insertCheckup({
    required String catalogKey,
    required int intervalMonths,
    String? customName,
    bool enabled = true,
  }) {
    return _db
        .into(_db.checkups)
        .insert(
          CheckupsCompanion.insert(
            catalogKey: catalogKey,
            intervalMonths: intervalMonths,
            customName: Value(customName),
            isEnabled: Value(enabled),
          ),
        );
  }

  Future<void> updateCheckup(int id, {int? intervalMonths, bool? enabled}) {
    return (_db.update(_db.checkups)..where((tbl) => tbl.id.equals(id))).write(
      CheckupsCompanion(
        intervalMonths: intervalMonths == null ? const Value.absent() : Value(intervalMonths),
        isEnabled: enabled == null ? const Value.absent() : Value(enabled),
      ),
    );
  }

  Future<void> deleteCheckup(int id) =>
      (_db.delete(_db.checkups)..where((tbl) => tbl.id.equals(id))).go();

  Stream<List<CheckupLog>> watchCheckupLogs() {
    return (_db.select(
      _db.checkupLogs,
    )..orderBy([(tbl) => OrderingTerm(expression: tbl.doneAt, mode: OrderingMode.desc)])).watch();
  }

  Future<int> insertCheckupLog({required int checkupId, required DateTime doneAt, String? notes}) {
    return _db
        .into(_db.checkupLogs)
        .insert(
          CheckupLogsCompanion.insert(checkupId: checkupId, doneAt: doneAt, notes: Value(notes)),
        );
  }

  Future<void> deleteCheckupLog(int id) =>
      (_db.delete(_db.checkupLogs)..where((tbl) => tbl.id.equals(id))).go();

  Future<void> restoreCheckupLog(CheckupLog log) =>
      _db.into(_db.checkupLogs).insertOnConflictUpdate(log);

  // ---------------------------------------------------------------------------
  // Síntomas
  // ---------------------------------------------------------------------------

  Future<int> insertSymptom({
    required String dateKey,
    required String symptom,
    required int intensity,
    String? notes,
  }) {
    return _db
        .into(_db.symptomLogs)
        .insert(
          SymptomLogsCompanion.insert(
            dateKey: dateKey,
            loggedAt: _clock.now(),
            symptom: symptom,
            intensity: intensity.clamp(1, 5),
            notes: Value(notes),
          ),
        );
  }

  Stream<List<SymptomLog>> watchSymptomsSince(String fromDateKey) {
    return (_db.select(_db.symptomLogs)
          ..where((tbl) => tbl.dateKey.isBiggerOrEqualValue(fromDateKey))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.loggedAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<List<SymptomLog>> getSymptomsSince(String fromDateKey) {
    return (_db.select(
      _db.symptomLogs,
    )..where((tbl) => tbl.dateKey.isBiggerOrEqualValue(fromDateKey))).get();
  }

  Future<void> deleteSymptom(int id) =>
      (_db.delete(_db.symptomLogs)..where((tbl) => tbl.id.equals(id))).go();

  Future<void> restoreSymptom(SymptomLog log) =>
      _db.into(_db.symptomLogs).insertOnConflictUpdate(log);

  // ---------------------------------------------------------------------------
  // Signos vitales
  // ---------------------------------------------------------------------------

  /// Guarda una lectura. Con [externalId] (Health Connect) no se duplica.
  Future<int> insertVital(VitalReadingsCompanion reading) {
    return _db.into(_db.vitalReadings).insert(reading, mode: InsertMode.insertOrIgnore);
  }

  Stream<List<VitalReading>> watchVitals(String kind, {int limit = 60}) {
    return (_db.select(_db.vitalReadings)
          ..where((tbl) => tbl.kind.equals(kind))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.measuredAt, mode: OrderingMode.desc)])
          ..limit(limit))
        .watch();
  }

  Future<List<VitalReading>> getVitalsSince(DateTime from) {
    return (_db.select(_db.vitalReadings)
          ..where((tbl) => tbl.measuredAt.isBiggerOrEqualValue(from))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.measuredAt)]))
        .get();
  }

  Future<void> deleteVital(int id) =>
      (_db.delete(_db.vitalReadings)..where((tbl) => tbl.id.equals(id))).go();

  Future<void> restoreVital(VitalReading reading) =>
      _db.into(_db.vitalReadings).insertOnConflictUpdate(reading);

  // ---------------------------------------------------------------------------
  // Alcohol y tabaco
  // ---------------------------------------------------------------------------

  Future<int> insertSubstance(SubstanceLogsCompanion log) =>
      _db.into(_db.substanceLogs).insert(log);

  Stream<List<SubstanceLog>> watchSubstancesSince(String fromDateKey) {
    return (_db.select(_db.substanceLogs)
          ..where((tbl) => tbl.dateKey.isBiggerOrEqualValue(fromDateKey))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.loggedAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<List<SubstanceLog>> getSubstancesSince(String fromDateKey) {
    return (_db.select(
      _db.substanceLogs,
    )..where((tbl) => tbl.dateKey.isBiggerOrEqualValue(fromDateKey))).get();
  }

  Stream<List<SubstanceLog>> watchSubstancesFor(String dateKey) {
    return (_db.select(_db.substanceLogs)..where((tbl) => tbl.dateKey.equals(dateKey))).watch();
  }

  Future<SubstanceLog?> getSubstance(int id) =>
      (_db.select(_db.substanceLogs)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Future<void> deleteSubstance(int id) =>
      (_db.delete(_db.substanceLogs)..where((tbl) => tbl.id.equals(id))).go();

  Future<void> restoreSubstance(SubstanceLog log) =>
      _db.into(_db.substanceLogs).insertOnConflictUpdate(log);

  // ---------------------------------------------------------------------------
  // Índice OMS-5
  // ---------------------------------------------------------------------------

  Future<int> insertWellbeing({
    required String dateKey,
    required String answersJson,
    required int percentScore,
  }) {
    return _db
        .into(_db.wellbeingChecks)
        .insert(
          WellbeingChecksCompanion.insert(
            dateKey: dateKey,
            createdAt: _clock.now(),
            answersJson: answersJson,
            percentScore: percentScore,
          ),
        );
  }

  Stream<List<WellbeingCheck>> watchWellbeing({int limit = 12}) {
    return (_db.select(_db.wellbeingChecks)
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc)])
          ..limit(limit))
        .watch();
  }
}

final careDaoProvider = Provider<CareDao>((Ref ref) {
  return CareDao(ref.watch(appDatabaseProvider), clock: ref.watch(clockProvider));
});
