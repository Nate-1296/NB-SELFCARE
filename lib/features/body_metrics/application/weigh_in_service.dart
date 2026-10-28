import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock/clock.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/body_measurements_dao.dart';
import '../../../core/database/daos/female_cycle_dao.dart';
import '../../../core/database/daos/food_dao.dart';
import '../../../core/database/daos/supplement_dao.dart';
import '../../../core/database/daos/tdee_dao.dart';
import '../../../core/database/daos/user_profile_dao.dart';
import '../../../core/domain/enums.dart';
import '../../../core/platform/health_connect_gateway.dart';
import '../../../core/platform/native_call.dart';
import '../../../shared/utils/biometric_formulas.dart';
import '../../../shared/utils/cycle_phase_calculator.dart';
import '../../../shared/utils/date_time_extensions.dart';
import '../../pet_gamification/application/reward_service.dart';
import '../../pet_gamification/domain/reward_policy.dart';
import '../domain/weigh_in_analyzer.dart';
import 'milestone_service.dart';
import 'tdee_calibration_service.dart';

/// Resultado de registrar un pesaje.
class WeighInResult {
  const WeighInResult({
    required this.measurementId,
    required this.analysis,
    required this.reward,
    required this.tdeeCalibration,
    required this.milestonesReached,
  });

  final int measurementId;
  final WeighInAnalysis analysis;
  final RewardGrant reward;

  /// Recalibración del TDEE disparada por este pesaje (si tocaba).
  final TdeeCalibrationOutcome? tdeeCalibration;

  /// Mini-hitos que el nuevo Peso Tendencia acaba de alcanzar.
  final List<MilestoneGoal> milestonesReached;
}

/// Caso de uso "Registrar pesaje": aplica la cascada biométrica completa de
/// docs/02 §4 (métricas → EMA → falsa subida → monedas → Health Connect → TDEE).
class WeighInService {
  WeighInService({
    required this._db,
    required this._profileDao,
    required this._measurementsDao,
    required this._foodDao,
    required this._cycleDao,
    required this._supplementDao,
    required this._rewards,
    required this._healthConnect,
    required this._tdeeCalibration,
    required this._milestones,
    required this._clock,
  });

  final AppDatabase _db;
  final UserProfileDao _profileDao;
  final BodyMeasurementsDao _measurementsDao;
  final FoodDao _foodDao;
  final FemaleCycleDao _cycleDao;
  final SupplementDao _supplementDao;
  final RewardService _rewards;
  final HealthConnectGateway _healthConnect;
  final TdeeCalibrationService _tdeeCalibration;
  final MilestoneService _milestones;
  final Clock _clock;

  /// Desviación respecto a la tendencia si el peso parece de otra persona (filtro de invitado).
  Future<double?> guestDeviation(double weightKg) async {
    final BodyMeasurement? latest = await _measurementsDao.getLatestWeighIn();
    return WeighInAnalyzer.guestDeviation(
      weightKg: weightKg,
      previousTrendKg: latest?.trendWeightKg,
    );
  }

  Future<void> deleteMeasurement(int id) => _measurementsDao.deleteMeasurement(id);

  Future<void> restoreMeasurement(BodyMeasurement measurement) =>
      _measurementsDao.restoreMeasurement(measurement);

