import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/domain/enums.dart';
import 'package:nb_selfcare/core/platform/health_connect_gateway.dart';
import 'package:nb_selfcare/features/body_metrics/application/weigh_in_service.dart';
import 'package:nb_selfcare/features/fasting/application/fasting_service.dart';
import 'package:nb_selfcare/features/nutrition_hydration/application/hydration_service.dart';
import 'package:nb_selfcare/features/profile_goals/application/onboarding_service.dart';
import 'package:nb_selfcare/features/today/application/daily_activity_service.dart';
import 'package:nb_selfcare/features/today/application/health_sync_service.dart';

import '../support/fake_platform.dart';
import '../support/test_container.dart';

/// Casos raros de los casos de uso: valores extremos, servicios nativos caídos,
/// acciones repetidas y fechas límite. La regla: lo que el usuario registra se
/// guarda siempre en local y nunca queda un estado incoherente.
final DateTime _now = DateTime(2026, 10, 27, 9, 30);

Future<void> _onboard(AppDatabase db, {bool contraindication = false}) async {
  final ProviderContainer c = createTestContainer(db, now: _now.subtract(const Duration(days: 1)));
  await c
      .read(onboardingServiceProvider)
      .complete(
        OnboardingAnswers(
          name: 'Ana',
          birthDate: DateTime(1990, 2, 28),
          sex: BiologicalSex.female,
          heightCm: 165,
          currentWeightKg: 70,
          targetWeightKg: 62,
          weeklyGoalRateKg: -0.4,
          dailyWaterGoalMl: 2000,
          dailyStepsGoal: 8000,
          dailySleepGoalHours: 7.5,
          themeKey: 'samsung_dark',
          hasImpedanceContraindication: contraindication,
        ),
      );
  c.dispose();
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await _onboard(db);
  });

  tearDown(() => db.close());

  group('Pesaje', () {
    test('pesos e impedancias extremos dan métricas finitas y acotadas', () async {
      final ProviderContainer c = createTestContainer(db, now: _now);
      addTearDown(c.dispose);
      for (final (double kg, int? ohms) in <(double, int?)>[
        (2, 500),
        (30, 0),
        (70, 99),
        (70, 3001),
        (70, 65535),
        (180, 300),
        (349.9, 2999),
      ]) {
        final WeighInResult r = await c
            .read(weighInServiceProvider)
            .record(weightKg: kg, impedanceOhms: ohms, source: MeasurementSource.manual);
        final m = r.analysis.metrics;
        final List<double> values = <double>[
          r.analysis.bmi,
          r.analysis.trendWeightKg,
          m.bodyFatPercentage,
          m.muscleMassKg,
          m.waterPercentage,
          m.boneMassKg,
          m.proteinPercentage,
          m.basalMetabolicRateKcal.toDouble(),
        ];
        for (final double v in values) {
          expect(v.isFinite, isTrue, reason: '$kg kg / $ohms Ω → $values');
          expect(v, greaterThanOrEqualTo(0), reason: '$kg kg / $ohms Ω → $values');
        }
        expect(m.bodyFatPercentage, lessThanOrEqualTo(75), reason: '$kg kg');
        expect(m.waterPercentage, lessThanOrEqualTo(80), reason: '$kg kg');
        expect(
          m.muscleMassKg,
          lessThanOrEqualTo(kg),
          reason: 'el músculo no puede pesar más que la persona',
        );
        expect(m.boneMassKg, lessThan(kg), reason: '$kg kg');
      }
    });

    test('Health Connect caído: el pesaje se guarda y la cascada termina', () async {
      final ThrowingHealthConnectGateway hc = ThrowingHealthConnectGateway();
      final ProviderContainer c = createTestContainer(db, now: _now, healthConnect: hc);
      addTearDown(c.dispose);
      final WeighInResult r = await c
          .read(weighInServiceProvider)
          .record(weightKg: 69.4, impedanceOhms: 510, source: MeasurementSource.miScale2Ble);
      expect(hc.calls, greaterThan(0));
      final List<BodyMeasurement> rows = await db.select(db.bodyMeasurements).get();
      expect(rows.where((BodyMeasurement b) => b.id == r.measurementId), hasLength(1));
      expect(r.reward.granted, isTrue);
    });

    test('contraindicación de bioimpedancia: nunca se guarda impedancia', () async {
      final AppDatabase other = AppDatabase(NativeDatabase.memory());
      addTearDown(other.close);
      await _onboard(other, contraindication: true);
      final ProviderContainer c = createTestContainer(other, now: _now);
      addTearDown(c.dispose);
      final WeighInResult r = await c
          .read(weighInServiceProvider)
          .record(weightKg: 68, impedanceOhms: 480, source: MeasurementSource.miScale2Ble);
      expect(r.analysis.hasImpedance, isFalse);
      final BodyMeasurement row = await (other.select(
        other.bodyMeasurements,
      )..where((t) => t.id.equals(r.measurementId))).getSingle();
      expect(row.impedanceOhms, isNull);
    });

    test('dos pesajes el mismo minuto: ambos se guardan y la moneda se da una vez', () async {
      final ProviderContainer c = createTestContainer(db, now: _now);
      addTearDown(c.dispose);
      final WeighInResult a = await c
          .read(weighInServiceProvider)
          .record(weightKg: 69.8, impedanceOhms: null, source: MeasurementSource.manual);
      final WeighInResult b = await c
          .read(weighInServiceProvider)
          .record(weightKg: 69.6, impedanceOhms: null, source: MeasurementSource.manual);
      expect(a.reward.granted, isTrue);
      expect(b.reward.granted, isFalse);
      expect(b.analysis.trendWeightKg, lessThan(a.analysis.trendWeightKg));
    });
  });

  group('Ayuno', () {
    test('iniciar con uno ya activo no crea un segundo ayuno en curso', () async {
      final ProviderContainer c = createTestContainer(db, now: _now);
      addTearDown(c.dispose);
      final int first = await c
          .read(fastingServiceProvider)
          .start(protocolName: '16:8', targetHours: 16);
      final int second = await c
          .read(fastingServiceProvider)
          .start(protocolName: '18:6', targetHours: 18);
      final List<FastingSession> open = await (db.select(
        db.fastingSessions,
      )..where((t) => t.actualEndedAt.isNull())).get();
      expect(open, hasLength(1));
      expect(second, first, reason: 'se devuelve el ayuno que ya estaba en curso');
    });

    test('un inicio en el futuro (reloj o selector) se acota a ahora', () async {
      final ProviderContainer c = createTestContainer(db, now: _now);
      addTearDown(c.dispose);
      final int id = await c
          .read(fastingServiceProvider)
          .start(
            protocolName: '16:8',
            targetHours: 16,
            startedAt: _now.add(const Duration(hours: 3)),
          );
      final FastingSession s = await (db.select(
        db.fastingSessions,
      )..where((t) => t.id.equals(id))).getSingle();
      expect(s.startedAt.isAfter(_now), isFalse);
      expect(
        await c
            .read(fastingServiceProvider)
            .adjustStart(sessionId: id, newStartedAt: _now.add(const Duration(minutes: 5))),
        isFalse,
      );
    });

    test('terminar dos veces no cambia la hora de fin ni duplica monedas', () async {
      final FakeNotificationGateway notes = FakeNotificationGateway();
      final ProviderContainer start = createTestContainer(db, now: _now, notifications: notes);
      final int id = await start
          .read(fastingServiceProvider)
          .start(protocolName: '16:8', targetHours: 16);
      start.dispose();
      final ProviderContainer end = createTestContainer(
        db,
        now: _now.add(const Duration(hours: 17)),
        notifications: notes,
      );
      addTearDown(end.dispose);
      final FastFinishResult? first = await end.read(fastingServiceProvider).finish(id);
      expect(first!.coins, greaterThan(0));
      final ProviderContainer later = createTestContainer(
        db,
        now: _now.add(const Duration(hours: 30)),
        notifications: notes,
      );
      addTearDown(later.dispose);
      final FastFinishResult? again = await later.read(fastingServiceProvider).finish(id);
      expect(again, isNull);
      final FastingSession s = await (db.select(
        db.fastingSessions,
      )..where((t) => t.id.equals(id))).getSingle();
      expect(s.actualEndedAt, _now.add(const Duration(hours: 17)));
      expect(notes.fastingTimer, isNull);
    });

    test('terminar un ayuno que no existe (borrado en otra pantalla)', () async {
      final ProviderContainer c = createTestContainer(db, now: _now);
      addTearDown(c.dispose);
      expect(await c.read(fastingServiceProvider).finish(9999), isNull);
    });

    test('ayuno de 72 h que cruza el cambio de hora: duración y monedas correctas', () async {
      final ProviderContainer start = createTestContainer(db, now: DateTime(2026, 10, 24, 20));
      final int id = await start
          .read(fastingServiceProvider)
          .start(protocolName: 'Extendido', targetHours: 72);
      start.dispose();
      final ProviderContainer end = createTestContainer(db, now: DateTime(2026, 10, 27, 20));
      addTearDown(end.dispose);
      final FastFinishResult r = (await end.read(fastingServiceProvider).finish(id))!;
      expect(r.hours, closeTo(72, 1.01));
      expect(r.session.isCompleted, r.hours >= 72);
      expect(r.suggestsRefeedingGuide, isTrue);
    });

    test('notificaciones caídas: el ayuno empieza, se ajusta y termina igual', () async {
      final ThrowingNotificationGateway notes = ThrowingNotificationGateway();
      final ProviderContainer c = createTestContainer(db, now: _now, notifications: notes);
      addTearDown(c.dispose);
      final FastingService s = c.read(fastingServiceProvider);
      final int id = await s.start(protocolName: '16:8', targetHours: 16);
      expect(
        await s.adjustStart(sessionId: id, newStartedAt: _now.subtract(const Duration(hours: 1))),
        isTrue,
      );
      expect(await s.finish(id), isNotNull);
      expect(notes.calls, greaterThan(0));
    });
  });

  group('Agua y actividad', () {
    test('la meta de agua da monedas una sola vez aunque se sigan sumando vasos', () async {
      final ProviderContainer c = createTestContainer(db, now: _now);
      addTearDown(c.dispose);
      int coins = 0;
      for (int i = 0; i < 20; i++) {
        coins +=
            (await c.read(hydrationServiceProvider).logGlass(dateKey: '2026-10-27', volumeMl: 250))
                .coins;
      }
      expect(coins, greaterThan(0));
      expect(coins, lessThanOrEqualTo(23), reason: '15 × 1,5 como máximo');
    });

    test('volúmenes imposibles se rechazan sin tocar la base', () async {
      final ProviderContainer c = createTestContainer(db, now: _now);
      addTearDown(c.dispose);
      for (final int ml in <int>[0, -250, 100000]) {
        await expectLater(
          c.read(hydrationServiceProvider).logGlass(dateKey: '2026-10-27', volumeMl: ml),
          throwsArgumentError,
          reason: '$ml ml',
        );
      }
      expect(await db.select(db.hydrationLogs).get(), isEmpty);
    });

    test('Health Connect caído: el vaso se guarda y queda pendiente de sincronizar', () async {
      final ProviderContainer c = createTestContainer(
        db,
        now: _now,
        healthConnect: ThrowingHealthConnectGateway(),
      );
      addTearDown(c.dispose);
      final WaterLogResult r = await c
          .read(hydrationServiceProvider)
          .logGlass(dateKey: '2026-10-27', volumeMl: 300);
      expect(r.totalMl, 300);
      final HydrationLog row = (await db.select(db.hydrationLogs).get()).single;
      expect(row.syncedToHealthConnect, isFalse);
    });

    test('pasos y sueño manuales fuera de rango se acotan', () async {
      final ProviderContainer c = createTestContainer(db, now: _now);
      addTearDown(c.dispose);
      await c
          .read(dailyActivityServiceProvider)
          .saveManualEntry(dateKey: '2026-10-27', steps: -40, sleepMinutes: 3000);
      final DailySummary s = await (db.select(
        db.dailySummaries,
      )..where((t) => t.dateKey.equals('2026-10-27'))).getSingle();
      expect(s.stepsCount, 0);
      expect(s.sleepDurationMinutes, lessThanOrEqualTo(24 * 60));
    });

    test('sincronizar con Health Connect caído no rompe el arranque', () async {
      final ProviderContainer c = createTestContainer(
        db,
        now: _now,
        healthConnect: ThrowingHealthConnectGateway(),
      );
      addTearDown(c.dispose);
      expect(
        await c.read(healthSyncServiceProvider).syncRecentDays(),
        HealthSyncOutcome.notConnected,
      );
    });

    test('sincronizar varias veces (cada apertura de la app) guarda siempre lo leído', () async {
      for (int i = 0; i < 4; i++) {
        final ProviderContainer c = createTestContainer(
          db,
          now: _now.add(Duration(hours: i)),
          healthConnect: FakeHealthConnectGateway(
            snapshot: DailyActivitySnapshot(steps: 1000 * (i + 1), sleepMinutes: 420),
          ),
        );
        expect(await c.read(healthSyncServiceProvider).syncRecentDays(), HealthSyncOutcome.synced);
        c.dispose();
      }
      final DailySummary s = await (db.select(
        db.dailySummaries,
      )..where((t) => t.dateKey.equals('2026-10-27'))).getSingle();
      expect(s.stepsCount, 4000, reason: 'la cuarta lectura no debe perderse');
    });

    test('Health Connect con solo pasos no borra el sueño registrado a mano', () async {
      final ProviderContainer manual = createTestContainer(db, now: _now);
      await manual
          .read(dailyActivityServiceProvider)
          .saveManualEntry(dateKey: '2026-10-27', steps: 1000, sleepMinutes: 450);
      manual.dispose();
      final ProviderContainer c = createTestContainer(
        db,
        now: _now,
        healthConnect: FakeHealthConnectGateway(snapshot: const DailyActivitySnapshot(steps: 6400)),
      );
      addTearDown(c.dispose);
      await c.read(healthSyncServiceProvider).syncDay('2026-10-27');
      final DailySummary s = await (db.select(
        db.dailySummaries,
      )..where((t) => t.dateKey.equals('2026-10-27'))).getSingle();
      expect(s.stepsCount, 6400);
      expect(s.sleepDurationMinutes, 450);
    });
  });
}
