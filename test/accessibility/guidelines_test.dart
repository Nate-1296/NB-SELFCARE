import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/app.dart';
import 'package:nb_selfcare/app/router/app_router.dart';
import 'package:nb_selfcare/core/clock/clock.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/database/seeder/database_seeder.dart';
import 'package:nb_selfcare/core/domain/enums.dart';
import 'package:nb_selfcare/features/profile_goals/application/onboarding_service.dart';

import '../support/test_container.dart';
import '../support/widget_test_helpers.dart';

void main() {
  final DateTime now = DateTime(2026, 10, 26, 13);

  for (final String route in <String>['/hoy', '/comer', '/cuerpo', '/perfil', '/ayuno', '/ajustes', '/protocolo']) {
    testWidgets('$route cumple las pautas de accesibilidad de Android', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(393 * 3, 873 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final SemanticsHandle semantics = tester.ensureSemantics();

      final AppDatabase db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await DatabaseSeeder.seedIfEmpty(db);
        final ProviderContainer c = createTestContainer(db, now: now);
        await c.read(onboardingServiceProvider).complete(
              OnboardingAnswers(
                name: 'Ana',
                birthDate: DateTime(1992, 3, 10),
                sex: BiologicalSex.female,
                heightCm: 165,
                currentWeightKg: 68,
                targetWeightKg: 62,
                weeklyGoalRateKg: -0.5,
                dailyWaterGoalMl: 2500,
                dailyStepsGoal: 8000,
                dailySleepGoalHours: 7.5,
                themeKey: 'samsung_dark',
              ),
            );
        c.dispose();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            clockProvider.overrideWithValue(Clock.fixed(now)),
          ],
          child: const NbSelfcareApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      ProviderScope.containerOf(tester.element(find.byType(NbSelfcareApp))).read(appRouterProvider).go(route);
      for (int i = 0; i < 6; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
        await tester.pump(const Duration(milliseconds: 200));
      }

      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));

      semantics.dispose();
      await unmountAndFlush(tester);
      await tester.runAsync(db.close);
    });
  }
}
