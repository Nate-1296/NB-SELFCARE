import 'package:flutter/material.dart';

import '../../../core/domain/care_enums.dart';
import '../../../core/l10n/l10n.dart';
import '../../../shared/utils/number_formats.dart';
import '../../../shared/widgets/science_on_demand_sheet.dart';
import '../domain/pelvic_floor_program.dart';
import '../domain/substance_catalog.dart';
import '../domain/vital_ranges.dart';
import '../domain/wellbeing_index.dart';

/// Textos de las claves del dominio de Cuidado (todo vive en el ARB).
extension CareModuleL10n on CareModule {
  String label(AppLocalizations l10n) => switch (this) {
    CareModule.treatments => l10n.moduleTreatments,
    CareModule.pelvicFloor => l10n.modulePelvicFloor,
    CareModule.activeBreaks => l10n.moduleActiveBreaks,
    CareModule.symptoms => l10n.moduleSymptoms,
    CareModule.checkups => l10n.moduleCheckups,
    CareModule.habits => l10n.moduleHabits,
    CareModule.substances => l10n.moduleSubstances,
  };
}

extension VitalKindL10n on VitalKind {
  String label(AppLocalizations l10n) => switch (this) {
    VitalKind.bloodPressure => l10n.vitalBloodPressure,
    VitalKind.glucose => l10n.vitalGlucose,
    VitalKind.oxygen => l10n.vitalOxygen,
    VitalKind.temperature => l10n.vitalTemperature,
  };

  /// Nombre del aparato (Ajustes y bienvenida).
  String device(AppLocalizations l10n) => switch (this) {
    VitalKind.bloodPressure => l10n.devicesBloodPressure,
    VitalKind.glucose => l10n.devicesGlucose,
    VitalKind.oxygen => l10n.devicesOxygen,
    VitalKind.temperature => l10n.devicesTemperature,
  };

  String unit(AppLocalizations l10n) => switch (this) {
    VitalKind.bloodPressure => l10n.vitalUnitBloodPressure,
    VitalKind.glucose => l10n.vitalUnitGlucose,
    VitalKind.oxygen => l10n.vitalUnitOxygen,
    VitalKind.temperature => l10n.vitalUnitTemperature,
  };

  IconData get icon => switch (this) {
    VitalKind.bloodPressure => Icons.favorite_border_rounded,
    VitalKind.glucose => Icons.water_drop_outlined,
    VitalKind.oxygen => Icons.air_rounded,
    VitalKind.temperature => Icons.thermostat_rounded,
  };

  /// Valor legible: "128/82", "96", "98", "36,8".
  String format(double primary, double? secondary) => switch (this) {
    VitalKind.bloodPressure => '${primary.round()}/${(secondary ?? 0).round()}',
    VitalKind.temperature => NumberFormats.fixed(primary, 1),
    _ => primary.round().toString(),
  };
}

extension VitalBandL10n on VitalBand {
  String label(AppLocalizations l10n) => switch (this) {
    VitalBand.low => l10n.vitalBandLow,
    VitalBand.normal => l10n.vitalBandNormal,
    VitalBand.elevated => l10n.vitalBandElevated,
    VitalBand.high => l10n.vitalBandHigh,
    VitalBand.consultSoon => l10n.vitalBandConsultSoon,
  };
}

extension GlucoseContextL10n on GlucoseContext {
  String label(AppLocalizations l10n) => switch (this) {
    GlucoseContext.fasting => l10n.careVitalContextFasting,
    GlucoseContext.afterMeal => l10n.careVitalContextAfterMeal,
    GlucoseContext.random => l10n.careVitalContextRandom,
  };
}

