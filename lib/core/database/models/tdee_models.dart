/// Modelos de lectura (resultados de JOIN) que la UI puede usar sin depender del DAO.
library;

/// Resultado tipado del motor de calibración quincenal de TDEE Adaptativo.
class TdeeCalibrationOutcome {
  const TdeeCalibrationOutcome({
    required this.didCalibrate,
    required this.foodDaysLogged,
    required this.weighInDaysLogged,
    this.previousTdeeKcal,
    this.newTdeeKcal,
    this.wasClamped = false,
    this.deltaEmaKg,
    this.averageIntakeKcal,
  });

  final bool didCalibrate;
  final int foodDaysLogged;
  final int weighInDaysLogged;
  final int? previousTdeeKcal;
  final int? newTdeeKcal;
  final bool wasClamped;
  final double? deltaEmaKg;
  final double? averageIntakeKcal;
}
