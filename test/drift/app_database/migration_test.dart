import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/domain/enums.dart';

import 'generated/schema.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('Cada versión migra a todas las posteriores con el esquema esperado', () {
    const List<int> versions = GeneratedHelper.versions;
    for (final (int i, int fromVersion) in versions.indexed) {
      for (final int toVersion in versions.skip(i + 1)) {
        test('v$fromVersion → v$toVersion', () async {
          final InitializedSchema schema = await verifier.schemaAt(fromVersion);
          final AppDatabase db = AppDatabase(schema.newConnection());
          await verifier.migrateAndValidate(db, toVersion);
          await db.close();
        });
      }
    }
  });

  test('v1 → actual conserva perfil, pesajes y comidas con sus enums', () async {
    final InitializedSchema schema = await verifier.schemaAt(1);
    schema.rawDatabase
      ..execute(
        'INSERT INTO user_profiles (name, birth_date, biological_sex, height_cm, target_weight_kg, '
        'weekly_goal_rate_kg, daily_water_goal_ml, daily_steps_goal, daily_sleep_goal_hours, '
        'current_adaptive_tdee_kcal, theme_mode, is_local_ai_enabled, created_at) VALUES '
        "('Ana', '1990-05-01T00:00:00.000', 'female', 165, 60, -0.5, 2500, 8000, 7.5, 1900, "
        "'material_you', 0, '2026-01-01T00:00:00.000')",
      )
      ..execute(
        'INSERT INTO body_measurements (measured_at, date_key, source, weight_kg, trend_weight_kg, '
        'bmi, is_water_retention_spike) VALUES '
        "('2026-01-02T07:00:00.000', '2026-01-02', 'mi_scale_2_ble', 64.2, 64.0, 23.6, 0)",
      )
      ..execute(
        'INSERT INTO food_items (name, source, default_serving_grams, serving_label, kcal_per100g, '
        'protein_per100g, carbs_per100g, fat_per100g, fiber_per100g, sugar_per100g, '
        'sodium_mg_per100g, potassium_mg_per100g, magnesium_mg_per100g, calcium_mg_per100g, '
        'iron_mg_per100g, zinc_mg_per100g, vitamin_c_mg_per100g, vitamin_d_ug_per100g, '
        'vitamin_b12_ug_per100g, is_favorite) VALUES '
        "('Avena', 'usda_seed', 40, '40g', 389, 16.9, 66.3, 6.9, 10.6, 1, 2, 429, 177, 54, "
        '4.7, 4, 0, 0, 0, 0)',
      )
      ..execute(
        'INSERT INTO food_logs (date_key, logged_at, meal_type, food_item_id, grams_consumed, '
        'portion_multiplier, total_kcal, total_protein_g, total_carbs_g, total_fat_g, '
        'total_fiber_g, total_sodium_mg, total_potassium_mg, total_magnesium_mg) VALUES '
        "('2026-01-02', '2026-01-02T08:00:00.000', 'breakfast', 1, 40, 1, 155.6, 6.8, 26.5, "
        '2.8, 4.2, 0.8, 171.6, 70.8)',
      );

    final AppDatabase db = AppDatabase(schema.newConnection());
    addTearDown(db.close);

    final UserProfile profile = await db.select(db.userProfiles).getSingle();
    expect(profile.biologicalSex, BiologicalSex.female);
    expect(profile.activeDietPhase, DietPhase.deficit, reason: 'Valor por defecto de v2');
    expect(profile.isFastingEnabled, isTrue);

    final BodyMeasurement weighIn = await db.select(db.bodyMeasurements).getSingle();
    expect(weighIn.source, MeasurementSource.miScale2Ble);
    expect(weighIn.weightKg, 64.2);

    final FoodLog log = await db.select(db.foodLogs).getSingle();
    expect(log.mealType, MealType.breakfast);

    final FoodItem food = await db.select(db.foodItems).getSingle();
    expect(food.source, FoodSource.usdaSeed);
  });

  test('v2 → v3 conserva la tabla ui_preferences creada fuera del esquema', () async {
    final InitializedSchema schema = await verifier.schemaAt(2);
    schema.rawDatabase
      ..execute(
        'CREATE TABLE ui_preferences (pref_key TEXT PRIMARY KEY NOT NULL, pref_value TEXT NOT NULL)',
      )
      ..execute("INSERT INTO ui_preferences VALUES ('hoy_layout', '[\"rings\",\"water\"]')");

    final AppDatabase db = AppDatabase(schema.newConnection());
    addTearDown(db.close);

    expect(await db.readUiPreference('hoy_layout'), '["rings","water"]');
    await db.writeUiPreference('hoy_layout', '["water"]');
    expect(await db.readUiPreference('hoy_layout'), '["water"]');
  });

  test('Un valor de enum desconocido en la base no rompe la lectura', () async {
    final InitializedSchema schema = await verifier.schemaAt(3);
    schema.rawDatabase.execute(
      'INSERT INTO body_measurements (measured_at, date_key, source, weight_kg, trend_weight_kg, '
      'bmi, is_water_retention_spike) VALUES '
      "('2026-01-02T07:00:00.000', '2026-01-02', 'origen_desconocido', 70, 70, 22, 0)",
    );

    final AppDatabase db = AppDatabase(schema.newConnection());
    addTearDown(db.close);

    final BodyMeasurement row = await db.select(db.bodyMeasurements).getSingle();
    expect(row.source, MeasurementSource.manual);
  });
}