extension PelvicCueL10n on PelvicCue {
  String label(AppLocalizations l10n) => switch (this) {
    PelvicCue.squeeze => l10n.careCueSqueeze,
    PelvicCue.release => l10n.careCueRelease,
    PelvicCue.quickSqueeze => l10n.careCueQuickSqueeze,
    PelvicCue.quickRelease => l10n.careCueQuickRelease,
    PelvicCue.lengthenInhale => l10n.careCueLengthenInhale,
    PelvicCue.lengthenExhale => l10n.careCueLengthenExhale,
    PelvicCue.rest => l10n.careCueRest,
  };
}

extension WellbeingBandL10n on WellbeingBand {
  String label(AppLocalizations l10n) => switch (this) {
    WellbeingBand.flourishing => l10n.wellbeingBandFlourishing,
    WellbeingBand.good => l10n.wellbeingBandGood,
    WellbeingBand.low => l10n.wellbeingBandLow,
    WellbeingBand.veryLow => l10n.wellbeingBandVeryLow,
  };
}

abstract final class CareText {
  static String routine(AppLocalizations l10n, String id) => switch (id) {
    'neck_shoulders' => l10n.careRoutineNeckShoulders,
    'back' => l10n.careRoutineBack,
    'wrists' => l10n.careRoutineWrists,
    'hips_legs' => l10n.careRoutineHipsLegs,
    _ => l10n.careRoutineEyes,
  };

  static IconData routineIcon(String id) => switch (id) {
    'neck_shoulders' => Icons.accessibility_new_rounded,
    'back' => Icons.airline_seat_recline_normal_rounded,
    'wrists' => Icons.back_hand_outlined,
    'hips_legs' => Icons.directions_walk_rounded,
    _ => Icons.visibility_outlined,
  };

  static String move(AppLocalizations l10n, String key) => switch (key) {
    'neckTiltRight' => l10n.careMoveNeckTiltRight,
    'neckTiltLeft' => l10n.careMoveNeckTiltLeft,
    'lookRight' => l10n.careMoveLookRight,
    'lookLeft' => l10n.careMoveLookLeft,
    'shoulderShrug' => l10n.careMoveShoulderShrug,
    'shoulderRolls' => l10n.careMoveShoulderRolls,
    'armsOverhead' => l10n.careMoveArmsOverhead,
    'sideBendRight' => l10n.careMoveSideBendRight,
    'sideBendLeft' => l10n.careMoveSideBendLeft,
    'chestOpener' => l10n.careMoveChestOpener,
    'twistRight' => l10n.careMoveTwistRight,
    'twistLeft' => l10n.careMoveTwistLeft,
    'wristExtensionRight' => l10n.careMoveWristExtensionRight,
    'wristExtensionLeft' => l10n.careMoveWristExtensionLeft,
    'wristFlexionRight' => l10n.careMoveWristFlexionRight,
    'wristFlexionLeft' => l10n.careMoveWristFlexionLeft,
    'fistOpen' => l10n.careMoveFistOpen,
    'shakeHands' => l10n.careMoveShakeHands,
    'marchInPlace' => l10n.careMoveMarchInPlace,
    'quadStretchRight' => l10n.careMoveQuadStretchRight,
    'quadStretchLeft' => l10n.careMoveQuadStretchLeft,
    'calfRaises' => l10n.careMoveCalfRaises,
    'hipCircles' => l10n.careMoveHipCircles,
    'lookFar' => l10n.careMoveLookFar,
    'slowBlinks' => l10n.careMoveSlowBlinks,
    'palming' => l10n.careMovePalming,
    _ => l10n.careMoveEyeFigureEight,
  };

