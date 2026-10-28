import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock/clock.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/body_measurements_dao.dart';
import '../../../core/database/daos/food_dao.dart';
import '../../../core/database/daos/health_sync_dao.dart';
import '../../../core/database/daos/supplement_dao.dart';
import '../../../core/services/clinical_report_pdf_service.dart';
import '../../../core/services/readiness_engine.dart';
import '../../../shared/utils/date_time_extensions.dart';
import '../../today/application/readiness_queries.dart';

/// Reúne los datos de los últimos 7 días y comparte el informe en PDF.
class ClinicalReportService {
  ClinicalReportService(this._ref);

  final Ref _ref;

  Future<void> share(UserProfile profile) async {
    final DateTime now = _ref.read(clockProvider).now();
    final String to = now.dateKey;
    final String from = now.addDays(-6).dateKey;
    final BodyMeasurementsDao body = _ref.read(bodyMeasurementsDaoProvider);

    double kcal = 0, protein = 0, carbs = 0, fat = 0;
    int foodDays = 0;
    for (int i = 0; i < 7; i++) {
      final List<FoodLog> logs =
          await _ref.read(foodDaoProvider).getLogsForDate(now.addDays(-i).dateKey);
      if (logs.isEmpty) continue;
      foodDays++;
      for (final FoodLog l in logs) {
        kcal += l.totalKcal;
        protein += l.totalProteinG;
        carbs += l.totalCarbsG;
        fat += l.totalFatG;
      }
    }

    final List<int> sleep = (await _ref.read(healthSyncDaoProvider).getSummariesBetween(from, to))
        .map((DailySummary d) => d.sleepDurationMinutes)
        .where((int m) => m > 0)
        .toList();
    final DailyReadinessResult? readiness = await _ref.read(readinessReaderProvider).forDate(to);
    double avg(double total) => foodDays > 0 ? total / foodDays : 0;

    await _ref.read(clinicalReportPdfServiceProvider).shareOrPrintReport(
          profile: profile,
          latestMeasurement: await body.getLatestMeasurement(),
          recentMeasurements: await body.getRecentMeasurements(limit: 14),
          averageDailyKcal: avg(kcal).round(),
          foodDays: foodDays,
          averageProteinG: avg(protein),
          averageCarbsG: avg(carbs),
          averageFatG: avg(fat),
          averageSleepHours: sleep.isEmpty ? 0 : sleep.reduce((int a, int b) => a + b) / sleep.length / 60.0,
          activeSupplements: await _ref.read(supplementDaoProvider).getActiveSupplements(),
          readinessScore: readiness?.totalScore,
        );
  }
}

final clinicalReportServiceProvider = Provider<ClinicalReportService>(ClinicalReportService.new);
