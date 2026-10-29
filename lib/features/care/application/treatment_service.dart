import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock/clock.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/supplement_dao.dart';
import '../../../core/platform/native_call.dart';
import '../../../core/platform/notification_gateway.dart';
import '../../../shared/utils/date_time_extensions.dart';
import '../../profile_goals/application/reminder_service.dart';
import '../domain/treatment_schedule.dart';

/// Tipo de tratamiento.
enum TreatmentKind {
  medication('medication'),
  supplement('supplement');

  const TreatmentKind(this.key);

  final String key;

  static TreatmentKind fromKey(String raw) =>
      raw == medication.key ? TreatmentKind.medication : TreatmentKind.supplement;
}

/// Lo que se edita en la hoja de un tratamiento.
class TreatmentDraft {
  const TreatmentDraft({
    required this.name,
    required this.dosage,
    required this.kind,
    this.times = const <int>[],
    this.daysMask = 127,
    this.stockUnits,
    this.unitsPerDose = 1,
    this.remindersEnabled = false,
    this.lowersGlucose = false,
    this.affectsWaterRetention = false,
    this.notes,
  });

  factory TreatmentDraft.of(SupplementsTrackerData t) => TreatmentDraft(
    name: t.name,
    dosage: t.dosage,
    kind: TreatmentKind.fromKey(t.kind),
    times: TreatmentSchedule.decodeTimes(t.scheduleJson),
    daysMask: t.daysOfWeekBitmask,
    stockUnits: t.stockUnits,
    unitsPerDose: t.unitsPerDose,
    remindersEnabled: t.remindersEnabled,
    lowersGlucose: t.lowersGlucose,
    affectsWaterRetention: t.affectsWaterRetention,
    notes: t.notes,
  );

  final String name;
  final String dosage;
  final TreatmentKind kind;
  final List<int> times;
  final int daysMask;
  final double? stockUnits;
  final double unitsPerDose;
  final bool remindersEnabled;
  final bool lowersGlucose;
  final bool affectsWaterRetention;
  final String? notes;
}

/// Medicamentos y suplementos: alta, edición, pausa, tomas y avisos.
class TreatmentService {
  TreatmentService(this._dao, this._reminders, this._notifications, this._clock);

  final SupplementDao _dao;
  final ReminderService _reminders;
  final NotificationGateway _notifications;
  final Clock _clock;

  static const int maxNameLength = 60;

  /// Guarda un tratamiento nuevo ([id] nulo) o editado, y reprograma los avisos.
  Future<int?> save(TreatmentDraft draft, {int? id}) async {
    final String name = draft.name.trim();
    if (name.isEmpty) return null;
    final List<int> times = TreatmentSchedule.decodeTimes(
      TreatmentSchedule.encodeTimes(draft.times),
    );
    final SupplementsTrackerCompanion row = SupplementsTrackerCompanion(
      id: id == null ? const Value<int>.absent() : Value<int>(id),
      name: Value(name.length > maxNameLength ? name.substring(0, maxNameLength) : name),
      dosage: Value(draft.dosage.trim()),
      kind: Value(draft.kind.key),
      scheduleJson: Value(TreatmentSchedule.encodeTimes(times)),
      targetTimeOfDayMinutes: Value(times.isEmpty ? null : times.first),
      daysOfWeekBitmask: Value(draft.daysMask & 0x7F == 0 ? 127 : draft.daysMask & 0x7F),
      stockUnits: Value(
        draft.stockUnits == null || draft.stockUnits! < 0 ? null : draft.stockUnits,
      ),
      unitsPerDose: Value(draft.unitsPerDose > 0 ? draft.unitsPerDose : 1),
      remindersEnabled: Value(draft.remindersEnabled && times.isNotEmpty),
      lowersGlucose: Value(draft.lowersGlucose),
      affectsWaterRetention: Value(draft.affectsWaterRetention),
      notes: Value(draft.notes?.trim().isEmpty ?? true ? null : draft.notes!.trim()),
      isEnabled: const Value(true),
    );
    final int savedId = await _dao.upsertSupplement(row);
    await _reminders.syncSchedules();
    return id ?? savedId;
  }

  /// Pausa o reanuda un tratamiento (deja de aparecer en el día y de avisar).
  Future<void> setActive(int id, {required bool active}) async {
    await _dao.updateSupplement(
      SupplementsTrackerCompanion(id: Value(id), isEnabled: Value(active)),
    );
    await _reminders.syncSchedules();
  }

  Future<void> remove(int id) async {
    await _dao.deleteSupplement(id);
    await _reminders.syncSchedules();
  }

  /// Deshacer un borrado (las tomas del historial se borran en cascada).
  Future<void> restore(SupplementsTrackerData row) async {
    await _dao.upsertSupplement(row.toCompanion(true));
    await _reminders.syncSchedules();
  }

  Future<void> markDose({
    required String dateKey,
    required int treatmentId,
    required int? slotMinutes,
    required bool taken,
  }) {
    return _dao.toggleSupplementIntake(
      dateKey: dateKey,
      supplementId: treatmentId,
      wasTaken: taken,
      slotMinutes: slotMinutes,
    );
  }

  Future<void> clearDose({
    required String dateKey,
    required int treatmentId,
    required int? slotMinutes,
  }) {
    return _dao.clearIntake(dateKey: dateKey, supplementId: treatmentId, slotMinutes: slotMinutes);
  }

  /// Suma unidades a la reserva (compré otra caja).
  Future<void> refill(int id, double units) async {
    final List<SupplementsTrackerData> all = await _dao.getAllSupplements();
    final SupplementsTrackerData? item = all
        .where((SupplementsTrackerData t) => t.id == id)
        .firstOrNull;
    if (item == null || units <= 0) return;
    await _dao.updateSupplement(
      SupplementsTrackerCompanion(id: Value(id), stockUnits: Value((item.stockUnits ?? 0) + units)),
    );
  }

  /// Aplica los "Hecho" pulsados en las notificaciones con la app cerrada.
  Future<int> applyNotificationActions() async {
    final List<ReminderActionEvent> events = await bestEffort(
      _notifications.consumeReminderActions,
      const <ReminderActionEvent>[],
    );
    int applied = 0;
    for (final ReminderActionEvent e in events) {
      final ({int treatmentId, int? slotMinutes})? dose = ReminderService.parseDoseAction(e.key);
      if (dose == null) continue;
      final DateTime at = e.at.isAfter(_clock.now()) ? _clock.now() : e.at;
      await _dao.toggleSupplementIntake(
        dateKey: at.dateKey,
        supplementId: dose.treatmentId,
        wasTaken: true,
        slotMinutes: dose.slotMinutes,
        at: at,
      );
      applied++;
    }
    return applied;
  }
}

final treatmentServiceProvider = Provider<TreatmentService>((Ref ref) {
  return TreatmentService(
    ref.watch(supplementDaoProvider),
    ref.watch(reminderServiceProvider),
    ref.watch(notificationGatewayProvider),
    ref.watch(clockProvider),
  );
});
