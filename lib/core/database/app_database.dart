import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/enums.dart';
import 'app_database.steps.dart';
import 'converters.dart';
import 'seeder/database_seeder.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// Base de datos relacional principal de NB Selfcare.
///
/// Implementa persistencia 100% offline-first con SQLite3, modo WAL,
/// tabla virtual FTS5 sin diacríticos para búsqueda ultrarrápida de alimentos,
/// e integridad referencial forzada.
@DriftDatabase(
  tables: [
    UserProfiles,
    BodyMeasurements,
    DailySummaries,
    HydrationLogs,
    FoodItems,
    MealCombos,
    MealComboItems,
    FoodLogs,
    FastingSessions,
    WorkoutBlocks,
    JournalEntries,
    PetStatus,
    CoinLedger,
    Reminders,
    TdeeCalibrations,
    HealthSyncCheckpoints,
    Recipes,
    RecipeIngredients,
    SupplementsTracker,
    SupplementLogs,
    FemaleCycleLogs,
    DigestiveLogs,
    CaffeineLogs,
    ProtocolPlans,
    MilestoneGoals,
    UiPreferences,
    CareSessions,
    CustomHabits,
    HabitLogs,
    Checkups,
    CheckupLogs,
    SymptomLogs,
    VitalReadings,
    SubstanceLogs,
    WellbeingChecks,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : _autoSeed = executor == null,
      super(executor ?? _openConnection());

  final bool _autoSeed;

  @override
  int get schemaVersion => 7;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'nb_selfcare',
      native: const DriftNativeOptions(shareAcrossIsolates: true),
    );
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON;');
      await customStatement('PRAGMA journal_mode = WAL;');
      if (_autoSeed) {
        await DatabaseSeeder.seedIfEmpty(this);
      }
    },
    onCreate: (Migrator m) async {
      await m.createAll();
      await _createFoodSearchIndex();
    },
    onUpgrade: stepByStep(
      from1To2: (Migrator m, Schema2 schema) async {
        await m.addColumn(schema.userProfiles, schema.userProfiles.isCycleTrackingEnabled);
        await m.addColumn(schema.userProfiles, schema.userProfiles.isFastingEnabled);
        await m.addColumn(schema.userProfiles, schema.userProfiles.isManualMacroMode);
        await m.addColumn(schema.userProfiles, schema.userProfiles.manualKcalTarget);
        await m.addColumn(schema.userProfiles, schema.userProfiles.manualProteinG);
        await m.addColumn(schema.userProfiles, schema.userProfiles.manualCarbsG);
        await m.addColumn(schema.userProfiles, schema.userProfiles.manualFatG);
        await m.addColumn(schema.userProfiles, schema.userProfiles.activeDietArchetype);
        await m.addColumn(schema.userProfiles, schema.userProfiles.activeDietPhase);
        await m.addColumn(schema.userProfiles, schema.userProfiles.calorieCyclingScheduleJson);
        await m.addColumn(schema.userProfiles, schema.userProfiles.caffeineBedtimeCutoffHours);
        await m.addColumn(schema.foodItems, schema.foodItems.novaGroup);

        await m.createTable(schema.recipes);
        await m.createTable(schema.recipeIngredients);
        await m.createTable(schema.supplementsTracker);
        await m.createTable(schema.supplementLogs);
        await m.createTable(schema.femaleCycleLogs);
        await m.createTable(schema.digestiveLogs);
        await m.createTable(schema.caffeineLogs);
        await m.createTable(schema.protocolPlans);
        await m.createTable(schema.milestoneGoals);
      },
      from2To3: (Migrator m, Schema3 schema) async {
        // ui_preferences existía fuera del esquema (CREATE TABLE IF NOT EXISTS en
        // beforeOpen). Se recrea con la definición de Drift conservando las filas.
        final bool hadLegacy = (await customSelect(
          "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'ui_preferences'",
        ).get()).isNotEmpty;
        if (hadLegacy) {
          await customStatement('ALTER TABLE ui_preferences RENAME TO ui_preferences_legacy;');
        }
        await m.createTable(schema.uiPreferences);
        if (hadLegacy) {
          await customStatement(
            'INSERT INTO ui_preferences (pref_key, pref_value) '
            'SELECT pref_key, pref_value FROM ui_preferences_legacy;',
          );
          await customStatement('DROP TABLE ui_preferences_legacy;');
        }

        // Los índices pasan a declararse en Drift: se recrean todos con su
        // definición canónica (algunos ni existían en bases migradas desde v1).
        for (final Index index in schema.entities.whereType<Index>()) {
          await customStatement('DROP INDEX IF EXISTS "${index.entityName}";');
          await m.create(index);
        }
      },
      from3To4: (Migrator m, Schema4 schema) async {
        await m.addColumn(schema.userProfiles, schema.userProfiles.activeDietPhaseStartedAt);
        await m.addColumn(schema.userProfiles, schema.userProfiles.hasImpedanceContraindication);
        await m.addColumn(schema.userProfiles, schema.userProfiles.hasEatingDisorderHistory);
        await m.addColumn(schema.userProfiles, schema.userProfiles.takesHypoglycemicMedication);
      },
      from4To5: (Migrator m, Schema5 schema) async {
        // Nibi 2.0: accesorio y color además del sombrero.
        await m.addColumn(schema.petStatus, schema.petStatus.equippedAccessoryId);
        await m.addColumn(schema.petStatus, schema.petStatus.equippedColorId);
      },
      from5To6: (Migrator m, Schema6 schema) async {
        // Fotos del diario dentro de la base de datos (portables en la copia).
        await m.addColumn(schema.journalEntries, schema.journalEntries.progressPhoto);
      },
      from6To7: (Migrator m, Schema7 schema) async {
        // Equipos declarados, módulos de Cuidado y hora de dormir.
        await m.addColumn(schema.userProfiles, schema.userProfiles.hasEinkScreen);
        await m.addColumn(schema.userProfiles, schema.userProfiles.hasSmartScale);
        await m.addColumn(schema.userProfiles, schema.userProfiles.vitalDevicesJson);
        await m.addColumn(schema.userProfiles, schema.userProfiles.careModulesJson);
        await m.addColumn(schema.userProfiles, schema.userProfiles.discreetNotifications);
        await m.addColumn(schema.userProfiles, schema.userProfiles.targetBedtimeMinutes);
        // Quien ya usaba la app lo veía todo: conserva la báscula y los modos de papel.
        await customStatement('UPDATE user_profiles SET has_eink_screen = 1, has_smart_scale = 1;');
        await m.addColumn(schema.dailySummaries, schema.dailySummaries.wakeTimeMinutes);

        // Suplementos → tratamientos con horario, reserva y avisos.
        await m.addColumn(schema.supplementsTracker, schema.supplementsTracker.kind);
        await m.addColumn(schema.supplementsTracker, schema.supplementsTracker.scheduleJson);
        await m.addColumn(schema.supplementsTracker, schema.supplementsTracker.daysOfWeekBitmask);
        await m.addColumn(schema.supplementsTracker, schema.supplementsTracker.stockUnits);
        await m.addColumn(schema.supplementsTracker, schema.supplementsTracker.unitsPerDose);
        await m.addColumn(schema.supplementsTracker, schema.supplementsTracker.remindersEnabled);
        await m.addColumn(schema.supplementsTracker, schema.supplementsTracker.lowersGlucose);
        await m.addColumn(schema.supplementsTracker, schema.supplementsTracker.notes);
        await customStatement(
          'UPDATE supplements_tracker SET schedule_json = '
          "'[' || target_time_of_day_minutes || ']' "
          'WHERE target_time_of_day_minutes IS NOT NULL;',
        );
        await m.addColumn(schema.supplementLogs, schema.supplementLogs.slotMinutes);

        await m.createTable(schema.careSessions);
        await m.createTable(schema.customHabits);
        await m.createTable(schema.habitLogs);
        await m.createTable(schema.checkups);
        await m.createTable(schema.checkupLogs);
        await m.createTable(schema.symptomLogs);
        await m.createTable(schema.vitalReadings);
        await m.createTable(schema.substanceLogs);
        await m.createTable(schema.wellbeingChecks);
        for (final Index index in <Index>[
          schema.idxCareSessionsDate,
          schema.idxHabitLogsUnique,
          schema.idxSymptomLogsDate,
          schema.idxVitalReadingsKind,
          schema.idxSubstanceLogsDate,
        ]) {
          await m.create(index);
        }
      },
    ),
  );

  /// Tabla virtual FTS5 sin diacríticos y triggers que la sincronizan con `food_items`.
  Future<void> _createFoodSearchIndex() async {
    await customStatement('''
      CREATE VIRTUAL TABLE food_items_fts USING fts5(
        name,
        brand,
        content='food_items',
        content_rowid='id',
        tokenize='unicode61 remove_diacritics 2'
      );
    ''');
    await customStatement('''
      CREATE TRIGGER food_items_ai AFTER INSERT ON food_items BEGIN
        INSERT INTO food_items_fts(rowid, name, brand) VALUES (new.id, new.name, new.brand);
      END;
    ''');
    await customStatement('''
      CREATE TRIGGER food_items_ad AFTER DELETE ON food_items BEGIN
        INSERT INTO food_items_fts(food_items_fts, rowid, name, brand) VALUES('delete', old.id, old.name, old.brand);
      END;
    ''');
    await customStatement('''
      CREATE TRIGGER food_items_au AFTER UPDATE ON food_items BEGIN
        INSERT INTO food_items_fts(food_items_fts, rowid, name, brand) VALUES('delete', old.id, old.name, old.brand);
        INSERT INTO food_items_fts(rowid, name, brand) VALUES (new.id, new.name, new.brand);
      END;
    ''');
  }

  /// Exporta una copia atómica e íntegra de la base de datos limpia mediante VACUUM INTO.
  ///
  /// Es inmune a transacciones concurrentes en modo WAL y no bloquea lecturas de la UI.
  Future<File> exportCleanDatabaseBackup(
    String targetDirectoryPath, {
    required DateTime stamp,
  }) async {
    final String dateStr = stamp.toIso8601String().split('T').first.replaceAll('-', '');
    final String backupPath = '$targetDirectoryPath/nb_selfcare_backup_$dateStr.sqlite';
    final File file = File(backupPath);
    if (file.existsSync()) {
      file.deleteSync();
    }

    await customStatement('VACUUM INTO ?', <Object>[backupPath]);
    return file;
  }

  /// Lee una preferencia local de interfaz persistida en SQLite (ej. layout de widgets en Hoy).
  Future<String?> readUiPreference(String key) async {
    final UiPreference? row = await (select(
      uiPreferences,
    )..where((UiPreferences t) => t.prefKey.equals(key))).getSingleOrNull();
    return row?.prefValue;
  }

  /// Persiste de forma atómica una preferencia local de interfaz en SQLite.
  Future<void> writeUiPreference(String key, String value) async {
    await into(uiPreferences)
        .insertOnConflictUpdate(UiPreferencesCompanion.insert(prefKey: key, prefValue: value));
  }
}

/// Provider global de Riverpod para inyectar la base de datos como singleton.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final AppDatabase db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