  Future<WeighInResult> record({
    required double weightKg,
    required int? impedanceOhms,
    required MeasurementSource source,
  }) async {
    final UserProfile? profile = await _profileDao.getProfile();
    if (profile == null) {
      throw StateError('No se puede registrar un pesaje sin perfil de usuario.');
    }

    final DateTime now = _clock.now();
    final String dateKey = now.dateKey;
    final BodyMeasurement? latest = await _measurementsDao.getLatestWeighIn();
    // Marcapasos, implantes o embarazo: solo peso, nunca bioimpedancia (docs/04 §1).
    final int? safeImpedance = profile.hasImpedanceContraindication ? null : impedanceOhms;

    final WeighInAnalysis analysis = WeighInAnalyzer.analyze(
      weightKg: weightKg,
      impedanceOhms: safeImpedance,
      heightCm: profile.heightCm,
      birthDate: profile.birthDate,
      sex: profile.biologicalSex,
      measuredAt: now,
      previous: latest == null
          ? null
          : PreviousWeighIn(
              weightKg: latest.weightKg,
              trendWeightKg: latest.trendWeightKg,
              waterPercentage: latest.waterPercentage,
              hadImpedance: latest.impedanceOhms != null,
            ),
      context: await _retentionContext(profile, now),
    );

    final DerivedBiometrics m = analysis.metrics;
    final (int id, RewardGrant reward) = await _db.transaction(() async {
      final int id = await _measurementsDao.insertMeasurement(
        BodyMeasurementsCompanion.insert(
          measuredAt: Value(now),
          dateKey: dateKey,
          source: source,
          weightKg: weightKg,
          trendWeightKg: analysis.trendWeightKg,
          impedanceOhms: Value(analysis.hasImpedance ? safeImpedance : null),
          bmi: analysis.bmi,
          bodyFatPercentage: Value(m.bodyFatPercentage),
          muscleMassKg: Value(m.muscleMassKg),
          waterPercentage: Value(m.waterPercentage),
          visceralFatIndex: Value(m.visceralFatIndex),
          boneMassKg: Value(m.boneMassKg),
          proteinPercentage: Value(m.proteinPercentage),
          basalMetabolicRateKcal: Value(m.basalMetabolicRateKcal),
          metabolicAge: Value(m.metabolicAgeYears),
          leanBodyMassKg: Value(m.leanBodyMassKg),
          bodyScore: Value(m.bodyScore),
          somatotype: Value(m.bodyType),
          isWaterRetentionSpike: Value(analysis.isWaterRetentionSpike),
          spikeExplanation: Value(analysis.spikeExplanation),
        ),
      );
      final RewardGrant reward = await _rewards.grant(RewardAction.weighIn, dateKey: dateKey);
      return (id, reward);
    });

    await bestEffort(
      () => _healthConnect.writeWeight(
        weightKg: weightKg,
        bodyFatPercentage: analysis.hasImpedance ? m.bodyFatPercentage : null,
        at: now,
        fromScale: source == MeasurementSource.miScale2Ble,
      ),
      false,
    );

    return WeighInResult(
      measurementId: id,
      analysis: analysis,
      reward: reward,
      tdeeCalibration: await _tdeeCalibration.calibrateIfDue(),
      milestonesReached: await _milestones.checkProgress(trendWeightKg: analysis.trendWeightKg),
    );
  }

  Future<RetentionContext> _retentionContext(UserProfile profile, DateTime now) async {
    final nutrition = await _foodDao.getRetentionNutritionContext(now.dateKey);
    final bool tracksCycle = profile.biologicalSex.isFemale && profile.isCycleTrackingEnabled;
    final bool isLuteal =
        tracksCycle &&
        (await _cycleDao.calculateCurrentPhase(now)).phase == FemaleCyclePhase.luteal;
    return RetentionContext(
      yesterdaySodiumMg: nutrition.yesterdaySodiumMg,
      yesterdayCarbsG: nutrition.yesterdayCarbsG,
      avg7dCarbsG: nutrition.avg7dCarbsG,
      isLutealPhase: isLuteal,
      takesWaterRetainingSupplement: await _supplementDao.hasActiveWaterRetentionSupplement(
        now.dateKey,
      ),
    );
  }
}

final weighInServiceProvider = Provider<WeighInService>((Ref ref) {
  return WeighInService(
    db: ref.watch(appDatabaseProvider),
    profileDao: ref.watch(userProfileDaoProvider),
    measurementsDao: ref.watch(bodyMeasurementsDaoProvider),
    foodDao: ref.watch(foodDaoProvider),
    cycleDao: ref.watch(femaleCycleDaoProvider),
    supplementDao: ref.watch(supplementDaoProvider),
    rewards: ref.watch(rewardServiceProvider),
    healthConnect: ref.watch(healthConnectGatewayProvider),
    tdeeCalibration: ref.watch(tdeeCalibrationServiceProvider),
    milestones: ref.watch(milestoneServiceProvider),
    clock: ref.watch(clockProvider),
  );
});
