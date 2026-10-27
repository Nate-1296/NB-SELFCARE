import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock/clock.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/user_profile_dao.dart';
import '../../../core/domain/enums.dart';
import '../../../shared/utils/daily_targets_calculator.dart';
import '../../body_metrics/application/weigh_in_service.dart';
import 'reminder_service.dart';

/// Respuestas del onboarding (docs/01 §6).
class OnboardingAnswers {
  const OnboardingAnswers({
    required this.name,
    required this.birthDate,
    required this.sex,
    required this.heightCm,
    required this.currentWeightKg,
    required this.targetWeightKg,
    required this.weeklyGoalRateKg,
    required this.dailyWaterGoalMl,
    required this.dailyStepsGoal,
    required this.dailySleepGoalHours,
    required this.themeKey,
    this.hasImpedanceContraindication = false,
    this.hasEatingDisorderHistory = false,
    this.takesHypoglycemicMedication = false,
  });

  final String name;
  final DateTime birthDate;
  final BiologicalSex sex;
  final double heightCm;
  final double currentWeightKg;
  final double targetWeightKg;
  final double weeklyGoalRateKg;
  final int dailyWaterGoalMl;
  final int dailyStepsGoal;
  final double dailySleepGoalHours;
  final String themeKey;

  /// Marcapasos, implantes electrónicos o embarazo: la báscula mide solo peso.
  final bool hasImpedanceContraindication;

  /// Antecedentes de TCA: déficit acotado y ayunos > 16 h desactivados por defecto.
  final bool hasEatingDisorderHistory;

  /// Medicación que baja la glucosa: aviso antes de cada ayuno.
  final bool takesHypoglycemicMedication;
}

/// Caso de uso "Completar onboarding": crea el perfil, registra el peso actual
/// como primer pesaje (punto de partida de la EMA) y programa los recordatorios.
class OnboardingService {
  OnboardingService(this._profileDao, this._weighIns, this._reminders, this._clock);

  final UserProfileDao _profileDao;
  final WeighInService _weighIns;
  final ReminderService _reminders;
  final Clock _clock;

  /// TDEE inicial (Mifflin-St Jeor × NEAT) con el peso **actual**, no el de la meta.
  int initialTdee(OnboardingAnswers a) => DailyTargetsCalculator.estimateInitialTdee(
        weightKg: a.currentWeightKg,
        heightCm: a.heightCm,
        birthDate: a.birthDate,
        biologicalSex: a.sex,
        now: _clock.now(),
        dailyStepsGoal: a.dailyStepsGoal,
      );

  Future<void> complete(OnboardingAnswers a) async {
    final DateTime now = _clock.now();
    await _profileDao.createProfile(
      UserProfilesCompanion.insert(
        name: a.name.trim(),
        birthDate: a.birthDate,
        biologicalSex: a.sex,
        heightCm: a.heightCm,
        targetWeightKg: a.targetWeightKg,
        weeklyGoalRateKg: Value(a.weeklyGoalRateKg),
        dailyWaterGoalMl: Value(a.dailyWaterGoalMl),
        dailyStepsGoal: Value(a.dailyStepsGoal),
        dailySleepGoalHours: Value(a.dailySleepGoalHours),
        themeMode: Value(a.themeKey),
        currentAdaptiveTdeeKcal: Value(initialTdee(a)),
        activeDietPhase: Value(
          a.weeklyGoalRateKg == 0 ? DietPhase.maintenance : DietPhase.deficit,
        ),
        activeDietPhaseStartedAt: Value(now),
        hasImpedanceContraindication: Value(a.hasImpedanceContraindication),
        hasEatingDisorderHistory: Value(a.hasEatingDisorderHistory),
        takesHypoglycemicMedication: Value(a.takesHypoglycemicMedication),
      ),
    );
    await _weighIns.record(
      weightKg: a.currentWeightKg,
      impedanceOhms: null,
      source: MeasurementSource.manual,
    );
    await _reminders.seedDefaults();
  }
}

final onboardingServiceProvider = Provider<OnboardingService>((Ref ref) {
  return OnboardingService(
    ref.watch(userProfileDaoProvider),
    ref.watch(weighInServiceProvider),
    ref.watch(reminderServiceProvider),
    ref.watch(clockProvider),
  );
});
