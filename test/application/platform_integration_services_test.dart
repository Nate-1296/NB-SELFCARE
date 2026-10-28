import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/database/daos/health_sync_dao.dart';
import 'package:nb_selfcare/core/database/daos/pet_dao.dart';
import 'package:nb_selfcare/core/database/daos/reminders_dao.dart';
import 'package:nb_selfcare/core/database/daos/user_profile_dao.dart';
import 'package:nb_selfcare/core/domain/enums.dart';
import 'package:nb_selfcare/core/platform/health_connect_gateway.dart';
import 'package:nb_selfcare/core/platform/notification_gateway.dart';
import 'package:nb_selfcare/core/services/fasting_dosage_advisor.dart';
import 'package:nb_selfcare/features/body_metrics/application/weigh_in_service.dart';
import 'package:nb_selfcare/features/fasting/application/fasting_service.dart';
import 'package:nb_selfcare/features/profile_goals/application/onboarding_service.dart';
import 'package:nb_selfcare/features/profile_goals/application/reminder_service.dart';
import 'package:nb_selfcare/features/today/application/health_sync_service.dart';

import '../support/fake_platform.dart';
import '../support/test_container.dart';

void main() {
  late AppDatabase db;
  final DateTime now = DateTime(2026, 10, 23, 8);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<void> createProfile({
    bool impedanceContraindication = false,
    bool edHistory = false,
    bool hypoglycemic = false,
    bool fastingEnabled = true,
  }) async {
    await UserProfileDao(db).createProfile(
      UserProfilesCompanion.insert(
        name: 'Ana',
        birthDate: DateTime(1992, 3, 10),
        biologicalSex: BiologicalSex.female,
        heightCm: 165,
        targetWeightKg: 60,
        // Perfil creado antes de los días que se sincronizan (los días previos
        // a la instalación no dan monedas).
        createdAt: Value(DateTime(2026, 10, 1)),
        hasImpedanceContraindication: Value(impedanceContraindication),
        hasEatingDisorderHistory: Value(edHistory),
        takesHypoglycemicMedication: Value(hypoglycemic),
        isFastingEnabled: Value(fastingEnabled),
      ),
    );
    await db.into(db.petStatus).insert(const PetStatusCompanion(coinsBalance: Value(0)));
  }

  group('HealthSyncService', () {
    test('Guarda sueño con fases, pasos y FC en reposo y premia el sueño reparador', () async {
      await createProfile();
      final FakeHealthConnectGateway hc = FakeHealthConnectGateway(
        snapshot: const DailyActivitySnapshot(
          steps: 8400,
          sleepMinutes: 455,
          deepSleepMinutes: 70,
          remSleepMinutes: 95,
          restingHeartRateBpm: 58,
        ),
      );
      final ProviderContainer c = createTestContainer(db, now: now, healthConnect: hc);
      addTearDown(c.dispose);

      final HealthSyncResult result = await c.read(healthSyncServiceProvider).syncDay('2026-10-23');
      expect(result.outcome, HealthSyncOutcome.synced);

      final DailySummary summary = (await HealthSyncDao(db).getSummaryForDate('2026-10-23'))!;
      expect(summary.stepsCount, 8400);
      expect(summary.sleepDeepMinutes, 70);
      expect(summary.sleepRemMinutes, 95);
      expect(summary.restingHeartRateBpm, 58);
      expect((await PetDao(db).getPetStatus())!.coinsBalance, 23);
    });

    test('Los datos sin permiso (null) no pisan lo registrado a mano', () async {
      await createProfile();
      await HealthSyncDao(db).upsertDailySummary(
        const DailySummariesCompanion(dateKey: Value('2026-10-23'), sleepDurationMinutes: Value(400)),
      );
      final ProviderContainer c = createTestContainer(
        db,
        now: now,
        healthConnect: FakeHealthConnectGateway(snapshot: const DailyActivitySnapshot(steps: 3000)),
      );
      addTearDown(c.dispose);

      await c.read(healthSyncServiceProvider).syncDay('2026-10-23');
      final DailySummary summary = (await HealthSyncDao(db).getSummaryForDate('2026-10-23'))!;
      expect(summary.stepsCount, 3000);
      expect(summary.sleepDurationMinutes, 400);
    });

    test('Sin Health Connect la app sigue funcionando (degradación elegante)', () async {
      await createProfile();
      final ProviderContainer c = createTestContainer(
        db,
        now: now,
        healthConnect: FakeHealthConnectGateway(status: HealthConnectAvailability.notInstalled),
      );
      addTearDown(c.dispose);
      expect(await c.read(healthSyncServiceProvider).syncRecentDays(), HealthSyncOutcome.notConnected);
    });
  });

  group('FastingService + notificaciones', () {
    test('Iniciar muestra el cronómetro y finalizar lo retira', () async {
      await createProfile();
      final FakeNotificationGateway notifications = FakeNotificationGateway();
      final ProviderContainer c = createTestContainer(db, now: now, notifications: notifications);
      addTearDown(c.dispose);
      final FastingService fasting = c.read(fastingServiceProvider);

      final int id = await fasting.start(protocolName: '16:8', targetHours: 16);
      expect(notifications.fastingTimer?.protocol, '16:8');
      expect(notifications.fastingTimer?.startedAt, now);

      await fasting.finish(id);
      expect(notifications.fastingTimer, isNull);
    });

    test('Con antecedentes de TCA se proponen ayunos de hasta 16 h', () async {
      await createProfile(edHistory: true);
      final ProviderContainer c = createTestContainer(db, now: now);
      addTearDown(c.dispose);
      final FastingSafetyVerdict verdict = await c.read(fastingServiceProvider).checkSafety(20);
      expect(verdict.isSafe, isFalse);
      expect(verdict.recommendedAlternativeHours, 16);
      expect((await c.read(fastingServiceProvider).checkSafety(16)).isSafe, isTrue);
    });

    test('Con medicación hipoglucemiante siempre se avisa antes de ayunar', () async {
      await createProfile(hypoglycemic: true);
      final ProviderContainer c = createTestContainer(db, now: now);
      addTearDown(c.dispose);
      expect((await c.read(fastingServiceProvider).checkSafety(14)).isSafe, isFalse);
    });
  });

  group('ReminderService', () {
    test('Programa los recordatorios activos con textos positivos', () async {
      await createProfile();
      final FakeNotificationGateway notifications = FakeNotificationGateway();
      final ProviderContainer c = createTestContainer(db, now: now, notifications: notifications);
      addTearDown(c.dispose);

      await c.read(reminderServiceProvider).seedDefaults();
      expect(notifications.reminders, hasLength(3), reason: 'El cierre de ventana viene desactivado');
      final ScheduledReminder water =
          notifications.reminders.firstWhere((ScheduledReminder r) => r.intervalMinutes != null);
      expect(water.title, 'Un vaso de agua');
      expect(water.daysMask, 127);
    });

    test('Sin módulo de ayuno no se programan los avisos de ventana', () async {
      await createProfile(fastingEnabled: false);
      final FakeNotificationGateway notifications = FakeNotificationGateway();
      final ProviderContainer c = createTestContainer(db, now: now, notifications: notifications);
      addTearDown(c.dispose);

      final ReminderService reminders = c.read(reminderServiceProvider);
      await reminders.seedDefaults();
      final Reminder fastingClose = (await db.select(db.reminders).get())
          .firstWhere((Reminder r) => r.reminderType == ReminderType.fastingClose);
      await reminders.setEnabled(fastingClose.id, true);

      expect(await RemindersDao(db).getEnabledReminders(), hasLength(4));
      expect(notifications.reminders, hasLength(3));
    });
  });

  group('Seguridad clínica', () {
    test('Con contraindicación de impedancia se guarda solo el peso', () async {
      await createProfile(impedanceContraindication: true);
      final ProviderContainer c = createTestContainer(db, now: now);
      addTearDown(c.dispose);

      final WeighInResult result = await c
          .read(weighInServiceProvider)
          .record(weightKg: 64, impedanceOhms: 510, source: MeasurementSource.miScale2Ble);
      expect(result.analysis.hasImpedance, isFalse);
      expect((await db.select(db.bodyMeasurements).getSingle()).impedanceOhms, isNull);
    });

    test('El onboarding usa el peso actual y lo registra como primer pesaje', () async {
      final ProviderContainer c = createTestContainer(db, now: now);
      addTearDown(c.dispose);
      await db.into(db.petStatus).insert(const PetStatusCompanion());
      final OnboardingService onboarding = c.read(onboardingServiceProvider);
      final OnboardingAnswers answers = OnboardingAnswers(
        name: 'Luis',
        birthDate: DateTime(1990, 1, 1),
        sex: BiologicalSex.male,
        heightCm: 178,
        currentWeightKg: 92,
        targetWeightKg: 78,
        weeklyGoalRateKg: -0.5,
        dailyWaterGoalMl: 2500,
        dailyStepsGoal: 8000,
        dailySleepGoalHours: 7.5,
        themeKey: 'samsung_dark',
        hasEatingDisorderHistory: true,
      );

      final int tdeeWithCurrent = onboarding.initialTdee(answers);
      await onboarding.complete(answers);

      final UserProfile profile = (await UserProfileDao(db).getProfile())!;
      expect(profile.currentAdaptiveTdeeKcal, tdeeWithCurrent);
      expect(profile.hasEatingDisorderHistory, isTrue);
      expect(profile.activeDietPhaseStartedAt, now);

      final BodyMeasurement first = await db.select(db.bodyMeasurements).getSingle();
      expect(first.weightKg, 92);
      expect(first.trendWeightKg, 92);
      expect(await RemindersDao(db).getEnabledReminders(), isNotEmpty);
    });
  });
}
