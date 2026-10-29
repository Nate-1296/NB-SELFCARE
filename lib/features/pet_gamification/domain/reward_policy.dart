import '../../../core/domain/enums.dart';

/// Acciones que otorgan monedas (docs/08 §6). Cada una se reclama como máximo
/// una vez al día: la clave [ledgerKey] es única por fecha en `coin_ledger`.
sealed class RewardAction {
  const RewardAction();

  static const RewardAction weighIn = _SimpleReward('weigh_in', 15);
  static const RewardAction waterGoal = _SimpleReward('water_goal', 15);
  static const RewardAction fastDone = _SimpleReward('fast_done', 20);
  static const RewardAction workoutDone = _SimpleReward('workout_done', 20);
  static const RewardAction journalEntry = _SimpleReward('journal_entry', 10);
  static const RewardAction restorativeSleep = _SimpleReward('restorative_sleep', 15);
  static const RewardAction milestoneReached = _SimpleReward('milestone_reached', 25);
  static const RewardAction sundayCheckIn = _SimpleReward('sunday_checkin', 15);

  /// Una sesión de respiración completa con Nibi (la primera del día).
  static const RewardAction mindfulBreath = _SimpleReward('mindful_breath', 10);

  /// Primera sesión del día de suelo pélvico.
  static const RewardAction pelvicFloor = _SimpleReward('pelvic_floor', 10);

  /// Primera pausa activa o descanso visual del día.
  static const RewardAction activeBreak = _SimpleReward('active_break', 10);

  /// Todos los hábitos propios del día marcados.
  static const RewardAction habitsDone = _SimpleReward('habits_done', 10);

  /// Un chequeo preventivo hecho.
  static const RewardAction checkupDone = _SimpleReward('checkup_done', 20);

  // Los medicamentos no dan monedas a propósito: un tratamiento no es un juego
  // y una toma olvidada nunca debe sentirse como un fallo.

  /// Desayuno, almuerzo y cena dan monedas (máx. 30/día). Los snacks no, para
  /// no premiar picar entre horas (docs/08 §6).
  static RewardAction? mealLogged(MealType meal) =>
      meal == MealType.snack ? null : _MealReward(meal);

  String get ledgerKey;
  int get baseAmount;
}

final class _SimpleReward extends RewardAction {
  const _SimpleReward(this.ledgerKey, this.baseAmount);

  @override
  final String ledgerKey;

  @override
  final int baseAmount;
}

final class _MealReward extends RewardAction {
  const _MealReward(this.meal);

  final MealType meal;

  @override
  String get ledgerKey => 'meal_log_${meal.dbValue}';

  @override
  int get baseAmount => 10;

  @override
  bool operator ==(Object other) => other is _MealReward && other.meal == meal;

  @override
  int get hashCode => meal.hashCode;
}

abstract final class RewardPolicy {
  static const double restorativeSleepMultiplier = 1.5;

  /// Umbral de sueño reparador por fases (REM + profundo), cuando la fuente las aporta.
  static const int restorativeStageMinutes = 90;

  /// Multiplicador del día (docs/08 §6): 1.5× si se alcanzó la meta de sueño
  /// del perfil o si REM + profundo suman al menos [restorativeStageMinutes].
  static double sleepMultiplier({
    required int sleepMinutes,
    required int deepMinutes,
    required int remMinutes,
    required double sleepGoalHours,
  }) {
    final bool metGoal = sleepMinutes > 0 && sleepMinutes >= (sleepGoalHours * 60).round();
    final bool restorativeStages = deepMinutes + remMinutes >= restorativeStageMinutes;
    return metGoal || restorativeStages ? restorativeSleepMultiplier : 1.0;
  }

  /// Monedas finales, redondeando hacia arriba (docs/08 §6).
  static int amountFor(RewardAction action, double multiplier) =>
      (action.baseAmount * multiplier).ceil();
}
