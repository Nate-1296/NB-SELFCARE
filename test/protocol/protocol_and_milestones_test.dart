import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/database/daos/milestone_dao.dart';
import 'package:nb_selfcare/core/database/daos/protocol_dao.dart';
import 'package:nb_selfcare/core/domain/enums.dart';
import 'package:nb_selfcare/core/services/clinical_report_pdf_service.dart';

void main() {
  late AppDatabase db;
  late ProtocolDao protocolDao;
  late MilestoneDao milestoneDao;
  late ClinicalReportPdfService pdfService;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    protocolDao = ProtocolDao(db);
    milestoneDao = MilestoneDao(db);
    pdfService = ClinicalReportPdfService();
  });

  tearDown(() async {
    await db.close();
  });

  group('Fase 7: Protocolo, Mini-Hitos y Reporte Clínico PDF', () {
    test('ProtocolDao: Guarda y recupera protocolo maestro semanal', () async {
      await protocolDao.saveActiveProtocol(
        planName: 'Protocolo de Definición Inteligente',
        fastingDaysBitmask: '1,2,3,4,5',
        workoutSlotsJson: '{"days": [1, 3, 5], "time": "mañana"}',
        dietArchetype: 'mediterranean',
      );

      final ProtocolPlan? active = await protocolDao.getActiveProtocol();
      expect(active, isNotNull);
      expect(active!.planName, equals('Protocolo de Definición Inteligente'));
      expect(active.dietArchetype, equals('mediterranean'));
      expect(active.fastingDaysBitmask, equals('1,2,3,4,5'));
      expect(active.workoutSlotsJson, contains('"days": [1, 3, 5]'));
    });

    test('MilestoneDao: Genera hitos escalonados de 1.5 kg hacia la meta', () async {
      // Usuario de 80.0 kg con meta de 75.0 kg (diferencia 5.0 kg)
      // 5.0 / 1.5 = 3.33 -> 4 hitos: 78.5, 77.0, 75.5, 75.0
      await milestoneDao.generateMilestones(
        currentWeightKg: 80.0,
        targetWeightKg: 75.0,
        stepKg: 1.5,
      );

      final List<MilestoneGoal> milestones = await milestoneDao.getMilestones();
      expect(milestones.length, equals(4));

      expect(milestones[0].milestoneOrder, equals(1));
      expect(milestones[0].targetWeightKg, equals(78.5));
      expect(milestones[0].isCompleted, isFalse);

      expect(milestones[1].milestoneOrder, equals(2));
      expect(milestones[1].targetWeightKg, equals(77.0));

      expect(milestones[2].milestoneOrder, equals(3));
      expect(milestones[2].targetWeightKg, equals(75.5));

      expect(milestones[3].milestoneOrder, equals(4));
      expect(milestones[3].targetWeightKg, equals(75.0));
    });

    test('MilestoneDao: Marca un hito como completado con timestamp', () async {
      await milestoneDao.generateMilestones(
        currentWeightKg: 80.0,
        targetWeightKg: 78.0,
        stepKg: 1.5,
      );

      List<MilestoneGoal> milestones = await milestoneDao.getMilestones();
      expect(milestones.first.isCompleted, isFalse);

      final DateTime achievementTime = DateTime(2026, 10, 26, 12, 0);
      await milestoneDao.markCompleted(milestones.first.id, achievementTime);

      milestones = await milestoneDao.getMilestones();
      expect(milestones.first.isCompleted, isTrue);
      expect(milestones.first.completedAt, equals(achievementTime));
    });

    test('MilestoneDao: Si la diferencia es mínima (<0.5 kg), crea un solo hito', () async {
      await milestoneDao.generateMilestones(
        currentWeightKg: 70.2,
        targetWeightKg: 70.0,
        stepKg: 1.5,
      );

      final List<MilestoneGoal> milestones = await milestoneDao.getMilestones();
      expect(milestones.length, equals(1));
      expect(milestones.first.targetWeightKg, equals(70.0));
    });

    test('ClinicalReportPdfService: Genera bytes de informe clínico PDF A4 formal', () async {
      final UserProfile dummyProfile = UserProfile(
        id: 1,
        name: 'Carlos Ruiz',
        birthDate: DateTime(1992, 5, 14),
        biologicalSex: BiologicalSex.male,
        heightCm: 178.0,
        targetWeightKg: 74.0,
        weeklyGoalRateKg: -0.4,
        dailyWaterGoalMl: 2500,
        dailyStepsGoal: 10000,
        dailySleepGoalHours: 8.0,
        currentAdaptiveTdeeKcal: 2150,
        themeMode: 'system',
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
      );

      final BodyMeasurement dummyMeasurement = BodyMeasurement(
        id: 1,
        measuredAt: DateTime.now(),
        dateKey: '2026-10-26',
        source: MeasurementSource.miScale2Ble,
        weightKg: 76.8,
        trendWeightKg: 77.1,
        bmi: 24.2,
        bodyFatPercentage: 16.5,
        muscleMassKg: 61.2,
        waterPercentage: 58.4,
        basalMetabolicRateKcal: 1720,
        isWaterRetentionSpike: false,
      );

      final Uint8List pdfBytes = await pdfService.generateReportBytes(
        profile: dummyProfile,
        latestMeasurement: dummyMeasurement,
        recentMeasurements: <BodyMeasurement>[dummyMeasurement],
        averageDailyKcal: 2120, foodDays: 7,
        averageProteinG: 155.0,
        averageCarbsG: 210.0,
        averageFatG: 62.0,
        averageSleepHours: 7.8,
        activeSupplements: const <SupplementsTrackerData>[],
        readinessScore: 88,
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);
      // Validar cabecera mágica de archivo PDF (%PDF-)
      final String header = String.fromCharCodes(pdfBytes.take(5));
      expect(header, equals('%PDF-'));
    });
  });
}
