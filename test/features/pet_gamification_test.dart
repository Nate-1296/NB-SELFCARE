import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/app.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/database/daos/pet_dao.dart';
import 'package:nb_selfcare/core/database/daos/user_profile_dao.dart';
import 'package:nb_selfcare/core/domain/enums.dart';
import 'package:nb_selfcare/core/l10n/l10n.dart';
import 'package:nb_selfcare/features/pet_gamification/domain/nibi_activity.dart';
import 'package:nb_selfcare/features/pet_gamification/domain/pet_catalog.dart';
import 'package:nb_selfcare/features/pet_gamification/presentation/nibi/nibi_view.dart';
import 'package:nb_selfcare/features/pet_gamification/presentation/nibi_screen.dart';
import 'package:nb_selfcare/features/pet_gamification/presentation/shop_modal.dart';
import 'package:nb_selfcare/shared/theme/sc_theme.dart';
import 'package:nb_selfcare/shared/utils/date_formats.dart';

void main() {
  late AppDatabase db;
  late PetDao petDao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    petDao = PetDao(db);

    await UserProfileDao(db).createProfile(
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
      ),
    );

    await db.into(db.petStatus).insert(
          const PetStatusCompanion(
            petName: drift.Value('Nibi'),
            coinsBalance: drift.Value(200),
            currentStreakDays: drift.Value(5),
            streakShieldsAvailable: drift.Value(1),
            unlockedItemsJson: drift.Value('["bg_default_room"]'),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('NibiView (dragón vectorial animado)', () {
    testWidgets('Todas las actividades con sombreros, en color y en papel, y la caricia',
        (tester) async {
      for (final String theme in <String>['samsung_dark', 'nxtpaper_eink_light']) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ScTheme.build(theme),
            locale: const Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Wrap(
                children: <Widget>[
                  for (final NibiActivity a in NibiActivity.values)
                    NibiView(
                      activity: a,
                      size: 90,
                      look: const NibiLook(hatId: 'hat_chef', accessoryId: 'acc_scarf', colorId: 'color_ocean'),
                      aura: a == NibiActivity.zen,
                      onReaction: (_) {},
                    ),
                ],
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(NibiView), findsNWidgets(NibiActivity.values.length));
        await tester.tap(find.byType(NibiView).first);
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.takeException(), isNull, reason: theme);
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('PetHabitatWidget & ShopModal', () {
    testWidgets('Abre la Tienda y compra un Escudo de Racha', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            locale: Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ShopModal()),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Tienda'), findsOneWidget);
      expect(find.text('Escudo de un día'), findsOneWidget);

      // Comprar el escudo de un día (25 monedas, en su propia fila).
      final Finder shieldRow = find.ancestor(of: find.text('Escudo de un día'), matching: find.byType(Row)).first;
      final Finder buyShieldBtn = find.descendant(of: shieldRow, matching: find.text('25'));
      expect(buyShieldBtn, findsOneWidget);
      await tester.tap(buyShieldBtn);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verificar que el balance de monedas disminuyó de 200 a 175
      final updatedPet = await petDao.getPetStatus();
      expect(updatedPet!.coinsBalance, equals(175));
      // Y los escudos disponibles aumentaron de 1 a 2
      expect(updatedPet.streakShieldsAvailable, equals(2));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets(
      'HoyScreen presenta cuadrícula Bento personalizable (2×2 / 4×2 / 4×4) sin botones sueltos',
      (tester) async {
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

        await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

        // Cero texto "Santuario Offline", cero fila suelta de "Acciones Rápidas" y sin botón superior de Personalizar
        expect(find.textContaining('Santuario Offline'), findsNothing);
        expect(find.textContaining('SANTUARIO OFFLINE'), findsNothing);
        expect(find.text('Acciones Rápidas'), findsNothing);
        expect(find.text('Personalizar'), findsNothing);

        // Fecha legible del día debajo del saludo ("lunes, 26 de octubre")
        final String day = DateFormats.weekdayDayMonth(DateTime.now(), 'es');
        expect(find.text(day[0].toUpperCase() + day.substring(1)), findsOneWidget);

        // Capturar saludo inicial de la sesión y verificar que NO cambia al cambiar de pestaña y volver
        final Finder greetingFinder = find.textContaining('Nathan');
        expect(greetingFinder, findsOneWidget);
        final String initialSessionGreeting =
            tester.widget<Text>(greetingFinder).data ?? '';

        await tester.tap(find.text('Cuerpo'));
        await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(find.text('Inicio'));
        await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

        final String greetingAfterTabSwitch =
            tester.widget<Text>(find.textContaining('Nathan')).data ?? '';
        expect(greetingAfterTabSwitch, equals(initialSessionGreeting));

        // Tarjetas de resumen presentes con sus propios controles embebidos
        expect(find.text('Objetivos del Día'), findsOneWidget);

        // Tocar botón embebido de agua +250 ml dentro del widget de Hidratación
        final addWaterBtn = find.text('+250 ml');
        await tester.ensureVisible(addWaterBtn);
        await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
        expect(addWaterBtn, findsOneWidget);
        await tester.tap(addWaterBtn);
        await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

        // Verificar que se registró en SQLite
        final totalWater = await db.select(db.hydrationLogs).get();
        expect(totalWater, hasLength(1));
        expect(totalWater.first.volumeMl, equals(250));

        // Esperar a que la SnackBar de agua desaparezca para que no bloquee los taps inferiores
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();

        // Entrar a modo edición usando el único botón al final de la página ("Editar tarjetas de Hoy")
        final editBottomBtn = find.text('Editar tarjetas de Hoy');
        await tester.scrollUntilVisible(
          editBottomBtn,
          350,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(editBottomBtn);
        await tester.pumpAndSettle();
        await tester.tap(editBottomBtn);
        await tester.pumpAndSettle();

        final saveBtn = find.text('Guardar diseño');
        await tester.scrollUntilVisible(
          saveBtn,
          350,
          scrollable: find.byType(Scrollable).first,
        );
        expect(saveBtn, findsOneWidget);

        // Volver arriba para ocultar Hidratación y verificar que pasa a la bandeja de ocultas
        final hideHydration = find.byTooltip('Ocultar (Agua)');
        await tester.scrollUntilVisible(
          hideHydration,
          -350,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(hideHydration);
        await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

        final hiddenTrayTitle = find.text('Tarjetas ocultas (1)');
        await tester.scrollUntilVisible(
          hiddenTrayTitle,
          350,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
        expect(hiddenTrayTitle, findsOneWidget);

        // Volver a mostrar la tarjeta oculta
        final showBtn = find.widgetWithText(FilledButton, 'Mostrar');
        await tester.ensureVisible(showBtn);
        await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(showBtn);
        await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('Tarjetas ocultas (1)'), findsNothing);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    test('PetDao.equipItem preserva fondo al equipar/desequipar sombrero y viceversa', () async {
      await petDao.equipItem(hatId: 'hat_crown', bgId: 'bg_zen_garden');
      var status = await petDao.getPetStatus();
      expect(status!.equippedHatId, equals('hat_crown'));
      expect(status.equippedBackgroundId, equals('bg_zen_garden'));

      // Desequipar solo el sombrero NO debe borrar el fondo equipado
      await petDao.equipItem(hatId: null);
      status = await petDao.getPetStatus();
      expect(status!.equippedHatId, isNull);
      expect(status.equippedBackgroundId, equals('bg_zen_garden'));

      // Cambiar solo el fondo NO debe tocar el sombrero
      await petDao.equipItem(hatId: 'hat_chef');
      await petDao.equipItem(bgId: 'bg_cyber_dojo');
      status = await petDao.getPetStatus();
      expect(status!.equippedHatId, equals('hat_chef'));
      expect(status.equippedBackgroundId, equals('bg_cyber_dojo'));
    });

    test('PetDao gestiona escudos consumibles, multiplicador 1.5x de sueño y racha diaria', () async {
      // Compra consumible: suma escudo sin ensuciar unlockedItemsJson
      final bought = await petDao.buyShopItem(
        itemId: 'shield_1',
        cost: 25,
        dateKey: '2026-10-20',
        isConsumable: true,
        shieldsToAdd: 1,
      );
      expect(bought, isTrue);

      var pet = await petDao.getPetStatus();
      expect(pet!.streakShieldsAvailable, equals(2));
      expect(pet.unlockedItemsJson, isNot(contains('shield_1')));

      // Día 1 con multiplicador de sueño reparador 1.5x (10 * 1.5 = 15 monedas)
      final grantedDay1 = await petDao.recordReward(
        dateKey: '2026-10-20',
        ledgerKey: 'meal_log_breakfast',
        amount: 15,
        multiplierApplied: 1.5,
      );
      expect(grantedDay1, isTrue);

      pet = await petDao.getPetStatus();
      expect(pet!.coinsBalance, equals(175 + 15));
      expect(pet.currentStreakDays, equals(6));

      // Salto de 1 día (2026-10-21 sin actividad -> 2026-10-22 activo): consume 1 escudo y mantiene racha
      await petDao.recordReward(
        dateKey: '2026-10-22',
        ledgerKey: 'weigh_in',
        amount: 15,
      );
      pet = await petDao.getPetStatus();
      expect(pet!.streakShieldsAvailable, equals(1));
      expect(pet.currentStreakDays, equals(7));
    });

    testWidgets(
        'NibiScreen renderiza hábitat del dragón, vitals, cuidados y armario',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            locale: Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: NibiScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Cabecera, ficha de monedas/escudos/racha y escenario con Nibi.
      expect(find.text('Nibi'), findsOneWidget);
      expect(find.text('200'), findsOneWidget);
      expect(find.text('5 d'), findsOneWidget);
      expect(find.byType(NibiView), findsOneWidget);

      // Cuidados junto al dragón (sin sección aparte): dar agua cambia lo que dice.
      expect(find.text('Cuidados'), findsNothing);
      await tester.tap(find.text('Dar agua'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('¡Glup, glup!'), findsOneWidget);

      // Respirar abre la sesión guiada dentro del escenario.
      await tester.tap(find.text('Respirar'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Empezar').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Empezar'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Inhala'), findsOneWidget);
      await tester.tap(find.text('Terminar'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Dar agua'), findsOneWidget);

      // Su día y el armario (solo lo que tiene).
      await tester.drag(find.byType(ListView).first, const Offset(0, -900));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Su día contigo'), findsOneWidget);
      expect(find.text('Sombreros'), findsWidgets);
      expect(find.text('Escenarios'), findsOneWidget);
      expect(find.text('Corona'), findsNothing);
      expect(find.text('Ver tienda'), findsWidgets);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
