import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/domain/enums.dart';
import 'package:nb_selfcare/core/services/backup_service.dart';

/// Inserta al menos una fila en cada una de las tablas del esquema.
Future<void> _populateEveryTable(AppDatabase db) async {
  await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          name: 'Ana',
          birthDate: DateTime(1990, 5, 1),
          biologicalSex: BiologicalSex.female,
          heightCm: 165,
          targetWeightKg: 60,
        ),
      );
  await db.into(db.bodyMeasurements).insert(
        BodyMeasurementsCompanion.insert(
          dateKey: '2026-10-01',
          source: MeasurementSource.manual,
          weightKg: 64,
          trendWeightKg: 64,
          bmi: 23.5,
        ),
      );
  await db.into(db.dailySummaries).insert(
        DailySummariesCompanion.insert(
          dateKey: '2026-10-01',
          calorieTargetKcal: 1900,
          proteinTargetG: 120,
          carbsTargetG: 180,
          fatTargetG: 60,
        ),
      );
  await db.into(db.hydrationLogs).insert(
        HydrationLogsCompanion.insert(dateKey: '2026-10-01', volumeMl: 250),
      );
  final int foodId = await db.into(db.foodItems).insert(
        FoodItemsCompanion.insert(
          name: 'Lentejas cocidas',
          source: FoodSource.usdaSeed,
          kcalPer100g: 116,
          proteinPer100g: 9,
          carbsPer100g: 20,
          fatPer100g: 0.4,
        ),
      );
  final int comboId = await db.into(db.mealCombos).insert(
        MealCombosCompanion.insert(name: 'Almuerzo', defaultMealType: MealType.lunch),
      );
  await db.into(db.mealComboItems).insert(
        MealComboItemsCompanion.insert(comboId: comboId, foodItemId: foodId, baseGrams: 200),
      );
  await db.into(db.foodLogs).insert(
        FoodLogsCompanion.insert(
          dateKey: '2026-10-01',
          mealType: MealType.lunch,
          foodItemId: foodId,
          gramsConsumed: 200,
          totalKcal: 232,
          totalProteinG: 18,
          totalCarbsG: 40,
          totalFatG: 0.8,
          totalFiberG: 16,
          totalSodiumMg: 4,
          totalPotassiumMg: 738,
          totalMagnesiumMg: 72,
        ),
      );
  await db.into(db.fastingSessions).insert(
        FastingSessionsCompanion.insert(
          protocolName: '16:8',
          targetHours: 16,
          startedAt: DateTime(2026, 10, 1, 20),
          plannedEndAt: DateTime(2026, 10, 2, 12),
        ),
      );
  await db.into(db.workoutBlocks).insert(
        WorkoutBlocksCompanion.insert(
          dateKey: '2026-10-01',
          category: WorkoutCategory.weights,
          durationMinutes: 45,
          rpeIntensity: RpeIntensity.moderate,
          appliedMet: 5,
          userWeightAtTimeKg: 64,
          netCaloriesBurned: 190,
        ),
      );
  await db.into(db.journalEntries).insert(
        JournalEntriesCompanion.insert(dateKey: '2026-10-01', content: 'Buen día'),
      );
  await db.into(db.petStatus).insert(PetStatusCompanion.insert());
  await db.into(db.coinLedger).insert(
        CoinLedgerCompanion.insert(dateKey: '2026-10-01', actionType: 'weigh_in', amount: 15),
      );
  await db.into(db.reminders).insert(
        RemindersCompanion.insert(reminderType: ReminderType.journal, timeOfDayMinutes: 1260),
      );
  await db.into(db.tdeeCalibrations).insert(
        TdeeCalibrationsCompanion.insert(
          dateKey: '2026-10-01',
          previousTdeeKcal: 2000,
          newTdeeKcal: 2050,
          calculatedRawTdeeKcal: 2050,
          deltaEma14d: -0.3,
          averageKcal14d: 1800,
          daysEvaluated: 12,
        ),
      );
  await db.into(db.healthSyncCheckpoints).insert(
        HealthSyncCheckpointsCompanion.insert(
          recordType: 'steps',
          lastSyncTimestamp: DateTime(2026, 10, 1),
        ),
      );
  final int recipeId = await db.into(db.recipes).insert(
        RecipesCompanion.insert(
          name: 'Sopa de lentejas',
          kcalPerServing: 300,
          proteinPerServing: 18,
          carbsPerServing: 40,
          fatPerServing: 6,
        ),
      );
  await db.into(db.recipeIngredients).insert(
        RecipeIngredientsCompanion.insert(recipeId: recipeId, foodItemId: foodId, rawGrams: 500),
      );
  final int supplementId = await db.into(db.supplementsTracker).insert(
        SupplementsTrackerCompanion.insert(name: 'Creatina', dosage: '5g'),
      );
  await db.into(db.supplementLogs).insert(
        SupplementLogsCompanion.insert(dateKey: '2026-10-01', supplementId: supplementId),
      );
  await db.into(db.femaleCycleLogs).insert(
        FemaleCycleLogsCompanion.insert(cycleStartDate: DateTime(2026, 9, 20)),
      );
  await db.into(db.digestiveLogs).insert(
        DigestiveLogsCompanion.insert(dateKey: '2026-10-01', bristolType: 4),
      );
  await db.into(db.caffeineLogs).insert(
        CaffeineLogsCompanion.insert(dateKey: '2026-10-01', sourceName: 'espresso', caffeineMg: 63),
      );
  await db.into(db.protocolPlans).insert(ProtocolPlansCompanion.insert());
  await db.into(db.milestoneGoals).insert(
        MilestoneGoalsCompanion.insert(milestoneOrder: 1, targetWeightKg: 62.5),
      );
  await db.writeUiPreference('hoy_layout', '["rings"]');
  final DateTime at = DateTime(2026, 10, 1, 9);
  await db.into(db.careSessions).insert(
        CareSessionsCompanion.insert(
          dateKey: '2026-10-01',
          completedAt: at,
          kind: 'pelvic_floor',
          variant: 'level_1',
          durationSeconds: 120,
        ),
      );
  final int habitId = await db.into(db.customHabits).insert(
        CustomHabitsCompanion.insert(name: 'Hilo dental', createdAt: at),
      );
  await db.into(db.habitLogs).insert(
        HabitLogsCompanion.insert(habitId: habitId, dateKey: '2026-10-01', loggedAt: at),
      );
  final int checkupId = await db.into(db.checkups).insert(
        CheckupsCompanion.insert(catalogKey: 'dental', intervalMonths: 12),
      );
  await db.into(db.checkupLogs).insert(CheckupLogsCompanion.insert(checkupId: checkupId, doneAt: at));
  await db.into(db.symptomLogs).insert(
        SymptomLogsCompanion.insert(dateKey: '2026-10-01', loggedAt: at, symptom: 'headache', intensity: 2),
      );
  await db.into(db.vitalReadings).insert(
        VitalReadingsCompanion.insert(
          kind: 'blood_pressure',
          measuredAt: at,
          dateKey: '2026-10-01',
          primaryValue: 120,
          secondaryValue: const Value(80),
        ),
      );
  await db.into(db.substanceLogs).insert(
        SubstanceLogsCompanion.insert(dateKey: '2026-10-01', loggedAt: at, kind: 'alcohol', presetKey: 'wine'),
      );
  await db.into(db.wellbeingChecks).insert(
        WellbeingChecksCompanion.insert(
          dateKey: '2026-10-01',
          createdAt: at,
          answersJson: '[3,3,3,3,3]',
          percentScore: 60,
        ),
      );
}

