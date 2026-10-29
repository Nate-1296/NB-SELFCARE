import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/care_dao.dart';
import '../../../core/database/daos/supplement_dao.dart';
import '../../../core/domain/care_enums.dart';
import '../../../shared/utils/current_date_provider.dart';
import '../../../shared/utils/date_time_extensions.dart';
import '../../profile_goals/application/profile_queries.dart';
import '../domain/checkup_catalog.dart';
import '../domain/pelvic_floor_program.dart';
import '../domain/substance_catalog.dart';
import '../domain/treatment_schedule.dart';
import 'care_session_service.dart';

/// Módulos de Cuidado que la persona tiene activos.
final careModulesProvider = Provider<Set<CareModule>>((Ref ref) {
  final UserProfile? profile = ref.watch(userProfileStreamProvider).value;
  return profile == null ? CareModule.defaults : ProfileSets.careModules(profile.careModulesJson);
});

/// Signos vitales de los aparatos que la persona declara tener.
final vitalDevicesProvider = Provider<Set<VitalKind>>((Ref ref) {
  final UserProfile? profile = ref.watch(userProfileStreamProvider).value;
  return profile == null ? const <VitalKind>{} : ProfileSets.vitalDevices(profile.vitalDevicesJson);
});

// -----------------------------------------------------------------------------
// Tratamientos
// -----------------------------------------------------------------------------

final treatmentsProvider = StreamProvider<List<SupplementsTrackerData>>((Ref ref) {
  return ref.watch(supplementDaoProvider).watchAllSupplements();
});

final doseLogsProvider = StreamProvider.family<List<SupplementLog>, String>((
  Ref ref,
  String dateKey,
) {
  return ref.watch(supplementDaoProvider).watchLogsForDate(dateKey);
});

/// Una toma prevista hoy con su tratamiento.
class TodayDose {
  const TodayDose({required this.treatment, required this.slot});

  final SupplementsTrackerData treatment;
  final DoseSlot slot;
}

/// Tomas del día ordenadas por hora (las "cuando sea" al final).
final todayDosesProvider = Provider.family<List<TodayDose>, String>((Ref ref, String dateKey) {
  final List<SupplementsTrackerData> treatments =
      ref.watch(treatmentsProvider).value ?? const <SupplementsTrackerData>[];
  final List<SupplementLog> logs =
      ref.watch(doseLogsProvider(dateKey)).value ?? const <SupplementLog>[];
  final int weekday = (DateTime.tryParse(dateKey) ?? DateTime(2000)).weekday;
  final List<DoseRecord> records = <DoseRecord>[
    for (final SupplementLog l in logs)
      DoseRecord(treatmentId: l.supplementId, slotMinutes: l.slotMinutes, taken: l.wasTaken),
  ];
  final List<TodayDose> doses = <TodayDose>[
    for (final SupplementsTrackerData t in treatments.where(
      (SupplementsTrackerData t) => t.isEnabled,
    ))
      for (final DoseSlot slot in TreatmentSchedule.slotsFor(
        treatmentId: t.id,
        times: TreatmentSchedule.decodeTimes(t.scheduleJson),
        daysMask: t.daysOfWeekBitmask,
        weekday: weekday,
        records: records,
      ))
        TodayDose(treatment: t, slot: slot),
  ];
  doses.sort(
    (TodayDose a, TodayDose b) =>
        (a.slot.slotMinutes ?? 24 * 60).compareTo(b.slot.slotMinutes ?? 24 * 60),
  );
  return doses;
});

