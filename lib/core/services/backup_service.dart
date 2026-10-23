import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqlite3/sqlite3.dart';

import '../database/app_database.dart';

/// Servicio de respaldo atómico y portabilidad total (.sqlite).
///
/// Implementa exportación en caliente sin bloqueos mediante SQLite `VACUUM INTO`
/// e importación con verificación previa de integridad estructural.
class BackupService {
  BackupService(this._db);

  final AppDatabase _db;

  /// Exporta la base de datos a un archivo .sqlite autónomo en la carpeta de documentos.
  Future<File> exportDatabase() async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final backupDirectory = Directory('${directory.path}/backups');
    if (!backupDirectory.existsSync()) {
      backupDirectory.createSync(recursive: true);
    }

    return _db.exportCleanDatabaseBackup(backupDirectory.path);
  }

  /// Exporta y comparte el archivo .sqlite mediante el diálogo del sistema operativo.
  Future<void> shareDatabaseBackup() async {
    final File backupFile = await exportDatabase();
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(backupFile.path)],
        subject: 'NB Selfcare - Respaldo SQLite',
      ),
    );
  }

  /// Verifica la integridad de un archivo SQLite externo antes de importarlo.
  Future<bool> verifyBackupIntegrity(String filePath) async {
    final File file = File(filePath);
    if (!file.existsSync()) return false;

    try {
      final Database rawDb = sqlite3.open(filePath, mode: OpenMode.readOnly);
      final ResultSet result = rawDb.select('PRAGMA integrity_check;');
      final bool isOk =
          result.isNotEmpty && result.first['integrity_check'] == 'ok';
      rawDb.close();
      return isOk;
    } catch (_) {
      return false;
    }
  }
}

/// Provider de Riverpod para inyectar BackupService.
final backupServiceProvider = Provider<BackupService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return BackupService(db);
});
