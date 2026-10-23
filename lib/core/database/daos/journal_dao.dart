import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_database.dart';
import 'pet_dao.dart';

/// DAO especializado en el diario privado y reflexiones personales.
class JournalDao {
  JournalDao(this._db, this._petDao);

  final AppDatabase _db;
  final PetDao _petDao;

  /// Emite en vivo las entradas del diario para una fecha específica.
  Stream<List<JournalEntry>> watchEntriesForDate(String dateKey) {
    return (_db.select(_db.journalEntries)
          ..where((tbl) => tbl.dateKey.equals(dateKey))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]))
        .watch();
  }

  /// Emite las entradas recientes para el feed del diario y correlaciones.
  Stream<List<JournalEntry>> watchRecentEntries({int limit = 30}) {
    return (_db.select(_db.journalEntries)
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)])
          ..limit(limit))
        .watch();
  }

  /// Guarda una nueva entrada en el diario y otorga +10 monedas en el libro mayor.
  Future<int> insertEntry(JournalEntriesCompanion companion) async {
    return _db.transaction(() async {
      final int id = await _db.into(_db.journalEntries).insert(companion);

      final String dateKey = companion.dateKey.value;
      await _petDao.grantDailyReward(
        dateKey: dateKey,
        actionType: 'journal_entry',
        baseAmount: 10,
      );

      return id;
    });
  }

  /// Elimina una entrada del diario por su ID.
  Future<int> deleteEntry(int id) {
    return (_db.delete(_db.journalEntries)..where((tbl) => tbl.id.equals(id))).go();
  }
}

/// Provider de Riverpod para inyectar JournalDao.
final journalDaoProvider = Provider<JournalDao>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  final PetDao petDao = ref.watch(petDaoProvider);
  return JournalDao(db, petDao);
});
