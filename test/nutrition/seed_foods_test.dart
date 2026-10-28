import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/database/seeder/database_seeder.dart';
import 'package:nb_selfcare/core/database/seeder/seed_foods.dart';

void main() {
  test('la semilla no repite nombres y sus valores son coherentes', () {
    final Set<String> names = <String>{};
    for (final SeedFood f in seedFoods) {
      expect(names.add(f.name), isTrue, reason: 'repetido: ${f.name}');
      expect(f.servingGrams, greaterThan(0), reason: f.name);
      for (final double v in <double>[f.kcal, f.protein, f.carbs, f.fat, f.fiber, f.sugar, f.sodiumMg]) {
        expect(v, greaterThanOrEqualTo(0), reason: f.name);
      }
      expect(f.protein + f.carbs + f.fat, lessThanOrEqualTo(100.5), reason: f.name);
      expect(f.sugar, lessThanOrEqualTo(f.carbs + 0.1), reason: f.name);
      // Energía ≈ Atwater (4·P + 4·carbohidratos disponibles + 2·fibra + 9·G),
      // salvo bebidas con alcohol y verduras casi sin energía.
      final double atwater = 4 * f.protein + 4 * (f.carbs - f.fiber) + 2 * f.fiber + 9 * f.fat;
      if (f.kcal > 30 && !<String>['Cerveza', 'Vino tinto'].contains(f.name)) {
        expect((atwater - f.kcal).abs() / f.kcal, lessThan(0.2), reason: '${f.name}: $atwater vs ${f.kcal}');
      }
    }
    expect(seedFoods.length, greaterThan(120));
  });

  test('una instalación antigua recibe los alimentos nuevos una sola vez', () async {
    final AppDatabase db = AppDatabase(NativeDatabase.memory());
    await DatabaseSeeder.seedIfEmpty(db);
    final int first = (await db.select(db.foodItems).get()).length;
    await DatabaseSeeder.seedIfEmpty(db);
    final int second = (await db.select(db.foodItems).get()).length;
    expect(second, first);
    expect(first, greaterThan(140));
    await db.close();
  });
}
