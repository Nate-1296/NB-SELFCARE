import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/database/daos/health_sync_dao.dart';
import 'package:nb_selfcare/core/database/daos/user_profile_dao.dart';
import 'package:nb_selfcare/core/domain/enums.dart';
import 'package:nb_selfcare/core/domain/metabolic_phase.dart';
import 'package:nb_selfcare/core/services/readiness_engine.dart';
import 'package:nb_selfcare/features/body_metrics/application/weigh_in_service.dart';
import 'package:nb_selfcare/features/journal/application/caffeine_queries.dart';
import 'package:nb_selfcare/features/today/application/readiness_queries.dart';
import 'package:nb_selfcare/features/today/application/weekly_review.dart';

import '../support/test_container.dart';

DailySummary _summary(String dateKey, {int sleep = 0, int deep = 0, int? rhr}) => DailySummary(
      dateKey: dateKey,
      stepsCount: 0,
      activeCaloriesFromSteps: 0,
      sleepDurationMinutes: sleep,
      sleepDeepMinutes: deep,
      sleepRemMinutes: 0,
      restingHeartRateBpm: rhr,
      waterConsumedMl: 0,
      calorieTargetKcal: 0,
      proteinTargetG: 0,
      carbsTargetG: 0,
      fatTargetG: 0,
    );

WorkoutBlock _workout(String dateKey, int minutes, RpeIntensity rpe) => WorkoutBlock(
      id: 0,
      dateKey: dateKey,
      performedAt: DateTime.parse(dateKey),
      category: WorkoutCategory.weights,
      durationMinutes: minutes,
      rpeIntensity: rpe,
      appliedMet: 5,
      userWeightAtTimeKg: 80,
      netCaloriesBurned: 200,
    );

