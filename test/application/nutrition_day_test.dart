import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/database/daos/user_profile_dao.dart';
import 'package:nb_selfcare/core/database/seeder/database_seeder.dart';
import 'package:nb_selfcare/core/domain/enums.dart';
import 'package:nb_selfcare/core/services/calorie_cycling_service.dart';
import 'package:nb_selfcare/features/nutrition_hydration/application/food_logging_service.dart';
import 'package:nb_selfcare/features/nutrition_hydration/application/nutrition_day.dart';

import '../support/test_container.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await DatabaseSeeder.seedIfEmpty(db);
    await UserProfileDao(db).createProfile(
      UserProfilesCompanion.insert(
        name: 'Ana',
        birthDate: DateTime(1992, 3, 10),
        biologicalSex: BiologicalSex.female,
        heightCm: 165,
        targetWeightKg: 60,
      ),
    );
    await db.into(db.petStatus).insert(const PetStatusCompanion());
  });

  tearDown(() => db.close());

  Future<FoodItem> food(String name) async =>
      (await db.select(db.foodItems).get()).firstWhere((FoodItem f) => f.name.contains(name));

  Future<void> logOn(DateTime day, String name, double grams) async {
    final ProviderContainer c = createTestContainer(db, now: day);
    await c.read(foodLoggingServiceProvider).logPortion(
          food: await food(name),
          grams: grams,
          mealType: MealType.lunch,
          dateKey: '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
        );
    c.dispose();
  }

  Future<T> settle<T>(ProviderContainer c, ProviderListenable<AsyncValue<T>> provider) async {
    final ProviderSubscription<AsyncValue<T>> sub = c.listen(provider, (_, _) {});
    for (int i = 0; i < 20 && !sub.read().hasValue; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    final T value = sub.read().value as T;
    sub.close();
    return value;
  }

  test('Los alimentos sin grupo NOVA no cuentan como "comida real"', () async {
    await logOn(DateTime(2026, 10, 28, 13), 'Pechuga', 150);
    final ProviderContainer c = createTestContainer(db, now: DateTime(2026, 10, 28, 14));
    addTearDown(c.dispose);

    final NutritionDay day = await settle(c, nutritionDayProvider('2026-10-28'));
    expect(day.totals.kcal, greaterThan(0));
    expect(day.totals.classifiedKcal, 0);
    expect(day.totals.unclassifiedKcal, closeTo(day.totals.kcal, 0.01));
  });

  test('El balance semanal solo cuenta días cerrados con registros', () async {
    // Lunes y martes con comida; el miércoles (hoy) no entra al balance.
    await logOn(DateTime(2026, 10, 26, 13), 'Pechuga', 200);
    await logOn(DateTime(2026, 10, 27, 13), 'Arroz', 300);
    await logOn(DateTime(2026, 10, 28, 13), 'Arroz', 900);
    final ProviderContainer c = createTestContainer(db, now: DateTime(2026, 10, 28, 20));
    addTearDown(c.dispose);

    final WeeklyCalorieBank bank = await settle(c, weeklyCalorieBankProvider('2026-10-28'));
    expect(bank.daysLogged, 2);
    expect(bank.remainingDaysInWeek, 4);
    expect(bank.hasBankSavings, isTrue, reason: 'Dos comidas sueltas quedan muy por debajo de la meta');
    expect(bank.accumulatedConsumedKcal, lessThan(1000));
  });

  test('Sin días cerrados el balance arranca vacío en lugar de inventar ahorro', () async {
    await logOn(DateTime(2026, 10, 26, 13), 'Pechuga', 200);
    final ProviderContainer c = createTestContainer(db, now: DateTime(2026, 10, 26, 20));
    addTearDown(c.dispose);

    final WeeklyCalorieBank bank = await settle(c, weeklyCalorieBankProvider('2026-10-26'));
    expect(bank.daysLogged, 0);
    expect(bank.netBalanceKcal, 0);
  });
}