/// Tratamientos activos cuya reserva alcanza para una semana o menos.
final lowStockTreatmentsProvider =
    Provider<List<({SupplementsTrackerData treatment, int daysLeft})>>((Ref ref) {
      final List<SupplementsTrackerData> treatments =
          ref.watch(treatmentsProvider).value ?? const <SupplementsTrackerData>[];
      return <({SupplementsTrackerData treatment, int daysLeft})>[
        for (final SupplementsTrackerData t in treatments.where(
          (SupplementsTrackerData t) => t.isEnabled,
        ))
          if (TreatmentSchedule.daysOfStockLeft(
                stockUnits: t.stockUnits,
                unitsPerDose: t.unitsPerDose,
                dosesPerDay: TreatmentSchedule.decodeTimes(t.scheduleJson).length.clamp(1, 24),
                daysMask: t.daysOfWeekBitmask,
              )
              case final int days when days <= TreatmentSchedule.lowStockDays)
            (treatment: t, daysLeft: days),
      ];
    });

// -----------------------------------------------------------------------------
// Hábitos propios
// -----------------------------------------------------------------------------

final habitsProvider = StreamProvider<List<CustomHabit>>((Ref ref) {
  return ref.watch(careDaoProvider).watchActiveHabits();
});

final habitLogsProvider = StreamProvider.family<List<HabitLog>, String>((Ref ref, String dateKey) {
  return ref.watch(careDaoProvider).watchHabitLogs(dateKey);
});

/// Hábitos que tocan hoy y si ya están hechos.
final todayHabitsProvider = Provider.family<List<({CustomHabit habit, bool done})>, String>((
  Ref ref,
  String dateKey,
) {
  final List<CustomHabit> habits = ref.watch(habitsProvider).value ?? const <CustomHabit>[];
  final Set<int> done = (ref.watch(habitLogsProvider(dateKey)).value ?? const <HabitLog>[])
      .map((HabitLog l) => l.habitId)
      .toSet();
  final int weekday = (DateTime.tryParse(dateKey) ?? DateTime(2000)).weekday;
  return <({CustomHabit habit, bool done})>[
    for (final CustomHabit h in habits)
      if (TreatmentSchedule.appliesOn(h.daysOfWeekBitmask, weekday))
        (habit: h, done: done.contains(h.id)),
  ];
});

// -----------------------------------------------------------------------------
// Sesiones guiadas
// -----------------------------------------------------------------------------

/// Sesiones de los últimos 30 días.
final recentCareSessionsProvider = StreamProvider<List<CareSession>>((Ref ref) {
  final DateTime today = ref.watch(currentDateProvider);
  return ref.watch(careDaoProvider).watchSessionsSince(today.addDays(-30).dateKey);
});

/// Progreso de suelo pélvico: nivel actual, sesiones en él y en la semana.
class PelvicProgress {
  const PelvicProgress({
    required this.level,
    required this.sessionsAtLevel,
    required this.sessionsThisWeek,
    required this.suggestedLevel,
  });

  final int level;
  final int sessionsAtLevel;
  final int sessionsThisWeek;
  final int? suggestedLevel;

  static String variantFor(PelvicVariant variant, int level) =>
      variant == PelvicVariant.relaxOnly ? 'relax' : 'level_$level';

  static int? levelOf(String variant) =>
      variant.startsWith('level_') ? int.tryParse(variant.substring(6)) : null;
}

final pelvicProgressProvider = Provider<PelvicProgress>((Ref ref) {
  final DateTime today = ref.watch(currentDateProvider);
  final List<CareSession> sessions =
      (ref.watch(recentCareSessionsProvider).value ?? const <CareSession>[])
          .where((CareSession s) => s.kind == CareSessionKind.pelvicFloor.key)
          .toList();
  final int level =
      sessions
          .map((CareSession s) => PelvicProgress.levelOf(s.variant))
          .whereType<int>()
          .firstOrNull ??
      1;
  final int atLevel = sessions
      .where((CareSession s) => PelvicProgress.levelOf(s.variant) == level)
      .length;
  final String weekStart = today.addDays(-(today.weekday - 1)).dateKey;
  return PelvicProgress(
    level: level,
    sessionsAtLevel: atLevel,
    sessionsThisWeek: sessions.where((CareSession s) => s.dateKey.compareTo(weekStart) >= 0).length,
    suggestedLevel: PelvicFloorProgram.suggestedNextLevel(current: level, sessionsAtLevel: atLevel),
  );
});

