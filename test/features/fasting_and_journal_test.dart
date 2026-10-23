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
import 'package:nb_selfcare/core/services/backup_service.dart';
import 'package:nb_selfcare/core/services/cross_analytics_engine.dart';
import 'package:nb_selfcare/features/fasting/presentation/fasting_screen.dart';
import 'package:nb_selfcare/features/journal_analytics/presentation/journal_analytics_profile_screen.dart';
import 'package:nb_selfcare/shared/utils/date_time_extensions.dart';

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
    fastingDao = FastingDao(db, petDao);
    journalDao = JournalDao(db, petDao);
    crossAnalyticsEngine = CrossAnalyticsEngine(db);
    backupService = BackupService(db);

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
      final startedAt = DateTime.now().subtract(const Duration(hours: 16));
      final sessionId = await fastingDao.startFast(
        protocolName: '16:8',
        targetHours: 16,
        startedAt: startedAt,
      );

      final active = await fastingDao.getActiveSession();
      expect(active, isNotNull);
      expect(active!.protocolName, equals('16:8'));
      expect(active.targetHours, equals(16));

      // Finalizar sesión de 16h
      final completed = await fastingDao.endFast(sessionId: sessionId, notes: 'Sensación de energía');
      expect(completed, isTrue);

      final updatedSession = await (db.select(db.fastingSessions)..where((tbl) => tbl.id.equals(sessionId))).getSingle();
      expect(updatedSession.isCompleted, isTrue);
      expect(updatedSession.actualEndedAt, isNotNull);

      // Verificar que el saldo de monedas subió de 100 a 120 (+20)
      final pet = await petDao.getPetStatus();
      expect(pet?.coinsBalance, equals(120));
    });

    testWidgets('FastingScreen renderiza temporizador, protocolos y tarjeta informativa', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            fastingDaoProvider.overrideWithValue(fastingDao),
          ],
          child: const MaterialApp(
            home: FastingScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Ayuno Intermitente y Cronobiología'), findsOneWidget);
      expect(find.text('Temporizador de Ayuno'), findsOneWidget);
      expect(find.text('16:8 (16h)'), findsOneWidget);
      expect(find.text('18:6 (18h)'), findsOneWidget);
      expect(find.text('20:4 (20h)'), findsOneWidget);
      expect(find.text('OMAD 23:1 (23h)'), findsOneWidget);
      expect(find.text('Iniciar Ayuno de 16 Horas'), findsOneWidget);

      // Limpiar timers reactivos de Drift
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('JournalDao and JournalAnalyticsProfileScreen', () {
    test('Insertar entrada en diario otorga +10 monedas Nibi y persiste datos', () async {
      final now = DateTime.now();
      final id = await journalDao.insertEntry(
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

      expect(id, isPositive);

      final entries = await (db.select(db.journalEntries)..where((tbl) => tbl.id.equals(id))).get();
      expect(entries.length, equals(1));
      expect(entries.first.content, contains('enfocado'));
      expect(entries.first.moodScore, equals(5));

      // Verificar que el saldo de monedas subió de 100 a 110 (+10)
      final pet = await petDao.getPetStatus();
      expect(pet?.coinsBalance, equals(110));
    });

    testWidgets('JournalAnalyticsProfileScreen renderiza pestañas y perfil vivo', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            journalDaoProvider.overrideWithValue(journalDao),
            crossAnalyticsEngineProvider.overrideWithValue(crossAnalyticsEngine),
            backupServiceProvider.overrideWithValue(backupService),
          ],
          child: const MaterialApp(
            home: JournalAnalyticsProfileScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Diario, Analítica y Perfil'), findsOneWidget);
      expect(find.text('Diario'), findsOneWidget);
      expect(find.text('Analítica'), findsOneWidget);
      expect(find.text('Perfil'), findsOneWidget);
      expect(find.text('Guardar Entrada en SQLite'), findsOneWidget);

      // Cambiar a la pestaña de Perfil
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();

      expect(find.text('Nathan'), findsOneWidget);
      expect(find.text('Portabilidad Total y Copia de Seguridad'), findsOneWidget);
      expect(find.text('Exportar y Compartir .sqlite'), findsOneWidget);

      // Limpiar timers reactivos de Drift
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
        final exportedFile = await db.exportCleanDatabaseBackup(tempDir.path);
        expect(exportedFile.existsSync(), isTrue);

        final bool isValid = await backupService.verifyBackupIntegrity(exportedFile.path);
        expect(isValid, isTrue);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
