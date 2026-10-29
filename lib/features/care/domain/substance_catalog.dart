/// Bebidas y tabaco que se registran con un toque.
enum SubstanceKind {
  alcohol('alcohol'),
  tobacco('tobacco');

  const SubstanceKind(this.key);

  final String key;
}

/// Preajuste de registro: una cerveza, una copa, un trago, un cigarrillo…
///
/// Bebida estándar = 10 g de alcohol puro (OMS). Gramos = ml × grado × 0,789.
class SubstancePreset {
  const SubstancePreset({
    required this.key,
    required this.kind,
    this.volumeMl = 0,
    this.abvPercent = 0,
    this.kcal = 0,
    this.carbsPer100ml = 0,
  });

  final String key;
  final SubstanceKind kind;
  final int volumeMl;
  final double abvPercent;
  final double kcal;
  final double carbsPer100ml;

  double get kcalPer100ml => volumeMl == 0 ? 0 : kcal / volumeMl * 100;

  double get alcoholGrams => volumeMl * abvPercent / 100 * 0.789;

  double get standardDrinks => alcoholGrams / 10;

  static const List<SubstancePreset> alcohol = <SubstancePreset>[
    SubstancePreset(
      key: 'beer',
      kind: SubstanceKind.alcohol,
      volumeMl: 330,
      abvPercent: 4.5,
      kcal: 140,
      carbsPer100ml: 3.6,
    ),
    SubstancePreset(
      key: 'wine',
      kind: SubstanceKind.alcohol,
      volumeMl: 150,
      abvPercent: 12,
      kcal: 125,
      carbsPer100ml: 2.6,
    ),
    // Aguardiente o ron: trago de 30 ml.
    SubstancePreset(
      key: 'spirit',
      kind: SubstanceKind.alcohol,
      volumeMl: 30,
      abvPercent: 35,
      kcal: 70,
    ),
    SubstancePreset(
      key: 'cocktail',
      kind: SubstanceKind.alcohol,
      volumeMl: 200,
      abvPercent: 8,
      kcal: 220,
      carbsPer100ml: 12,
    ),
  ];

  static const List<SubstancePreset> tobacco = <SubstancePreset>[
    SubstancePreset(key: 'cigarette', kind: SubstanceKind.tobacco),
    SubstancePreset(key: 'vape', kind: SubstanceKind.tobacco),
  ];

  static SubstancePreset? byKey(String key) {
    for (final SubstancePreset p in <SubstancePreset>[...alcohol, ...tobacco]) {
      if (p.key == key) return p;
    }
    return null;
  }
}

/// Comparación semanal en positivo: se celebra bajar, nunca se reprocha subir.
class WeeklyTrend {
  const WeeklyTrend({required this.thisWeek, required this.lastWeek});

  final double thisWeek;
  final double lastWeek;

  bool get isLower => lastWeek > 0 && thisWeek < lastWeek;

  /// Porcentaje de reducción frente a la semana anterior (0 si no bajó).
  int get reductionPercent => isLower ? (((lastWeek - thisWeek) / lastWeek) * 100).round() : 0;
}

abstract final class SubstanceGuidance {
  /// Límite orientativo de bajo riesgo (OMS/Europa): como mucho 10 bebidas
  /// estándar a la semana y no más de 2 en un día, con días sin alcohol.
  static const double weeklyLowRiskDrinks = 10;
  static const double dailyLowRiskDrinks = 2;
}
