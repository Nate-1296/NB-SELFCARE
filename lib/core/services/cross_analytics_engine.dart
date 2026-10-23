import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';

/// Resultado estructurado de una correlación cruzada empírica.
class CrossCorrelationInsight {
  const CrossCorrelationInsight({
    required this.title,
    required this.description,
    required this.correlationR,
    required this.sampleSize,
    required this.domain,
  });

  final String title;
  final String description;
  final double correlationR;
  final int sampleSize;
  final String domain;

  /// Intensidad descriptiva de la correlación
  String get strengthLabel {
    final abs = correlationR.abs();
    if (abs >= 0.7) return 'Correlación Fuerte';
    if (abs >= 0.4) return 'Correlación Moderada';
    if (abs >= 0.2) return 'Correlación Leve';
    return 'Sin relación lineal significativa';
  }
}

/// Motor estadístico de correlaciones cruzadas (Pearson) entre variables biométricas y conductuales.
class CrossAnalyticsEngine {
  CrossAnalyticsEngine(this._db);

  final AppDatabase _db;

  /// Calcula el coeficiente de correlación de Pearson r entre dos series numéricas.
  static double calculatePearsonR(List<double> x, List<double> y) {
    if (x.length != y.length || x.length < 2) return 0.0;

    final int n = x.length;
    final double meanX = x.reduce((a, b) => a + b) / n;
    final double meanY = y.reduce((a, b) => a + b) / n;

    double numerator = 0.0;
    double sumSqDiffX = 0.0;
    double sumSqDiffY = 0.0;

    for (int i = 0; i < n; i++) {
      final double diffX = x[i] - meanX;
      final double diffY = y[i] - meanY;
      numerator += diffX * diffY;
      sumSqDiffX += diffX * diffX;
      sumSqDiffY += diffY * diffY;
    }

    final double denominator = math.sqrt(sumSqDiffX * sumSqDiffY);
    if (denominator == 0.0) return 0.0;

    final double r = numerator / denominator;
    return double.parse(r.clamp(-1.0, 1.0).toStringAsFixed(2));
  }

  /// Ejecuta el análisis cruzado sobre la base de datos SQLite y retorna los hallazgos validados.
  Future<List<CrossCorrelationInsight>> computeInsights() async {
    final List<CrossCorrelationInsight> insights = [];

    // 1. Análisis de Estrés vs Carbohidratos (JournalEntries vs FoodLogs)
    final stressCarbQuery = await _db.customSelect(
      '''
      SELECT j.stress_level, SUM(f.total_carbs_g) as carbs
      FROM journal_entries j
      JOIN food_logs f ON j.date_key = f.date_key
      WHERE j.stress_level IS NOT NULL
      GROUP BY j.date_key
      HAVING carbs > 0
      ORDER BY j.date_key ASC
      ''',
      readsFrom: {_db.journalEntries, _db.foodLogs},
    ).get();

    if (stressCarbQuery.length >= 10) {
      final List<double> stressLevels = [];
      final List<double> carbsGrams = [];

      for (final row in stressCarbQuery) {
        stressLevels.add(row.read<int>('stress_level').toDouble());
        carbsGrams.add(row.read<double>('carbs'));
      }

      final double r = calculatePearsonR(stressLevels, carbsGrams);
      if (r.abs() >= 0.3) {
        insights.add(
          CrossCorrelationInsight(
            title: 'Estrés y Consumo de Carbohidratos',
            description: r > 0
                ? 'En los días con mayor nivel de estrés (4-5), tu consumo de carbohidratos tiende a aumentar.'
                : 'En los días con menor estrés sueles mantener un consumo más balanceado de carbohidratos.',
            correlationR: r,
            sampleSize: stressCarbQuery.length,
            domain: 'stress_vs_carbs',
          ),
        );
      }
    }

    // 2. Análisis de Horas de Ayuno vs Calorías Totales del Día
    final fastCalQuery = await _db.customSelect(
      '''
      SELECT s.target_hours, SUM(f.total_kcal) as total_kcal
      FROM fasting_sessions s
      JOIN food_logs f ON s.started_at LIKE f.date_key || '%'
      WHERE s.is_completed = 1
      GROUP BY f.date_key
      HAVING total_kcal > 0
      ''',
      readsFrom: {_db.fastingSessions, _db.foodLogs},
    ).get();

    if (fastCalQuery.length >= 10) {
      final List<double> fastHours = [];
      final List<double> totalKcals = [];

      for (final row in fastCalQuery) {
        fastHours.add(row.read<int>('target_hours').toDouble());
        totalKcals.add(row.read<double>('total_kcal'));
      }

      final double r = calculatePearsonR(fastHours, totalKcals);
      insights.add(
        CrossCorrelationInsight(
          title: 'Duración del Ayuno vs Ingesta Calórica',
          description: r < 0
              ? 'Tus ayunos más prolongados se asocian de forma natural con un menor consumo calórico total sin sensación de restricción.'
              : 'Tus sesiones de ayuno mantienen una ingesta calórica estable y controlada.',
          correlationR: r,
          sampleSize: fastCalQuery.length,
          domain: 'fasting_vs_calories',
        ),
      );
    }

    return insights;
  }
}

/// Provider de Riverpod para inyectar CrossAnalyticsEngine.
final crossAnalyticsEngineProvider = Provider<CrossAnalyticsEngine>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return CrossAnalyticsEngine(db);
});
