import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/features/protocol/domain/weekly_protocol.dart';

void main() {
  test('El plan se guarda y se vuelve a leer igual (incluidas las horas de ayuno)', () {
    const WeeklyProtocol plan = WeeklyProtocol(
      fastingDays: <int>{1, 3, 6},
      fastingHours: 18,
      workoutDays: <int>{2, 4},
      workoutTime: WorkoutTimeOfDay.evening,
    );
    final WeeklyProtocol back =
        WeeklyProtocol.decode(fastingDays: plan.encodedFastingDays, workoutSlots: plan.encodedWorkoutSlots);
    expect(back.fastingDays, plan.fastingDays);
    expect(back.fastingHours, 18);
    expect(back.workoutDays, plan.workoutDays);
    expect(back.workoutTime, WorkoutTimeOfDay.evening);
  });

  test('Lee el formato antiguo de la pantalla ("1,2,3" y hora en español)', () {
    final WeeklyProtocol legacy = WeeklyProtocol.decode(
      fastingDays: '1,2,3',
      workoutSlots: '{"days": [1,5], "time": "tarde"}',
    );
    expect(legacy.fastingDays, <int>{1, 2, 3});
    expect(legacy.fastingHours, 16);
    expect(legacy.workoutDays, <int>{1, 5});
    expect(legacy.workoutTime, WorkoutTimeOfDay.afternoon);
  });

  test('El valor por defecto de la tabla (JSON día → horas) se interpreta', () {
    final WeeklyProtocol fromDefault = WeeklyProtocol.decode(
      fastingDays: '{"1":16,"2":16,"3":16,"4":16,"5":16,"6":0,"7":0}',
      workoutSlots: '[]',
    );
    expect(fromDefault.fastingDays, <int>{1, 2, 3, 4, 5});
    expect(fromDefault.fastingHoursFor(DateTime(2026, 10, 26)), 16, reason: 'lunes');
    expect(fromDefault.fastingHoursFor(DateTime(2026, 10, 31)), isNull, reason: 'sábado');
  });
}