/// Pausas activas y descansos visuales de hoy.
final breaksTodayProvider = Provider<int>((Ref ref) {
  final String todayKey = ref.watch(currentDateKeyProvider);
  return (ref.watch(recentCareSessionsProvider).value ?? const <CareSession>[])
      .where((CareSession s) => s.kind == CareSessionKind.activeBreak.key && s.dateKey == todayKey)
      .length;
});

// -----------------------------------------------------------------------------
// Chequeos preventivos
// -----------------------------------------------------------------------------

final _checkupsProvider = StreamProvider<List<Checkup>>(
  (Ref ref) => ref.watch(careDaoProvider).watchCheckups(),
);

final _checkupLogsProvider = StreamProvider<List<CheckupLog>>(
  (Ref ref) => ref.watch(careDaoProvider).watchCheckupLogs(),
);

class CheckupItem {
  const CheckupItem({required this.checkup, required this.lastLog, required this.due});

  final Checkup checkup;
  final CheckupLog? lastLog;
  final CheckupDue due;
}

/// Chequeos con su estado: primero lo que toca, luego lo pendiente de estrenar, y
/// al final lo que está al día. Los desactivados van aparte.
final checkupItemsProvider = Provider<List<CheckupItem>>((Ref ref) {
  final DateTime today = ref.watch(currentDateProvider);
  final List<Checkup> checkups = ref.watch(_checkupsProvider).value ?? const <Checkup>[];
  final List<CheckupLog> logs = ref.watch(_checkupLogsProvider).value ?? const <CheckupLog>[];
  final List<CheckupItem> items = <CheckupItem>[
    for (final Checkup c in checkups)
      () {
        final CheckupLog? last = logs.where((CheckupLog l) => l.checkupId == c.id).firstOrNull;
        return CheckupItem(
          checkup: c,
          lastLog: last,
          due: CheckupDue.evaluate(
            lastDone: last?.doneAt,
            intervalMonths: c.intervalMonths,
            today: today,
          ),
        );
      }(),
  ];
  int rank(CheckupItem i) => switch (i.due.status) {
    CheckupStatus.due => 0,
    CheckupStatus.dueSoon => 1,
    CheckupStatus.neverDone => 2,
    CheckupStatus.upToDate => 3,
  };
  items.sort((CheckupItem a, CheckupItem b) {
    final int byRank = rank(a).compareTo(rank(b));
    return byRank != 0 ? byRank : (a.due.daysUntil ?? 0).compareTo(b.due.daysUntil ?? 0);
  });
  return items;
});

final checkupLogsProvider = Provider<List<CheckupLog>>(
  (Ref ref) => ref.watch(_checkupLogsProvider).value ?? const <CheckupLog>[],
);

// -----------------------------------------------------------------------------
// Síntomas, signos vitales, alcohol y tabaco, bienestar
// -----------------------------------------------------------------------------

final recentSymptomsProvider = StreamProvider<List<SymptomLog>>((Ref ref) {
  final DateTime today = ref.watch(currentDateProvider);
  return ref.watch(careDaoProvider).watchSymptomsSince(today.addDays(-30).dateKey);
});

final vitalReadingsProvider = StreamProvider.family<List<VitalReading>, VitalKind>((
  Ref ref,
  VitalKind kind,
) {
  return ref.watch(careDaoProvider).watchVitals(kind.key);
});

final _recentSubstancesProvider = StreamProvider<List<SubstanceLog>>((Ref ref) {
  final DateTime today = ref.watch(currentDateProvider);
  return ref.watch(careDaoProvider).watchSubstancesSince(today.addDays(-13).dateKey);
});

