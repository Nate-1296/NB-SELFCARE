import 'dart:async';
import 'dart:math';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/database/daos/pet_dao.dart';
import 'package:nb_selfcare/core/database/seeder/database_seeder.dart';
import 'package:nb_selfcare/core/domain/enums.dart';
import 'package:nb_selfcare/core/platform/health_connect_gateway.dart';
import 'package:nb_selfcare/core/services/calorie_cycling_service.dart';
import 'package:nb_selfcare/core/services/cross_analytics_engine.dart';
import 'package:nb_selfcare/core/services/readiness_engine.dart';
import 'package:nb_selfcare/features/body_metrics/application/weigh_in_service.dart';
import 'package:nb_selfcare/features/body_metrics/application/workout_service.dart';
import 'package:nb_selfcare/features/fasting/application/fasting_service.dart';
import 'package:nb_selfcare/features/journal/application/journal_service.dart';
import 'package:nb_selfcare/features/nutrition_hydration/application/food_logging_service.dart';
import 'package:nb_selfcare/features/nutrition_hydration/application/hydration_service.dart';
import 'package:nb_selfcare/features/nutrition_hydration/application/nutrition_day.dart';
import 'package:nb_selfcare/features/profile_goals/application/clinical_report_service.dart';
import 'package:nb_selfcare/features/profile_goals/application/onboarding_service.dart';
import 'package:nb_selfcare/features/profile_goals/application/profile_queries.dart';
import 'package:nb_selfcare/features/today/application/daily_activity_service.dart';
import 'package:nb_selfcare/features/today/application/health_sync_service.dart';
import 'package:nb_selfcare/features/today/application/readiness_queries.dart';
import 'package:nb_selfcare/features/today/application/today_overview.dart';
import 'package:nb_selfcare/features/today/application/weekly_review.dart';
import 'package:nb_selfcare/shared/utils/date_time_extensions.dart';

import '../support/fake_platform.dart';
import '../support/test_container.dart';

/// Simulación de 4 meses de uso real con un usuario imperfecto: días sin abrir
/// la app, ayunos olvidados, vasos borrados, pesajes con ruido, compras en la
/// tienda, Health Connect que a veces responde y a veces no. Cruza fin de año,
/// un 29 de febrero y (según la zona horaria) cambios de horario.
///
/// Tras cada día se comprueban invariantes de la economía, de la racha, del
/// ayuno y de los datos; y que las pantallas pueden componer sus resúmenes.
Future<T> _settle<T>(ProviderContainer c, ProviderListenable<AsyncValue<T>> provider) {
  final Completer<T> done = Completer<T>();
  late final ProviderSubscription<AsyncValue<T>> sub;
  sub = c.listen<AsyncValue<T>>(provider, (AsyncValue<T>? _, AsyncValue<T> next) {
    if (done.isCompleted) return;
    if (next.hasError) done.completeError(next.error!, next.stackTrace);
    if (next.hasValue && !next.isLoading) done.complete(next.requireValue);
  }, fireImmediately: true);
  return done.future.timeout(const Duration(seconds: 10)).whenComplete(sub.close);
}

