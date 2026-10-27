import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/database/daos/pet_dao.dart';
import 'package:nb_selfcare/core/domain/streak_policy.dart';

void main() {
  group('StreakPolicy', () {
    StreakUpdate advance({
      required DateTime? lastActive,
      int streak = 5,
      int highest = 5,
      int shields = 0,
    }) {
      return StreakPolicy.onFirstHabitOfDay(
        day: DateTime(2026, 10, 20),
        lastActiveDay: lastActive,
        currentStreakDays: streak,
        highestStreakDays: highest,
        shieldsAvailable: shields,
      );
    }

    test('Día consecutivo: la racha avanza sin tocar escudos', () {
      final StreakUpdate u = advance(lastActive: DateTime(2026, 10, 19), shields: 2);
      expect(u.currentStreakDays, 6);
      expect(u.highestStreakDays, 6);
      expect(u.shieldsAvailable, 2);
      expect(u.shieldsConsumed, 0);
    });

    test('Cada día perdido consume exactamente un escudo', () {
      final StreakUpdate u = advance(lastActive: DateTime(2026, 10, 17), shields: 3);
      expect(u.currentStreakDays, 6);
      expect(u.shieldsConsumed, 2);
      expect(u.shieldsAvailable, 1);
    });

    test('Si los escudos no alcanzan, la racha reinicia y los escudos se conservan', () {
      final StreakUpdate u = advance(lastActive: DateTime(2026, 10, 10), shields: 1);
      expect(u.currentStreakDays, 1);
      expect(u.highestStreakDays, 5);
      expect(u.shieldsAvailable, 1);
      expect(u.shieldsConsumed, 0);
    });

    test('Sin historial previo la racha avanza desde su valor actual', () {
      expect(advance(lastActive: null, streak: 0, highest: 0).currentStreakDays, 1);
      expect(advance(lastActive: null, streak: 3, highest: 3).currentStreakDays, 4);
    });

    test('El cambio de horario de verano no inventa días perdidos', () {
      expect(StreakPolicy.missedDaysBetween(DateTime(2026, 3, 7), DateTime(2026, 3, 8)), 0);
      expect(StreakPolicy.missedDaysBetween(DateTime(2026, 10, 31), DateTime(2026, 11, 2)), 1);
    });
  });

  group('PetDao.recordReward aplica la política de racha', () {
    late AppDatabase db;
    late PetDao petDao;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      petDao = PetDao(db);
      await db.into(db.petStatus).insert(
            const PetStatusCompanion(
              currentStreakDays: drift.Value(0),
              streakShieldsAvailable: drift.Value(1),
            ),
          );
    });

    tearDown(() => db.close());

    Future<void> activeOn(String dateKey) => petDao.recordReward(
          dateKey: dateKey,
          ledgerKey: 'weigh_in',
          amount: 15,
        );

    test('Diez días perdidos con un solo escudo reinician la racha', () async {
      await activeOn('2026-10-01');
      await activeOn('2026-10-02');
      await activeOn('2026-10-13');

      final PetStatusData pet = (await petDao.getPetStatus())!;
      expect(pet.currentStreakDays, 1);
      expect(pet.highestStreakDays, 2);
      expect(pet.streakShieldsAvailable, 1);
    });

    test('Un día perdido con un escudo mantiene la racha', () async {
      await activeOn('2026-10-01');
      await activeOn('2026-10-02');
      await activeOn('2026-10-04');

      final PetStatusData pet = (await petDao.getPetStatus())!;
      expect(pet.currentStreakDays, 3);
      expect(pet.streakShieldsAvailable, 0);
    });
  });
}
