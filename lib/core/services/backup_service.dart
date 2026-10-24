import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqlite3/sqlite3.dart';

import '../database/app_database.dart';

/// Servicio de respaldo atómico y portabilidad total (.sqlite).
///
/// Implementa exportación en caliente sin bloqueos mediante SQLite `VACUUM INTO`
/// sobre directorio temporal seguro (`AGENTS.md` §1.4) e importación transaccional
/// en vivo con verificación previa de integridad estructural.
class BackupService {
  BackupService(this._db);

  final AppDatabase _db;

  static const List<String> _orderedTables = <String>[
    'user_profiles',
    'body_measurements',
    'daily_summaries',
    'hydration_logs',
    'food_items',
    'meal_combos',
    'meal_combo_items',
    'food_logs',
    'fasting_sessions',
    'workout_blocks',
    'journal_entries',
    'pet_status',
    'coin_ledger',
    'reminders',
    'tdee_calibrations',
    'health_sync_checkpoints',
  ];

  /// Exporta la base de datos a un archivo `.sqlite` limpio en el directorio temporal seguro.
  Future<File> exportDatabase() async {
    final Directory tempDir = await getTemporaryDirectory();
    final Directory backupDirectory = Directory('${tempDir.path}/nb_backups');
    if (!backupDirectory.existsSync()) {
      backupDirectory.createSync(recursive: true);
    }

    return _db.exportCleanDatabaseBackup(backupDirectory.path);
  }

  /// Exporta y comparte el archivo `.sqlite` mediante el diálogo nativo del sistema.
  Future<void> shareDatabaseBackup() async {
    final File backupFile = await exportDatabase();
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(backupFile.path)],
        subject: 'NB Selfcare - Respaldo SQLite',
      ),
    );
  }

  /// Verifica la integridad física y de esquema de un archivo SQLite externo antes de restaurarlo.
  Future<bool> verifyBackupIntegrity(String filePath) async {
    final File file = File(filePath);
    if (!file.existsSync() || file.lengthSync() < 4096) return false;

    Database? rawDb;
    try {
      rawDb = sqlite3.open(filePath, mode: OpenMode.readOnly);
      final ResultSet integrity = rawDb.select('PRAGMA integrity_check;');
      final bool isOk =
          integrity.isNotEmpty && integrity.first['integrity_check'] == 'ok';
      if (!isOk) return false;

      final ResultSet tables = rawDb.select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('user_profiles', 'food_items', 'pet_status');",
      );
      return tables.length == 3;
    } catch (_) {
      return false;
    } finally {
      rawDb?.close();
    }
  }

  /// Restaura de forma atómica y en caliente todas las tablas desde un respaldo `.sqlite` verificado,
  /// reconstruyendo el índice FTS5 y notificando inmediatamente a todos los streams de Drift.
  Future<bool> restoreDatabaseFromFile(String externalFilePath) async {
    final bool valid = await verifyBackupIntegrity(externalFilePath);
    if (!valid) return false;

    await _db.customStatement('PRAGMA foreign_keys = OFF;');
    await _db.customStatement(
      'ATTACH DATABASE ? AS ext_backup;',
      <Object>[externalFilePath],
    );

    try {
      await _db.transaction(() async {
        // Limpiar en orden inverso para respetar cualquier restricción activa
        for (final String table in _orderedTables.reversed) {
          await _db.customStatement('DELETE FROM main.$table;');
        }

        // Copiar tablas preservando claves primarias e historial
        for (final String table in _orderedTables) {
          await _db.customStatement(
            'INSERT INTO main.$table SELECT * FROM ext_backup.$table;',
          );
        }

        // Restaurar preferencias de diseño de UI si existen en el respaldo
        final uiPrefsRow = await _db.customSelect(
          "SELECT COUNT(*) AS cnt FROM ext_backup.sqlite_master WHERE type = 'table' AND name = 'ui_preferences'",
        ).getSingle();
        if (uiPrefsRow.read<int>('cnt') > 0) {
          await _db.customStatement('DELETE FROM main.ui_preferences;');
          await _db.customStatement(
            'INSERT INTO main.ui_preferences SELECT * FROM ext_backup.ui_preferences;',
          );
        }

        // Reconstruir índice virtual FTS5 de alimentos
        await _db.customStatement(
          "INSERT INTO food_items_fts(food_items_fts) VALUES('rebuild');",
        );
      });

      _db.markTablesUpdated(_db.allTables);
      return true;
    } catch (_) {
      return false;
    } finally {
      try {
        await _db.customStatement('DETACH DATABASE ext_backup;');
      } catch (_) {}
      await _db.customStatement('PRAGMA foreign_keys = ON;');
    }
  }

  /// Abre el selector de archivos del sistema y restaura un respaldo `.sqlite` seleccionado por el usuario.
  Future<({bool cancelled, bool restored})> importDatabaseFromPicker() async {
    final PlatformFile? picked = await FilePicker.pickFile(
      dialogTitle: 'Seleccionar respaldo .sqlite de NB Selfcare',
      type: FileType.any,
    );

    final String? path = picked?.path;
    if (path == null || path.isEmpty) {
      return (cancelled: true, restored: false);
    }

    final bool restored = await restoreDatabaseFromFile(path);
    return (cancelled: false, restored: restored);
  }
}

/// Provider de Riverpod para inyectar BackupService.
final backupServiceProvider = Provider<BackupService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return BackupService(db);
});