void main() {
  final ReadinessEngine engine = ReadinessEngine();

  group('Disposición con datos reales', () {
    test('Sin sueño registrado no se inventa una puntuación', () {
      expect(
        evaluateReadiness(
          engine: engine,
          dateKey: '2026-10-26',
          targetSleepHours: 7.5,
          summaries: <DailySummary>[_summary('2026-10-26', rhr: 58)],
          workouts: const <WorkoutBlock>[],
        ),
        isNull,
      );
    });

    test('Usa el sueño, la FC frente a su línea base y la carga de 3 días', () {
      final List<DailySummary> summaries = <DailySummary>[
        for (int d = 12; d <= 25; d++) _summary('2026-10-$d', sleep: 450, rhr: 58),
        _summary('2026-10-26', sleep: 300, deep: 30, rhr: 66),
      ];
      final DailyReadinessResult tired = evaluateReadiness(
        engine: engine,
        dateKey: '2026-10-26',
        targetSleepHours: 7.5,
        summaries: summaries,
        workouts: <WorkoutBlock>[
          _workout('2026-10-24', 60, RpeIntensity.moderate),
          _workout('2026-10-25', 60, RpeIntensity.moderate),
          _workout('2026-10-20', 300, RpeIntensity.intense),
        ],
      )!;
      expect(tired.rhrSubScore, 14, reason: '+8 bpm sobre la media de 58');
      expect(tired.strainSubScore, 25, reason: '2 h a RPE 6 = 12; el bloque intenso del día 20 queda fuera de la ventana');
      expect(tired.category, ReadinessCategory.recoveryNeeded);

      final DailyReadinessResult rested = evaluateReadiness(
        engine: engine,
        dateKey: '2026-10-25',
        targetSleepHours: 7.5,
        summaries: summaries,
        workouts: const <WorkoutBlock>[],
      )!;
      expect(rested.category, ReadinessCategory.optimal);
    });

    test('Con menos de 3 lecturas previas de FC no se compara contra una línea base', () {
      final DailyReadinessResult result = evaluateReadiness(
        engine: engine,
        dateKey: '2026-10-26',
        targetSleepHours: 7.5,
        summaries: <DailySummary>[
          _summary('2026-10-25', sleep: 400, rhr: 50),
          _summary('2026-10-26', sleep: 450, rhr: 70),
        ],
        workouts: const <WorkoutBlock>[],
      )!;
      expect(result.rhrSubScore, 32);
    });

    test('El lector puntual del PDF lee la base de datos', () async {
      final AppDatabase db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final ProviderContainer c = createTestContainer(db, now: DateTime(2026, 10, 26, 9));
      addTearDown(c.dispose);
      await HealthSyncDao(db).upsertDailySummary(
        const DailySummariesCompanion(dateKey: Value('2026-10-26'), sleepDurationMinutes: Value(480)),
      );
      expect(await c.read(readinessReaderProvider).forDate('2026-10-26'), isNotNull);
      expect(await c.read(readinessReaderProvider).forDate('2026-10-25'), isNull);
    });
  });

  group('Cafeína', () {
    test('La hora límite respeta la preferencia del perfil', () async {
      final AppDatabase db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await UserProfileDao(db).createProfile(
        UserProfilesCompanion.insert(
          name: 'Ana',
          birthDate: DateTime(1992, 3, 10),
          biologicalSex: BiologicalSex.female,
          heightCm: 165,
          targetWeightKg: 60,
          caffeineBedtimeCutoffHours: const Value(6),
        ),
      );
      final ProviderContainer c = createTestContainer(db, now: DateTime(2026, 10, 26, 9));
      addTearDown(c.dispose);
      final ProviderSubscription<AsyncValue<CaffeineDay>> sub =
          c.listen(caffeineDayProvider('2026-10-26'), (_, _) {});
      addTearDown(sub.close);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await c.read(caffeineServiceProvider).log(dateKey: '2026-10-26', sourceName: 'Espresso', mg: 80);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final CaffeineDay day = sub.read().value!;
      expect(day.status.recommendedCutoffTime, DateTime(2026, 10, 26, 17));
      expect(day.logs, hasLength(1));
      expect(day.status.currentResidualMg, 80);
    });
  });

  group('Fases metabólicas del ayuno (docs/09)', () {
    test('Umbrales 4 · 12 · 18 · 24 h', () {
      expect(MetabolicPhase.forHours(0), MetabolicPhase.anabolic);
      expect(MetabolicPhase.forHours(3.9), MetabolicPhase.anabolic);
      expect(MetabolicPhase.forHours(4), MetabolicPhase.glycogenolysis);
      expect(MetabolicPhase.forHours(14.3), MetabolicPhase.fatBurning);
      expect(MetabolicPhase.forHours(18), MetabolicPhase.ketosis);
      expect(MetabolicPhase.forHours(16), isNot(MetabolicPhase.autophagy));
      expect(MetabolicPhase.forHours(30), MetabolicPhase.autophagy);
      expect(MetabolicPhase.autophagy.nextStartsAtHour, isNull);
      expect(MetabolicPhase.fatBurning.nextStartsAtHour, 18);
    });
  });

  group('Check-in dominical', () {
    test('Una semana bajando de peso muestra un delta negativo', () async {
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
      await db.into(db.petStatus).insert(const PetStatusCompanion());
      for (int d = 0; d < 7; d++) {
        final ProviderContainer day = createTestContainer(db, now: DateTime(2026, 10, 20 + d, 7));
        await day.read(weighInServiceProvider).record(
              weightKg: 70 - d * 0.3,
              impedanceOhms: null,
              source: MeasurementSource.manual,
            );
        day.dispose();
      }
      final ProviderContainer c = createTestContainer(db, now: DateTime(2026, 10, 26, 9));
      addTearDown(c.dispose);

      final WeeklyReview review = await c.read(weeklyReviewReaderProvider).forWeekEnding('2026-10-26');
      expect(review.trendWeightDeltaKg, lessThan(0));
      expect(review.workoutCount, 0);
      expect(review.averageSleepHours, 0);
    });
  });
}
