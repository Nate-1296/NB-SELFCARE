import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/app.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/database/daos/pet_dao.dart';
import 'package:nb_selfcare/core/database/daos/user_profile_dao.dart';
import 'package:nb_selfcare/features/dashboard/presentation/dashboard_screen.dart';
import 'package:nb_selfcare/features/dashboard/presentation/widgets/pet_habitat_widget.dart';
import 'package:nb_selfcare/features/pet_gamification/presentation/shop_modal.dart';
import 'package:nb_selfcare/features/pet_gamification/presentation/widgets/procedural_pet_canvas.dart';

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

  group('ProceduralPetCanvas (CustomPainter)', () {
    testWidgets('Renderiza todas las variantes de estado sin errores visuales', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                // Variante 1: Normal
                ProceduralPetCanvas(size: 100),
                // Variante 2: Cetosis + Buena Hidratación + Buen Sueño
                ProceduralPetCanvas(
                  isFastingKetosis: true,
                  hydrationRatio: 1.0,
                  sleepHours: 8.0,
                  size: 100,
                ),
                // Variante 3: Pesaje en vivo + Sombrero de Chef
                ProceduralPetCanvas(
                  isWeighingIn: true,
                  equippedHatId: 'hat_chef',
                  size: 100,
                ),
                // Variante 4: Modo Papel E-Ink (NXTPAPER)
                ProceduralPetCanvas(
                  isEink: true,
                  equippedHatId: 'hat_crown',
                  size: 100,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(ProceduralPetCanvas), findsNWidgets(4));
    });
  });

  group('PetHabitatWidget & ShopModal', () {
    testWidgets('Abre la Tienda desde el Hábitat y compra un Escudo de Racha', (tester) async {
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

      // Verificar que el Hábitat de Nibi está presente en el Dashboard
      expect(find.byType(PetHabitatWidget), findsOneWidget);
      expect(find.text('Nibi · Tu Compañero de Hábitos'), findsOneWidget);

      // Tocar botón de Tienda en el Hábitat
      final shopBtn = find.text('Tienda');
      expect(shopBtn, findsOneWidget);
      await tester.tap(shopBtn);
      await tester.pumpAndSettle();

      // Debe abrirse ShopModal
      expect(find.byType(ShopModal), findsOneWidget);
      expect(find.text('Tienda de Recompensas'), findsOneWidget);

      // Comprar Escudo Diario de Racha (cuesta 40 monedas)
      final buyShieldBtn = find.widgetWithText(FilledButton, '40');
      expect(buyShieldBtn, findsOneWidget);
      await tester.tap(buyShieldBtn);
      await tester.pumpAndSettle();

      // Verificar que el balance de monedas disminuyó de 200 a 160
      final updatedPet = await petDao.getPetStatus();
      expect(updatedPet!.coinsBalance, equals(160));
      // Y los escudos disponibles aumentaron de 1 a 2
      expect(updatedPet.streakShieldsAvailable, equals(2));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('DashboardScreen unifica macro rings, bento grid de agua y peso', (tester) async {
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

      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.text('Calorías y Balance Nutricional'), findsOneWidget);
      expect(find.text('Agua de hoy'), findsOneWidget);
      expect(find.text('Acciones Rápidas (1 Toque)'), findsOneWidget);

      // Tocar botón rápido de agua +250ml
      final addWaterBtn = find.text('+250ml');
      expect(addWaterBtn, findsOneWidget);
      await tester.tap(addWaterBtn);
      await tester.pumpAndSettle();

      // Verificar que se registró en SQLite
      final totalWater = await db.select(db.hydrationLogs).get();
      expect(totalWater, hasLength(1));
      expect(totalWater.first.volumeMl, equals(250));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
