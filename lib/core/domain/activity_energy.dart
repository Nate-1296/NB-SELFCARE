/// Gasto activo estimado por pasos (NEAT). Un único criterio para Hoy, Cuerpo
/// y la sincronización con Health Connect.
abstract final class ActivityEnergy {
  /// kcal por paso para un adulto medio (≈ 0,5 kcal/kg/km con ~1.300 pasos/km a 80 kg).
  static const double kcalPerStep = 0.04;

  static int kcalFromSteps(int steps) => (steps.clamp(0, 200000) * kcalPerStep).round();
}