  /// Nombre de un síntoma del catálogo o el texto propio tal cual.
  static String symptom(AppLocalizations l10n, String key) => switch (key) {
    'headache' => l10n.symptomHeadache,
    'migraine' => l10n.symptomMigraine,
    'back_pain' => l10n.symptomBackPain,
    'joint_pain' => l10n.symptomJointPain,
    'muscle_pain' => l10n.symptomMusclePain,
    'fatigue' => l10n.symptomFatigue,
    'anxiety' => l10n.symptomAnxiety,
    'low_mood' => l10n.symptomLowMood,
    'insomnia' => l10n.symptomInsomnia,
    'dizziness' => l10n.symptomDizziness,
    'nausea' => l10n.symptomNausea,
    'allergy' => l10n.symptomAllergy,
    'congestion' => l10n.symptomCongestion,
    'cramps' => l10n.symptomCramps,
    'breast_tenderness' => l10n.symptomBreastTenderness,
    'bloating' => l10n.symptomBloating,
    'hot_flashes' => l10n.symptomHotFlashes,
    'night_sweats' => l10n.symptomNightSweats,
    'brain_fog' => l10n.symptomBrainFog,
    'vaginal_dryness' => l10n.symptomVaginalDryness,
    _ => key,
  };

  static String intensity(AppLocalizations l10n, int value) => switch (value) {
    1 => l10n.careIntensity1,
    2 => l10n.careIntensity2,
    3 => l10n.careIntensity3,
    4 => l10n.careIntensity4,
    _ => l10n.careIntensity5,
  };

  static String checkup(AppLocalizations l10n, String key, String? customName) => switch (key) {
    'dental' => l10n.checkupDental,
    'general' => l10n.checkupGeneral,
    'vision' => l10n.checkupVision,
    'blood_pressure' => l10n.checkupBloodPressure,
    'lipids_glucose' => l10n.checkupLipidsGlucose,
    'cervical' => l10n.checkupCervical,
    'mammography' => l10n.checkupMammography,
    'prostate' => l10n.checkupProstate,
    'colorectal' => l10n.checkupColorectal,
    'bone_density' => l10n.checkupBoneDensity,
    'flu_vaccine' => l10n.checkupFluVaccine,
    'tetanus' => l10n.checkupTetanus,
    _ => customName ?? key,
  };

  static String interval(AppLocalizations l10n, int months) {
    if (months == 12) return l10n.careCheckupEveryYear;
    if (months % 12 == 0) return l10n.careCheckupEveryYears('${months ~/ 12}');
    return l10n.careCheckupEveryMonths('$months');
  }

  static String substance(AppLocalizations l10n, String key) => switch (key) {
    'beer' => l10n.substanceBeer,
    'wine' => l10n.substanceWine,
    'spirit' => l10n.substanceSpirit,
    'cocktail' => l10n.substanceCocktail,
    'cigarette' => l10n.substanceCigarette,
    _ => l10n.substanceVape,
  };

  static IconData substanceIcon(SubstancePreset p) => switch (p.key) {
    'beer' => Icons.sports_bar_outlined,
    'wine' => Icons.wine_bar_outlined,
    'spirit' => Icons.local_bar_outlined,
    'cocktail' => Icons.nightlife_rounded,
    'cigarette' => Icons.smoking_rooms_rounded,
    _ => Icons.cloud_outlined,
  };

  static IconData habitIcon(String key) => switch (key) {
    'tooth' => Icons.clean_hands_outlined,
    'sun' => Icons.wb_sunny_outlined,
    'leaf' => Icons.eco_outlined,
    'book' => Icons.menu_book_outlined,
    'walk' => Icons.directions_walk_rounded,
    'drop' => Icons.water_drop_outlined,
    'heart' => Icons.favorite_border_rounded,
    'bed' => Icons.bedtime_outlined,
    'phone_off' => Icons.phonelink_erase_outlined,
    _ => Icons.auto_awesome_outlined,
  };

  static String weekdays(AppLocalizations l10n, int mask) {
    if (mask & 0x7F == 0x7F) return l10n.careEveryDay;
    final List<String> names = l10n.careWeekdaysShort.split(',');
    return <String>[
      for (int i = 0; i < 7; i++)
        if (mask & (1 << i) != 0 && i < names.length) names[i],
    ].join(' ');
  }

