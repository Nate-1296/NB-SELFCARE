import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/journal_dao.dart';

/// Entradas recientes del diario (más nuevas primero).
final recentJournalEntriesProvider = StreamProvider<List<JournalEntry>>((Ref ref) {
  return ref.watch(journalDaoProvider).watchRecentEntries(limit: 30);
});
