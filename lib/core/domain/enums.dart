/// Enumeraciones de dominio compartidas por varias features.
///
/// Cada valor conserva en [DbEnum.dbValue] la cadena exacta que se guarda en
/// SQLite, de modo que el archivo `.sqlite` exportado sigue siendo legible y los
/// datos existentes no requieren migración.
library;

/// Contrato de un enum persistido como texto estable.
abstract interface class DbEnum {
  String get dbValue;
}

/// Busca el valor cuyo [DbEnum.dbValue] coincide con [raw]; devuelve [fallback] si no existe.
T enumFromDb<T extends DbEnum>(List<T> values, String? raw, T fallback) {
  for (final T value in values) {
    if (value.dbValue == raw) return value;
  }
  return fallback;
}

enum BiologicalSex implements DbEnum {
  male('male'),
  female('female');

  const BiologicalSex(this.dbValue);

  @override
  final String dbValue;

  bool get isMale => this == BiologicalSex.male;
  bool get isFemale => this == BiologicalSex.female;
}

/// Fase de periodización de la dieta.
enum DietPhase implements DbEnum {
  deficit('deficit'),
  maintenance('maintenance'),
  dietBreak('diet_break'),
  reverseDiet('reverse_diet');

  const DietPhase(this.dbValue);

  @override
  final String dbValue;
}

/// Estilo alimentario activo.
enum DietArchetype implements DbEnum {
  flexible('flexible'),
  mediterranean('mediterranean'),
  keto('keto'),
  highProtein('high_protein'),
  plantBased('plant_based'),
  balanced('balanced');

  const DietArchetype(this.dbValue);

  @override
  final String dbValue;
}

enum MealType implements DbEnum {
  breakfast('breakfast'),
  lunch('lunch'),
  dinner('dinner'),
  snack('snack');

  const MealType(this.dbValue);

  @override
  final String dbValue;

  /// Bloque sugerido según la hora local: desayuno 05–11, almuerzo 11–16,
  /// merienda 16–19, cena 19–24 y snack nocturno 00–05.
  static MealType forHour(int hour) {
    if (hour >= 5 && hour < 11) return MealType.breakfast;
    if (hour >= 11 && hour < 16) return MealType.lunch;
    if (hour >= 19) return MealType.dinner;
    return MealType.snack;
  }
}

enum WorkoutCategory implements DbEnum {
  weights('weights'),
  calisthenics('calisthenics'),
  cardio('cardio'),
  sports('sports');

  const WorkoutCategory(this.dbValue);

  @override
  final String dbValue;
}

enum RpeIntensity implements DbEnum {
  light('light'),
  moderate('moderate'),
  intense('intense');

  const RpeIntensity(this.dbValue);

  @override
  final String dbValue;

  /// Valor central de la escala RPE 1–10 de cada bloque (docs/06 §1).
  double get representativeRpe => switch (this) {
    RpeIntensity.light => 3,
    RpeIntensity.moderate => 6,
    RpeIntensity.intense => 9,
  };
}

/// Origen de una fila de `body_measurements`.
enum MeasurementSource implements DbEnum {
  miScale2Ble('mi_scale_2_ble'),
  healthConnect('health_connect'),
  manual('manual'),

  /// Fila creada solo para guardar la cinta métrica: arrastra el último peso real.
  navyTape('manual_navy_tape');

  const MeasurementSource(this.dbValue);

  @override
  final String dbValue;

  /// `true` si la fila representa un pesaje real (no una fila de cinta).
  bool get isWeighIn => this != MeasurementSource.navyTape;
}

/// Origen de un alimento del catálogo local.
enum FoodSource implements DbEnum {
  usdaSeed('usda_seed'),
  openFoodFacts('open_food_facts'),
  userCustom('user_custom'),

  /// Valores estimados por el extractor de texto cuando el alimento no está en el catálogo.
  textEstimate('ai_fallback');

  const FoodSource(this.dbValue);

  @override
  final String dbValue;
}

enum ReminderType implements DbEnum {
  hydration('hydration'),
  fastingOpen('fasting_open'),
  fastingClose('fasting_close'),
  morningWeighIn('morning_weigh_in'),
  tapeMeasure('tape_measure'),
  journal('journal'),

  /// Media hora antes de dormir: bajar luces y pantallas (v7).
  windDown('wind_down'),

  /// Ejercicios de suelo pélvico, con texto siempre discreto (v7).
  pelvicFloor('pelvic_floor'),

  /// Descanso visual 20-20-20, repetido dentro de la jornada (v7).
  eyeRest('eye_rest');

  const ReminderType(this.dbValue);

  @override
  final String dbValue;
}
