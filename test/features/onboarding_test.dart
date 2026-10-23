import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/app.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/features/profile_goals/presentation/onboarding_screen.dart';
import 'package:nb_selfcare/features/today/presentation/hoy_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('OnboardingGate muestra OnboardingScreen cuando no hay perfil', (tester) async {
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

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Tu Santuario de Autocuidado'), findsOneWidget);
    expect(find.text('Comenzar mi Santuario'), findsOneWidget);

    // Limpiar árbol para vaciar timers pendientes de Drift
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('Completar Onboarding guarda perfil y transiciona a DashboardScreen', (tester) async {
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

    // Llenar el nombre
    final nameField = find.widgetWithText(TextFormField, '¿Cómo te llamas?');
    await tester.enterText(nameField, 'Nathan');
    await tester.pump();

    // Presionar el botón de guardar
    final submitButton = find.text('Comenzar mi Santuario');
    await tester.tap(submitButton);

    // Esperar a que la transacción termine y el stream reactive la UI
    await tester.pumpAndSettle();

    // Debe mostrar ahora HoyScreen
    expect(find.byType(HoyScreen), findsOneWidget);
    expect(find.textContaining('Nathan'), findsOneWidget);

    // Limpiar árbol para vaciar timers pendientes de Drift
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
