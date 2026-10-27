import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../clock/clock.dart';
import '../database/app_database.dart';

/// Resultado de inspeccionar un archivo `.sqlite` externo antes de restaurarlo.
class BackupInspection {
  const BackupInspection({required this.isValid, this.schemaVersion});

  const BackupInspection.invalid() : this(isValid: false);

  final bool isValid;

  /// `PRAGMA user_version` del respaldo (versión de esquema de Drift).
  final int? schemaVersion;
}

/// Servicio de respaldo atómico y portabilidad total (.sqlite).
///
/// Exporta en caliente con `VACUUM INTO` sobre un directorio temporal seguro
/// (`AGENTS.md` §1.4). Restaura todas las tablas del esquema actual: si el
/// respaldo es de una versión anterior, primero se migra una copia temporal con
/// la misma `MigrationStrategy` de la app y luego se copia columna a columna.
class BackupService {
  BackupService(
    this._db, {
    Future<Directory> Function()? temporaryDirectory,
    this._clock = const Clock(),
  })  : _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  final AppDatabase _db;
  final Clock _clock;
  final Future<Directory> Function() _temporaryDirectory;

  static const String _attachedAlias = 'ext_backup';

  /// Tablas que deben existir en cualquier respaldo legítimo de NB Selfcare.
  static const List<String> _requiredTables = <String>[
    'user_profiles',
    'food_items',
    'pet_status',
  ];

  /// Tablas de datos en orden compatible con las claves foráneas
  /// (el orden de declaración en `@DriftDatabase` respeta las dependencias).
  List<String> get _dataTables =>
      _db.allTables.map((TableInfo<Table, Object?> t) => t.actualTableName).toList();

  /// Exporta la base de datos a un archivo `.sqlite` limpio en el directorio temporal seguro.
  Future<File> exportDatabase() async {
    final Directory tempDir = await _temporaryDirectory();
    final Directory backupDirectory = Directory(p.join(tempDir.path, 'nb_backups'));
    if (!backupDirectory.existsSync()) {
      backupDirectory.createSync(recursive: true);
    }

    return _db.exportCleanDatabaseBackup(backupDirectory.path, stamp: _clock.now());
  }

