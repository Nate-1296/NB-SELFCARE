import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/app.dart';
import 'package:nb_selfcare/app/router/app_router.dart';
import 'package:nb_selfcare/core/clock/clock.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/database/seeder/database_seeder.dart';
import 'package:nb_selfcare/core/domain/enums.dart';
import 'package:nb_selfcare/features/body_metrics/application/weigh_in_service.dart';
import 'package:nb_selfcare/features/fasting/application/fasting_service.dart';
import 'package:nb_selfcare/features/journal/application/journal_service.dart';
import 'package:nb_selfcare/features/nutrition_hydration/application/food_logging_service.dart';
import 'package:nb_selfcare/features/nutrition_hydration/application/hydration_service.dart';
import 'package:nb_selfcare/features/profile_goals/application/onboarding_service.dart';
import 'package:nb_selfcare/shared/theme/theme_controller.dart';

import 'test_container.dart';

/// Arnés de la app completa (router, tema, base de datos sembrada) para pruebas
/// de estrés de interfaz.
final DateTime harnessNow = DateTime(2026, 10, 26, 13, 30);

enum SeedProfile {
  /// Recién terminada la bienvenida: un único pesaje y nada más.
  fresh,

  /// Un mes de uso normal.
  typical,

  /// Volúmenes extremos y textos larguísimos.
  extreme,
}

Future<void> seedHarness(AppDatabase db, SeedProfile profile, String themeKey) async {
  await DatabaseSeeder.seedIfEmpty(db);
  final DateTime start = harnessNow.subtract(Duration(days: profile == SeedProfile.fresh ? 0 : 60));
  final ProviderContainer first = createTestContainer(db, now: start);
  await first
      .read(onboardingServiceProvider)
      .complete(
        OnboardingAnswers(
          name: profile == SeedProfile.extreme
              ? 'Maria de los Ángeles Fernández-Villavicencio de la Concepción Pérez'
              : 'Nathan',
          birthDate: DateTime(1996, 5, 20),
          sex: BiologicalSex.female,
          heightCm: 178,
          currentWeightKg: 84.6,
          targetWeightKg: 76,
          weeklyGoalRateKg: -0.5,
          dailyWaterGoalMl: 2500,
          dailyStepsGoal: 8000,
          dailySleepGoalHours: 7.5,
          themeKey: themeKey,
        ),
      );
  first.dispose();
  if (profile == SeedProfile.fresh) return;

  final int days = profile == SeedProfile.extreme ? 60 : 30;
  for (int d = days; d >= 1; d--) {
    final DateTime morning = DateTime(harnessNow.year, harnessNow.month, harnessNow.day - d, 7, 10);
    final ProviderContainer c = createTestContainer(db, now: morning);
    await c
        .read(weighInServiceProvider)
        .record(
          weightKg: 84.6 - (days - d) * 0.05 + (d % 3) * 0.3,
          impedanceOhms: 480 + d % 40,
          source: MeasurementSource.miScale2Ble,
        );
    c.dispose();
  }

  final ProviderContainer today = createTestContainer(db, now: harnessNow);
  final List<FoodItem> catalog = await db.select(db.foodItems).get();
  if (profile == SeedProfile.extreme) {
    final int longId = await db
        .into(db.foodItems)
        .insert(
          FoodItemsCompanion.insert(
            name:
                'Ensalada mediterránea de quinoa tricolor con aguacate, tomate cherry, '
                'aceitunas kalamata, queso feta desmenuzado y vinagreta de limón y menta',
            brand: const Value('Marca con un nombre comercial larguísimo S.A.S. de Colombia'),
            source: FoodSource.userCustom,
            kcalPer100g: 180,
            proteinPer100g: 6,
            carbsPer100g: 14,
            fatPer100g: 11,
          ),
        );
    final FoodItem longFood = await (db.select(
      db.foodItems,
    )..where((t) => t.id.equals(longId))).getSingle();
    for (int i = 0; i < 120; i++) {
      await today
          .read(foodLoggingServiceProvider)
          .logPortion(
            food: i % 5 == 0 ? longFood : catalog[i % catalog.length],
            grams: 50 + (i % 9) * 40,
            mealType: MealType.values[i % MealType.values.length],
            dateKey: '2026-10-26',
          );
    }
    for (int i = 0; i < 30; i++) {
      await today.read(hydrationServiceProvider).logGlass(dateKey: '2026-10-26', volumeMl: 250);
    }
    await today
        .read(journalServiceProvider)
        .save(
          JournalEntriesCompanion.insert(
            dateKey: '2026-10-26',
            content: List<String>.filled(80, 'Una reflexión muy larga sobre el día.').join(' '),
            moodScore: const Value(5),
          ),
        );
  } else {
    for (final (String name, double g, MealType m) in <(String, double, MealType)>[
      ('Avena', 60, MealType.breakfast),
      ('Huevo', 120, MealType.breakfast),
      ('Pechuga', 180, MealType.lunch),
      ('Arroz', 150, MealType.lunch),
    ]) {
      await today
          .read(foodLoggingServiceProvider)
          .logPortion(
            food: catalog.firstWhere((FoodItem f) => f.name.contains(name)),
            grams: g,
            mealType: m,
            dateKey: '2026-10-26',
          );
    }
    for (int i = 0; i < 4; i++) {
      await today.read(hydrationServiceProvider).logGlass(dateKey: '2026-10-26', volumeMl: 250);
    }
  }
  await today
      .read(fastingServiceProvider)
      .start(
        protocolName: '16:8',
        targetHours: 16,
        startedAt: harnessNow.subtract(const Duration(hours: 14, minutes: 20)),
      );
  today.dispose();
}

/// Monta la app completa en [route] y deja que carguen los datos.
Future<ProviderContainer> pumpHarness(
  WidgetTester tester, {
  required AppDatabase db,
  required String themeKey,
  required String route,
  Size size = const Size(393, 873),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(Clock.fixed(harnessNow)),
      ],
      child: const NbSelfcareApp(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
  final ProviderContainer container = ProviderScope.containerOf(
    tester.element(find.byType(NbSelfcareApp)),
  );
  await tester.runAsync(
    () => container.read(themeControllerProvider.notifier).selectTheme(themeKey),
  );
  container.read(appRouterProvider).go(route);
  await settleHarness(tester);
  return container;
}

/// Bombea fotogramas dejando correr el bucle real (consultas de Drift).
Future<void> settleHarness(WidgetTester tester, {int rounds = 6}) async {
  for (int i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> unmountHarness(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
  await tester.runAsync(db.close);
}

AppDatabase harnessDatabase() => AppDatabase(NativeDatabase.memory());
