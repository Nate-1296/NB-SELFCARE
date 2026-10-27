import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/app/router/app_router.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/database/daos/user_profile_dao.dart';
import 'package:nb_selfcare/core/domain/enums.dart';
import 'package:nb_selfcare/features/profile_goals/application/profile_queries.dart';
import 'package:nb_selfcare/features/profile_goals/presentation/app_settings_screen.dart';
import 'package:nb_selfcare/features/profile_goals/presentation/perfil_yo_screen.dart';
import 'package:nb_selfcare/shared/theme/sc_colors.dart';
import 'package:nb_selfcare/shared/theme/sc_theme.dart';

import '../support/widget_test_helpers.dart';

void main() {
  late AppDatabase db;
  late UserProfileDao profileDao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    profileDao = UserProfileDao(db);

    await profileDao.createProfile(
      UserProfilesCompanion(
        name: const drift.Value('Nathan'),
        birthDate: drift.Value(DateTime(1995, 8, 14)),
        biologicalSex: const drift.Value(BiologicalSex.male),
        heightCm: const drift.Value(180.0),
        targetWeightKg: const drift.Value(75.0),
        weeklyGoalRateKg: const drift.Value(-0.5),
        dailyWaterGoalMl: const drift.Value(2500),
        dailyStepsGoal: const drift.Value(10000),
        dailySleepGoalHours: const drift.Value(8.0),
        currentAdaptiveTdeeKcal: const drift.Value(2350),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestPerfil({String themeKey = 'azul_oceano'}) {
    final ThemeData themeData = ScTheme.build(themeKey);
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        userProfileDaoProvider.overrideWithValue(profileDao),
        latestTdeeCalibrationStreamProvider
            .overrideWith((ref) => Stream.value(null)),
        userProfileStreamProvider.overrideWith(
          (ref) => Stream.value(
            UserProfile(
              id: 1,
              name: 'Nathan',
              birthDate: DateTime(1995, 8, 14),
              biologicalSex: BiologicalSex.male,
              heightCm: 180.0,
              targetWeightKg: 75.0,
              weeklyGoalRateKg: -0.5,
              dailyWaterGoalMl: 2500,
              dailyStepsGoal: 10000,
              dailySleepGoalHours: 8.0,
              currentAdaptiveTdeeKcal: 2350,
              themeMode: 'azul_oceano',
              isLocalAiEnabled: true,
              isCycleTrackingEnabled: false,
              isFastingEnabled: true,
              isManualMacroMode: false,
              activeDietArchetype: DietArchetype.flexible,
              activeDietPhase: DietPhase.deficit,
              calorieCyclingScheduleJson: '{}',
              caffeineBedtimeCutoffHours: 8.0,
              hasImpedanceContraindication: false,
              hasEatingDisorderHistory: false,
              takesHypoglycemicMedication: false,
              createdAt: DateTime.now(),
            ),
          ),
        ),
      ],
      child: routedTestApp(
        theme: themeData,
        home: const PerfilYoScreen(),
        routes: const <String, Widget>{'/ajustes': AppSettingsScreen()},
      ),
    );
  }

  testWidgets(
      'PerfilYoScreen renderiza avatar ampliado, gráfico centrado, 2x2 stat cards y botones expandidos',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestPerfil());
    await tester.pumpAndSettle();

    // 1. Identidad
    expect(find.text('Nathan'), findsOneWidget);
    expect(find.textContaining('años'), findsOneWidget);
    expect(find.text('Hombre'), findsOneWidget);
    expect(find.text('180 cm'), findsOneWidget);
    expect(find.text('75.0 kg meta'), findsOneWidget);

    // 2. Metas y gasto diario
    expect(find.text('Metas y gasto diario'), findsOneWidget);
    expect(find.text('kcal / día'), findsOneWidget);

    // 3. 2x2 Stat Cards
    expect(find.text('Gasto diario'), findsOneWidget);
    expect(find.text('Meta de peso'), findsOneWidget);
    expect(find.text('Agua'), findsOneWidget);
    expect(find.text('Pasos y sueño'), findsOneWidget);

    // 4. Botones ordenados y expandidos
    expect(find.text('Ajustar metas'), findsOneWidget);
    expect(find.text('Recalcular mi gasto (14 días)'), findsOneWidget);

    // 5. Patrones vacíos / iniciales
    await tester.scrollUntilVisible(
      find.text('Aún reuniendo datos'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Tus patrones'), findsOneWidget);

    // 6. Ajustes desde la cabecera
    await tester.scrollUntilVisible(find.byTooltip('Ajustes'), -400, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byTooltip('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.byType(AppSettingsScreen), findsOneWidget);
    await unmountAndFlush(tester);
  });

  testWidgets('PerfilYoScreen renderiza nítidamente en Modo Papel NXTPAPER E-Ink',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestPerfil(themeKey: 'nxtpaper_eink_light'));
    await tester.pumpAndSettle();

    expect(find.text('Nathan'), findsOneWidget);
    expect(find.text('Metas y gasto diario'), findsOneWidget);
    await unmountAndFlush(tester);
  });

  test('Temas NXTPAPER E-Ink asignan tonos de gris o colores distintos a los macronutrientes',
      () {
    final ScColors einkLight = scThemeByKey('nxtpaper_eink_light').colors;
    expect(einkLight.protein, isNot(equals(einkLight.carbs)));
    expect(einkLight.carbs, isNot(equals(einkLight.fat)));
    expect(einkLight.protein, isNot(equals(einkLight.fat)));

    final ScColors einkDark = scThemeByKey('nxtpaper_eink_dark').colors;
    expect(einkDark.protein, isNot(equals(einkDark.carbs)));
    expect(einkDark.carbs, isNot(equals(einkDark.fat)));
    expect(einkDark.protein, isNot(equals(einkDark.fat)));

    final ScColors colorPaper = scThemeByKey('nxtpaper_color_paper').colors;
    expect(colorPaper.protein, isNot(equals(colorPaper.carbs)));
    expect(colorPaper.carbs, isNot(equals(colorPaper.fat)));
    expect(colorPaper.protein, isNot(equals(colorPaper.fat)));
  });

  test('branchKeys contiene las 5 claves correspondientes a las 5 pestañas', () {
    expect(branchKeys.length, 5);
    expect(branchKeys[0], equals(branchHoyKey));
    expect(branchKeys[1], equals(branchComerKey));
    expect(branchKeys[2], equals(branchCuerpoKey));
    expect(branchKeys[3], equals(branchNibiKey));
    expect(branchKeys[4], equals(branchPerfilKey));
  });
}
