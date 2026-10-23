import 'package:drift/drift.dart';

// 1. PERFIL DINÁMICO Y PREFERENCIAS DEL SISTEMA
class UserProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get avatarPath => text().nullable()();

  // Edad dinámica calculada al vuelo: DateTime.now().difference(birthDate).inDays / 365.25
  DateTimeColumn get birthDate => dateTime()();
  TextColumn get biologicalSex => text()(); // 'male' | 'female'
  RealColumn get heightCm => real()();

  // Metas biométricas y conductuales
  RealColumn get targetWeightKg => real()();
  RealColumn get weeklyGoalRateKg => real().withDefault(const Constant(-0.5))();
  IntColumn get dailyWaterGoalMl => integer().withDefault(const Constant(2500))();
  IntColumn get dailyStepsGoal => integer().withDefault(const Constant(8000))();
  RealColumn get dailySleepGoalHours => real().withDefault(const Constant(7.5))();

  // Motor de TDEE Adaptativo (Auto-calibrado en ventana móvil de 14 días)
  IntColumn get currentAdaptiveTdeeKcal => integer().withDefault(const Constant(2000))();
  DateTimeColumn get lastTdeeCalibration => dateTime().nullable()();

  // Hardware & Preferencias de UI (TCL 50 Pro NXTPAPER + Mi Scale 2 + SLM Local)
  TextColumn get scaleMacAddress => text().nullable()();
  TextColumn get themeMode => text().withDefault(const Constant('material_you'))(); // 'material_you' | 'nxtpaper_eink'
  TextColumn get localAiModelPath => text().nullable()();
  BoolColumn get isLocalAiEnabled => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// 2. BIOMETRÍA: BÁSCULA XIAOMI MI SCALE 2 (13 MÉTRICAS) + CINTA US NAVY
class BodyMeasurements extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get measuredAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get dateKey => text()(); // Formato YYYY-MM-DD para joins directos
  TextColumn get source => text()(); // 'mi_scale_2_ble' | 'health_connect' | 'manual'

  RealColumn get weightKg => real()();
  RealColumn get trendWeightKg => real()(); // EMA (alpha = 0.1)
  IntColumn get impedanceOhms => integer().nullable()(); // 4 electrodos BIA

  // Las 13 métricas derivadas de la Xiaomi Mi Body Composition Scale 2 (XMTZC05HM)
  RealColumn get bmi => real()();
  RealColumn get bodyFatPercentage => real().nullable()();
  RealColumn get muscleMassKg => real().nullable()();
  RealColumn get waterPercentage => real().nullable()();
  IntColumn get visceralFatIndex => integer().nullable()();
  RealColumn get boneMassKg => real().nullable()();
  RealColumn get proteinPercentage => real().nullable()();
  IntColumn get basalMetabolicRateKcal => integer().nullable()();
  IntColumn get metabolicAge => integer().nullable()();
  RealColumn get leanBodyMassKg => real().nullable()();
  IntColumn get bodyScore => integer().nullable()(); // 10 - 100
  TextColumn get somatotype => text().nullable()(); // 9 fenotipos corporales

  // Validación Quincenal por Cinta Métrica (Ecuación US Navy)
  RealColumn get waistCm => real().nullable()();
  RealColumn get neckCm => real().nullable()();
  RealColumn get hipCm => real().nullable()();
  RealColumn get validatedBodyFatPercentage => real().nullable()(); // 0.6*BIA + 0.4*Navy

  // Heurística de Detección de Falsa Subida (Retención Hídrica / Glucógeno)
  BoolColumn get isWaterRetentionSpike => boolean().withDefault(const Constant(false))();
  TextColumn get spikeExplanation => text().nullable()();
}

// 3. RESUMEN DIARIO CONSOLIDADO (PUENTE CON HEALTH CONNECT)
class DailySummaries extends Table {
  TextColumn get dateKey => text()(); // PK: 'YYYY-MM-DD'

  IntColumn get stepsCount => integer().withDefault(const Constant(0))();
  IntColumn get activeCaloriesFromSteps => integer().withDefault(const Constant(0))();
  IntColumn get sleepDurationMinutes => integer().withDefault(const Constant(0))();
  IntColumn get sleepDeepMinutes => integer().withDefault(const Constant(0))();
  IntColumn get sleepRemMinutes => integer().withDefault(const Constant(0))();
  IntColumn get restingHeartRateBpm => integer().nullable()();
  IntColumn get waterConsumedMl => integer().withDefault(const Constant(0))();

