import 'dart:convert';

/// Estado de una toma del día. "Omitida" es una decisión, no un fallo.
enum DoseStatus { pending, taken, skipped }

/// Toma registrada (lo que hay en `supplement_logs` para un día).
class DoseRecord {
  const DoseRecord({required this.treatmentId, required this.slotMinutes, required this.taken});

  final int treatmentId;

  /// `null` = toma única sin hora.
  final int? slotMinutes;
  final bool taken;
}

/// Una toma prevista hoy.
class DoseSlot {
  const DoseSlot({required this.treatmentId, required this.slotMinutes, required this.status});

  final int treatmentId;
  final int? slotMinutes;
  final DoseStatus status;
}

abstract final class TreatmentSchedule {
  /// Horas de toma guardadas como JSON (minutos desde medianoche), ordenadas y sin repetir.
  static List<int> decodeTimes(String raw) {
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return const <int>[];
      final Set<int> times = decoded
          .whereType<num>()
          .map((num v) => v.toInt())
          .where((int v) => v >= 0 && v < 24 * 60)
          .toSet();
      return times.toList()..sort();
    } on FormatException {
      return const <int>[];
    }
  }

  static String encodeTimes(Iterable<int> times) {
    final List<int> sorted = times.where((int v) => v >= 0 && v < 24 * 60).toSet().toList()..sort();
    return jsonEncode(sorted);
  }

  /// Si el tratamiento toca el [weekday] (1 = lunes … 7 = domingo).
  static bool appliesOn(int daysMask, int weekday) => daysMask & (1 << (weekday - 1)) != 0;

  /// Tomas de hoy con su estado. Sin horario = una toma "cuando sea" (slot null).
  static List<DoseSlot> slotsFor({
    required int treatmentId,
    required List<int> times,
    required int daysMask,
    required int weekday,
    required List<DoseRecord> records,
  }) {
    if (!appliesOn(daysMask, weekday)) return const <DoseSlot>[];
    final List<int?> slots = times.isEmpty ? const <int?>[null] : times;
    return <DoseSlot>[
      for (final int? slot in slots)
        DoseSlot(
          treatmentId: treatmentId,
          slotMinutes: slot,
          status: _statusOf(treatmentId, slot, records),
        ),
    ];
  }

  static DoseStatus _statusOf(int id, int? slot, List<DoseRecord> records) {
    for (final DoseRecord r in records.reversed) {
      if (r.treatmentId == id && r.slotMinutes == slot) {
        return r.taken ? DoseStatus.taken : DoseStatus.skipped;
      }
    }
    return DoseStatus.pending;
  }

  /// Días que alcanza la reserva, o `null` si no se lleva la cuenta.
  static int? daysOfStockLeft({
    required double? stockUnits,
    required double unitsPerDose,
    required int dosesPerDay,
    required int daysMask,
  }) {
    if (stockUnits == null) return null;
    final int activeDays = List<int>.generate(
      7,
      (int i) => i + 1,
    ).where((int d) => appliesOn(daysMask, d)).length;
    if (activeDays == 0 || dosesPerDay == 0 || unitsPerDose <= 0) return null;
    final double perDay = unitsPerDose * dosesPerDay * activeDays / 7;
    return (stockUnits / perDay).floor();
  }

  /// Aviso de reponer cuando quedan una semana o menos.
  static const int lowStockDays = 7;
}