void main() {
  for (final int seed in <int>[42, 1337, 2026]) {
    test('120 días de uso caótico mantienen la app coherente (semilla $seed)', () async {
      final AppDatabase db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await DatabaseSeeder.seedIfEmpty(db);

      final DateTime start = DateTime(2027, 12, 1, 7);
      final ProviderContainer first = createTestContainer(db, now: start);
      await first
          .read(onboardingServiceProvider)
          .complete(
            OnboardingAnswers(
              name: 'Simulación',
              birthDate: DateTime(1988, 2, 29),
              sex: BiologicalSex.female,
              heightCm: 168,
              currentWeightKg: 82,
              targetWeightKg: 68,
              weeklyGoalRateKg: -0.5,
              dailyWaterGoalMl: 2200,
              dailyStepsGoal: 9000,
              dailySleepGoalHours: 7.5,
              themeKey: 'salvia_lino',
            ),
          );
      first.dispose();

      final Random rng = Random(seed);
      final List<FoodItem> catalog = await db.select(db.foodItems).get();
      // Saldo de bienvenida (no pasa por el libro mayor) = saldo − movimientos ya anotados.
      final int initialCoins =
          (await PetDao(db).getPetStatus())!.coinsBalance -
          (await db.select(db.coinLedger).get()).fold(0, (int s, CoinLedgerData e) => s + e.amount);
      double trueWeight = 82;
      int? openFastId;
      int activeDays = 0;
      const int maxCoinsPerDay = 248; // 165 base × 1,5 de sueño, redondeado hacia arriba por acción

      for (int d = 0; d < 120; d++) {
        final DateTime day = start.addDays(d);
        final String key = day.dateKey;
        ProviderContainer at(int hour, [int minute = 0]) {
          final HealthConnectGateway hc = rng.nextDouble() < 0.2
              ? ThrowingHealthConnectGateway()
              : FakeHealthConnectGateway(
                  granted: rng.nextBool(),
                  snapshot: DailyActivitySnapshot(
                    steps: rng.nextInt(16000),
                    sleepMinutes: 300 + rng.nextInt(260),
                  ),
                );
          return createTestContainer(
            db,
            now: DateTime(day.year, day.month, day.day, hour, minute),
            healthConnect: hc,
          );
        }

        // Cerrar un ayuno que se quedó abierto (a veces días después).
        if (openFastId != null && rng.nextDouble() < 0.7) {
          final ProviderContainer c = at(8 + rng.nextInt(10));
          await c.read(fastingServiceProvider).finish(openFastId);
          openFastId = null;
          c.dispose();
        }

        final bool skipsDay = rng.nextDouble() < 0.15;
        if (!skipsDay) {
          activeDays++;
          final ProviderContainer morning = at(7, rng.nextInt(60));
          await morning.read(healthSyncServiceProvider).syncRecentDays();
          trueWeight += -0.07 + rng.nextDouble() * 0.1;
          if (rng.nextDouble() < 0.85) {
            await morning
                .read(weighInServiceProvider)
                .record(
                  weightKg: double.parse(
                    (trueWeight + rng.nextDouble() * 1.2 - 0.6).toStringAsFixed(1),
                  ),
                  impedanceOhms: rng.nextBool() ? 420 + rng.nextInt(160) : null,
                  source: MeasurementSource.miScale2Ble,
                );
          }
          if (rng.nextDouble() < 0.6) {
            await morning
                .read(dailyActivityServiceProvider)
                .saveManualEntry(
                  dateKey: key,
                  steps: rng.nextInt(20000),
                  sleepMinutes: 240 + rng.nextInt(330),
                );
          }
          morning.dispose();

          final ProviderContainer noon = at(13);
          for (final MealType meal in MealType.values) {
            final int items = rng.nextInt(3);
            for (int i = 0; i < items; i++) {
              await noon
                  .read(foodLoggingServiceProvider)
                  .logPortion(
                    food: catalog[rng.nextInt(catalog.length)],
                    grams: 20 + rng.nextInt(300).toDouble(),
                    mealType: meal,
                    dateKey: key,
                  );
            }
          }
          if (rng.nextDouble() < 0.1) {
            await noon.read(foodLoggingServiceProvider).repeatYesterday(toDateKey: key);
          }
          final int glasses = rng.nextInt(12);
          for (int i = 0; i < glasses; i++) {
            final WaterLogResult r = await noon
                .read(hydrationServiceProvider)
                .logGlass(dateKey: key, volumeMl: <int>[150, 250, 330, 500, 750][rng.nextInt(5)]);
            if (rng.nextDouble() < 0.1) {
              await noon.read(hydrationServiceProvider).deleteGlass(r.logId);
            }
          }
          if (rng.nextDouble() < 0.4) {
            await noon
                .read(workoutServiceProvider)
                .log(
                  category: WorkoutCategory.values[rng.nextInt(WorkoutCategory.values.length)],
                  intensity: RpeIntensity.values[rng.nextInt(RpeIntensity.values.length)],
                  durationMinutes: 5 + rng.nextInt(120),
                );
          }
          if (rng.nextDouble() < 0.3) {
            await noon
                .read(journalServiceProvider)
                .save(
                  JournalEntriesCompanion.insert(
                    dateKey: key,
                    content: 'Día $d',
                    moodScore: Value(1 + rng.nextInt(5)),
                  ),
                );
          }
          if (rng.nextDouble() < 0.1) {
            final int balance = (await PetDao(db).getPetStatus())!.coinsBalance;
            await PetDao(db).buyShopItem(itemId: 'item_$d', cost: rng.nextInt(120), dateKey: key);
            expect((await PetDao(db).getPetStatus())!.coinsBalance, lessThanOrEqualTo(balance));
          }
          noon.dispose();

          if (openFastId == null && rng.nextDouble() < 0.5) {
            final ProviderContainer night = at(20, rng.nextInt(60));
            openFastId = await night
                .read(fastingServiceProvider)
                .start(protocolName: '16:8', targetHours: 16);
            // Doble toque en "Empezar" no abre un segundo ayuno.
            expect(
              await night.read(fastingServiceProvider).start(protocolName: '16:8', targetHours: 16),
              openFastId,
            );
            night.dispose();
          }
        }

        // ---- Invariantes del día ----
        final PetStatusData pet = (await PetDao(db).getPetStatus())!;
        final List<CoinLedgerData> ledger = await db.select(db.coinLedger).get();
        final int ledgerSum = ledger.fold(0, (int s, CoinLedgerData e) => s + e.amount);
        expect(pet.coinsBalance, initialCoins + ledgerSum, reason: 'día $d: saldo = libro mayor');
        expect(pet.coinsBalance, greaterThanOrEqualTo(0), reason: 'día $d');
        final int earnedToday = ledger
            .where((CoinLedgerData e) => e.dateKey == key && e.amount > 0)
            .fold(0, (int s, CoinLedgerData e) => s + e.amount);
        expect(earnedToday, lessThanOrEqualTo(maxCoinsPerDay), reason: 'día $d');
        expect(pet.currentStreakDays, lessThanOrEqualTo(d + 1), reason: 'día $d');
        expect(pet.highestStreakDays, greaterThanOrEqualTo(pet.currentStreakDays));
        expect(pet.streakShieldsAvailable, greaterThanOrEqualTo(0));

        final List<FastingSession> open = await (db.select(
          db.fastingSessions,
        )..where((t) => t.actualEndedAt.isNull())).get();
        expect(open.length, lessThanOrEqualTo(1), reason: 'día $d: un solo ayuno en curso');

        for (final FastingSession s in await db.select(db.fastingSessions).get()) {
          if (s.actualEndedAt != null) expect(s.actualEndedAt!.isBefore(s.startedAt), isFalse);
        }

        final List<BodyMeasurement> weights = await db.select(db.bodyMeasurements).get();
        if (weights.isNotEmpty) {
          final double lo = weights.map((BodyMeasurement b) => b.weightKg).reduce(min);
          final double hi = weights.map((BodyMeasurement b) => b.weightKg).reduce(max);
          for (final BodyMeasurement b in weights) {
            expect(
              b.trendWeightKg,
              inInclusiveRange(lo - 0.01, hi + 0.01),
              reason: 'la tendencia no sale del rango real',
            );
          }
        }

        // Las pantallas pueden componer el día (cada 10 días para no alargar la prueba).
        if (d % 10 == 0 || d == 119) {
          final ProviderContainer ui = at(21);
          await _settle<UserProfile?>(ui, userProfileStreamProvider);
          final TodayOverview today = await _settle(ui, todayOverviewProvider(key));
          expect(today.totalWaterMl, greaterThanOrEqualTo(0));
          expect(
            today.targets.effectiveCalorieTargetKcal,
            inInclusiveRange(1000, 5000),
            reason: 'día $d',
          );
          final NutritionDay nutrition = await _settle(ui, nutritionDayProvider(key));
          expect(nutrition.totals.kcal.isFinite, isTrue);
          await _settle<WeeklyCalorieBank>(ui, weeklyCalorieBankProvider(key));
          await _settle<DailyReadinessResult?>(ui, readinessProvider(key));
          final WeeklyReview review = await ui.read(weeklyReviewReaderProvider).forWeekEnding(key);
          expect(review.toString(), isNotEmpty);
          ui.dispose();
        }
      }

      expect(activeDays, greaterThan(80));
      final ProviderContainer end = createTestContainer(db, now: start.addDays(120));
      addTearDown(end.dispose);
      await _settle<List<CrossCorrelationInsight>>(end, crossInsightsProvider);
      final List<DailySummary> summaries = await db.select(db.dailySummaries).get();
      final Set<String> keys = summaries.map((DailySummary s) => s.dateKey).toSet();
      expect(keys.length, summaries.length, reason: 'un resumen por día');
      expect(keys, contains('2028-02-29'));
      expect(end.read(clinicalReportServiceProvider), isNotNull);
    }, timeout: const Timeout(Duration(minutes: 5)));
  }
}