  /// Exporta y comparte el archivo `.sqlite` mediante el diálogo nativo del sistema.
  Future<void> shareDatabaseBackup() async {
    final File backupFile = await exportDatabase();
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(backupFile.path)],
        subject: 'NB Selfcare - Respaldo SQLite',
      ),
    );
  }

  /// Verifica integridad física, tablas mínimas y versión de esquema compatible.
  BackupInspection inspectBackup(String filePath) {
    final File file = File(filePath);
    if (!file.existsSync() || file.lengthSync() < 4096) {
      return const BackupInspection.invalid();
    }

    sqlite.Database? rawDb;
    try {
      rawDb = sqlite.sqlite3.open(filePath, mode: sqlite.OpenMode.readOnly);
      final sqlite.ResultSet integrity = rawDb.select('PRAGMA integrity_check;');
      if (integrity.isEmpty || integrity.first['integrity_check'] != 'ok') {
        return const BackupInspection.invalid();
      }

      final sqlite.ResultSet tables = rawDb.select(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN "
        "(${_requiredTables.map((_) => '?').join(', ')});",
        _requiredTables,
      );
      if (tables.length != _requiredTables.length) {
        return const BackupInspection.invalid();
      }

      final int version = rawDb.select('PRAGMA user_version;').first.values.first as int;
      if (version < 1 || version > _db.schemaVersion) {
        return BackupInspection(isValid: false, schemaVersion: version);
      }
      return BackupInspection(isValid: true, schemaVersion: version);
    } on sqlite.SqliteException {
      return const BackupInspection.invalid();
    } finally {
      rawDb?.close();
    }
  }

  /// Atajo booleano de [inspectBackup].
  Future<bool> verifyBackupIntegrity(String filePath) async =>
      inspectBackup(filePath).isValid;

  /// Restaura de forma atómica todas las tablas desde un respaldo `.sqlite` verificado,
  /// reconstruye el índice FTS5 y notifica a todos los streams de Drift.
  Future<bool> restoreDatabaseFromFile(String externalFilePath) async {
    final BackupInspection inspection = inspectBackup(externalFilePath);
    if (!inspection.isValid) return false;

    final Directory stagingDir =
        (await _temporaryDirectory()).createTempSync('nb_restore_');
    final File staging = File(p.join(stagingDir.path, 'staging.sqlite'));

    try {
      await File(externalFilePath).copy(staging.path);
      if (inspection.schemaVersion! < _db.schemaVersion) {
        await _migrateStagingCopy(staging);
      }
      return await _copyFromStaging(staging.path);
    } on Exception {
      return false;
    } finally {
      if (stagingDir.existsSync()) {
        stagingDir.deleteSync(recursive: true);
      }
    }
  }

  /// Abre la copia temporal con la estrategia de migración de la app para llevarla
  /// al esquema actual sin tocar el archivo original del usuario.
  Future<void> _migrateStagingCopy(File staging) async {
    final AppDatabase legacy = AppDatabase(NativeDatabase(staging));
    try {
      await legacy.customSelect('SELECT 1').get();
      await legacy.customStatement('PRAGMA wal_checkpoint(TRUNCATE);');
    } finally {
      await legacy.close();
    }
  }

  Future<bool> _copyFromStaging(String stagingPath) async {
    await _db.customStatement('PRAGMA foreign_keys = OFF;');
    await _db.customStatement('ATTACH DATABASE ? AS $_attachedAlias;', <Object>[stagingPath]);

    try {
      await _db.transaction(() async {
        final List<String> tables = _dataTables;
        for (final String table in tables.reversed) {
          await _db.customStatement('DELETE FROM main."$table";');
        }

        for (final String table in tables) {
          final List<String> columns = await _sharedColumns(table);
          if (columns.isEmpty) continue;
          final String columnList = columns.map((String c) => '"$c"').join(', ');
          await _db.customStatement(
            'INSERT INTO main."$table" ($columnList) '
            'SELECT $columnList FROM $_attachedAlias."$table";',
          );
        }

        if (await _attachedTableExists('ui_preferences')) {
          await _db.customStatement('DELETE FROM main.ui_preferences;');
          await _db.customStatement(
            'INSERT INTO main.ui_preferences (pref_key, pref_value) '
            'SELECT pref_key, pref_value FROM $_attachedAlias.ui_preferences;',
          );
        }

        await _db.customStatement(
          "INSERT INTO food_items_fts(food_items_fts) VALUES('rebuild');",
        );
      });

      _db.markTablesUpdated(_db.allTables);
      return true;
    } finally {
      await _db.customStatement('DETACH DATABASE $_attachedAlias;');
      await _db.customStatement('PRAGMA foreign_keys = ON;');
    }
  }

  Future<bool> _attachedTableExists(String table) async {
    final QueryRow row = await _db.customSelect(
      'SELECT COUNT(*) AS cnt FROM $_attachedAlias.sqlite_master '
      "WHERE type = 'table' AND name = ?",
      variables: <Variable<Object>>[Variable.withString(table)],
    ).getSingle();
    return row.read<int>('cnt') > 0;
  }

  /// Columnas presentes tanto en la tabla local como en la del respaldo.
  Future<List<String>> _sharedColumns(String table) async {
    Future<List<String>> columnsOf(String schema) async {
      final List<QueryRow> rows = await _db
          .customSelect('SELECT name FROM pragma_table_info(?, ?)',
              variables: <Variable<Object>>[
                Variable.withString(table),
                Variable.withString(schema),
              ])
          .get();
      return rows.map((QueryRow r) => r.read<String>('name')).toList();
    }

    final Set<String> backupColumns = (await columnsOf(_attachedAlias)).toSet();
    return (await columnsOf('main')).where(backupColumns.contains).toList();
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
final backupServiceProvider = Provider<BackupService>((Ref ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return BackupService(db, clock: ref.watch(clockProvider));
});
