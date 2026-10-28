import 'dart:math' as math;

/// Fase de una respiración guiada.
enum BreathPhase { inhale, holdIn, exhale, holdOut }

/// Patrón de respiración: fases con su duración en segundos.
class BreathingPattern {
  const BreathingPattern({required this.id, required this.phases});

  final String id;
  final List<(BreathPhase, int)> phases;

  int get cycleSeconds => phases.fold(0, (int s, (BreathPhase, int) p) => s + p.$2);

  /// "4-4-4-4", "4-7-8"…
  String get rhythm => phases.map(((BreathPhase, int) p) => '${p.$2}').join('-');

  /// Respiración en caja: calma y foco.
  static const BreathingPattern box = BreathingPattern(
    id: 'box',
    phases: <(BreathPhase, int)>[
      (BreathPhase.inhale, 4),
      (BreathPhase.holdIn, 4),
      (BreathPhase.exhale, 4),
      (BreathPhase.holdOut, 4),
    ],
  );

  /// Triángulo 4-4-4: la más sencilla para empezar.
  static const BreathingPattern triangle = BreathingPattern(
    id: 'triangle',
    phases: <(BreathPhase, int)>[
      (BreathPhase.inhale, 4),
      (BreathPhase.holdIn, 4),
      (BreathPhase.exhale, 4),
    ],
  );

  /// 4-7-8: exhalación larga para relajarse antes de dormir.
  static const BreathingPattern relax = BreathingPattern(
    id: 'relax',
    phases: <(BreathPhase, int)>[
      (BreathPhase.inhale, 4),
      (BreathPhase.holdIn, 7),
      (BreathPhase.exhale, 8),
    ],
  );

  /// Coherencia 5-5: seis respiraciones por minuto, sin retenciones.
  static const BreathingPattern coherence = BreathingPattern(
    id: 'coherence',
    phases: <(BreathPhase, int)>[
      (BreathPhase.inhale, 5),
      (BreathPhase.exhale, 5),
    ],
  );

  static const List<BreathingPattern> all = <BreathingPattern>[box, triangle, relax, coherence];
}

/// Instante de una sesión de respiración.
class BreathingMoment {
  const BreathingMoment({
    required this.phase,
    required this.phaseIndex,
    required this.phaseProgress,
    required this.secondsLeftInPhase,
    required this.lung,
    required this.cycle,
    required this.cycles,
    required this.remainingSeconds,
    required this.progress,
    required this.done,
  });

  final BreathPhase phase;
  final int phaseIndex;

  /// Avance dentro de la fase 0–1.
  final double phaseProgress;

  /// Cuenta atrás de la fase (4, 3, 2, 1).
  final int secondsLeftInPhase;

  /// Pulmones: 0 vacíos, 1 llenos (suavizado al inhalar y exhalar).
  final double lung;

  /// Respiración actual (empieza en 1) y total.
  final int cycle;
  final int cycles;
  final int remainingSeconds;

  /// Avance de toda la sesión 0–1.
  final double progress;
  final bool done;
}

/// Sesión de respiración: patrón y duración redondeada a respiraciones enteras
/// (nunca se corta a mitad de una exhalación).
class BreathingSession {
  BreathingSession({required this.pattern, required int minutes})
      : cycles = math.max(1, (minutes * 60 / pattern.cycleSeconds).round());

  /// Duraciones que se ofrecen.
  static const List<int> minuteOptions = <int>[1, 3, 5];

  final BreathingPattern pattern;
  final int cycles;

  int get totalSeconds => cycles * pattern.cycleSeconds;

  static double _ease(double x) => x < 0.5 ? 2 * x * x : 1 - math.pow(-2 * x + 2, 2) / 2;

  BreathingMoment at(double elapsedSeconds) {
    final double total = totalSeconds.toDouble();
    final double e = elapsedSeconds.isFinite ? elapsedSeconds.clamp(0.0, total) : 0;
    final bool done = e >= total;
    final int cycleSeconds = pattern.cycleSeconds;
    final int cycleIndex = done ? cycles - 1 : (e / cycleSeconds).floor();
    double inCycle = done ? cycleSeconds.toDouble() : e - cycleIndex * cycleSeconds;

    int index = 0;
    for (; index < pattern.phases.length - 1; index++) {
      final int len = pattern.phases[index].$2;
      if (inCycle < len) break;
      inCycle -= len;
    }
    final (BreathPhase phase, int length) = pattern.phases[index];
    final double progress = (inCycle / length).clamp(0.0, 1.0);
    final double lung = switch (phase) {
      BreathPhase.inhale => _ease(progress),
      BreathPhase.holdIn => 1,
      BreathPhase.exhale => 1 - _ease(progress),
      BreathPhase.holdOut => 0,
    };
    return BreathingMoment(
      phase: phase,
      phaseIndex: index,
      phaseProgress: progress,
      secondsLeftInPhase: done ? 0 : math.max(1, (length - inCycle).ceil()),
      lung: done ? 0 : lung,
      cycle: cycleIndex + 1,
      cycles: cycles,
      remainingSeconds: (total - e).ceil(),
      progress: e / total,
      done: done,
    );
  }
}