  // Snapshot de metas vigentes en ese día
  IntColumn get calorieTargetKcal => integer()();
  IntColumn get proteinTargetG => integer()();
  IntColumn get carbsTargetG => integer()();
  IntColumn get fatTargetG => integer()();

  @override
  Set<Column> get primaryKey => {dateKey};
}

// 4. REGISTRO ATÓMICO DE VASOS DE AGUA (SINCRONIZACIÓN Y EDICIÓN RÁPIDA)
class HydrationLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get dateKey => text()(); // 'YYYY-MM-DD'
  DateTimeColumn get loggedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get volumeMl => integer()(); // ej. 250, 500
  BoolColumn get syncedToHealthConnect => boolean().withDefault(const Constant(false))();
}

// 5. CATÁLOGO DE ALIMENTOS (USDA SEED + CACHE OPEN FOOD FACTS + CUSTOM)
class FoodItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get barcode => text().nullable().unique()();
  TextColumn get name => text()();
  TextColumn get brand => text().nullable()();
  TextColumn get source => text()(); // 'usda_seed' | 'open_food_facts' | 'user_custom' | 'ai_fallback'
  TextColumn get nutriScore => text().nullable()(); // 'A'..'E'
  RealColumn get defaultServingGrams => real().withDefault(const Constant(100.0))();
  TextColumn get servingLabel => text().withDefault(const Constant('100g'))();

  // Macronutrientes por 100g
  RealColumn get kcalPer100g => real()();
  RealColumn get proteinPer100g => real()();
  RealColumn get carbsPer100g => real()();
  RealColumn get fatPer100g => real()();
  RealColumn get fiberPer100g => real().withDefault(const Constant(0.0))();
  RealColumn get sugarPer100g => real().withDefault(const Constant(0.0))();

  // Triángulo Electrolítico y Micronutrientes Clave por 100g
  RealColumn get sodiumMgPer100g => real().withDefault(const Constant(0.0))();
  RealColumn get potassiumMgPer100g => real().withDefault(const Constant(0.0))();
  RealColumn get magnesiumMgPer100g => real().withDefault(const Constant(0.0))();
  RealColumn get calciumMgPer100g => real().withDefault(const Constant(0.0))();
  RealColumn get ironMgPer100g => real().withDefault(const Constant(0.0))();
  RealColumn get zincMgPer100g => real().withDefault(const Constant(0.0))();
  RealColumn get vitaminCMgPer100g => real().withDefault(const Constant(0.0))();
  RealColumn get vitaminDUgPer100g => real().withDefault(const Constant(0.0))();
  RealColumn get vitaminB12UgPer100g => real().withDefault(const Constant(0.0))();

  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastUsedAt => dateTime().nullable()();
}

// 6. PLANTILLAS DE COMBOS CASEROS CON ESCALADOR DE PORCIÓN
class MealCombos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get defaultMealType => text()(); // 'breakfast' | 'lunch' | 'dinner' | 'snack'
  IntColumn get timesUsed => integer().withDefault(const Constant(0))();
}

class MealComboItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get comboId => integer().references(MealCombos, #id, onDelete: KeyAction.cascade)();
  IntColumn get foodItemId => integer().references(FoodItems, #id)();
  RealColumn get baseGrams => real()(); // Cantidad base para 1.0x
}

// 7. REGISTRO DIARIO DE INGESTA NUTRICIONAL
class FoodLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get dateKey => text()(); // 'YYYY-MM-DD'
  DateTimeColumn get loggedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get mealType => text()(); // 'breakfast' | 'lunch' | 'dinner' | 'snack'

  IntColumn get foodItemId => integer().references(FoodItems, #id)();
  RealColumn get gramsConsumed => real()();
  RealColumn get portionMultiplier => real().withDefault(const Constant(1.0))();

  // Totales calculados al momento de registrar (O(1) aggregations)
  RealColumn get totalKcal => real()();
  RealColumn get totalProteinG => real()();
  RealColumn get totalCarbsG => real()();
  RealColumn get totalFatG => real()();
  RealColumn get totalFiberG => real()();
  RealColumn get totalSodiumMg => real()();
  RealColumn get totalPotassiumMg => real()();
  RealColumn get totalMagnesiumMg => real()();
}

// 8. SESIONES DE AYUNO INTERMITENTE
class FastingSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get protocolName => text()(); // '16:8', '18:6', '20:4', 'OMAD', 'Custom'
  IntColumn get targetHours => integer()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get plannedEndAt => dateTime()();
  DateTimeColumn get actualEndedAt => dateTime().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
}

