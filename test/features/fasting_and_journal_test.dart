import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/database/daos/fasting_dao.dart';
import 'package:nb_selfcare/core/database/daos/journal_dao.dart';
import 'package:nb_selfcare/core/database/daos/pet_dao.dart';
import 'package:nb_selfcare/core/database/daos/user_profile_dao.dart';
import 'package:nb_selfcare/core/domain/enums.dart';
import 'package:nb_selfcare/core/l10n/l10n.dart';
import 'package:nb_selfcare/core/services/backup_service.dart';
import 'package:nb_selfcare/core/services/cross_analytics_engine.dart';
import 'package:nb_selfcare/features/fasting/application/fasting_service.dart';
import 'package:nb_selfcare/features/fasting/presentation/fasting_screen.dart';
import 'package:nb_selfcare/features/journal/application/journal_service.dart';
import 'package:nb_selfcare/features/profile_goals/presentation/app_settings_screen.dart';
import 'package:nb_selfcare/features/profile_goals/presentation/perfil_yo_screen.dart';
import 'package:nb_selfcare/features/today/presentation/hoy_screen.dart';
import 'package:nb_selfcare/shared/theme/sc_theme.dart';
import 'package:nb_selfcare/shared/utils/date_time_extensions.dart';

import '../support/test_container.dart';
import '../support/widget_test_helpers.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late PetDao petDao;
  late FastingDao fastingDao;
  late JournalDao journalDao;
  late CrossAnalyticsEngine crossAnalyticsEngine;
  late BackupService backupService;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    petDao = PetDao(db);
    fastingDao = FastingDao(db);
    journalDao = JournalDao(db);
    crossAnalyticsEngine = CrossAnalyticsEngine(db);
    backupService = BackupService(db, temporaryDirectory: () async => Directory.systemTemp);

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
            coinsBalance: drift.Value(100),
            currentStreakDays: drift.Value(3),
            streakShieldsAvailable: drift.Value(1),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('CrossAnalyticsEngine (Pearson R)', () {
    test('Calcula correlación positiva perfecta r = 1.0', () {
      final x = [1.0, 2.0, 3.0, 4.0, 5.0];
      final y = [2.0, 4.0, 6.0, 8.0, 10.0];
      final r = CrossAnalyticsEngine.calculatePearsonR(x, y);
      expect((r - 1.0).abs() < 0.0001, isTrue);
    });

    test('Calcula correlación negativa perfecta r = -1.0', () {
      final x = [1.0, 2.0, 3.0, 4.0, 5.0];
      final y = [10.0, 8.0, 6.0, 4.0, 2.0];
      final r = CrossAnalyticsEngine.calculatePearsonR(x, y);
      expect((r - (-1.0)).abs() < 0.0001, isTrue);
    });

    test('Devuelve 0.0 ante series constantes o tamaño insuficiente', () {
      expect(CrossAnalyticsEngine.calculatePearsonR([1.0], [2.0]), equals(0.0));
      expect(CrossAnalyticsEngine.calculatePearsonR([1.0, 2.0], [3.0]), equals(0.0));
      expect(CrossAnalyticsEngine.calculatePearsonR([5.0, 5.0, 5.0], [1.0, 2.0, 3.0]), equals(0.0));
    });

    test('CrossCorrelationInsight describe la intensidad correctamente', () {
      const insightFuerte = CrossCorrelationInsight(
        title: 'Estrés vs Carbohidratos',
        description: 'Test',
        correlationR: 0.75,
        sampleSize: 15,
        domain: 'stress_vs_carbs',
      );
      expect(insightFuerte.strengthLabel, equals('Correlación Fuerte'));

      const insightNula = CrossCorrelationInsight(
        title: 'Pasos vs Grasa',
        description: 'Test',
        correlationR: 0.05,
        sampleSize: 15,
        domain: 'steps_vs_fat',
      );
      expect(insightNula.strengthLabel, equals('Sin relación lineal significativa'));
    });
  });

  group('FastingDao and FastingScreen', () {
    test('Iniciar y completar ayuno de ≥ 14 horas otorga +20 monedas Nibi', () async {
      final DateTime now = DateTime(2026, 10, 23, 12);
      final ProviderContainer container = createTestContainer(db, now: now);
      addTearDown(container.dispose);
      final FastingService service = container.read(fastingServiceProvider);

      final sessionId = await service.start(
        protocolName: '16:8',
        targetHours: 16,
        startedAt: now.subtract(const Duration(hours: 16)),
      );

      final active = await fastingDao.getActiveSession();
      expect(active, isNotNull);
      expect(active!.protocolName, equals('16:8'));
      expect(active.targetHours, equals(16));

      // Finalizar sesión de 16h
      final FastFinishResult? completed = await service.finish(sessionId);
      expect(completed, isNotNull);
      expect(completed!.coins, equals(20));
      expect(completed.suggestsRefeedingGuide, isFalse, reason: '16 h < 18 h');

      final updatedSession = await (db.select(db.fastingSessions)..where((tbl) => tbl.id.equals(sessionId))).getSingle();
      expect(updatedSession.isCompleted, isTrue);
      expect(updatedSession.actualEndedAt, isNotNull);

      // Verificar que el saldo de monedas subió de 100 a 120 (+20)
      final pet = await petDao.getPetStatus();
      expect(pet?.coinsBalance, equals(120));
    });

    testWidgets('FastingScreen renderiza temporizador, protocolos y tarjeta informativa', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            fastingDaoProvider.overrideWithValue(fastingDao),
          ],
          child: MaterialApp(
            locale: const Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: ScTheme.build('samsung_dark'),
            home: const FastingScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Ayuno'), findsOneWidget);
      expect(find.text('Empezar ayuno 16:8'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('20:4'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('18:6'), findsOneWidget);
      expect(find.text('20:4'), findsOneWidget);

      // Elegir 18:6 actualiza el botón de inicio.
      await tester.tap(find.text('18:6'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Empezar ayuno 18:6'), -300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Empezar ayuno 18:6'), findsOneWidget);

      // Limpiar timers reactivos de Drift
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('JournalDao and JournalAnalyticsProfileScreen', () {
    test('Insertar entrada en diario otorga +10 monedas Nibi y persiste datos', () async {
      final DateTime now = DateTime(2026, 10, 23, 21);
      final ProviderContainer container = createTestContainer(db, now: now);
      addTearDown(container.dispose);
      final ({int entryId, int coins}) saved = await container.read(journalServiceProvider).save(
        JournalEntriesCompanion(
          dateKey: drift.Value(now.dateKey),
          createdAt: drift.Value(now),
          content: const drift.Value('Hoy me sentí enfocado y con buena recuperación muscular.'),
          moodScore: const drift.Value(5),
          energyLevel: const drift.Value(4),
          stressLevel: const drift.Value(1),
          tagsJson: const drift.Value('["recuperacion"]'),
        ),
      );
      final int id = saved.entryId;

      expect(id, isPositive);
      expect(saved.coins, equals(10));

      final entries = await (db.select(db.journalEntries)..where((tbl) => tbl.id.equals(id))).get();
      expect(entries.length, equals(1));
      expect(entries.first.content, contains('enfocado'));
      expect(entries.first.moodScore, equals(5));

      // Verificar que el saldo de monedas subió de 100 a 110 (+10)
      final pet = await petDao.getPetStatus();
      expect(pet?.coinsBalance, equals(110));
    });

    testWidgets('PerfilYoScreen renderiza identidad y respaldo sin duplicar el Diario', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            journalDaoProvider.overrideWithValue(journalDao),
            crossAnalyticsEngineProvider.overrideWithValue(crossAnalyticsEngine),
            backupServiceProvider.overrideWithValue(backupService),
          ],
          child: routedTestApp(
            theme: ScTheme.build('samsung_dark'),
            home: const PerfilYoScreen(),
            routes: const <String, Widget>{'/ajustes': AppSettingsScreen()},
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(PerfilYoScreen), findsOneWidget);
      expect(find.text('Nathan'), findsOneWidget);
      // El Diario vive exclusivamente en el widget 4×4 de Hoy, jamás en Perfil
      expect(find.text('Diario de Reflexión'), findsNothing);
      expect(find.text('Diario Personal'), findsNothing);
      await tester.tap(find.byTooltip('Ajustes'));
      await tester.pumpAndSettle();
      expect(find.byType(AppSettingsScreen), findsOneWidget);
      expect(find.text('Apariencia'), findsOneWidget);

      // Limpiar timers reactivos de Drift
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('HoyScreen aloja el único widget gigante 4×4 de Diario Personal y guarda entrada (+10 🪙)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final beforePet = await petDao.getPetStatus();
      final int initialCoins = beforePet?.coinsBalance ?? 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            journalDaoProvider.overrideWithValue(journalDao),
          ],
          child: MaterialApp(
            locale: const Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: ScTheme.build('samsung_dark'),
            home: const HoyScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final journalHeader = find.text('Diario Personal');
      await tester.scrollUntilVisible(
        journalHeader,
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(journalHeader, findsOneWidget);

      final textField = find.byType(TextField);
      await tester.ensureVisible(textField);
      await tester.pumpAndSettle();
      await tester.enterText(
        textField,
        'Me siento muy tranquilo y feliz por cuidar mi energía hoy.',
      );
      await tester.pumpAndSettle();

      final saveBtn = find.text('Guardar en mi diario (+10 🪙)');
      await tester.ensureVisible(saveBtn);
      await tester.pumpAndSettle();
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      final savedEntries = await db.select(db.journalEntries).get();
      expect(savedEntries, hasLength(1));
      expect(savedEntries.first.content, contains('tranquilo y feliz'));

      final afterPet = await petDao.getPetStatus();
      expect(afterPet?.coinsBalance, equals(initialCoins + 10));

      // Desmontar ProviderScope para limpiar timers reactivos y el TTL de 120s de TextAssistant
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('BackupService Integrity', () {
    test('Verifica que un archivo inexistente retorne false', () async {
      final bool ok = await backupService.verifyBackupIntegrity('/non/existent/path.sqlite');
      expect(ok, isFalse);
    });

    test('Exporta con VACUUM INTO a directorio temporal y verifica integridad ok', () async {
      final tempDir = Directory.systemTemp.createTempSync('nb_backup_test_');
      try {
        final exportedFile = await db.exportCleanDatabaseBackup(tempDir.path, stamp: DateTime(2026, 10, 26));
        expect(exportedFile.existsSync(), isTrue);

        final bool isValid = await backupService.verifyBackupIntegrity(exportedFile.path);
        expect(isValid, isTrue);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('Restaura respaldo .sqlite en vivo recuperando registros eliminados y FTS5', () async {
      final tempDir = Directory.systemTemp.createTempSync('nb_restore_test_');
      try {
        // 1. Insertar entrada de diario y alimento personalizado antes del respaldo
        await journalDao.insertEntry(
          JournalEntriesCompanion(
            dateKey: const drift.Value('2026-10-20'),
            createdAt: drift.Value(DateTime(2026, 10, 20, 20)),
            content: const drift.Value('Entrada crítica antes del respaldo'),
            moodScore: const drift.Value(5),
            energyLevel: const drift.Value(5),
            stressLevel: const drift.Value(1),
          ),
        );
        await db.into(db.foodItems).insert(
              FoodItemsCompanion.insert(
                name: 'Arepa de choclo artesanal',
                source: FoodSource.userCustom,
                kcalPer100g: 230,
                proteinPer100g: 6,
                carbsPer100g: 38,
                fatPer100g: 6,
              ),
            );

        final exportedFile = await db.exportCleanDatabaseBackup(tempDir.path, stamp: DateTime(2026, 10, 26));

        // 2. Borrar entradas en la base de datos activa
        await db.delete(db.journalEntries).go();
        await db.delete(db.foodItems).go();
        expect(await db.select(db.journalEntries).get(), isEmpty);

        // 3. Restaurar en caliente desde el archivo .sqlite
        final bool restored =
            await backupService.restoreDatabaseFromFile(exportedFile.path);
        expect(restored, isTrue);

        // 4. Verificar que los datos y el índice FTS5 volvieron intactos
        final entries = await db.select(db.journalEntries).get();
        expect(entries, hasLength(1));
        expect(entries.first.content, contains('antes del respaldo'));

        final ftsRows = await db.customSelect(
          'SELECT name FROM food_items_fts WHERE food_items_fts MATCH ?',
          variables: [drift.Variable.withString('choclo*')],
        ).get();
        expect(ftsRows, hasLength(1));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });

  group('CrossAnalyticsEngine (Agregación 1:1 diaria sin producto cartesiano)', () {
    test('Pre-agrega múltiples comidas por día y filtra correlaciones débiles', () async {
      final int foodId = await db.into(db.foodItems).insert(
            FoodItemsCompanion.insert(
              name: 'Avena integral',
              source: FoodSource.usdaSeed,
              kcalPer100g: 370,
              proteinPer100g: 13,
              carbsPer100g: 60,
              fatPer100g: 7,
            ),
          );

      // Poblar 6 días donde mayor estrés coincide linealmente con más carbohidratos (3 comidas/día)
      for (int i = 1; i <= 6; i++) {
        final String dayKey = '2026-10-0$i';
        await db.into(db.journalEntries).insert(
              JournalEntriesCompanion.insert(
                dateKey: dayKey,
                content: 'Día $i',
                moodScore: const drift.Value(4),
                energyLevel: const drift.Value(4),
                stressLevel: drift.Value(i.clamp(1, 5)),
              ),
            );

        for (int meal = 0; meal < 3; meal++) {
          final double carbs = (i * 25).toDouble();
          await db.into(db.foodLogs).insert(
                FoodLogsCompanion.insert(
                  dateKey: dayKey,
                  mealType: MealType.lunch,
                  foodItemId: foodId,
                  gramsConsumed: 100,
                  totalKcal: carbs * 4,
                  totalProteinG: 10,
                  totalCarbsG: carbs,
                  totalFatG: 5,
                  totalFiberG: 4,
                  totalSodiumMg: 50,
                  totalPotassiumMg: 150,
                  totalMagnesiumMg: 30,
                ),
              );
        }
      }

      // Con solo 6 días únicos (aunque haya 18 registros en food_logs), no debe inflar n >= 10
      expect(await crossAnalyticsEngine.computeInsights(), isEmpty);

      // Completar hasta 12 días únicos (36 comidas totales)
      for (int i = 7; i <= 12; i++) {
        final String dayKey = '2026-10-${i.toString().padLeft(2, '0')}';
        final int stress = (((i - 1) * 4) / 11 + 1).round().clamp(1, 5);
        await db.into(db.journalEntries).insert(
              JournalEntriesCompanion.insert(
                dateKey: dayKey,
                content: 'Día $i',
                moodScore: const drift.Value(4),
                energyLevel: const drift.Value(4),
                stressLevel: drift.Value(stress),
              ),
            );

        for (int meal = 0; meal < 3; meal++) {
          final double carbs = (stress * 30).toDouble();
          await db.into(db.foodLogs).insert(
                FoodLogsCompanion.insert(
                  dateKey: dayKey,
                  mealType: MealType.lunch,
                  foodItemId: foodId,
                  gramsConsumed: 100,
                  totalKcal: carbs * 4,
                  totalProteinG: 10,
                  totalCarbsG: carbs,
                  totalFatG: 5,
                  totalFiberG: 4,
                  totalSodiumMg: 50,
                  totalPotassiumMg: 150,
                  totalMagnesiumMg: 30,
                ),
              );
        }
      }

      final insights = await crossAnalyticsEngine.computeInsights();
      final stressInsight = insights.where((e) => e.domain == 'stress_vs_carbs').toList();
      expect(stressInsight, hasLength(1));
      // Debe contar exactamente 12 días únicos, jamás 36 filas infladas por JOIN cartesiano
      expect(stressInsight.first.sampleSize, equals(12));
      expect(stressInsight.first.correlationR, greaterThan(0.85));
    });
  });
}
