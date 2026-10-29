import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/database/daos/care_dao.dart';
import 'package:nb_selfcare/core/database/daos/pet_dao.dart';
import 'package:nb_selfcare/core/database/daos/user_profile_dao.dart';
import 'package:nb_selfcare/core/domain/care_enums.dart';
import 'package:nb_selfcare/core/domain/enums.dart';
import 'package:nb_selfcare/core/platform/health_connect_gateway.dart';
import 'package:nb_selfcare/core/platform/notification_gateway.dart';
import 'package:nb_selfcare/features/care/application/care_preferences_service.dart';
import 'package:nb_selfcare/features/care/application/care_session_service.dart';
import 'package:nb_selfcare/features/care/application/checkup_service.dart';
import 'package:nb_selfcare/features/care/application/habit_service.dart';
import 'package:nb_selfcare/features/care/application/health_log_services.dart';
import 'package:nb_selfcare/features/care/application/treatment_service.dart';
import 'package:nb_selfcare/features/care/domain/substance_catalog.dart';
import 'package:nb_selfcare/features/fasting/application/fasting_service.dart';
import 'package:nb_selfcare/features/pet_gamification/application/reward_service.dart';
import 'package:nb_selfcare/features/profile_goals/application/reminder_service.dart';

import '../support/fake_platform.dart';
import '../support/test_container.dart';

