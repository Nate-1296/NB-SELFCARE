import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : _autoSeed = executor == null,
        super(executor ?? _openConnection());

  final bool _autoSeed;

  @override
  int get schemaVersion => 2;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'nb_selfcare',
      native: const DriftNativeOptions(
        shareAcrossIsolates: true,
      ),
    );
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (OpeningDetails details) async {
          await customStatement('PRAGMA foreign_keys = ON;');
          await customStatement('PRAGMA journal_mode = WAL;');
          await customStatement('''
            CREATE TABLE IF NOT EXISTS ui_preferences (
              pref_key TEXT PRIMARY KEY NOT NULL,
              pref_value TEXT NOT NULL
            );
          ''');
          if (_autoSeed) {
            await DatabaseSeeder.seedIfEmpty(this);
          }
        },
        onCreate: (Migrator m) async {
          await m.createAll();

          // Tabla virtual FTS5 para búsqueda insensible a acentos/tildes en alimentos
          await customStatement('''
            CREATE VIRTUAL TABLE food_items_fts USING fts5(
              name,
              brand,
              content='food_items',
              content_rowid='id',
              tokenize='unicode61 remove_diacritics 2'
            );
          ''');

          // Triggers de sincronización automática entre food_items y food_items_fts
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

          // Índices de alto rendimiento para joins y series temporales
          await customStatement(
            'CREATE INDEX idx_body_measurements_date ON body_measurements(date_key DESC, measured_at DESC);',
          );
          await customStatement(
            'CREATE INDEX idx_hydration_logs_date ON hydration_logs(date_key, logged_at);',
          );
          await customStatement(
            'CREATE INDEX idx_food_logs_date_meal ON food_logs(date_key, meal_type);',
          );
          await customStatement(
            'CREATE INDEX idx_workout_blocks_date ON workout_blocks(date_key);',
          );
          await customStatement(
            "CREATE UNIQUE INDEX idx_coin_ledger_daily_unique ON coin_ledger(date_key, action_type) WHERE action_type != 'shop_buy';",
          );
          await customStatement(
            'CREATE INDEX idx_recipes_name ON recipes(name);',
          );
          await customStatement(
            'CREATE INDEX idx_supplement_logs_date ON supplement_logs(date_key);',
          );
          await customStatement(
            'CREATE INDEX idx_digestive_logs_date ON digestive_logs(date_key);',
          );
          await customStatement(
            'CREATE INDEX idx_caffeine_logs_date ON caffeine_logs(date_key);',
          );
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            // 1. Nuevas columnas en UserProfiles
            await m.addColumn(userProfiles, userProfiles.isCycleTrackingEnabled);
            await m.addColumn(userProfiles, userProfiles.isFastingEnabled);
            await m.addColumn(userProfiles, userProfiles.isManualMacroMode);
            await m.addColumn(userProfiles, userProfiles.manualKcalTarget);
            await m.addColumn(userProfiles, userProfiles.manualProteinG);
            await m.addColumn(userProfiles, userProfiles.manualCarbsG);
            await m.addColumn(userProfiles, userProfiles.manualFatG);
            await m.addColumn(userProfiles, userProfiles.activeDietArchetype);
            await m.addColumn(userProfiles, userProfiles.activeDietPhase);
            await m.addColumn(userProfiles, userProfiles.calorieCyclingScheduleJson);
            await m.addColumn(userProfiles, userProfiles.caffeineBedtimeCutoffHours);

            // 2. Columna NOVA en FoodItems
            await m.addColumn(foodItems, foodItems.novaGroup);

            // 3. Crear las 7 tablas nuevas
            await m.createTable(recipes);
            await m.createTable(recipeIngredients);
            await m.createTable(supplementsTracker);
            await m.createTable(supplementLogs);
            await m.createTable(femaleCycleLogs);
            await m.createTable(digestiveLogs);
            await m.createTable(caffeineLogs);
            await m.createTable(protocolPlans);
            await m.createTable(milestoneGoals);

            // 4. Nuevos índices
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_recipes_name ON recipes(name);',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_supplement_logs_date ON supplement_logs(date_key);',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_digestive_logs_date ON digestive_logs(date_key);',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_caffeine_logs_date ON caffeine_logs(date_key);',
            );
          }
        },
      );

  /// Exporta una copia atómica e íntegra de la base de datos limpia mediante VACUUM INTO.
  ///
  /// Es inmune a transacciones concurrentes en modo WAL y no bloquea lecturas de la UI.
  Future<File> exportCleanDatabaseBackup(String targetDirectoryPath) async {
    final String dateStr =
        DateTime.now().toIso8601String().split('T').first.replaceAll('-', '');
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
    final rows = await customSelect(
      'SELECT pref_value FROM ui_preferences WHERE pref_key = ? LIMIT 1',
      variables: [Variable.withString(key)],
    ).get();
    if (rows.isEmpty) return null;
    return rows.first.read<String>('pref_value');
  }

  /// Persiste de forma atómica una preferencia local de interfaz en SQLite.
  Future<void> writeUiPreference(String key, String value) async {
    await customStatement(
      'INSERT INTO ui_preferences (pref_key, pref_value) VALUES (?, ?) '
      'ON CONFLICT(pref_key) DO UPDATE SET pref_value = excluded.pref_value;',
      <Object>[key, value],
    );
  }
}

/// Provider global de Riverpod para inyectar la base de datos como singleton.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final AppDatabase db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
