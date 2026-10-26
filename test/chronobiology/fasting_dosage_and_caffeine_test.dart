import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/services/caffeine_pharmacokinetics_service.dart';
import 'package:nb_selfcare/core/services/fasting_dosage_advisor.dart';
import 'package:nb_selfcare/core/services/readiness_engine.dart';

void main() {
  group('Fase 5: FastingDosageAdvisor Tests', () {
    test('Protocol 16:8 is always evaluated as safe without warnings', () {
      final FastingSafetyVerdict verdict =
          FastingDosageAdvisor.evaluateProtocolSafety(
        proposedTargetHours: 16,
        recentSessions: const <FastingSession>[],
      );

      expect(verdict.isSafe, isTrue);
      expect(verdict.warningTitle, isNull);
    });

    test('OMAD (23:1) triggers warning if user already had 2+ prolonged fasts this week', () {
      final DateTime now = DateTime.now();
      final List<FastingSession> mockHistory = <FastingSession>[
        FastingSession(
          id: 1,
          startedAt: now.subtract(const Duration(days: 4, hours: 23)),
          plannedEndAt: now.subtract(const Duration(days: 4)),
          actualEndedAt: now.subtract(const Duration(days: 4)),
          targetHours: 23,
          protocolName: '23:1',
          isCompleted: true,
        ),
        FastingSession(
          id: 2,
          startedAt: now.subtract(const Duration(days: 2, hours: 23)),
          plannedEndAt: now.subtract(const Duration(days: 2)),
          actualEndedAt: now.subtract(const Duration(days: 2)),
          targetHours: 23,
          protocolName: '23:1',
          isCompleted: true,
        ),
      ];

      final FastingSafetyVerdict verdict =
          FastingDosageAdvisor.evaluateProtocolSafety(
        proposedTargetHours: 23,
        recentSessions: mockHistory,
      );

      expect(verdict.isSafe, isFalse);
      expect(verdict.warningTitle, contains('Límite Semanal'));
      expect(verdict.recommendedAlternativeHours, 16);
    });

    test('OMAD (23:1) warns against consecutive back-to-back prolonged fasts', () {
      final DateTime now = DateTime.now();
      final List<FastingSession> mockHistory = <FastingSession>[
        FastingSession(
          id: 1,
          startedAt: now.subtract(const Duration(hours: 30)),
          plannedEndAt: now.subtract(const Duration(hours: 7)),
          actualEndedAt: now.subtract(const Duration(hours: 7)),
          targetHours: 23,
          protocolName: '23:1',
          isCompleted: true,
        ),
      ];

      final FastingSafetyVerdict verdict =
          FastingDosageAdvisor.evaluateProtocolSafety(
        proposedTargetHours: 23,
        recentSessions: mockHistory,
      );

      expect(verdict.isSafe, isFalse);
      expect(verdict.warningTitle, contains('Recuperación Metabólica'));
    });

    test('getRefeedingGuidance returns 3 stages for fasts >= 18 hours', () {
      final List<FastBreakStage> stages =
          FastingDosageAdvisor.getRefeedingGuidance(20.0);

      expect(stages.length, 3);
      expect(stages[0].phaseNumber, 1);
      expect(stages[0].recommendedFoods.any((f) => f.contains('Caldo')), isTrue);
      expect(stages[1].phaseNumber, 2);
      expect(stages[1].recommendedFoods.any((f) => f.contains('aguacate') || f.contains('huevo')), isTrue);
      expect(stages[2].phaseNumber, 3);
    });
  });

  group('Fase 5: CaffeinePharmacokineticsService Tests', () {
    final CaffeinePharmacokineticsService service =
        CaffeinePharmacokineticsService();

    test('Decay formula matches half-life of 5.5 hours exactly', () {
      final DateTime intakeTime = DateTime(2026, 10, 26, 8, 0);
      final List<CaffeineLog> logs = <CaffeineLog>[
        CaffeineLog(
          id: 1,
          dateKey: '2026-10-26',
          loggedAt: intakeTime,
          sourceName: 'Café Filtro',
          caffeineMg: 100.0,
        ),
      ];

      // Exactamente 5.5 horas después (13:30)
      final DateTime at5HalfHours = DateTime(2026, 10, 26, 13, 30);
      final double residual1 = service.computeResidualCaffeineAt(
        logs: logs,
        targetTime: at5HalfHours,
      );
      expect(residual1, closeTo(50.0, 0.5));

      // Exactamente 11 horas después (2 vidas medias -> 19:00)
      final DateTime at11Hours = DateTime(2026, 10, 26, 19, 0);
      final double residual2 = service.computeResidualCaffeineAt(
        logs: logs,
        targetTime: at11Hours,
      );
      expect(residual2, closeTo(25.0, 0.5));
    });

    test('Bedtime cutoff leaves < 25 mg at 23:00 for 100mg cup', () {
      final DateTime targetBedtime = DateTime(2026, 10, 26, 23, 0);
      final DateTime cutoff = service.computeBedtimeCutoff(
        targetBedtime: targetBedtime,
        typicalDoseMg: 100.0,
        maxResidual: 25.0,
      );

      // 100 -> 25 requiere exactamente 2 vidas medias = 11 horas antes de las 23:00 -> 12:00
      expect(cutoff.hour, 12);
      expect(cutoff.minute, 0);
    });
  });

  group('Fase 5: ReadinessEngine Tests', () {
    final ReadinessEngine engine = ReadinessEngine();

    test('Optimal sleep and recovered RHR produces Optimal score >= 85', () {
      final DailyReadinessResult result = engine.compute(
        actualSleepHours: 8.0,
        targetSleepHours: 8.0,
        deepSleepMinutes: 100.0,
        currentRhrBpm: 58,
        baselineRhrBpm: 60,
        recent3DayWorkoutHours: 1.0,
        averageRecentRpe: 6.0,
      );

      expect(result.totalScore, greaterThanOrEqualTo(85));
      expect(result.isOptimal, isTrue);
      expect(result.category, ReadinessCategory.optimal);
    });

    test('Sleep deprivation (<5h) and excessive strain produces Recovery category', () {
      final DailyReadinessResult result = engine.compute(
        actualSleepHours: 4.5,
        targetSleepHours: 8.0,
        currentRhrBpm: 68,
        baselineRhrBpm: 58, // +10 bpm sobre la media
        recent3DayWorkoutHours: 4.0,
        averageRecentRpe: 8.5,
      );

      expect(result.totalScore, lessThan(70));
      expect(result.isRecoveryNeeded, isTrue);
      expect(result.category, ReadinessCategory.recoveryNeeded);
      expect(result.actionableAdvice, contains('priorices la restauración'));
    });
  });
}
