import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/database/daos/user_profile_dao.dart';
import 'package:nb_selfcare/core/domain/enums.dart';
import 'package:nb_selfcare/features/fasting/application/fasting_service.dart';

import '../support/test_container.dart';

void main() {
  test('Eliminar un ayuno del historial se puede deshacer', () async {
    final AppDatabase db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await UserProfileDao(db).createProfile(
      UserProfilesCompanion.insert(
        name: 'Ana',
        birthDate: DateTime(1992, 3, 10),
        biologicalSex: BiologicalSex.female,
        heightCm: 165,
        targetWeightKg: 60,
      ),
    );
    await db.into(db.petStatus).insert(const PetStatusCompanion(coinsBalance: Value(0)));

    final ProviderContainer start = createTestContainer(db, now: DateTime(2026, 10, 25, 20));
    final int id = await start.read(fastingServiceProvider).start(protocolName: '16:8', targetHours: 16);
    start.dispose();
    final ProviderContainer c = createTestContainer(db, now: DateTime(2026, 10, 26, 12, 30));
    addTearDown(c.dispose);
    final FastingService service = c.read(fastingServiceProvider);
    await service.finish(id);

    final FastingSession finished = await db.select(db.fastingSessions).getSingle();
    await service.delete(id);
    expect(await db.select(db.fastingSessions).get(), isEmpty);

    await service.restore(finished);
    final FastingSession restored = await db.select(db.fastingSessions).getSingle();
    expect(restored.actualEndedAt, finished.actualEndedAt);
    expect(restored.isCompleted, isTrue);
  });
}