  static String hhmm(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
}

/// Explicaciones "Saber más" de Cuidado, con los textos del ARB.
abstract final class CareScience {
  static List<String> _refs(String raw) =>
      raw.split('\n').where((String s) => s.trim().isNotEmpty).toList();

  static ScienceSpec pelvicFloor(AppLocalizations l10n) => ScienceSpec(
    title: l10n.carePelvicScienceTitle,
    badgeLabel: l10n.carePelvicScienceBadge,
    icon: Icons.self_improvement_rounded,
    quickTake: l10n.carePelvicScienceQuick,
    howItWorks: l10n.carePelvicScienceHow,
    scientificReferences: _refs(l10n.carePelvicScienceRefs),
    actionableAdvice: l10n.carePelvicScienceAdvice,
  );

  static ScienceSpec activeBreaks(AppLocalizations l10n) => ScienceSpec(
    title: l10n.careBreaksScienceTitle,
    badgeLabel: l10n.careBreaksScienceBadge,
    icon: Icons.accessibility_new_rounded,
    quickTake: l10n.careBreaksScienceQuick,
    howItWorks: l10n.careBreaksScienceHow,
    scientificReferences: _refs(l10n.careBreaksScienceRefs),
    actionableAdvice: l10n.careBreaksScienceAdvice,
  );

  static ScienceSpec checkups(AppLocalizations l10n) => ScienceSpec(
    title: l10n.careCheckupsScienceTitle,
    badgeLabel: l10n.careCheckupsScienceBadge,
    icon: Icons.event_available_rounded,
    quickTake: l10n.careCheckupsScienceQuick,
    howItWorks: l10n.careCheckupsScienceHow,
    scientificReferences: _refs(l10n.careCheckupsScienceRefs),
    actionableAdvice: l10n.careCheckupsScienceAdvice,
  );

  static ScienceSpec vitals(AppLocalizations l10n) => ScienceSpec(
    title: l10n.careVitalsScienceTitle,
    badgeLabel: l10n.careVitalsScienceBadge,
    icon: Icons.monitor_heart_outlined,
    quickTake: l10n.careVitalsScienceQuick,
    howItWorks: l10n.careVitalsScienceHow,
    scientificReferences: _refs(l10n.careVitalsScienceRefs),
    actionableAdvice: l10n.careVitalsScienceAdvice,
  );

  static ScienceSpec alcohol(AppLocalizations l10n) => ScienceSpec(
    title: l10n.careAlcoholScienceTitle,
    badgeLabel: l10n.careAlcoholScienceBadge,
    icon: Icons.local_bar_outlined,
    quickTake: l10n.careAlcoholScienceQuick,
    howItWorks: l10n.careAlcoholScienceHow,
    scientificReferences: _refs(l10n.careAlcoholScienceRefs),
    actionableAdvice: l10n.careAlcoholScienceAdvice,
  );

  static ScienceSpec wellbeing(AppLocalizations l10n) => ScienceSpec(
    title: l10n.wellbeingScienceTitle,
    badgeLabel: l10n.wellbeingScienceBadge,
    icon: Icons.sentiment_satisfied_alt_outlined,
    quickTake: l10n.wellbeingScienceQuick,
    howItWorks: l10n.wellbeingScienceHow,
    scientificReferences: _refs(l10n.wellbeingScienceRefs),
    actionableAdvice: l10n.wellbeingScienceAdvice,
  );

  static ScienceSpec sleepRegularity(AppLocalizations l10n) => ScienceSpec(
    title: l10n.sleepRegularityScienceTitle,
    badgeLabel: l10n.sleepRegularityScienceBadge,
    icon: Icons.bedtime_outlined,
    quickTake: l10n.sleepRegularityScienceQuick,
    howItWorks: l10n.sleepRegularityScienceHow,
    scientificReferences: _refs(l10n.sleepRegularityScienceRefs),
    actionableAdvice: l10n.sleepRegularityScienceAdvice,
  );
}
