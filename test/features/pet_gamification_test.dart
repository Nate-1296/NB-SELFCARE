import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/app.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/database/daos/pet_dao.dart';
import 'package:nb_selfcare/core/database/daos/user_profile_dao.dart';
import 'package:nb_selfcare/features/pet_gamification/presentation/nibi_screen.dart';
import 'package:nb_selfcare/features/pet_gamification/presentation/shop_modal.dart';
import 'package:nb_selfcare/features/pet_gamification/presentation/widgets/animated_nibi_view.dart';

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
        biologicalSex: const drift.Value('male'),
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

  group('AnimatedNibiView (Dragón Ilustrado)', () {
    testWidgets('Renderiza estados del dragón, accesorios y gestos de caricia',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                // Variante 1: Reposo / Idle
                AnimatedNibiView(mood: NibiMood.idle, size: 100),
                // Variante 2: Bebiendo agua + Sombrero de chef
                AnimatedNibiView(
                  mood: NibiMood.drinking,
                  equippedHatId: 'hat_chef',
                  size: 100,
                ),
                // Variante 3: Zen / Meditación + Corona
                AnimatedNibiView(
                  mood: NibiMood.zen,
                  equippedHatId: 'hat_crown',
                  size: 100,
                ),
                // Variante 4: Modo Papel E-Ink (NXTPAPER)
                AnimatedNibiView(
                  mood: NibiMood.happy,
                  isEink: true,
                  size: 100,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(AnimatedNibiView), findsNWidgets(4));

      // Probar gesto de caricia / interacción
      await tester.tap(find.byType(AnimatedNibiView).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AnimatedNibiView), findsNWidgets(4));
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
            home: Scaffold(body: ShopModal()),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Debe estar visible la Tienda de Recompensas
      expect(find.text('Tienda de Recompensas'), findsOneWidget);

      // Comprar Escudo Diario de Racha (cuesta 25 monedas)
      final buyShieldBtn = find.widgetWithText(FilledButton, '25');
      expect(buyShieldBtn, findsOneWidget);
      await tester.tap(buyShieldBtn);
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

        // Fecha corta DD/MM/YYYY debajo del saludo
        final DateTime now = DateTime.now();
        final String expectedShortDate =
            '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year.toString().padLeft(4, '0')}';
        expect(find.text(expectedShortDate), findsOneWidget);

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

        // Entrar a modo edición usando el único botón al final de la página ("Editar tarjetas de Hoy")
        final editBottomBtn = find.text('Editar tarjetas de Hoy');
        await tester.scrollUntilVisible(
          editBottomBtn,
          350,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(editBottomBtn);
        await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Guardar diseño de Hoy'), findsOneWidget);

        // Volver arriba para ocultar Hidratación y verificar que pasa a la bandeja de ocultas
        final hideHydration = find.byTooltip('Ocultar (Hidratación)');
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
      final grantedDay1 = await petDao.grantDailyReward(
        dateKey: '2026-10-20',
        actionType: 'meal_log_breakfast',
        baseAmount: 10,
        sleepMultiplier: 1.5,
      );
      expect(grantedDay1, isTrue);

      pet = await petDao.getPetStatus();
      expect(pet!.coinsBalance, equals(175 + 15));
      expect(pet.currentStreakDays, equals(6));

      // Salto de 1 día (2026-10-21 sin actividad -> 2026-10-22 activo): consume 1 escudo y mantiene racha
      await petDao.grantDailyReward(
        dateKey: '2026-10-22',
        actionType: 'weigh_in',
        baseAmount: 15,
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
            home: NibiScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Cabecera e identidad (Solo nombre y avatar)
      expect(find.text('Nibi'), findsOneWidget);

      // 3 Mini Tarjetas de métricas (Monedas, Protección, Racha con fueguito)
      expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
      expect(find.text('5'), findsOneWidget); // racha de 5 días inicial
      expect(find.text('200'), findsOneWidget); // 200 monedas iniciales

      // Globo de diálogo en 1ª persona y Dragón
      expect(find.textContaining('¡Me llena de alegría compartir este día contigo!'), findsOneWidget);
      expect(find.byType(AnimatedNibiView), findsOneWidget);

      // Vitals
      expect(find.text('Bienestar del Dragón'), findsOneWidget);
      expect(find.text('Hidratación'), findsOneWidget);
      expect(find.text('Sueño'), findsOneWidget);
      expect(find.text('Protección'), findsOneWidget);

      // Cuidados del Dragón (sin etiquetas de saldo o monedas)
      expect(find.text('Cuidados del Dragón'), findsOneWidget);
      expect(find.text('Acariciar'), findsOneWidget);
      expect(find.text('Dar Agua'), findsOneWidget);
      expect(find.text('Nutrir'), findsOneWidget);
      expect(find.text('Zen'), findsOneWidget);

      // Tocar "Dar Agua" transforma el dragón y actualiza el globo en 1ª persona
      await tester.tap(find.text('Dar Agua'));
      await tester.pump();
      expect(find.textContaining('¡Glup, glup!'), findsOneWidget);

      // Armario, Hábitats y Botones Inferiores (desplazar la lista)
      await tester.drag(find.byType(ListView).first, const Offset(0, -700));
      await tester.pump();
      expect(find.text('Armario y Hábitats'), findsOneWidget);
      expect(find.text('Sombreros y Accesorios'), findsOneWidget);
      expect(find.text('Fondos del Santuario'), findsOneWidget);
      expect(find.text('Tienda del Santuario'), findsOneWidget);
      expect(find.text('Renombrar Mascota'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
