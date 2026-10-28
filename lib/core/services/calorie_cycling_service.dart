import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/utils/date_time_extensions.dart';

/// Modalidades de distribución del presupuesto calórico semanal.
enum CalorieCyclingMode {
  /// 7 días con la misma meta calórica.
  flat,

  /// Lunes a Jueves con leve recorte (-150 kcal) para reservar +300 kcal viernes y sábado.
  weekendBuffer,

  /// Días de entrenamiento con superávit (+200 kcal) y descanso en normo/déficit (-200 kcal).
  trainingSplit,

  /// Configuración libre personalizada por día de la semana.
  custom,
}

/// Presupuesto calórico para un día específico de la semana.
class DayCalorieBudget {
  const DayCalorieBudget({
    required this.dayOfWeek,
    required this.dayName,
    required this.targetKcal,
    required this.deltaKcal,
  });

  /// 1 = Lunes ... 7 = Domingo (estándar ISO-8601).
  final int dayOfWeek;
  final String dayName;
  final int targetKcal;
  final int deltaKcal;
}

/// Balance acumulado del "Banco Semanal de Calorías".
class WeeklyCalorieBank {
  const WeeklyCalorieBank({
    required this.accumulatedTargetKcal,
    required this.accumulatedConsumedKcal,
    required this.netBalanceKcal,
    required this.daysLogged,
    required this.remainingDaysInWeek,
  });

  final int accumulatedTargetKcal;
  final int accumulatedConsumedKcal;

  /// Positivo = calorías acumuladas en reserva ("en el banco").
  /// Negativo = consumo superior al objetivo acumulado.
  final int netBalanceKcal;
  final int daysLogged;
  final int remainingDaysInWeek;

  bool get isInSurplus => netBalanceKcal < 0;
  bool get hasBankSavings => netBalanceKcal > 0;
}

/// Servicio de periodización y distribución calórica semanal (Calorie Cycling).
class CalorieCyclingService {
  static const List<String> _dayNames = <String>[
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  /// Calcula la distribución de calorías para los 7 días de la semana
  /// preservando con exactitud matemática el promedio semanal.
  List<DayCalorieBudget> computeSchedule({
    required int baseDailyKcal,
    CalorieCyclingMode mode = CalorieCyclingMode.flat,
    Map<int, int>? customSchedule,
  }) {
    final List<DayCalorieBudget> list = <DayCalorieBudget>[];

    switch (mode) {
      case CalorieCyclingMode.flat:
        for (int i = 1; i <= 7; i++) {
          list.add(
            DayCalorieBudget(
              dayOfWeek: i,
              dayName: _dayNames[i - 1],
              targetKcal: baseDailyKcal,
              deltaKcal: 0,
            ),
          );
        }
        break;

      case CalorieCyclingMode.weekendBuffer:
        // Lunes a Jueves: -150 kcal (Ahorro total = 600 kcal)
        // Viernes y Sábado: +300 kcal (Uso de reserva social)
        // Domingo: base
        for (int i = 1; i <= 7; i++) {
          int delta = 0;
          if (i >= 1 && i <= 4) {
            delta = -150;
          } else if (i == 5 || i == 6) {
            delta = 300;
          } else {
            delta = 0;
          }
          list.add(
            DayCalorieBudget(
              dayOfWeek: i,
              dayName: _dayNames[i - 1],
              targetKcal: baseDailyKcal + delta,
              deltaKcal: delta,
            ),
          );
        }
        break;

      case CalorieCyclingMode.trainingSplit:
        // Supongamos Lunes, Miércoles, Viernes, Sábado entrenos (+200 kcal), Martes, Jueves, Domingo descanso (-266 kcal)
        for (int i = 1; i <= 7; i++) {
          final bool isTrainingDay = i == 1 || i == 3 || i == 5 || i == 6;
          final int delta = isTrainingDay ? 200 : -266;
          list.add(
            DayCalorieBudget(
              dayOfWeek: i,
              dayName: _dayNames[i - 1],
              targetKcal: baseDailyKcal + delta,
              deltaKcal: delta,
            ),
          );
        }
        break;

      case CalorieCyclingMode.custom:
        final Map<int, int> schedule = customSchedule ?? <int, int>{};
        for (int i = 1; i <= 7; i++) {
          final int target = schedule[i] ?? baseDailyKcal;
          list.add(
            DayCalorieBudget(
              dayOfWeek: i,
              dayName: _dayNames[i - 1],
              targetKcal: target,
              deltaKcal: target - baseDailyKcal,
            ),
          );
        }
        break;
    }

    return list;
  }

  /// Calcula el balance acumulado de la semana en curso (Lunes a Domingo).
  WeeklyCalorieBank computeWeeklyBank({
    required int baseDailyKcal,
    required DateTime today,
    required Map<String, int> caloriesLoggedByDateKey,
    CalorieCyclingMode mode = CalorieCyclingMode.flat,
    Map<int, int>? customSchedule,
  }) {
    final List<DayCalorieBudget> schedule = computeSchedule(
      baseDailyKcal: baseDailyKcal,
      mode: mode,
      customSchedule: customSchedule,
    );

    // Encontrar el lunes de la semana actual
    final int currentWeekday = today.weekday; // 1 = Lunes ... 7 = Domingo
    final DateTime monday = today.addDays(1 - currentWeekday);

    int targetSum = 0;
    int consumedSum = 0;
    int daysLogged = 0;

    for (int i = 1; i <= currentWeekday; i++) {
      final DateTime day = monday.addDays(i - 1);
      final String dateKey =
          '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

      // Solo cuentan los días registrados: un día sin datos no es un "ahorro".
      final int? consumed = caloriesLoggedByDateKey[dateKey];
      if (consumed != null) {
        targetSum += schedule[i - 1].targetKcal;
        consumedSum += consumed;
        daysLogged++;
      }
    }

    final int netBalance = targetSum - consumedSum;
    final int remainingDays = 7 - currentWeekday;

    return WeeklyCalorieBank(
      accumulatedTargetKcal: targetSum,
      accumulatedConsumedKcal: consumedSum,
      netBalanceKcal: netBalance,
      daysLogged: daysLogged,
      remainingDaysInWeek: remainingDays,
    );
  }

  /// Deserializa el horario de cycling desde JSON guardado en UserProfiles.
  static Map<int, int> parseScheduleJson(String rawJson) {
    if (rawJson.trim().isEmpty || rawJson == '{}') return <int, int>{};
    try {
      final Map<String, dynamic> decoded =
          jsonDecode(rawJson) as Map<String, dynamic>;
      final Map<int, int> result = <int, int>{};
      decoded.forEach((String key, dynamic val) {
        final int? day = int.tryParse(key);
        final int? kcal = (val as num?)?.toInt();
        if (day != null && kcal != null) {
          result[day] = kcal;
        }
      });
      return result;
    } catch (_) {
      return <int, int>{};
    }
  }

  /// Serializa el horario de cycling a JSON para persistencia.
  static String encodeScheduleJson(Map<int, int> schedule) {
    final Map<String, int> stringMap = schedule.map(
      (int k, int v) => MapEntry<String, int>(k.toString(), v),
    );
    return jsonEncode(stringMap);
  }
}

/// Provider de Riverpod para inyectar CalorieCyclingService.
final calorieCyclingServiceProvider = Provider<CalorieCyclingService>((ref) {
  return CalorieCyclingService();
});
