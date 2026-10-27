// Arnés de capturas de pantalla para revisar la UI sin dispositivo.
//
//   flutter test tool/screenshots --update-goldens
//
// Genera PNG en tool/screenshots/goldens/ con datos realistas sembrados.
// Con --dart-define=FULL_PAGE=true captura la página completa (alto 3200).
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/app.dart';
import 'package:nb_selfcare/app/router/app_router.dart';
import 'package:nb_selfcare/core/clock/clock.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/database/daos/health_sync_dao.dart';
import 'package:nb_selfcare/core/database/seeder/database_seeder.dart';
import 'package:nb_selfcare/core/domain/enums.dart';
import 'package:nb_selfcare/features/body_metrics/application/weigh_in_service.dart';
import 'package:nb_selfcare/features/fasting/application/fasting_service.dart';
import 'package:nb_selfcare/features/journal/application/journal_service.dart';
import 'package:nb_selfcare/features/nutrition_hydration/application/food_logging_service.dart';
import 'package:nb_selfcare/features/nutrition_hydration/application/hydration_service.dart';
import 'package:nb_selfcare/features/profile_goals/application/onboarding_service.dart';
import 'package:nb_selfcare/shared/theme/theme_controller.dart';

final DateTime _now = DateTime(2026, 10, 26, 13, 30);

ProviderContainer _container(AppDatabase db, DateTime now) => ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(Clock.fixed(now)),
      ],
    );

Future<void> _seed(AppDatabase db, String themeKey) async {
  await DatabaseSeeder.seedIfEmpty(db);
  final DateTime start = _now.subtract(const Duration(days: 29));

  final ProviderContainer first = _container(db, DateTime(start.year, start.month, start.day, 7));
  await first.read(onboardingServiceProvider).complete(
        OnboardingAnswers(
          name: 'Nathan',
          birthDate: DateTime(1996, 5, 20),
          sex: BiologicalSex.male,
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

  // 29 pesajes con tendencia a la baja y ruido diario de agua.
  const List<double> noise = <double>[0.3, -0.2, 0.5, -0.4, 0.1, 0.6, -0.3, 0.2, -0.1, 0.4];
  for (int day = 1; day < 30; day++) {
    final DateTime morning = DateTime(start.year, start.month, start.day + day, 7, 10);
    final ProviderContainer c = _container(db, morning);
    await c.read(weighInServiceProvider).record(
          weightKg: double.parse((84.6 - day * 0.08 + noise[day % noise.length]).toStringAsFixed(1)),
          impedanceOhms: 480 + (day % 7) * 6,
          source: MeasurementSource.miScale2Ble,
        );
    await HealthSyncDao(db).upsertDailySummary(
      DailySummariesCompanion(
        dateKey: Value(
          '${morning.year}-${morning.month.toString().padLeft(2, '0')}-${morning.day.toString().padLeft(2, '0')}',
        ),
        stepsCount: Value(5200 + (day % 6) * 900),
        sleepDurationMinutes: Value(400 + (day % 5) * 20),
        sleepDeepMinutes: Value(55 + (day % 3) * 10),
        sleepRemMinutes: Value(70 + (day % 4) * 8),
        restingHeartRateBpm: Value(56 + day % 5),
      ),
    );
    c.dispose();
  }

  final ProviderContainer today = _container(db, _now);
  final List<FoodItem> catalog = await db.select(db.foodItems).get();
  FoodItem food(String name) => catalog.firstWhere((FoodItem f) => f.name.contains(name));
  final FoodLoggingService logging = today.read(foodLoggingServiceProvider);
  await logging.logPortion(food: food('Avena'), grams: 60, mealType: MealType.breakfast, dateKey: '2026-10-26');
  await logging.logPortion(food: food('Huevo'), grams: 120, mealType: MealType.breakfast, dateKey: '2026-10-26');
  await logging.logPortion(food: food('Pechuga'), grams: 180, mealType: MealType.lunch, dateKey: '2026-10-26');
  await logging.logPortion(food: food('Arroz'), grams: 150, mealType: MealType.lunch, dateKey: '2026-10-26');
  await logging.logPortion(food: food('Aguacate'), grams: 70, mealType: MealType.lunch, dateKey: '2026-10-26');
  for (int i = 0; i < 4; i++) {
    await today.read(hydrationServiceProvider).logGlass(dateKey: '2026-10-26', volumeMl: 250);
  }
  await today.read(fastingServiceProvider).start(
        protocolName: '16:8',
        targetHours: 16,
        startedAt: _now.subtract(const Duration(hours: 14, minutes: 20)),
      );
  await today.read(journalServiceProvider).save(
        JournalEntriesCompanion.insert(
          dateKey: '2026-10-26',
          content: 'Dormí bien y entrené fuerza por la mañana. Mucha energía.',
          moodScore: const Value(4),
          energyLevel: const Value(5),
          stressLevel: const Value(2),
        ),
      );
  today.dispose();
}

void main() {
  const bool fullPage = bool.fromEnvironment('FULL_PAGE');
  const Size phone = Size(393, fullPage ? 3200 : 873);

  for (final String themeKey in <String>['samsung_dark', 'nxtpaper_eink_light']) {
    for (final String route in <String>[
      '/hoy',
      '/comer',
      '/cuerpo',
      '/nibi',
      '/perfil',
      '/ayuno',
      '/ajustes',
      '/protocolo',
      '/onboarding',
    ]) {
      testWidgets('$themeKey $route', (WidgetTester tester) async {
        tester.view.physicalSize = phone * 2;
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);

        final AppDatabase db = AppDatabase(NativeDatabase.memory());
        await tester.runAsync(
          () => route == '/onboarding' ? DatabaseSeeder.seedIfEmpty(db) : _seed(db, themeKey),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              clockProvider.overrideWithValue(Clock.fixed(_now)),
            ],
            child: const NbSelfcareApp(),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        final ProviderContainer container =
            ProviderScope.containerOf(tester.element(find.byType(NbSelfcareApp)));
        await tester.runAsync(() => container.read(themeControllerProvider.notifier).selectTheme(themeKey));
        container.read(appRouterProvider).go(route);
        for (int i = 0; i < 8; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
          await tester.pump(const Duration(milliseconds: 250));
        }
        await tester.runAsync(() async {
          for (final Element e in find.byType(Image).evaluate()) {
            await precacheImage((e.widget as Image).image, e);
          }
        });
        await tester.pump(const Duration(milliseconds: 300));

        final String name = '${themeKey}_${route.substring(1)}${fullPage ? '_full' : ''}';
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(db.close);
      });
    }
  }
}

