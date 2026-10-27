import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/journal_dao.dart';
import '../../pet_gamification/application/reward_service.dart';
import '../../pet_gamification/domain/reward_policy.dart';

/// Casos de uso del diario privado (docs/09 §2).
class JournalService {
  JournalService(this._db, this._journalDao, this._rewards);

  final AppDatabase _db;
  final JournalDao _journalDao;
  final RewardService _rewards;

  /// Guarda la entrada y otorga las monedas del diario (una vez al día).
  Future<({int entryId, int coins})> save(JournalEntriesCompanion entry) {
    return _db.transaction(() async {
      final int id = await _journalDao.insertEntry(entry);
      final RewardGrant grant =
          await _rewards.grant(RewardAction.journalEntry, dateKey: entry.dateKey.value);
      return (entryId: id, coins: grant.coins);
    });
  }

  Future<void> delete(int entryId) => _journalDao.deleteEntry(entryId);

  Future<void> restore(JournalEntry entry) => _journalDao.restoreEntry(entry);
}

final journalServiceProvider = Provider<JournalService>((Ref ref) {
  return JournalService(
    ref.watch(appDatabaseProvider),
    ref.watch(journalDaoProvider),
    ref.watch(rewardServiceProvider),
  );
});
