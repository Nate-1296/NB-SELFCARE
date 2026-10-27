import '../../../core/database/app_database.dart';
import '../../../core/database/models/food_models.dart';

/// Suma de nutrientes de un conjunto de registros de comida.
class NutrientTotals {
  const NutrientTotals({
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
    required this.sodiumMg,
    required this.potassiumMg,
    required this.magnesiumMg,
    required this.minimallyProcessedKcal,
    required this.ultraProcessedKcal,
  });

  factory NutrientTotals.of(Iterable<FoodLogWithItem> entries) {
    double kcal = 0, p = 0, c = 0, f = 0, fiber = 0, na = 0, k = 0, mg = 0, fresh = 0, ultra = 0;
    for (final FoodLogWithItem e in entries) {
      final FoodLog l = e.log;
      kcal += l.totalKcal;
      p += l.totalProteinG;
      c += l.totalCarbsG;
      f += l.totalFatG;
      fiber += l.totalFiberG;
      na += l.totalSodiumMg;
      k += l.totalPotassiumMg;
      mg += l.totalMagnesiumMg;
      final int? nova = e.foodItem?.novaGroup;
      if (nova == 4) {
        ultra += l.totalKcal;
      } else if (nova != null && nova >= 1) {
        fresh += l.totalKcal;
      }
    }
    return NutrientTotals(
      kcal: kcal,
      proteinG: p,
      carbsG: c,
      fatG: f,
      fiberG: fiber,
      sodiumMg: na,
      potassiumMg: k,
      magnesiumMg: mg,
      minimallyProcessedKcal: fresh,
      ultraProcessedKcal: ultra,
    );
  }

  static const NutrientTotals zero = NutrientTotals(
    kcal: 0,
    proteinG: 0,
    carbsG: 0,
    fatG: 0,
    fiberG: 0,
    sodiumMg: 0,
    potassiumMg: 0,
    magnesiumMg: 0,
    minimallyProcessedKcal: 0,
    ultraProcessedKcal: 0,
  );

  final double kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;
  final double sodiumMg;
  final double potassiumMg;
  final double magnesiumMg;

  /// Kcal de alimentos NOVA 1–3.
  final double minimallyProcessedKcal;

  /// Kcal de alimentos NOVA 4 (ultraprocesados).
  final double ultraProcessedKcal;

  double get netCarbsG => (carbsG - fiberG).clamp(0, double.infinity);

  /// Kcal de alimentos sin grupo NOVA conocido (p. ej. catálogo USDA o recetas).
  double get unclassifiedKcal => (kcal - minimallyProcessedKcal - ultraProcessedKcal).clamp(0, double.infinity);

  double get classifiedKcal => minimallyProcessedKcal + ultraProcessedKcal;
}