// 9. BLOQUES RÁPIDOS DE ENTRENAMIENTO (RPE -> METs)
class WorkoutBlocks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get dateKey => text()(); // 'YYYY-MM-DD'
  DateTimeColumn get performedAt => dateTime().withDefault(currentDateAndTime)();

  TextColumn get category => text()(); // 'weights' | 'calisthenics' | 'cardio' | 'sports'
  IntColumn get durationMinutes => integer()();
  TextColumn get rpeIntensity => text()(); // 'light' | 'moderate' | 'intense'

  RealColumn get appliedMet => real()();
  RealColumn get userWeightAtTimeKg => real()();
  IntColumn get netCaloriesBurned => integer()();
}

// 10. DIARIO PERSONAL Y NLP LOCAL
class JournalEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get dateKey => text()(); // 'YYYY-MM-DD'
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  TextColumn get content => text()();
  TextColumn get progressPhotoPath => text().nullable()();

  IntColumn get moodScore => integer().nullable()(); // 1..5
  IntColumn get energyLevel => integer().nullable()(); // 1..5
  IntColumn get stressLevel => integer().nullable()(); // 1..5
  TextColumn get tagsJson => text().withDefault(const Constant('[]'))();
  TextColumn get aiInsightSummary => text().nullable()();
}

// 11. ESTADO DE LA MASCOTA VIRTUAL Y LIBRO MAYOR DE MONEDAS
class PetStatus extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get petName => text().withDefault(const Constant('Nibi'))();
  IntColumn get coinsBalance => integer().withDefault(const Constant(50))();
  IntColumn get currentStreakDays => integer().withDefault(const Constant(0))();
  IntColumn get highestStreakDays => integer().withDefault(const Constant(0))();

  IntColumn get streakShieldsAvailable => integer().withDefault(const Constant(1))();
  DateTimeColumn get shieldActiveUntil => dateTime().nullable()();

  TextColumn get equippedHatId => text().nullable()();
  TextColumn get equippedBackgroundId => text().withDefault(const Constant('bg_default_room'))();
  TextColumn get unlockedItemsJson => text().withDefault(const Constant('["bg_default_room"]'))();

  TextColumn get lastAiGreeting => text().nullable()();
  DateTimeColumn get lastGreetingAt => dateTime().nullable()();
}

class CoinLedger extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get dateKey => text()(); // 'YYYY-MM-DD'
  TextColumn get actionType => text()(); // 'weigh_in' | 'meal_log' | 'water_goal' | 'fast_done' | 'journal_entry' | 'shop_buy'
  IntColumn get amount => integer()();
  RealColumn get sleepMultiplierApplied => real().withDefault(const Constant(1.0))();
}

// 12. PROGRAMADOR DE RECORDATORIOS EXACTOS
class Reminders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get reminderType => text()(); // 'hydration' | 'fasting_open' | 'fasting_close' | 'morning_weigh_in' | 'tape_measure' | 'journal'
  IntColumn get timeOfDayMinutes => integer()(); // Minutos desde medianoche (ej. 480 = 08:00 AM)
  IntColumn get daysOfWeekBitmask => integer().withDefault(const Constant(127))(); // 7 bits (L-D, 127 = todos)
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  IntColumn get intervalMinutes => integer().nullable()(); // Para recordatorios de agua recurrentes
}

// 13. HISTORIAL DE CALIBRACIÓN DEL TDEE ADAPTATIVO (CADA 14 DÍAS)
class TdeeCalibrations extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get calibratedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get dateKey => text()(); // 'YYYY-MM-DD'
  IntColumn get previousTdeeKcal => integer()();
  IntColumn get newTdeeKcal => integer()();
  IntColumn get calculatedRawTdeeKcal => integer()();
  BoolColumn get wasClamped => boolean().withDefault(const Constant(false))();
  RealColumn get deltaEma14d => real()();
  RealColumn get averageKcal14d => real()();
  IntColumn get daysEvaluated => integer()();
}

// 14. CONTROL DE SINCRONIZACIÓN HEALTH CONNECT (CHECKPOINTS)
class HealthSyncCheckpoints extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get recordType => text().unique()(); // 'steps' | 'sleep' | 'heart_rate' | 'weight' | 'body_fat' | 'hydration'
  DateTimeColumn get lastSyncTimestamp => dateTime()();
  IntColumn get lastReadCount => integer().withDefault(const Constant(0))();
  IntColumn get lastWriteCount => integer().withDefault(const Constant(0))();
}
