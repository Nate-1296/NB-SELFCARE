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
import 'package:nb_selfcare/core/domain/enums.dart';
import 'package:nb_selfcare/core/l10n/l10n.dart';
import 'package:nb_selfcare/features/body_metrics/presentation/cuerpo_screen.dart';
import 'package:nb_selfcare/shared/theme/sc_theme.dart';
import 'package:nb_selfcare/shared/utils/date_time_extensions.dart';

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
        biologicalSex: const drift.Value(BiologicalSex.male),
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

  testWidgets('Laboratorio Corporal y pesaje manual con derivación de 13 métricas', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ScTheme.build('samsung_dark'),
          home: const CuerpoScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(CuerpoScreen), findsOneWidget);
    expect(find.text('Composición corporal'), findsOneWidget);

    // Abrir diálogo de pesaje manual
    final manualWeighBtn = find.text('Manual');
    expect(manualWeighBtn, findsOneWidget);
    await tester.tap(manualWeighBtn);
    await tester.pumpAndSettle();

    expect(find.text('Pesaje manual'), findsOneWidget);

    // Guardar pesaje de 70.0 kg
    final saveBtn = find.text('Guardar');
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();

    // Verificar que la medición se guardó en Drift con derivación de 13 métricas
    final measurements = await BodyMeasurementsDao(db).getLatestMeasurement();
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

    // En HoyScreen tocar el botón embebido Entreno 5s de la tarjeta de Entrenamiento
    final entrenarBtn = find.text('Registrar');
    await tester.scrollUntilVisible(
      entrenarBtn,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(entrenarBtn, findsOneWidget);
    await tester.tap(entrenarBtn);
    await tester.pumpAndSettle();

    expect(find.text('Registrar entrenamiento'), findsWidgets);

    // Guardar entrenamiento de 45 min
    final submitBtn = find.text('Guardar');
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    // Verificar que se guardó en workoutDao y se sumaron 20 monedas (50 + 20 = 70)
    final workouts = await db.select(db.workoutBlocks).get();
    expect(workouts, hasLength(1));
    expect(workouts.first.durationMinutes, equals(45));

    final pet = await PetDao(db).getPetStatus();
    expect(pet!.coinsBalance, equals(70));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('WeightTrendChartCard renderiza gráfica temporal y permite conmutar métricas', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Insertar serie de 3 pesajes para trazar la línea
    final dao = BodyMeasurementsDao(db);
    final now = DateTime.now();

    for (int i = 3; i >= 1; i--) {
      await dao.insertMeasurement(
        BodyMeasurementsCompanion.insert(
          measuredAt: drift.Value(now.subtract(Duration(days: i))),
          dateKey: now.subtract(Duration(days: i)).dateKey,
          source: MeasurementSource.miScale2Ble,
          weightKg: 73.0 - (i * 0.5),
          trendWeightKg: 73.0 - (i * 0.4),
          bmi: 23.0,
          bodyFatPercentage: const drift.Value(18.5),
          muscleMassKg: const drift.Value(55.0),
          waterPercentage: const drift.Value(58.0),
        ),
      );
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ScTheme.build('samsung_dark'),
          home: const CuerpoScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Debe mostrar la tarjeta de Evolución Temporal
    expect(find.text('Evolución'), findsOneWidget);
    expect(find.text('Peso'), findsOneWidget);
    expect(find.text('Grasa'), findsOneWidget);

    // Conmutar a % Grasa
    final fatMetricBtn = find.text('Grasa');
    await tester.tap(fatMetricBtn);
    await tester.pumpAndSettle();

    expect(find.text('Evolución'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('CuerpoScreen en 390px (Samsung Dark) sin overflows, con detalle métrico y cinta Navy', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final dao = BodyMeasurementsDao(db);
    final now = DateTime.now();
    await dao.insertMeasurement(
      BodyMeasurementsCompanion.insert(
        measuredAt: drift.Value(now),
        dateKey: now.dateKey,
        source: MeasurementSource.miScale2Ble,
        weightKg: 71.4,
        trendWeightKg: 71.6,
        impedanceOhms: const drift.Value(485),
        bmi: 22.5,
        bodyFatPercentage: const drift.Value(17.8),
        muscleMassKg: const drift.Value(55.2),
        waterPercentage: const drift.Value(59.5),
        visceralFatIndex: const drift.Value(5),
        boneMassKg: const drift.Value(2.85),
        proteinPercentage: const drift.Value(17.2),
        basalMetabolicRateKcal: const drift.Value(1620),
        metabolicAge: const drift.Value(24),
        leanBodyMassKg: const drift.Value(58.7),
        bodyScore: const drift.Value(86),
        somatotype: const drift.Value('balanced_muscular'),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ScTheme.build('samsung_dark'),
          home: const CuerpoScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Cuerpo'), findsOneWidget);
    expect(find.textContaining('71.4', findRichText: true), findsWidgets);

    // Abrir modal de Cinta US Navy desde la Estación de Pesaje
    final navyBtn = find.text('Cinta métrica');
    expect(navyBtn, findsOneWidget);
    await tester.tap(navyBtn);
    await tester.pumpAndSettle();

    expect(find.text('Medidas con cinta'), findsOneWidget);
    expect(find.text('Guardar medidas'), findsOneWidget);

    await tester.tap(find.text('Guardar medidas'));
    await tester.pumpAndSettle();

    // Desplazar hacia la sección de Composición Corporal
    final compHead = find.text('Composición corporal');
    await tester.scrollUntilVisible(
      compHead,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(compHead, findsOneWidget);
    final somatotypeCard = find.text('Atlético');
    expect(somatotypeCard, findsOneWidget);
    await tester.tap(somatotypeCard);
    await tester.pumpAndSettle();

    expect(find.text('¿Qué representa?'), findsOneWidget);
    expect(find.text('Valor actual'), findsOneWidget);

    final closeBtn = find.text('Cerrar');
    expect(closeBtn, findsOneWidget);
    await tester.ensureVisible(closeBtn);
    await tester.pumpAndSettle();
    await tester.tap(closeBtn);
    await tester.pumpAndSettle();

    // Abrir entrenamiento RPE desde Cuerpo
    final rpeBtn = find.text('Registrar entrenamiento');
    await tester.scrollUntilVisible(
      rpeBtn,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(rpeBtn, findsOneWidget);
    await tester.tap(rpeBtn);
    await tester.pumpAndSettle();

    expect(find.text('Registrar entrenamiento'), findsWidgets);
    expect(find.text('Pesas / Fuerza'), findsOneWidget);
    expect(find.text('Moderado'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded).last);
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('CuerpoScreen en 390px (NXTPAPER E-Ink) sin overflows', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ScTheme.build('nxtpaper_eink'),
          home: const CuerpoScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Cuerpo'), findsOneWidget);

    final compHead = find.text('Composición corporal');
    await tester.scrollUntilVisible(
      compHead,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(compHead, findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
