enum FemaleCyclePhase {
  menstrual,
  follicular,
  ovulatory,
  luteal,
  unknown,
}

class CyclePhaseInfo {
  const CyclePhaseInfo({
    required this.phase,
    required this.cycleDay,
    required this.totalCycleLengthDays,
    required this.isLutealMetabolicSurge,
    required this.recommendedCaloricSurgeKcal,
  });

  static const CyclePhaseInfo unknown = CyclePhaseInfo(
    phase: FemaleCyclePhase.unknown,
    cycleDay: 0,
    totalCycleLengthDays: 28,
    isLutealMetabolicSurge: false,
    recommendedCaloricSurgeKcal: 0,
  );

  final FemaleCyclePhase phase;
  final int cycleDay;
  final int totalCycleLengthDays;
  final bool isLutealMetabolicSurge;
  final int recommendedCaloricSurgeKcal;

  String get displayName => switch (phase) {
        FemaleCyclePhase.menstrual => 'Menstrual',
        FemaleCyclePhase.follicular => 'Folicular',
        FemaleCyclePhase.ovulatory => 'Ovulación',
        FemaleCyclePhase.luteal => 'Lútea (Premenstrual)',
        FemaleCyclePhase.unknown => 'No configurado',
      };
}

/// Predicción de la fase del ciclo a partir del último inicio de sangrado.
///
/// La fase lútea dura ~14 días con independencia de la longitud del ciclo, así
/// que la ovulación se estima 14 días antes del siguiente sangrado.
abstract final class CyclePhaseCalculator {
  static const int lutealLengthDays = 14;
  static const int menstrualLengthDays = 5;

  /// Compensación calórica sugerida en fase lútea por el aumento del gasto basal.
  static const int lutealSurgeKcal = 150;

  static CyclePhaseInfo phaseFor({
    required DateTime cycleStart,
    required int cycleLengthDays,
    required DateTime date,
  }) {
    final int length = cycleLengthDays >= 21 && cycleLengthDays <= 45 ? cycleLengthDays : 28;
    final DateTime start = DateTime.utc(cycleStart.year, cycleStart.month, cycleStart.day);
    final DateTime day = DateTime.utc(date.year, date.month, date.day);
    final int elapsed = day.difference(start).inDays;
    if (elapsed < 0) return CyclePhaseInfo.unknown;

    final int cycleDay = (elapsed % length) + 1;
    final int ovulationDay = length - lutealLengthDays;

    final FemaleCyclePhase phase;
    if (cycleDay <= menstrualLengthDays) {
      phase = FemaleCyclePhase.menstrual;
    } else if (cycleDay < ovulationDay - 1) {
      phase = FemaleCyclePhase.follicular;
    } else if (cycleDay <= ovulationDay + 1) {
      phase = FemaleCyclePhase.ovulatory;
    } else {
      phase = FemaleCyclePhase.luteal;
    }

    final bool isLuteal = phase == FemaleCyclePhase.luteal;
    return CyclePhaseInfo(
      phase: phase,
      cycleDay: cycleDay,
      totalCycleLengthDays: length,
      isLutealMetabolicSurge: isLuteal,
      recommendedCaloricSurgeKcal: isLuteal ? lutealSurgeKcal : 0,
    );
  }
}
