import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/database/daos/fasting_dao.dart';
import 'package:nb_selfcare/core/database/daos/food_dao.dart';
import 'package:nb_selfcare/core/database/daos/hydration_dao.dart';
import 'package:nb_selfcare/core/database/daos/pet_dao.dart';
import 'package:nb_selfcare/core/database/daos/user_profile_dao.dart';
import 'package:nb_selfcare/core/domain/enums.dart';
import 'package:nb_selfcare/core/l10n/l10n.dart';
import 'package:nb_selfcare/core/services/open_food_facts_service.dart';
import 'package:nb_selfcare/features/nutrition_hydration/application/hydration_service.dart';
import 'package:nb_selfcare/features/nutrition_hydration/presentation/nutricion_screen.dart';
import 'package:nb_selfcare/shared/theme/sc_theme.dart';
import 'package:nb_selfcare/shared/utils/current_date_provider.dart';

import '../support/test_container.dart';

class _FixedDateNotifier extends CurrentDateNotifier {
  _FixedDateNotifier(this._fixed);
  final DateTime _fixed;

  @override
  DateTime build() => _fixed;
}

void main() {
  late AppDatabase db;
  late FoodDao foodDao;
  late PetDao petDao;
  late HydrationDao hydrationDao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    foodDao = FoodDao(db);
    petDao = PetDao(db);
    hydrationDao = HydrationDao(db);

    // Perfil inicial
    await UserProfileDao(db).createProfile(
      UserProfilesCompanion(
        name: const drift.Value('Nathan'),
        birthDate: drift.Value(DateTime(1998, 5, 20)),
        biologicalSex: const drift.Value(BiologicalSex.male),
        heightCm: const drift.Value(178.0),
        targetWeightKg: const drift.Value(72.0),
        weeklyGoalRateKg: const drift.Value(-0.5),
        dailyWaterGoalMl: const drift.Value(2000),
        dailyStepsGoal: const drift.Value(8000),
        dailySleepGoalHours: const drift.Value(7.5),
      ),
    );

    // Mascota Nibi inicial
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

  group('OpenFoodFactsService & FTS5 Cache', () {
    test('Resuelve código de barras desde Open Food Facts y lo persiste en SQLite', () async {
      final mockHttpClient = MockClient((request) async {
        if (request.url.path.contains('7702001041400')) {
          final sampleOffJson = {
            'status': 1,
            'product': {
              'product_name_es': 'Avena en Hojuelas Integral',
              'brands': 'Quaker',
              'nutriscore_grade': 'a',
              'nutriments': {
                'energy-kcal_100g': 375.0,
                'proteins_100g': 13.5,
                'carbohydrates_100g': 67.0,
                'fat_100g': 7.0,
                'fiber_100g': 10.0,
                'sodium_100g': 0.005, // 5 mg
                'potassium_100g': 0.420, // 420 mg
                'magnesium_100g': 0.138, // 138 mg
              },
            },
          };
          return http.Response(jsonEncode(sampleOffJson), 200);
        }
        return http.Response('{"status": 0}', 404);
      });

      final offService = OpenFoodFactsService(foodDao, httpClient: mockHttpClient);

      final food = await offService.resolveBarcode('7702001041400');
      expect(food, isNotNull);
      expect(food!.name, equals('Avena en Hojuelas Integral'));
      expect(food.kcalPer100g, equals(375.0));
      expect(food.proteinPer100g, equals(13.5));
      expect(food.sodiumMgPer100g, closeTo(5.0, 0.1));
      expect(food.potassiumMgPer100g, closeTo(420.0, 1.0));
      expect(food.magnesiumMgPer100g, closeTo(138.0, 1.0));

      // Verificar que se guardó en SQLite y se encuentra inmediatamente en la caché
      final cached = await foodDao.getByBarcode('7702001041400');
      expect(cached, isNotNull);
      expect(cached!.name, equals('Avena en Hojuelas Integral'));

      // Verificar que es indexado y localizable por FTS5
      final ftsResults = await foodDao.searchFood('hojuelas');
      expect(ftsResults, isNotEmpty);
      expect(ftsResults.first.barcode, equals('7702001041400'));
    });
  });

  group('Combos Caseros con Escalador Proporcional', () {
    test('Crea combo y lo registra escalado al 1.5x en food_logs', () async {
      // 1. Insertar dos ingredientes base
      final huevoId = await foodDao.insertFood(
        const FoodItemsCompanion(
          name: drift.Value('Huevo Entero'),
          source: drift.Value(FoodSource.usdaSeed),
          kcalPer100g: drift.Value(143.0),
          proteinPer100g: drift.Value(12.6),
          carbsPer100g: drift.Value(0.7),
          fatPer100g: drift.Value(9.5),
        ),
      );

      final aguacateId = await foodDao.insertFood(
        const FoodItemsCompanion(
          name: drift.Value('Aguacate Hass'),
          source: drift.Value(FoodSource.usdaSeed),
          kcalPer100g: drift.Value(160.0),
          proteinPer100g: drift.Value(2.0),
          carbsPer100g: drift.Value(8.5),
          fatPer100g: drift.Value(14.7),
        ),
      );

      // 2. Crear combo con 100g de huevo y 50g de aguacate
      final comboId = await foodDao.createCombo(
        name: 'Desayuno Keto',
        defaultMealType: MealType.breakfast,
        itemsWithGrams: [
          MapEntry(huevoId, 100.0),
          MapEntry(aguacateId, 50.0),
        ],
      );

      // 3. Registrar con escalador de 1.5x
      final loggedIds = await foodDao.logCombo(
        comboId: comboId,
        multiplier: 1.5,
        dateKey: '2026-10-23',
        mealType: MealType.breakfast,
      );

      expect(loggedIds, hasLength(2));

      // 4. Verificar logs escalados:
      // Huevo 100g * 1.5 = 150g -> 143 * 1.5 = 214.5 kcal
      // Aguacate 50g * 1.5 = 75g -> 160 * 0.75 = 120.0 kcal
      final logs = await foodDao.getLogsForDateAndMeal('2026-10-23', MealType.breakfast);
      expect(logs, hasLength(2));

      final huevoLog = logs.firstWhere((l) => l.foodItemId == huevoId);
      expect(huevoLog.gramsConsumed, equals(150.0));
      expect(huevoLog.totalKcal, closeTo(214.5, 0.1));

      final aguacateLog = logs.firstWhere((l) => l.foodItemId == aguacateId);
      expect(aguacateLog.gramsConsumed, equals(75.0));
      expect(aguacateLog.totalKcal, closeTo(120.0, 0.1));
    });
  });

  group('Flujo < 15s: Repetir Comida de Ayer', () {
    test('Copia todos los alimentos del bloque del día anterior con un toque', () async {
      final foodId = await foodDao.insertFood(
        const FoodItemsCompanion(
          name: drift.Value('Pechuga de Pollo'),
          source: drift.Value(FoodSource.usdaSeed),
          kcalPer100g: drift.Value(165.0),
          proteinPer100g: drift.Value(31.0),
          carbsPer100g: drift.Value(0.0),
          fatPer100g: drift.Value(3.6),
        ),
      );

      // Comida registrada ayer
      await foodDao.logFood(
        FoodLogsCompanion(
          dateKey: const drift.Value('2026-10-22'),
          loggedAt: drift.Value(DateTime(2026, 10, 22, 13, 0)),
          mealType: const drift.Value(MealType.lunch),
          foodItemId: drift.Value(foodId),
          gramsConsumed: const drift.Value(200.0),
          portionMultiplier: const drift.Value(1.0),
          totalKcal: const drift.Value(330.0),
          totalProteinG: const drift.Value(62.0),
          totalCarbsG: const drift.Value(0.0),
          totalFatG: const drift.Value(7.2),
          totalFiberG: const drift.Value(0.0),
          totalSodiumMg: const drift.Value(140.0),
          totalPotassiumMg: const drift.Value(500.0),
          totalMagnesiumMg: const drift.Value(50.0),
        ),
      );

      // Repetir en el día de hoy
      final repeated = await foodDao.repeatMealFromYesterday(
        fromDateKey: '2026-10-22',
        toDateKey: '2026-10-23',
        mealType: MealType.lunch,
      );

      expect(repeated, hasLength(1));

      final todayLogs = await foodDao.getLogsForDateAndMeal('2026-10-23', MealType.lunch);
      expect(todayLogs, hasLength(1));
      expect(todayLogs.first.gramsConsumed, equals(200.0));
      expect(todayLogs.first.totalKcal, equals(330.0));
    });
  });

  group('Registro Atómico de Hidratación y Recompensas', () {
    test('Registrar vasos acumula mililitros y otorga recompensa al alcanzar la meta diaria', () async {
      final ProviderContainer container = createTestContainer(db);
      addTearDown(container.dispose);
      final HydrationService service = container.read(hydrationServiceProvider);

      // 3 vasos de 500 ml = 1500 ml: todavía no alcanza la meta de 2000 ml del perfil.
      for (int i = 0; i < 3; i++) {
        await service.logGlass(dateKey: '2026-10-23', volumeMl: 500);
      }
      var pet = await petDao.getPetStatus();
      expect(pet!.coinsBalance, equals(50));

      // Cuarto vaso -> 2000 ml alcanzados -> otorga +15 monedas (50 + 15 = 65)
      final WaterLogResult goal = await service.logGlass(dateKey: '2026-10-23', volumeMl: 500);
      expect(goal.totalMl, equals(2000));
      expect(goal.coins, equals(15));
      pet = await petDao.getPetStatus();
      expect(pet!.coinsBalance, equals(65));

      // Un quinto vaso no debe otorgar doble recompensa (idempotencia diaria)
      final WaterLogResult extra = await service.logGlass(dateKey: '2026-10-23', volumeMl: 250);
      expect(extra.coins, equals(0));
      pet = await petDao.getPetStatus();
      expect(pet!.coinsBalance, equals(65));
      expect(await hydrationDao.getTotalWaterMl('2026-10-23'), equals(2250));
    });
  });

  group('NutricionScreen ("Comer") y Subpáginas rediseñadas', () {
    testWidgets(
      'Renderiza Comer sin overflows en Material You y Modo Papel NXTPAPER con fecha corta DD/MM/YYYY',
      (WidgetTester tester) async {
        // Ancho compacto realista de móvil (390 px lógicos) para detectar cualquier corte o overflow
        tester.view.physicalSize = const Size(390, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final FastingDao fastingDao = FastingDao(db);
        final DateTime fixedDate = DateTime(2026, 10, 24, 13, 0);

        for (final String themeId in <String>[
          'samsung_dark',
          'nxtpaper_eink',
        ]) {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                appDatabaseProvider.overrideWithValue(db),
                foodDaoProvider.overrideWithValue(foodDao),
                hydrationDaoProvider.overrideWithValue(hydrationDao),
                petDaoProvider.overrideWithValue(petDao),
                fastingDaoProvider.overrideWithValue(fastingDao),
                currentDateProvider.overrideWith(
                  () => _FixedDateNotifier(fixedDate),
                ),
              ],
              child: MaterialApp(
                locale: const Locale('es'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: ScTheme.build(themeId),
                home: const NutricionScreen(),
              ),
            ),
          );

          await tester.pumpAndSettle();

          expect(find.text('Comida'), findsOneWidget);
          expect(find.text('Sábado, 24 de octubre'), findsOneWidget);
          expect(find.text('Buscar alimento o marca'), findsOneWidget);
          expect(find.text('Escribir comida').first, findsOneWidget);
          expect(find.text('Mis combos'), findsOneWidget);
          expect(find.text('Ayuno'), findsOneWidget);
          expect(find.text('Crear alimento'), findsOneWidget);
          expect(find.text('Balance energético'), findsOneWidget);

          // Desplazar hasta el bloque de Hidratación para validar toda la lista sin overflows
          final Finder waterTitle = find.text('Agua de hoy');
          await tester.scrollUntilVisible(
            waterTitle,
            300,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(waterTitle, findsOneWidget);
          expect(find.text('A medida'), findsOneWidget);

          // Reiniciar árbol entre temas para volver al inicio del scroll
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(milliseconds: 50));
        }
      },
    );

    testWidgets(
      'Subpáginas FoodSearchModal y FoodDetailSheet muestran Nutri-Score, Honestidad de Datos y registran alimento',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(412, 920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final FastingDao fastingDao = FastingDao(db);
        final DateTime fixedDate = DateTime(2026, 10, 24, 13, 0);

        // Insertar un producto comercial con Nutri-Score B y sin potasio/magnesio reportados
        await foodDao.insertFood(
          const FoodItemsCompanion(
            name: drift.Value('Yogur Griego Artesanal'),
            brand: drift.Value('Alpina'),
            source: drift.Value(FoodSource.openFoodFacts),
            nutriScore: drift.Value('B'),
            defaultServingGrams: drift.Value(150.0),
            servingLabel: drift.Value('1 vaso'),
            kcalPer100g: drift.Value(95.0),
            proteinPer100g: drift.Value(10.0),
            carbsPer100g: drift.Value(4.0),
            fatPer100g: drift.Value(4.2),
            sodiumMgPer100g: drift.Value(45.0),
            potassiumMgPer100g: drift.Value(0.0),
            magnesiumMgPer100g: drift.Value(0.0),
            isFavorite: drift.Value(true),
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              foodDaoProvider.overrideWithValue(foodDao),
              hydrationDaoProvider.overrideWithValue(hydrationDao),
              petDaoProvider.overrideWithValue(petDao),
              fastingDaoProvider.overrideWithValue(fastingDao),
              currentDateProvider.overrideWith(
                () => _FixedDateNotifier(fixedDate),
              ),
            ],
            child: MaterialApp(
              locale: const Locale('es'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: ScTheme.build('samsung_dark'),
              home: const NutricionScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Abrir subpágina de búsqueda FTS5
        await tester.tap(find.text('Buscar alimento o marca'));
        await tester.pumpAndSettle();

        expect(find.text('Añadir alimento'), findsOneWidget);
        expect(find.text('Yogur Griego Artesanal'), findsOneWidget);
        expect(find.text('Nutri-Score B'), findsOneWidget);

        // Abrir subpágina de detalle al tocar la tarjeta del alimento
        await tester.tap(find.text('Yogur Griego Artesanal'));
        await tester.pumpAndSettle();

        // Regla de Honestidad de Datos (potasio y magnesio no reportados en etiqueta)
        expect(find.text('Dato no reportado'), findsNWidgets(2));

        // Registrar la porción de 150 g en el momento seleccionado
        final Finder registerBtn = find.textContaining('Registrar en ');
        await tester.ensureVisible(registerBtn);
        await tester.pumpAndSettle();
        await tester.tap(registerBtn);
        await tester.pumpAndSettle();

        final List<FoodLog> logs = await (db.select(db.foodLogs)
              ..where((tbl) => tbl.dateKey.equals('2026-10-24')))
            .get();
        expect(logs, hasLength(1));
        expect(logs.first.gramsConsumed, equals(150.0));

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      'Subpágina CustomWaterSheet registra vaso personalizado desde Hidratación en Comer',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(412, 920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final FastingDao fastingDao = FastingDao(db);
        final DateTime fixedDate = DateTime(2026, 10, 24, 13, 0);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              foodDaoProvider.overrideWithValue(foodDao),
              hydrationDaoProvider.overrideWithValue(hydrationDao),
              petDaoProvider.overrideWithValue(petDao),
              fastingDaoProvider.overrideWithValue(fastingDao),
              currentDateProvider.overrideWith(
                () => _FixedDateNotifier(fixedDate),
              ),
            ],
            child: MaterialApp(
              locale: const Locale('es'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: ScTheme.build('samsung_dark'),
              home: const NutricionScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final Finder customWaterBtn = find.text('A medida');
        await tester.scrollUntilVisible(
          customWaterBtn,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        await tester.tap(customWaterBtn);
        await tester.pumpAndSettle();

        expect(find.text('Vaso o botella a medida'), findsOneWidget);
        await tester.tap(find.text('330 ml'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Registrar +330 ml'));
        await tester.pumpAndSettle();

        final List<HydrationLog> waterLogs = await (db.select(db.hydrationLogs)
              ..where((tbl) => tbl.dateKey.equals('2026-10-24')))
            .get();
        final int totalWater =
            waterLogs.fold(0, (int s, HydrationLog l) => s + l.volumeMl);
        expect(totalWater, equals(330));

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      'Subpáginas Escribir comida, Mis Combos y Crear alimento abren sin overflows en 390px',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final FastingDao fastingDao = FastingDao(db);
        final DateTime fixedDate = DateTime(2026, 10, 24, 9, 0);

        final int avenaId = await foodDao.insertFood(
          const FoodItemsCompanion(
            name: drift.Value('Avena Integral'),
            source: drift.Value(FoodSource.usdaSeed),
            kcalPer100g: drift.Value(375.0),
            proteinPer100g: drift.Value(13.0),
            carbsPer100g: drift.Value(66.0),
            fatPer100g: drift.Value(7.0),
          ),
        );
        await foodDao.createCombo(
          name: 'Desayuno Avena Base',
          defaultMealType: MealType.breakfast,
          itemsWithGrams: <MapEntry<int, double>>[
            MapEntry<int, double>(avenaId, 80.0),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              foodDaoProvider.overrideWithValue(foodDao),
              hydrationDaoProvider.overrideWithValue(hydrationDao),
              petDaoProvider.overrideWithValue(petDao),
              fastingDaoProvider.overrideWithValue(fastingDao),
              currentDateProvider.overrideWith(
                () => _FixedDateNotifier(fixedDate),
              ),
            ],
            child: MaterialApp(
              locale: const Locale('es'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: ScTheme.build('samsung_dark'),
              home: const NutricionScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Escribir comida
        await tester.tap(find.text('Escribir comida').first);
        await tester.pumpAndSettle();
        expect(find.text('Escribir comida'), findsWidgets);
        await tester.tap(find.byTooltip('Cerrar'));
        await tester.pumpAndSettle();

        // 2. Mis Combos
        await tester.tap(find.text('Mis combos'));
        await tester.pumpAndSettle();
        expect(find.text('Mis combos'), findsWidgets);
        expect(find.text('Desayuno Avena Base'), findsOneWidget);
        await tester.tap(find.byTooltip('Cerrar'));
        await tester.pumpAndSettle();

        // 3. Crear alimento
        await tester.tap(find.text('Crear alimento'));
        await tester.pumpAndSettle();
        expect(find.text('Crear alimento propio'), findsOneWidget);
        await tester.tap(find.byTooltip('Cerrar'));
        await tester.pumpAndSettle();

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );
  });
}