/// Resumen de alcohol y tabaco: hoy, esta semana y la anterior (7 días móviles).
class SubstanceSummary {
  const SubstanceSummary({
    required this.today,
    required this.alcohol,
    required this.tobacco,
    required this.drinksToday,
    required this.unitsTobaccoToday,
  });

  final List<SubstanceLog> today;
  final WeeklyTrend alcohol;
  final WeeklyTrend tobacco;
  final double drinksToday;
  final int unitsTobaccoToday;
}

final substanceSummaryProvider = Provider<SubstanceSummary>((Ref ref) {
  final DateTime today = ref.watch(currentDateProvider);
  final String todayKey = today.dateKey;
  final String weekStart = today.addDays(-6).dateKey;
  final List<SubstanceLog> logs =
      ref.watch(_recentSubstancesProvider).value ?? const <SubstanceLog>[];
  double sum(SubstanceKind kind, bool thisWeek) => logs
      .where(
        (SubstanceLog l) =>
            l.kind == kind.key &&
            (thisWeek ? l.dateKey.compareTo(weekStart) >= 0 : l.dateKey.compareTo(weekStart) < 0),
      )
      .fold(
        0.0,
        (double s, SubstanceLog l) =>
            s + (kind == SubstanceKind.alcohol ? l.standardDrinks : l.units),
      );
  final List<SubstanceLog> todays = logs.where((SubstanceLog l) => l.dateKey == todayKey).toList();
  return SubstanceSummary(
    today: todays,
    alcohol: WeeklyTrend(
      thisWeek: sum(SubstanceKind.alcohol, true),
      lastWeek: sum(SubstanceKind.alcohol, false),
    ),
    tobacco: WeeklyTrend(
      thisWeek: sum(SubstanceKind.tobacco, true),
      lastWeek: sum(SubstanceKind.tobacco, false),
    ),
    drinksToday: todays
        .where((SubstanceLog l) => l.kind == SubstanceKind.alcohol.key)
        .fold(0.0, (double s, SubstanceLog l) => s + l.standardDrinks),
    unitsTobaccoToday: todays
        .where((SubstanceLog l) => l.kind == SubstanceKind.tobacco.key)
        .fold(0, (int s, SubstanceLog l) => s + l.units),
  );
});

final wellbeingHistoryProvider = StreamProvider<List<WellbeingCheck>>((Ref ref) {
  return ref.watch(careDaoProvider).watchWellbeing();
});

// -----------------------------------------------------------------------------
// Resumen para la tarjeta de Inicio
// -----------------------------------------------------------------------------

class CareTodaySummary {
  const CareTodaySummary({
    required this.dosesPending,
    required this.dosesTotal,
    required this.nextDose,
    required this.habitsDone,
    required this.habitsTotal,
  });

  final int dosesPending;
  final int dosesTotal;
  final TodayDose? nextDose;
  final int habitsDone;
  final int habitsTotal;

  bool get isEmpty => dosesTotal == 0 && habitsTotal == 0;
}

final careTodaySummaryProvider = Provider.family<CareTodaySummary, String>((
  Ref ref,
  String dateKey,
) {
  final Set<CareModule> modules = ref.watch(careModulesProvider);
  final List<TodayDose> doses = modules.contains(CareModule.treatments)
      ? ref.watch(todayDosesProvider(dateKey))
      : const <TodayDose>[];
  final List<({CustomHabit habit, bool done})> habits = modules.contains(CareModule.habits)
      ? ref.watch(todayHabitsProvider(dateKey))
      : const <({CustomHabit habit, bool done})>[];
  final List<TodayDose> pending = doses
      .where((TodayDose d) => d.slot.status == DoseStatus.pending)
      .toList();
  return CareTodaySummary(
    dosesPending: pending.length,
    dosesTotal: doses.length,
    nextDose: pending.firstOrNull,
    habitsDone: habits.where((({CustomHabit habit, bool done}) h) => h.done).length,
    habitsTotal: habits.length,
  );
});
