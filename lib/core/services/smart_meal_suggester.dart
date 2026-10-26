import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../database/daos/food_dao.dart';

/// Arquetipo dietético con distribución porcentual de macronutrientes.
class DietArchetypeInfo {
  const DietArchetypeInfo({
    required this.id,
    required this.name,
    required this.tagline,
    required this.proteinPct,
    required this.carbsPct,
    required this.fatPct,
    required this.recommendedSearchTerms,
  });

  final String id;
  final String name;
  final String tagline;
  final double proteinPct;
  final double carbsPct;
  final double fatPct;
  final List<String> recommendedSearchTerms;

  static const Map<String, DietArchetypeInfo> archetypes =
      <String, DietArchetypeInfo>{
    'mediterranean': DietArchetypeInfo(
      id: 'mediterranean',
      name: 'Mediterránea',
      tagline: 'Grasas cardiosaludables, pescado, legumbres y cereales integrales',
      proteinPct: 20.0,
      carbsPct: 50.0,
      fatPct: 30.0,
      recommendedSearchTerms: <String>[
        'aceite de oliva',
        'atún',
        'salmón',
        'lentejas',
        'avena',
        'tomate',
        'nueces',
      ],
    ),
    'keto': DietArchetypeInfo(
      id: 'keto',
      name: 'Cetogénica (Keto)',
      tagline: 'Muy baja en carbohidratos (<30g netos), alta en grasas saludables',
      proteinPct: 25.0,
      carbsPct: 5.0,
      fatPct: 70.0,
      recommendedSearchTerms: <String>[
        'huevo',
        'aguacate',
        'aceite de oliva',
        'salmón',
        'nueces',
        'espinacas',
        'queso',
      ],
    ),
    'high_protein': DietArchetypeInfo(
      id: 'high_protein',
      name: 'Fitness / Hipertrofia',
      tagline: 'Alta en proteínas (2.0–2.4 g/kg) para protección y síntesis muscular',
      proteinPct: 35.0,
      carbsPct: 40.0,
      fatPct: 25.0,
      recommendedSearchTerms: <String>[
        'pechuga de pollo',
        'claras de huevo',
        'atún',
        'arroz',
        'avena',
        'yogurt griego',
      ],
    ),
    'plant_based': DietArchetypeInfo(
      id: 'plant_based',
      name: 'Basada en Plantas',
      tagline: '100% de origen vegetal: legumbres, semillas, frutos secos y granos',
      proteinPct: 20.0,
      carbsPct: 55.0,
      fatPct: 25.0,
      recommendedSearchTerms: <String>[
        'lentejas',
        'garbanzos',
        'tofu',
        'avena',
        'semillas de chía',
        'nueces',
        'plátano',
      ],
    ),
    'balanced': DietArchetypeInfo(
      id: 'balanced',
      name: 'Equilibrada',
      tagline: 'Distribución balanceada de energía sin restricciones de grupos',
      proteinPct: 25.0,
      carbsPct: 45.0,
      fatPct: 30.0,
      recommendedSearchTerms: <String>[
        'huevo',
        'pollo',
        'arroz',
        'avena',
        'aceite de oliva',
        'manzana',
      ],
    ),
    'flexible': DietArchetypeInfo(
      id: 'flexible',
      name: 'Modo Libre',
      tagline: 'Personalización sin arquetipo fijo guiada por tus macros adaptativos',
      proteinPct: 25.0,
      carbsPct: 50.0,
      fatPct: 25.0,
      recommendedSearchTerms: <String>['arroz', 'pollo', 'huevo', 'avena'],
    ),
  };

  static DietArchetypeInfo getById(String? id) {
    return archetypes[id] ?? archetypes['balanced']!;
  }
}

