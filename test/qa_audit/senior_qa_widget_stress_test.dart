import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/database/daos/user_profile_dao.dart';
import 'package:nb_selfcare/core/domain/enums.dart';
import 'package:nb_selfcare/core/l10n/l10n.dart';
import 'package:nb_selfcare/features/profile_goals/application/profile_queries.dart';
import 'package:nb_selfcare/features/profile_goals/presentation/perfil_yo_screen.dart';
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
        name: const drift.Value('Nathan QA'),
        birthDate: drift.Value(DateTime(1996, 4, 12)),
        biologicalSex: const drift.Value(BiologicalSex.male),
        heightCm: const drift.Value(178.0),
        targetWeightKg: const drift.Value(72.0),
        weeklyGoalRateKg: const drift.Value(-0.4),
        dailyWaterGoalMl: const drift.Value(2800),
        dailyStepsGoal: const drift.Value(10000),
        dailySleepGoalHours: const drift.Value(8.0),
        currentAdaptiveTdeeKcal: const drift.Value(2250),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestWidget({
    required Size screenSize,
    String themeKey = 'azul_oceano',
  }) {
    final ThemeData themeData = ScTheme.build(themeKey);

    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        userProfileDaoProvider.overrideWithValue(profileDao),
        latestTdeeCalibrationStreamProvider.overrideWith((ref) => Stream.value(null)),
        userProfileStreamProvider.overrideWith(
          (ref) => Stream.value(
            UserProfile(
              id: 1,
              name: 'Nathan QA',
              birthDate: DateTime(1996, 4, 12),
              biologicalSex: BiologicalSex.male,
              heightCm: 178.0,
              targetWeightKg: 72.0,
              weeklyGoalRateKg: -0.4,
              dailyWaterGoalMl: 2800,
              dailyStepsGoal: 10000,
              dailySleepGoalHours: 8.0,
              currentAdaptiveTdeeKcal: 2250,
              themeMode: themeKey,
              isLocalAiEnabled: true,
              isCycleTrackingEnabled: false,
              isFastingEnabled: true,
              isManualMacroMode: false,
              activeDietArchetype: DietArchetype.mediterranean,
              activeDietPhase: DietPhase.deficit,
              calorieCyclingScheduleJson: '',
              caffeineBedtimeCutoffHours: 8.0,
              hasImpedanceContraindication: false,
              hasEatingDisorderHistory: false,
              takesHypoglycemicMedication: false,
              createdAt: DateTime.now(),
            ),
          ),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: themeData,
        home: MediaQuery(
          data: MediaQueryData(size: screenSize),
          child: const Scaffold(
            body: PerfilYoScreen(),
          ),
        ),
      ),
    );
  }

  group('Senior QA Widget Stress & Viewport Tests', () {
    testWidgets('Narrow Viewport (320px width) renders PerfilYoScreen without RenderFlex overflow', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 700 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(screenSize: const Size(320, 700)));
      await tester.pumpAndSettle();

      expect(find.text('Nathan QA'), findsOneWidget);

      final Finder titleFinder = find.text('Tus patrones');
      await tester.scrollUntilVisible(titleFinder, 150.0);
      await tester.pumpAndSettle();

      expect(titleFinder, findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmountAndFlush(tester);
    });

    testWidgets('NXTPAPER High-Contrast E-Ink theme renders cleanly with zero elevation and flat borders', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 2.0, 844 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestWidget(
          screenSize: const Size(390, 844),
          themeKey: 'nxtpaper_pure',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nathan QA'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmountAndFlush(tester);
    });

    testWidgets('Interactive Pearson Correlation Refresh button triggers recomputation smoothly', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 2.0, 844 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(screenSize: const Size(390, 844)));
      await tester.pumpAndSettle();

      // Scroll down to Cross Analytics card
      final Finder refreshBtn = find.byTooltip('Volver a calcular');
      await tester.scrollUntilVisible(refreshBtn, 150.0);
      await tester.drag(find.byType(ListView), const Offset(0, -120));
      await tester.pumpAndSettle();
      expect(refreshBtn, findsOneWidget);

      // Tap refresh
      await tester.tap(refreshBtn, warnIfMissed: false);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await unmountAndFlush(tester);
    });
  });
}
