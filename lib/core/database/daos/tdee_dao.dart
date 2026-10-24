import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/utils/biometric_formulas.dart';
import '../../../shared/utils/daily_targets_calculator.dart';
import '../../../shared/utils/date_time_extensions.dart';
import '../../constants/app_constants.dart';
import '../app_database.dart';
import 'user_profile_dao.dart';

/// Resultado tipado del motor de calibración quincenal de TDEE Adaptativo.
class TdeeCalibrationOutcome {
  const TdeeCalibrationOutcome({
    required this.didCalibrate,
    required this.foodDaysLogged,
    required this.weighInDaysLogged,
    this.previousTdeeKcal,
    this.newTdeeKcal,
    this.wasClamped = false,
    this.deltaEmaKg,
    this.averageIntakeKcal,
  });

  final bool didCalibrate;
  final int foodDaysLogged;
  final int weighInDaysLogged;
  final int? previousTdeeKcal;
  final int? newTdeeKcal;
  final bool wasClamped;
  final double? deltaEmaKg;
  final double? averageIntakeKcal;
}

/// DAO especializado en el registro y auditoría histórica de las calibraciones del TDEE Adaptativo.
class TdeeDao {
  TdeeDao(this._db);

  final AppDatabase _db;

  /// Emite la última calibración registrada del TDEE adaptativo.
  Stream<TdeeCalibration?> watchLatestCalibration() {
    return (_db.select(_db.tdeeCalibrations)
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.calibratedAt)])
          ..limit(1))
        .watchSingleOrNull();
  }

  /// Registra el resultado de una calibración quincenal.
  Future<int> insertCalibration(TdeeCalibrationsCompanion companion) {
    return _db.into(_db.tdeeCalibrations).insert(companion);
  }

  /// Obtiene el historial de calibraciones para visualización en el perfil.
  Future<List<TdeeCalibration>> getCalibrationHistory({int limit = 12}) {
    return (_db.select(_db.tdeeCalibrations)
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.calibratedAt)])
          ..limit(limit))
        .get();
  }

  /// Evalúa la ventana móvil de 14 días (mínimo 10 días de comida y 6 pesajes)
  /// y actualiza el TDEE adaptativo del usuario de forma segura y auditable.
  Future<TdeeCalibrationOutcome> calibrateFromLast14Days({
    required UserProfile profile,
    required UserProfileDao profileDao,
    DateTime? referenceDate,
  }) async {
    final DateTime now = referenceDate ?? DateTime.now();
    final String toDateKey = now.dateKey;
    final String fromDateKey = now
        .subtract(const Duration(days: AppConstants.adaptiveTdeeWindowDays - 1))
        .dateKey;

    final foodRows = await _db.customSelect(
      '''
      SELECT date_key, SUM(total_kcal) AS daily_kcal
      FROM food_logs
      WHERE date_key >= ? AND date_key <= ?
      GROUP BY date_key
      HAVING daily_kcal >= 600
      ORDER BY date_key ASC
      ''',
      variables: [
        Variable.withString(fromDateKey),
        Variable.withString(toDateKey),
      ],
      readsFrom: {_db.foodLogs},
    ).get();

    final measurements = await (_db.select(_db.bodyMeasurements)
          ..where((tbl) =>
              tbl.dateKey.isBiggerOrEqualValue(fromDateKey) &
              tbl.dateKey.isSmallerOrEqualValue(toDateKey))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.measuredAt)]))
        .get();

    final int uniqueWeighDays =
        measurements.map((m) => m.dateKey).toSet().length;

    if (foodRows.length < AppConstants.adaptiveTdeeMinFoodLogDays ||
        uniqueWeighDays < AppConstants.adaptiveTdeeMinWeighInDays) {
      return TdeeCalibrationOutcome(
        didCalibrate: false,
        foodDaysLogged: foodRows.length,
        weighInDaysLogged: uniqueWeighDays,
      );
    }

    final double totalKcal = foodRows.fold<double>(
      0.0,
      (sum, row) => sum + row.read<double>('daily_kcal'),
    );
    final double avgDailyIntake = totalKcal / foodRows.length;

    final double startEma = measurements.first.trendWeightKg;
    final double endEma = measurements.last.trendWeightKg;
    final double deltaEma = endEma - startEma;

    final int bmrKcal = DailyTargetsCalculator.estimateBmr(
      profile: profile,
      currentWeightKg: endEma,
      referenceDate: now,
    );

    final int rawCalculatedTdee =
        (avgDailyIntake - ((deltaEma * AppConstants.kcalPerKgBodyFat) / 14.0))
            .round();

    final int newTdee = BiometricFormulas.calibrateAdaptiveTdee(
      avgDailyIntakeKcal: avgDailyIntake,
      startEmaKg: startEma,
      endEmaKg: endEma,
      previousTdeeKcal: profile.currentAdaptiveTdeeKcal,
      userBmrKcal: bmrKcal,
    );

    final bool wasClamped = (newTdee - rawCalculatedTdee).abs() > 1;

    await _db.transaction(() async {
      await insertCalibration(
        TdeeCalibrationsCompanion.insert(
          calibratedAt: Value(now),
          dateKey: toDateKey,
          previousTdeeKcal: profile.currentAdaptiveTdeeKcal,
          newTdeeKcal: newTdee,
          calculatedRawTdeeKcal: rawCalculatedTdee,
          wasClamped: Value(wasClamped),
          deltaEma14d: double.parse(deltaEma.toStringAsFixed(2)),
          averageKcal14d: double.parse(avgDailyIntake.toStringAsFixed(1)),
          daysEvaluated: foodRows.length,
        ),
      );

      await profileDao.updateAdaptiveTdee(newTdee, now);
    });

    return TdeeCalibrationOutcome(
      didCalibrate: true,
      foodDaysLogged: foodRows.length,
      weighInDaysLogged: uniqueWeighDays,
      previousTdeeKcal: profile.currentAdaptiveTdeeKcal,
      newTdeeKcal: newTdee,
      wasClamped: wasClamped,
      deltaEmaKg: deltaEma,
      averageIntakeKcal: avgDailyIntake,
    );
  }
}

/// Provider de Riverpod para inyectar TdeeDao.
final tdeeDaoProvider = Provider<TdeeDao>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return TdeeDao(db);
});

/// StreamProvider con la calibración más reciente del TDEE.
final latestTdeeCalibrationStreamProvider =
    StreamProvider.autoDispose<TdeeCalibration?>((ref) {
  return ref.watch(tdeeDaoProvider).watchLatestCalibration();
});