Future<Map<String, int>> _rowCounts(AppDatabase db) async {
  final Map<String, int> counts = <String, int>{};
  for (final TableInfo<Table, Object?> table in db.allTables) {
    final QueryRow row = await db
        .customSelect('SELECT COUNT(*) AS cnt FROM "${table.actualTableName}"')
        .getSingle();
    counts[table.actualTableName] = row.read<int>('cnt');
  }
  return counts;
}

void main() {
  late Directory workDir;
  late AppDatabase source;
  late AppDatabase target;

  setUp(() {
    workDir = Directory.systemTemp.createTempSync('nb_backup_roundtrip_');
    source = AppDatabase(NativeDatabase(File('${workDir.path}/source.sqlite')));
    target = AppDatabase(NativeDatabase(File('${workDir.path}/target.sqlite')));
  });

  tearDown(() async {
    await source.close();
    await target.close();
    workDir.deleteSync(recursive: true);
  });

  BackupService serviceFor(AppDatabase db) =>
      BackupService(db, temporaryDirectory: () async => workDir);

  test('Restaura las filas de todas las tablas del esquema, sin excepción', () async {
    await _populateEveryTable(source);
    final Map<String, int> expected = await _rowCounts(source);
    expect(expected.values.every((int c) => c > 0), isTrue,
        reason: 'El fixture debe cubrir todas las tablas: $expected');

    final File backup = await source.exportCleanDatabaseBackup(workDir.path, stamp: DateTime(2026, 10, 26));

    // El destino tiene datos distintos que deben desaparecer tras restaurar.
    await target.into(target.recipes).insert(
          RecipesCompanion.insert(
            name: 'Receta local que no está en el respaldo',
            kcalPerServing: 1,
            proteinPerServing: 1,
            carbsPerServing: 1,
            fatPerServing: 1,
          ),
        );
    await target.into(target.recipes).insert(
          RecipesCompanion.insert(
            name: 'Otra receta local',
            kcalPerServing: 1,
            proteinPerServing: 1,
            carbsPerServing: 1,
            fatPerServing: 1,
          ),
        );

    expect(await serviceFor(target).restoreDatabaseFromFile(backup.path), isTrue);
    expect(await _rowCounts(target), expected);

    final List<Recipe> recipes = await target.select(target.recipes).get();
    expect(recipes.single.name, 'Sopa de lentejas');
    expect(await target.readUiPreference('hoy_layout'), '["rings"]');

    final List<QueryRow> fts = await target.customSelect(
      'SELECT name FROM food_items_fts WHERE food_items_fts MATCH ?',
      variables: <Variable<Object>>[Variable.withString('lentejas*')],
    ).get();
    expect(fts, hasLength(1));

    final List<QueryRow> fkViolations =
        await target.customSelect('PRAGMA foreign_key_check').get();
    expect(fkViolations, isEmpty);
  });

  test('Rechaza respaldos de una versión de esquema futura', () async {
    await _populateEveryTable(source);
    final File backup = await source.exportCleanDatabaseBackup(workDir.path, stamp: DateTime(2026, 10, 26));
    final AppDatabase raw = AppDatabase(NativeDatabase(backup));
    await raw.customStatement('PRAGMA user_version = ${source.schemaVersion + 1};');
    await raw.close();

    final BackupInspection inspection = serviceFor(target).inspectBackup(backup.path);
    expect(inspection.isValid, isFalse);
    expect(inspection.schemaVersion, source.schemaVersion + 1);
  });

  test('Rechaza archivos que no son respaldos de NB Selfcare', () async {
    final File junk = File('${workDir.path}/junk.sqlite')
      ..writeAsBytesSync(List<int>.filled(8192, 7));
    expect(await serviceFor(target).restoreDatabaseFromFile(junk.path), isFalse);
  });

  test('Un fallo a mitad de la restauración no deja la base a medias', () async {
    await _populateEveryTable(source);
    await _populateEveryTable(target);
    final Map<String, int> before = await _rowCounts(target);

    // Respaldo con una fila que viola NOT NULL en coin_ledger: la copia falla
    // dentro de la transacción y todo debe revertirse.
    final File backup = await source.exportCleanDatabaseBackup(workDir.path, stamp: DateTime(2026, 10, 26));
    final AppDatabase poisoned = AppDatabase(NativeDatabase(backup));
    await poisoned.customStatement('ALTER TABLE coin_ledger RENAME TO coin_ledger_old;');
    await poisoned.customStatement(
      'CREATE TABLE coin_ledger (id INTEGER PRIMARY KEY, created_at TEXT, date_key TEXT, '
      'action_type TEXT, amount INTEGER, sleep_multiplier_applied REAL);',
    );
    await poisoned.customStatement(
      "INSERT INTO coin_ledger (date_key, action_type, amount) VALUES (NULL, 'x', 1);",
    );
    await poisoned.close();

    expect(await serviceFor(target).restoreDatabaseFromFile(backup.path), isFalse);
    expect(await _rowCounts(target), before);
  });
}
