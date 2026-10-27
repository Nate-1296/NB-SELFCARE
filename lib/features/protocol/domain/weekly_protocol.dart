import 'dart:convert';

enum WorkoutTimeOfDay {
  morning('morning'),
  afternoon('afternoon'),
  evening('evening');

  const WorkoutTimeOfDay(this.code);

  final String code;

  static WorkoutTimeOfDay parse(Object? raw) => switch (raw) {
        'afternoon' || 'tarde' => WorkoutTimeOfDay.afternoon,
        'evening' || 'noche' => WorkoutTimeOfDay.evening,
        _ => WorkoutTimeOfDay.morning,
      };
}

/// Plan semanal ("Mi protocolo"): qué días se ayuna y cuántas horas, y qué
/// días y a qué hora se entrena. Días ISO: 1 = lunes … 7 = domingo.
class WeeklyProtocol {
  const WeeklyProtocol({
    required this.fastingDays,
    required this.fastingHours,
    required this.workoutDays,
    required this.workoutTime,
  });

  static const WeeklyProtocol defaults = WeeklyProtocol(
    fastingDays: <int>{1, 2, 3, 4, 5},
    fastingHours: 16,
    workoutDays: <int>{1, 3, 5},
    workoutTime: WorkoutTimeOfDay.morning,
  );

  /// Lee las columnas guardadas. Acepta el formato actual (JSON día → horas)
  /// y el antiguo de la pantalla ("1,2,3"), que no guardaba las horas.
  factory WeeklyProtocol.decode({required String fastingDays, required String workoutSlots}) {
    Set<int> fasting = WeeklyProtocol.defaults.fastingDays;
    int hours = WeeklyProtocol.defaults.fastingHours;
    final String f = fastingDays.trim();
    if (f.startsWith('{')) {
      final Object? decoded = jsonDecode(f);
      if (decoded is Map<String, dynamic>) {
        final Map<int, int> byDay = <int, int>{
          for (final MapEntry<String, dynamic> e in decoded.entries)
            if (int.tryParse(e.key) != null && e.value is num) int.parse(e.key): (e.value as num).toInt(),
        };
        fasting = byDay.entries.where((MapEntry<int, int> e) => e.value > 0).map((MapEntry<int, int> e) => e.key).toSet();
        final Iterable<int> active = byDay.values.where((int h) => h > 0);
        if (active.isNotEmpty) hours = active.first;
      }
    } else if (f.isNotEmpty) {
      fasting = f.split(',').map((String s) => int.tryParse(s.trim())).whereType<int>().toSet();
    }

    Set<int> workout = WeeklyProtocol.defaults.workoutDays;
    WorkoutTimeOfDay time = WeeklyProtocol.defaults.workoutTime;
    final String w = workoutSlots.trim();
    if (w.startsWith('{')) {
      final Object? decoded = jsonDecode(w);
      if (decoded is Map<String, dynamic>) {
        final Object? days = decoded['days'];
        if (days is List<dynamic>) workout = days.whereType<num>().map((num n) => n.toInt()).toSet();
        time = WorkoutTimeOfDay.parse(decoded['time']);
      }
    }
    return WeeklyProtocol(
      fastingDays: fasting.where((int d) => d >= 1 && d <= 7).toSet(),
      fastingHours: hours.clamp(12, 36),
      workoutDays: workout.where((int d) => d >= 1 && d <= 7).toSet(),
      workoutTime: time,
    );
  }

  final Set<int> fastingDays;
  final int fastingHours;
  final Set<int> workoutDays;
  final WorkoutTimeOfDay workoutTime;

  String get encodedFastingDays =>
      jsonEncode(<String, int>{for (int d = 1; d <= 7; d++) '$d': fastingDays.contains(d) ? fastingHours : 0});

  String get encodedWorkoutSlots =>
      jsonEncode(<String, Object>{'days': (workoutDays.toList()..sort()), 'time': workoutTime.code});

  /// Horas de ayuno previstas para un día, o `null` si ese día no se ayuna.
  int? fastingHoursFor(DateTime day) => fastingDays.contains(day.weekday) ? fastingHours : null;

  WeeklyProtocol copyWith({
    Set<int>? fastingDays,
    int? fastingHours,
    Set<int>? workoutDays,
    WorkoutTimeOfDay? workoutTime,
  }) {
    return WeeklyProtocol(
      fastingDays: fastingDays ?? this.fastingDays,
      fastingHours: fastingHours ?? this.fastingHours,
      workoutDays: workoutDays ?? this.workoutDays,
      workoutTime: workoutTime ?? this.workoutTime,
    );
  }

  /// Aviso de coherencia: mucho entreno y ayuno a la vez en déficit.
  bool needsRecovery({required bool inDeficit}) => inDeficit && workoutDays.length >= 5 && fastingDays.length >= 6;
}
