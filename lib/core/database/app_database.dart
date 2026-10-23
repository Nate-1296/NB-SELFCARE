import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

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
}

/// Provider global de Riverpod para inyectar la base de datos como singleton.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final AppDatabase db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
