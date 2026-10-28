import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/features/journal/application/journal_service.dart';

import '../support/test_container.dart';

void main() {
  test('dos entradas del diario el mismo día: ambas se guardan y solo la primera da monedas', () async {
    final AppDatabase db = AppDatabase(NativeDatabase.memory());
    await db.into(db.petStatus).insert(const PetStatusCompanion(coinsBalance: drift.Value(0)));
    final ProviderContainer c = createTestContainer(db);
    JournalEntriesCompanion entry(String text) => JournalEntriesCompanion.insert(
          dateKey: '2026-10-23',
          content: text,
        );
    final ({int entryId, int coins}) first = await c.read(journalServiceProvider).save(entry('Primera'));
    final ({int entryId, int coins}) second = await c.read(journalServiceProvider).save(entry('Segunda'));
    expect(first.coins, greaterThan(0));
    expect(second.coins, 0);
    expect((await db.select(db.journalEntries).get()).length, 2);
    final List<CoinLedgerData> ledger = await db.select(db.coinLedger).get();
    expect(ledger.where((CoinLedgerData l) => l.actionType == 'journal_entry').length, 1);
    c.dispose();
    await db.close();
  });
}
