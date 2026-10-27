import '../../core/constants/app_constants.dart';
import '../../core/domain/enums.dart';

/// Reglas de periodización de la dieta (docs/14 Fase 4).
abstract final class DietPhasePolicy {
  /// Incremento semanal del reverse diet (rango recomendado: +50 a +100 kcal).
  static const int reverseDietStepKcal = 75;

  /// Duración máxima recomendada de un diet break.
  static const int dietBreakMaxDays = 14;

  /// Ritmo de pérdida máximo permitido para cualquier perfil (~1 kg/semana).
  static const int maxDailyDeficitKcal = 1100;

  /// Con historial de TCA se limita a ~0,25 kg/semana (docs/01 §6).
  static const int maxDailyDeficitKcalWithEdHistory = 275;

  /// Ajuste diario respecto al TDEE según la fase activa.
  ///
  /// * `deficit`: ritmo semanal configurado (negativo = pérdida, positivo = ganancia),
  ///   acotado por los pisos de seguridad.
  /// * `maintenance` y `diet_break`: 0 (normocalórica).
  /// * `reverse_diet`: parte del déficit configurado y suma [reverseDietStepKcal]
  ///   por cada semana completa desde [phaseStartedAt] hasta llegar a 0.
  static int dailyAdjustmentKcal({
    required DietPhase phase,
    required double weeklyGoalRateKg,
    required DateTime? phaseStartedAt,
    required DateTime now,
    bool hasEatingDisorderHistory = false,
  }) {
    final int floor =
        hasEatingDisorderHistory ? maxDailyDeficitKcalWithEdHistory : maxDailyDeficitKcal;
    final int planned =
        ((weeklyGoalRateKg * AppConstants.kcalPerKgBodyFat) / 7.0).round().clamp(-floor, floor);

    return switch (phase) {
      DietPhase.deficit => planned,
      DietPhase.maintenance || DietPhase.dietBreak => 0,
      DietPhase.reverseDiet => _reverseDietAdjustment(planned, phaseStartedAt, now),
    };
  }

  static int _reverseDietAdjustment(int planned, DateTime? startedAt, DateTime now) {
    final int startingDeficit = planned < 0 ? planned : 0;
    final int weeks = startedAt == null ? 0 : now.difference(startedAt).inDays ~/ 7;
    final int adjusted = startingDeficit + reverseDietStepKcal * weeks;
    return adjusted > 0 ? 0 : adjusted;
  }

  /// `true` cuando el reverse diet ya alcanzó el mantenimiento.
  static bool isReverseDietComplete({
    required double weeklyGoalRateKg,
    required DateTime? phaseStartedAt,
    required DateTime now,
  }) {
    return dailyAdjustmentKcal(
          phase: DietPhase.reverseDiet,
          weeklyGoalRateKg: weeklyGoalRateKg,
          phaseStartedAt: phaseStartedAt,
          now: now,
        ) ==
        0;
  }

  /// `true` cuando el diet break supera los [dietBreakMaxDays] recomendados.
  /// La app solo lo sugiere: el usuario decide cuándo volver al déficit.
  static bool isDietBreakOverdue({
    required DietPhase phase,
    required DateTime? phaseStartedAt,
    required DateTime now,
  }) {
    return phase == DietPhase.dietBreak &&
        phaseStartedAt != null &&
        now.difference(phaseStartedAt).inDays > dietBreakMaxDays;
  }
}