/// Alimento porcionado sugerido dentro de una toma.
class SuggestedMealItem {
  const SuggestedMealItem({
    required this.food,
    required this.grams,
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  final FoodItem food;
  final double grams;
  final double kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
}

/// Menú diario sugerido con platos y porciones calculadas exactamente.
class SuggestedDailyMenu {
  const SuggestedDailyMenu({
    required this.archetype,
    required this.targetKcal,
    required this.meals,
    required this.totalKcal,
    required this.totalProteinG,
    required this.totalCarbsG,
    required this.totalFatG,
  });

  final DietArchetypeInfo archetype;
  final int targetKcal;
  final Map<String, List<SuggestedMealItem>> meals;
  final double totalKcal;
  final double totalProteinG;
  final double totalCarbsG;
  final double totalFatG;
}

/// Motor de sugerencia inteligente de comidas basadas en arquetipos y porciones exactas.
class SmartMealSuggester {
  /// Genera un menú sugerido de 3 comidas (Desayuno, Almuerzo, Cena) porcionando
  /// matemáticamente alimentos disponibles en el catálogo local para cuadrar los macros.
  Future<SuggestedDailyMenu> generateMenu({
    required UserProfile profile,
    required FoodDao foodDao,
    int? targetKcalOverride,
  }) async {
    final DietArchetypeInfo archetype =
        DietArchetypeInfo.getById(profile.activeDietArchetype);
    final int kcalGoal = targetKcalOverride ??
        (profile.isManualMacroMode
            ? (profile.manualKcalTarget ?? 2000)
            : profile.currentAdaptiveTdeeKcal);

    // Reparto por tomas: Desayuno 30%, Almuerzo 40%, Cena 30%
    const Map<String, double> mealDistribution = <String, double>{
      'breakfast': 0.30,
      'lunch': 0.40,
      'dinner': 0.30,
    };

    final Map<String, List<SuggestedMealItem>> resultMeals =
        <String, List<SuggestedMealItem>>{};

    double totalMenuKcal = 0;
    double totalMenuP = 0;
    double totalMenuC = 0;
    double totalMenuF = 0;

    // Obtener catálogo disponible
    final List<FoodItem> catalog = await foodDao.filterCatalog(limit: 60);

    for (final MapEntry<String, double> entry in mealDistribution.entries) {
      final String mealSlot = entry.key;
      final double slotKcal = kcalGoal * entry.value;

      // Seleccionar 2-3 alimentos del catálogo compatibles
      final List<FoodItem> slotFoods = _pickFoodsForSlot(
        catalog,
        mealSlot,
        archetype,
      );

      final List<SuggestedMealItem> mealItems = <SuggestedMealItem>[];

      if (slotFoods.isNotEmpty) {
        // Porcionar proporcionalmente para encajar en slotKcal
        final double perFoodKcal = slotKcal / slotFoods.length;

        for (final FoodItem f in slotFoods) {
          final double foodKcalPerGram =
              f.kcalPer100g > 0 ? f.kcalPer100g / 100.0 : 1.0;
          final double grams = (perFoodKcal / foodKcalPerGram).clamp(20.0, 450.0);
          final double ratio = grams / 100.0;

          final item = SuggestedMealItem(
            food: f,
            grams: double.parse(grams.toStringAsFixed(0)),
            kcal: double.parse((f.kcalPer100g * ratio).toStringAsFixed(1)),
            proteinG: double.parse((f.proteinPer100g * ratio).toStringAsFixed(1)),
            carbsG: double.parse((f.carbsPer100g * ratio).toStringAsFixed(1)),
            fatG: double.parse((f.fatPer100g * ratio).toStringAsFixed(1)),
          );

          mealItems.add(item);
          totalMenuKcal += item.kcal;
          totalMenuP += item.proteinG;
          totalMenuC += item.carbsG;
          totalMenuF += item.fatG;
        }
      }

      resultMeals[mealSlot] = mealItems;
    }

    return SuggestedDailyMenu(
      archetype: archetype,
      targetKcal: kcalGoal,
      meals: resultMeals,
      totalKcal: totalMenuKcal,
      totalProteinG: totalMenuP,
      totalCarbsG: totalMenuC,
      totalFatG: totalMenuF,
    );
  }

  List<FoodItem> _pickFoodsForSlot(
    List<FoodItem> catalog,
    String slot,
    DietArchetypeInfo archetype,
  ) {
    if (catalog.isEmpty) return <FoodItem>[];

    // Preferir alimentos que coincidan con los términos del arquetipo
    final List<FoodItem> matched = catalog.where((FoodItem f) {
      final String nameLower = f.name.toLowerCase();
      return archetype.recommendedSearchTerms.any(nameLower.contains);
    }).toList();

    final List<FoodItem> pool = matched.isNotEmpty ? matched : catalog;

    // Tomar 2 alimentos distintos
    if (slot == 'breakfast') {
      return pool.take(2).toList();
    } else if (slot == 'lunch') {
      return pool.skip(math.min(1, pool.length)).take(2).toList();
    } else {
      return pool.reversed.take(2).toList();
    }
  }
}

/// Oráculo Local de Nutrientes ("¿Qué como para cerrar mis metas hoy?").
class NutrientOracle {
  /// Analiza los déficits de macros pendientes del día y busca en SQLite local
  /// los 2 o 3 alimentos con mayor densidad nutricional específica para cubrirlos.
  Future<List<SuggestedMealItem>> recommendToCloseGap({
    required double remainingKcal,
    required double remainingProteinG,
    required double remainingCarbsG,
    required double remainingFatG,
    required FoodDao foodDao,
  }) async {
    final List<FoodItem> all = await foodDao.filterCatalog(limit: 60);
    return recommendFromCatalog(
      remainingKcal: remainingKcal,
      remainingProteinG: remainingProteinG,
      remainingCarbsG: remainingCarbsG,
      remainingFatG: remainingFatG,
      catalog: all,
    );
  }

  /// Recomendación pura a partir de una lista en memoria de alimentos.
  List<SuggestedMealItem> recommendFromCatalog({
    required double remainingKcal,
    required double remainingProteinG,
    required double remainingCarbsG,
    required double remainingFatG,
    required List<FoodItem> catalog,
  }) {
    if (remainingKcal <= 50 || catalog.isEmpty) {
      return <SuggestedMealItem>[];
    }

    final List<FoodItem> all = catalog;
    final List<SuggestedMealItem> recommendations = <SuggestedMealItem>[];

    // 1. Si falta proteína preponderantemente (>12g)
    if (remainingProteinG >= 12.0) {
      final List<FoodItem> proteinSources = all
          .where((FoodItem f) => f.proteinPer100g >= 12.0)
          .toList()
        ..sort((FoodItem a, FoodItem b) =>
            b.proteinPer100g.compareTo(a.proteinPer100g));

      if (proteinSources.isNotEmpty) {
        final FoodItem bestP = proteinSources.first;
        final double neededGrams =
            (remainingProteinG / (bestP.proteinPer100g / 100.0))
                .clamp(30.0, 300.0);
        final double ratio = neededGrams / 100.0;
        recommendations.add(
          SuggestedMealItem(
            food: bestP,
            grams: double.parse(neededGrams.toStringAsFixed(0)),
            kcal: double.parse((bestP.kcalPer100g * ratio).toStringAsFixed(0)),
            proteinG:
                double.parse((bestP.proteinPer100g * ratio).toStringAsFixed(1)),
            carbsG:
                double.parse((bestP.carbsPer100g * ratio).toStringAsFixed(1)),
            fatG: double.parse((bestP.fatPer100g * ratio).toStringAsFixed(1)),
          ),
        );
      }
    }

    // 2. Si faltan carbohidratos (>25g) y hay calorías disponibles
    if (remainingCarbsG >= 25.0) {
      final List<FoodItem> carbSources = all
          .where((FoodItem f) => f.carbsPer100g >= 20.0)
          .toList()
        ..sort((FoodItem a, FoodItem b) =>
            b.carbsPer100g.compareTo(a.carbsPer100g));

      if (carbSources.isNotEmpty) {
        final FoodItem bestC = carbSources.first;
        final double neededGrams =
            (remainingCarbsG / (bestC.carbsPer100g / 100.0)).clamp(30.0, 250.0);
        final double ratio = neededGrams / 100.0;
        recommendations.add(
          SuggestedMealItem(
            food: bestC,
            grams: double.parse(neededGrams.toStringAsFixed(0)),
            kcal: double.parse((bestC.kcalPer100g * ratio).toStringAsFixed(0)),
            proteinG:
                double.parse((bestC.proteinPer100g * ratio).toStringAsFixed(1)),
            carbsG:
                double.parse((bestC.carbsPer100g * ratio).toStringAsFixed(1)),
            fatG: double.parse((bestC.fatPer100g * ratio).toStringAsFixed(1)),
          ),
        );
      }
    }

    // 3. Si faltan grasas (>10g)
    if (remainingFatG >= 10.0 && recommendations.length < 3) {
      final List<FoodItem> fatSources = all
          .where((FoodItem f) => f.fatPer100g >= 15.0)
          .toList()
        ..sort((FoodItem a, FoodItem b) =>
            b.fatPer100g.compareTo(a.fatPer100g));

      if (fatSources.isNotEmpty) {
        final FoodItem bestF = fatSources.first;
        final double neededGrams =
            (remainingFatG / (bestF.fatPer100g / 100.0)).clamp(10.0, 100.0);
        final double ratio = neededGrams / 100.0;
        recommendations.add(
          SuggestedMealItem(
            food: bestF,
            grams: double.parse(neededGrams.toStringAsFixed(0)),
            kcal: double.parse((bestF.kcalPer100g * ratio).toStringAsFixed(0)),
            proteinG:
                double.parse((bestF.proteinPer100g * ratio).toStringAsFixed(1)),
            carbsG:
                double.parse((bestF.carbsPer100g * ratio).toStringAsFixed(1)),
            fatG: double.parse((bestF.fatPer100g * ratio).toStringAsFixed(1)),
          ),
        );
      }
    }

    return recommendations;
  }
}

/// Providers de Riverpod.
final smartMealSuggesterProvider = Provider<SmartMealSuggester>((ref) {
  return SmartMealSuggester();
});

final nutrientOracleProvider = Provider<NutrientOracle>((ref) {
  return NutrientOracle();
});
