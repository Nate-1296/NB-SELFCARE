import 'package:drift/drift.dart';

import 'converters.dart';

// 1. PERFIL DINÁMICO Y PREFERENCIAS DEL SISTEMA
class UserProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get avatarPath => text().nullable()();

  // La edad nunca se almacena: se calcula al vuelo con BiometricFormulas.calculateDynamicAge.
  DateTimeColumn get birthDate => dateTime()();
  TextColumn get biologicalSex => text().map(biologicalSexConverter)();
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

  // Modos contextuales, objetivos y personalización avanzada
  BoolColumn get isCycleTrackingEnabled => boolean().withDefault(const Constant(false))();
  BoolColumn get isFastingEnabled => boolean().withDefault(const Constant(true))();
  BoolColumn get isManualMacroMode => boolean().withDefault(const Constant(false))();
  IntColumn get manualKcalTarget => integer().nullable()();
  IntColumn get manualProteinG => integer().nullable()();
  IntColumn get manualCarbsG => integer().nullable()();
  IntColumn get manualFatG => integer().nullable()();
  TextColumn get activeDietArchetype =>
      text().map(dietArchetypeConverter).withDefault(const Constant('flexible'))();
  TextColumn get activeDietPhase =>
      text().map(dietPhaseConverter).withDefault(const Constant('deficit'))();
  TextColumn get calorieCyclingScheduleJson => text().withDefault(const Constant('{}'))(); // JSON con metas por día de la semana
  RealColumn get caffeineBedtimeCutoffHours => real().withDefault(const Constant(8.0))(); // Horas antes de dormir para corte de cafeína
  DateTimeColumn get activeDietPhaseStartedAt => dateTime().nullable()(); // Inicio de la fase vigente (reverse diet, diet break)

  // Seguridad clínica declarada en el onboarding (docs/01 §6)
  BoolColumn get hasImpedanceContraindication =>
      boolean().withDefault(const Constant(false))(); // Marcapasos, implantes o embarazo: solo peso
  BoolColumn get hasEatingDisorderHistory =>
      boolean().withDefault(const Constant(false))(); // Oculta déficit agresivo y ayunos > 16 h
  BoolColumn get takesHypoglycemicMedication =>
      boolean().withDefault(const Constant(false))(); // Aviso antes de ayunar

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// 2. BIOMETRÍA: BÁSCULA XIAOMI MI SCALE 2 (13 MÉTRICAS) + CINTA US NAVY
@TableIndex.sql(
  'CREATE INDEX idx_body_measurements_date ON body_measurements(date_key DESC, measured_at DESC)',
)
class BodyMeasurements extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get measuredAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get dateKey => text()(); // Formato YYYY-MM-DD para joins directos
  TextColumn get source => text().map(measurementSourceConverter)();

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
@TableIndex(name: 'idx_hydration_logs_date', columns: {#dateKey, #loggedAt})
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
  TextColumn get source => text().map(foodSourceConverter)();
  TextColumn get nutriScore => text().nullable()(); // 'A'..'E'
  IntColumn get novaGroup => integer().nullable()(); // 1 a 4 (Clasificación NOVA de ultraprocesados)
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
  TextColumn get defaultMealType => text().map(mealTypeConverter)();
  IntColumn get timesUsed => integer().withDefault(const Constant(0))();
}

class MealComboItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get comboId => integer().references(MealCombos, #id, onDelete: KeyAction.cascade)();
  IntColumn get foodItemId => integer().references(FoodItems, #id)();
  RealColumn get baseGrams => real()(); // Cantidad base para 1.0x
}

// 7. REGISTRO DIARIO DE INGESTA NUTRICIONAL
@TableIndex(name: 'idx_food_logs_date_meal', columns: {#dateKey, #mealType})
@TableIndex(name: 'idx_food_logs_food_item', columns: {#foodItemId})
class FoodLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get dateKey => text()(); // 'YYYY-MM-DD'
  DateTimeColumn get loggedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get mealType => text().map(mealTypeConverter)();

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
@TableIndex(name: 'idx_fasting_sessions_started', columns: {#startedAt})
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
@TableIndex(name: 'idx_workout_blocks_date', columns: {#dateKey})
class WorkoutBlocks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get dateKey => text()(); // 'YYYY-MM-DD'
  DateTimeColumn get performedAt => dateTime().withDefault(currentDateAndTime)();

  TextColumn get category => text().map(workoutCategoryConverter)();
  IntColumn get durationMinutes => integer()();
  TextColumn get rpeIntensity => text().map(rpeIntensityConverter)();

  RealColumn get appliedMet => real()();
  RealColumn get userWeightAtTimeKg => real()();
  IntColumn get netCaloriesBurned => integer()();
}

// 10. DIARIO PERSONAL Y NLP LOCAL
@TableIndex(name: 'idx_journal_entries_date', columns: {#dateKey})
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

@TableIndex.sql(
  'CREATE UNIQUE INDEX idx_coin_ledger_daily_unique ON coin_ledger(date_key, action_type) '
  "WHERE action_type != 'shop_buy'",
)
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
  TextColumn get reminderType => text().map(reminderTypeConverter)();
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

// 15. RECETAS CASERAS MULTIRACIÓN (BATCH COOKING & MEAL PREP)
@TableIndex(name: 'idx_recipes_name', columns: {#name})
class Recipes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get defaultMealType =>
      text().map(mealTypeConverter).withDefault(const Constant('lunch'))();
  IntColumn get totalYieldServings => integer().withDefault(const Constant(1))();
  RealColumn get cookedTotalWeightGrams => real().nullable()(); // Peso total cocinado opcional

  // Valores consolidados calculados por ración (1 serving)
  RealColumn get kcalPerServing => real()();
  RealColumn get proteinPerServing => real()();
  RealColumn get carbsPerServing => real()();
  RealColumn get fatPerServing => real()();
  RealColumn get fiberPerServing => real().withDefault(const Constant(0.0))();
  RealColumn get sodiumMgPerServing => real().withDefault(const Constant(0.0))();
  RealColumn get potassiumMgPerServing => real().withDefault(const Constant(0.0))();
  RealColumn get magnesiumMgPerServing => real().withDefault(const Constant(0.0))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastUsedAt => dateTime().nullable()();
}

class RecipeIngredients extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get recipeId => integer().references(Recipes, #id, onDelete: KeyAction.cascade)();
  IntColumn get foodItemId => integer().references(FoodItems, #id)();
  RealColumn get rawGrams => real()(); // Gramos de ingrediente crudo para la preparación total
}

// 16. SEGUIMIENTO DE SUPLEMENTACIÓN Y MEDICACIÓN
class SupplementsTracker extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()(); // ej. 'Creatina Monohidrato', 'Magnesio', 'Vitamina D3'
  TextColumn get dosage => text()(); // ej. '5g', '400mg', '2000 UI'
  IntColumn get targetTimeOfDayMinutes => integer().nullable()(); // Minutos desde medianoche
  BoolColumn get affectsWaterRetention => boolean().withDefault(const Constant(false))(); // ej. Creatina -> retención intramuscular
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@TableIndex(name: 'idx_supplement_logs_date', columns: {#dateKey})
class SupplementLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get dateKey => text()(); // 'YYYY-MM-DD'
  IntColumn get supplementId => integer().references(SupplementsTracker, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get takenAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get wasTaken => boolean().withDefault(const Constant(true))();
}

// 17. SALUD HORMONAL Y CICLO MENSTRUAL FEMENINO
class FemaleCycleLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get cycleStartDate => dateTime()(); // Fecha de inicio del sangrado
  DateTimeColumn get cycleEndDate => dateTime().nullable()();
  IntColumn get cycleLengthDays => integer().withDefault(const Constant(28))(); // Duración promedio del ciclo
  TextColumn get flowIntensity => text().nullable()(); // 'light', 'medium', 'heavy'
  TextColumn get symptomsJson => text().withDefault(const Constant('[]'))(); // 'cramps', 'bloating', 'headache', 'mood_swings'
  TextColumn get notes => text().nullable()();
}

// 18. SALUD INTESTINAL Y ESCALA DE BRISTOL
@TableIndex(name: 'idx_digestive_logs_date', columns: {#dateKey})
class DigestiveLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get dateKey => text()(); // 'YYYY-MM-DD'
  DateTimeColumn get loggedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get bristolType => integer()(); // 1 a 7 (Escala de Heces de Bristol)
  IntColumn get discomfortLevel => integer().withDefault(const Constant(1))(); // 1 (ninguno) a 5 (severo)
  TextColumn get symptomsJson => text().withDefault(const Constant('[]'))(); // 'bloating', 'gas', 'acid_reflux', 'cramps'
  TextColumn get notes => text().nullable()();
}

// 19. REGISTRO FARMACOCINÉTICO DE CAFEÍNA
@TableIndex(name: 'idx_caffeine_logs_date', columns: {#dateKey})
class CaffeineLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get dateKey => text()(); // 'YYYY-MM-DD'
  DateTimeColumn get loggedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get sourceName => text()(); // 'espresso', 'filtro', 'energy_drink', 'pre_workout', 'tea'
  RealColumn get caffeineMg => real()(); // Miligramos de cafeína
}

// 20. PLANIFICADOR SEMANAL DE PROTOCOLO INTEGRAL
class ProtocolPlans extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get planName => text().withDefault(const Constant('Mi Protocolo Semanal'))();
  TextColumn get fastingDaysBitmask => text().withDefault(const Constant('{"1":16,"2":16,"3":16,"4":16,"5":16,"6":0,"7":0}'))(); // Día semana -> horas ayuno
  TextColumn get workoutSlotsJson => text().withDefault(const Constant('[]'))(); // Slots de entrenamiento planeados
  TextColumn get dietArchetype => text().withDefault(const Constant('flexible'))();
  BoolColumn get isCurrentActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

// 21. MINI-HITOS PSICOLÓGICOS DE PESO (HAPPY SCALE)
class MilestoneGoals extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get milestoneOrder => integer()(); // 1, 2, 3...
  RealColumn get targetWeightKg => real()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get estimatedCompletionDate => dateTime().nullable()();
}

// 22. PREFERENCIAS LOCALES DE INTERFAZ (layout de widgets de Hoy, etc.)
class UiPreferences extends Table {
  TextColumn get prefKey => text()();
  TextColumn get prefValue => text()();

  @override
  Set<Column> get primaryKey => {prefKey};
}