void main() {
  late AppDatabase db;
  final DateTime now = DateTime(2026, 10, 28, 9);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await UserProfileDao(db).createProfile(
      UserProfilesCompanion.insert(
        name: 'Ana',
        birthDate: DateTime(1974, 3, 10),
        biologicalSex: BiologicalSex.female,
        heightCm: 165,
        targetWeightKg: 60,
      ),
    );
    await db.into(db.petStatus).insert(const PetStatusCompanion(coinsBalance: Value(0)));
  });

  tearDown(() => db.close());

  Future<int> coins() async => (await PetDao(db).getPetStatus())!.coinsBalance;

  group('Tratamientos', () {
    test('marcar una toma descuenta la reserva y desmarcarla la devuelve', () async {
      final ProviderContainer c = createTestContainer(db, now: now);
      addTearDown(c.dispose);
      final TreatmentService service = c.read(treatmentServiceProvider);
      final int id = (await service.save(
        const TreatmentDraft(
          name: 'Losartán',
          dosage: '50 mg',
          kind: TreatmentKind.medication,
          times: <int>[480, 1200],
          stockUnits: 10,
        ),
      ))!;
      await service.markDose(dateKey: '2026-10-28', treatmentId: id, slotMinutes: 480, taken: true);
      await service.markDose(dateKey: '2026-10-28', treatmentId: id, slotMinutes: 480, taken: true);
      Future<double?> stock() async =>
          (await (db.select(db.supplementsTracker)..where((t) => t.id.equals(id))).getSingle()).stockUnits;
      expect(await stock(), 9, reason: 'Marcar dos veces la misma toma descuenta una sola vez');

      await service.markDose(dateKey: '2026-10-28', treatmentId: id, slotMinutes: 1200, taken: false);
      expect(await stock(), 9, reason: 'Omitir no gasta reserva');

      await service.clearDose(dateKey: '2026-10-28', treatmentId: id, slotMinutes: 480);
      expect(await stock(), 10);
      expect(await coins(), 0, reason: 'Los medicamentos no dan monedas');
    });

    test('los avisos de tomas son discretos y llevan "Hecho"', () async {
      final FakeNotificationGateway notifications = FakeNotificationGateway();
      final ProviderContainer c = createTestContainer(db, now: now, notifications: notifications);
      addTearDown(c.dispose);
      final int id = (await c.read(treatmentServiceProvider).save(
        const TreatmentDraft(
          name: 'Sertralina',
          dosage: '50 mg',
          kind: TreatmentKind.medication,
          times: <int>[540],
          remindersEnabled: true,
        ),
      ))!;
      final ScheduledReminder dose = notifications.reminders.singleWhere(
        (ScheduledReminder r) => r.id >= ReminderService.treatmentIdBase,
      );
      expect(dose.title, isNot(contains('Sertralina')));
      expect(dose.body, isNot(contains('Sertralina')));
      expect(dose.actionKey, ReminderService.doseActionKey(id, 540));
      expect(dose.minutesOfDay, 540);

      await c.read(carePreferencesServiceProvider).setDiscreetNotifications(false);
      expect(
        notifications.reminders.singleWhere((ScheduledReminder r) => r.id >= ReminderService.treatmentIdBase).body,
        contains('Sertralina'),
      );

      await c.read(carePreferencesServiceProvider).setCareModule(CareModule.treatments, enabled: false);
      expect(notifications.reminders.where((ScheduledReminder r) => r.id >= ReminderService.treatmentIdBase), isEmpty);
    });

    test('"Hecho" pulsado con la app cerrada se aplica al abrirla', () async {
      final FakeNotificationGateway notifications = FakeNotificationGateway();
      final ProviderContainer c = createTestContainer(db, now: now, notifications: notifications);
      addTearDown(c.dispose);
      final TreatmentService service = c.read(treatmentServiceProvider);
      final int id = (await service.save(
        const TreatmentDraft(name: 'Vitamina D', dosage: '', kind: TreatmentKind.supplement, times: <int>[480]),
      ))!;
      notifications.pendingActions = <ReminderActionEvent>[
        ReminderActionEvent(key: ReminderService.doseActionKey(id, 480), at: DateTime(2026, 10, 28, 8, 2)),
        ReminderActionEvent(key: 'basura', at: DateTime(2026, 10, 28, 8, 3)),
      ];
      expect(await service.applyNotificationActions(), 1);
      final SupplementLog log = await db.select(db.supplementLogs).getSingle();
      expect(log.wasTaken, isTrue);
      expect(log.slotMinutes, 480);
      expect(log.dateKey, '2026-10-28');
      expect(await service.applyNotificationActions(), 0, reason: 'Se consumen una sola vez');
    });

    test('un tratamiento que baja la glucosa activa el aviso de ayuno', () async {
      final ProviderContainer c = createTestContainer(db, now: now);
      addTearDown(c.dispose);
      expect((await c.read(fastingServiceProvider).checkSafety(16)).isSafe, isTrue);
      await c.read(treatmentServiceProvider).save(
            const TreatmentDraft(
              name: 'Glibenclamida',
              dosage: '5 mg',
              kind: TreatmentKind.medication,
              lowersGlucose: true,
            ),
          );
      expect((await c.read(fastingServiceProvider).checkSafety(16)).isSafe, isFalse);
    });

    test('borrar y deshacer conserva el tratamiento', () async {
      final ProviderContainer c = createTestContainer(db, now: now);
      addTearDown(c.dispose);
      final TreatmentService service = c.read(treatmentServiceProvider);
      final int id = (await service.save(
        const TreatmentDraft(name: 'Omega 3', dosage: '1 g', kind: TreatmentKind.supplement),
      ))!;
      final SupplementsTrackerData row = await db.select(db.supplementsTracker).getSingle();
      await service.remove(id);
      expect(await db.select(db.supplementsTracker).get(), isEmpty);
      await service.restore(row);
      expect((await db.select(db.supplementsTracker).getSingle()).name, 'Omega 3');
      expect(await service.save(const TreatmentDraft(name: '  ', dosage: '', kind: TreatmentKind.supplement)), isNull);
    });
  });

  group('Sesiones guiadas', () {
    test('suelo pélvico da monedas una vez al día; una sesión cortada no cuenta', () async {
      final ProviderContainer c = createTestContainer(db, now: now);
      addTearDown(c.dispose);
      final CareSessionService service = c.read(careSessionServiceProvider);
      final RewardGrant tooShort =
          await service.complete(kind: CareSessionKind.pelvicFloor, variant: 'level_1', durationSeconds: 5);
      expect(tooShort.granted, isFalse);
      expect(await db.select(db.careSessions).get(), isEmpty);

      expect(
        (await service.complete(kind: CareSessionKind.pelvicFloor, variant: 'level_1', durationSeconds: 120)).coins,
        10,
      );
      expect(
        (await service.complete(kind: CareSessionKind.pelvicFloor, variant: 'level_1', durationSeconds: 120)).granted,
        isFalse,
      );
      expect((await db.select(db.careSessions).get()).length, 2);
    });

    test('la respiración se comparte con Health Connect', () async {
      final FakeHealthConnectGateway health = FakeHealthConnectGateway();
      final ProviderContainer c = createTestContainer(db, now: now, healthConnect: health);
      addTearDown(c.dispose);
      await c.read(careSessionServiceProvider).complete(
            kind: CareSessionKind.breathing,
            variant: 'box',
            durationSeconds: 64,
            healthTitle: 'Caja',
          );
      expect(health.mindfulness.single.end.difference(health.mindfulness.single.start).inSeconds, 64);
    });

    test('si Health Connect falla, la sesión se guarda igual', () async {
      final ProviderContainer c = createTestContainer(db, now: now, healthConnect: ThrowingHealthConnectGateway());
      addTearDown(c.dispose);
      final RewardGrant grant = await c.read(careSessionServiceProvider).complete(
            kind: CareSessionKind.breathing,
            variant: 'box',
            durationSeconds: 64,
          );
      expect(grant.granted, isTrue);
    });
  });

  group('Hábitos', () {
    test('completar todos los de hoy da monedas una vez', () async {
      final ProviderContainer c = createTestContainer(db, now: now);
      addTearDown(c.dispose);
      final HabitService service = c.read(habitServiceProvider);
      final int a = (await service.add(name: 'Hilo dental', iconKey: 'tooth'))!;
      final int b = (await service.add(name: 'Protector solar', iconKey: 'sun'))!;
      // Solo los domingos: no cuenta un miércoles.
      await service.add(name: 'Planear la semana', iconKey: 'book', daysMask: 64);
      expect(await service.add(name: '   ', iconKey: 'tooth'), isNull);

      expect((await service.setDone(habitId: a, dateKey: '2026-10-28', done: true)).granted, isFalse);
      expect((await service.setDone(habitId: b, dateKey: '2026-10-28', done: true)).coins, 10);
      await service.setDone(habitId: b, dateKey: '2026-10-28', done: false);
      expect((await service.setDone(habitId: b, dateKey: '2026-10-28', done: true)).granted, isFalse);
      expect((await db.select(db.habitLogs).get()).length, 2);
    });
  });

  group('Chequeos', () {
    test('la lista inicial depende de la edad y el sexo', () async {
      final ProviderContainer c = createTestContainer(db, now: now);
      addTearDown(c.dispose);
      await c.read(checkupServiceProvider).seedIfEmpty();
      await c.read(checkupServiceProvider).seedIfEmpty();
      final List<Checkup> all = await db.select(db.checkups).get();
      expect(all.where((Checkup ch) => ch.catalogKey == 'dental').length, 1, reason: 'Sembrar dos veces no duplica');
      expect(all.any((Checkup ch) => ch.catalogKey == 'prostate'), isFalse);
      final Checkup mammo = all.singleWhere((Checkup ch) => ch.catalogKey == 'mammography');
      expect(mammo.isEnabled, isTrue, reason: '52 años');
      expect(all.singleWhere((Checkup ch) => ch.catalogKey == 'bone_density').isEnabled, isFalse);
    });

    test('marcar hecho da monedas y no acepta fechas futuras', () async {
      final ProviderContainer c = createTestContainer(db, now: now);
      addTearDown(c.dispose);
      final CheckupService service = c.read(checkupServiceProvider);
      final int id = (await service.addCustom(name: 'Dermatología', intervalMonths: 12))!;
      final RewardGrant grant = await service.markDone(id, doneAt: DateTime(2027, 1, 1));
      expect(grant.coins, 20);
      expect((await db.select(db.checkupLogs).getSingle()).doneAt, now);
    });
  });

  group('Signos vitales', () {
    test('manual: valida y guarda; Health Connect: sin duplicados', () async {
      await UserProfileDao(db).updateProfile(
        const UserProfilesCompanion(vitalDevicesJson: Value('["blood_pressure","glucose"]')),
      );
      final FakeHealthConnectGateway health = FakeHealthConnectGateway()
        ..vitals = <VitalSample>[
          VitalSample(
            externalId: 'hc-1',
            kind: VitalKind.bloodPressure,
            at: DateTime(2026, 10, 27, 8),
            primary: 128,
            secondary: 84,
          ),
          VitalSample(externalId: 'hc-2', kind: VitalKind.oxygen, at: DateTime(2026, 10, 27, 8), primary: 97),
          VitalSample(externalId: 'hc-3', kind: VitalKind.glucose, at: DateTime(2026, 10, 27, 8), primary: 9000),
        ];
      final ProviderContainer c = createTestContainer(db, now: now, healthConnect: health);
      addTearDown(c.dispose);
      final VitalService service = c.read(vitalServiceProvider);

      expect(await service.addManual(kind: VitalKind.bloodPressure, primary: 80, secondary: 120), isFalse);
      expect(await service.addManual(kind: VitalKind.glucose, primary: 95, context: 'fasting'), isTrue);

      await service.syncFromHealthConnect();
      await service.syncFromHealthConnect();
      final List<VitalReading> all = await db.select(db.vitalReadings).get();
      expect(all.where((VitalReading r) => r.externalId == 'hc-1').length, 1);
      expect(all.any((VitalReading r) => r.kind == 'oxygen'), isFalse, reason: 'Sin oxímetro declarado');
      expect(all.any((VitalReading r) => r.externalId == 'hc-3'), isFalse, reason: 'Valor imposible');
    });

    test('declarar un aparato pide solo su permiso', () async {
      final FakeHealthConnectGateway health = FakeHealthConnectGateway(granted: true);
      final ProviderContainer c = createTestContainer(db, now: now, healthConnect: health);
      addTearDown(c.dispose);
      final CarePreferencesService prefs = c.read(carePreferencesServiceProvider);
      await prefs.setVitalDevices(<VitalKind>{VitalKind.glucose});
      await prefs.setVitalDevices(<VitalKind>{VitalKind.glucose, VitalKind.oxygen});
      expect(health.requestedVitals, <Set<VitalKind>>[
        <VitalKind>{VitalKind.glucose},
        <VitalKind>{VitalKind.oxygen},
      ]);
    });
  });

  group('Alcohol y tabaco', () {
    test('una cerveza suma sus kcal en Comida y deshacer las quita', () async {
      final ProviderContainer c = createTestContainer(db, now: now);
      addTearDown(c.dispose);
      final SubstanceService service = c.read(substanceServiceProvider);
      final int id = await service.log(SubstancePreset.byKey('beer')!, units: 2);
      final FoodLog food = await db.select(db.foodLogs).getSingle();
      expect(food.totalKcal, closeTo(280, 1));
      expect(food.mealType, MealType.snack);

      await service.log(SubstancePreset.byKey('beer')!);
      expect((await db.select(db.foodItems).get()).where((FoodItem f) => f.barcode == 'nb-drink-beer').length, 1);

      await service.undo(id);
      expect((await db.select(db.foodLogs).get()).length, 1);
      await service.log(SubstancePreset.byKey('cigarette')!);
      expect((await db.select(db.foodLogs).get()).length, 1, reason: 'El tabaco no va a Comida');
    });
  });

  group('Equipos', () {
    test('sin pantalla de papel se sale del tema de papel', () async {
      await UserProfileDao(db).updateThemeMode('nxtpaper_eink_light');
      final ProviderContainer c = createTestContainer(db, now: now);
      addTearDown(c.dispose);
      await c.read(carePreferencesServiceProvider).setEinkScreen(false);
      final UserProfile p = (await UserProfileDao(db).getProfile())!;
      expect(p.hasEinkScreen, isFalse);
      expect(p.themeMode, isNot('nxtpaper_eink_light'));
    });

    test('la hora de dormir mueve el aviso de desconectar', () async {
      final ProviderContainer c = createTestContainer(db, now: now);
      addTearDown(c.dispose);
      await c.read(reminderServiceProvider).seedDefaults();
      await c.read(carePreferencesServiceProvider).setTargetBedtime(30); // 00:30
      final Reminder windDown = (await db.select(db.reminders).get())
          .singleWhere((Reminder r) => r.reminderType == ReminderType.windDown);
      expect(windDown.timeOfDayMinutes, 0);
      expect((await UserProfileDao(db).getProfile())!.targetBedtimeMinutes, 30);
    });
  });

  test('OMS-5 se guarda con su puntuación', () async {
    final ProviderContainer c = createTestContainer(db, now: now);
    addTearDown(c.dispose);
    expect(await c.read(wellbeingServiceProvider).save(<int>[4, 3, 2, 4, 5]), 72);
    expect((await CareDao(db).watchWellbeing().first).single.percentScore, 72);
  });
}
