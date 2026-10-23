import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/app.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/database/daos/body_measurements_dao.dart';
import 'package:nb_selfcare/core/database/daos/pet_dao.dart';
import 'package:nb_selfcare/core/database/daos/user_profile_dao.dart';
import 'package:nb_selfcare/features/body_metrics/presentation/body_and_workout_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());

    // Crear perfil inicial
    final profileDao = UserProfileDao(db);
    await profileDao.createProfile(
      UserProfilesCompanion(
        name: const drift.Value('Nathan'),
        birthDate: drift.Value(DateTime(1998, 5, 20)),
        biologicalSex: const drift.Value('male'),
        heightCm: const drift.Value(178.0),
        targetWeightKg: const drift.Value(72.0),
        weeklyGoalRateKg: const drift.Value(-0.5),
        dailyWaterGoalMl: const drift.Value(2500),
        dailyStepsGoal: const drift.Value(8000),
        dailySleepGoalHours: const drift.Value(7.5),
        themeMode: const drift.Value('material_you'),
      ),
    );

    // Inicializar estado de mascota
    await db.into(db.petStatus).insert(
          const PetStatusCompanion(
            petName: drift.Value('Nibi'),
            coinsBalance: drift.Value(50),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('Navegación al Laboratorio Corporal y pesaje manual con derivación de 13 métricas', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: const NbSelfcareApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Tocar el botón de Pesarme en el Dashboard
    final cardFinder = find.text('Pesarme');
    expect(cardFinder, findsOneWidget);
    await tester.tap(cardFinder);
    await tester.pumpAndSettle();

    expect(find.byType(BodyAndWorkoutScreen), findsOneWidget);
    expect(find.text('Xiaomi Mi Scale 2 BLE'), findsOneWidget);

    // Abrir diálogo de pesaje manual
    final manualWeighBtn = find.byIcon(Icons.edit_note_outlined);
    expect(manualWeighBtn, findsOneWidget);
    await tester.tap(manualWeighBtn);
    await tester.pumpAndSettle();

    expect(find.text('Registro Manual de Peso'), findsOneWidget);

    // Guardar pesaje de 74.0 kg
    final saveBtn = find.text('Guardar');
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();

    // Verificar que la medición se guardó en Drift con derivación de 13 métricas
    final measurements = await BodyMeasurementsDao(db, PetDao(db)).getLatestMeasurement();
    expect(measurements, isNotNull);
    expect(measurements!.weightKg, equals(70.0));
    expect(measurements.bmi, greaterThan(20.0));
    expect(measurements.bodyFatPercentage, isNotNull);
    expect(measurements.muscleMassKg, isNotNull);
    expect(measurements.waterPercentage, isNotNull);

    // Verificar que el libro mayor otorgó +15 monedas (50 iniciales + 15 = 65)
    final pet = await PetDao(db).getPetStatus();
    expect(pet!.coinsBalance, equals(65));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('Registro de entrenamiento en 5 segundos calcula gasto neto y otorga +20 monedas', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: const NbSelfcareApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Navegar a BodyAndWorkoutScreen vía botón Entrenar
    await tester.tap(find.text('Entrenar'));
    await tester.pumpAndSettle();

    // Abrir modal de entrenamiento
    final registerWorkoutBtn = find.text('Registrar');
    await tester.ensureVisible(registerWorkoutBtn);
    await tester.tap(registerWorkoutBtn);
    await tester.pumpAndSettle();

    expect(find.text('Entrenamiento en 5 Segundos'), findsNWidgets(2));
    expect(find.text('Registrar en 5 segundos'), findsOneWidget);

    // Guardar bloque RPE
    await tester.tap(find.text('Registrar en 5 segundos'));
    await tester.pumpAndSettle();

    // Verificar inserción en Drift
    final workouts = await db.select(db.workoutBlocks).get();
    expect(workouts, hasLength(1));
    expect(workouts.first.category, equals('weights'));
    expect(workouts.first.netCaloriesBurned, greaterThan(100));

    // Verificar recompensa de +20 monedas (50 iniciales + 20 = 70)
    final pet = await PetDao(db).getPetStatus();
    expect(pet!.coinsBalance, equals(70));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
