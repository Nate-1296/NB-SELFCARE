import 'dart:math' as math;

/// Paso de una sesión guiada: una indicación que dura unos segundos.
class GuidedStep<T> {
  const GuidedStep(this.cue, this.seconds);

  final T cue;
  final int seconds;
}

/// Instante de una sesión guiada.
class GuidedMoment<T> {
  const GuidedMoment({
    required this.index,
    required this.step,
    required this.stepProgress,
    required this.secondsLeftInStep,
    required this.remainingSeconds,
    required this.progress,
    required this.done,
  });

  final int index;
  final GuidedStep<T> step;

  /// Avance dentro del paso 0–1.
  final double stepProgress;
  final int secondsLeftInStep;
  final int remainingSeconds;

  /// Avance de toda la sesión 0–1.
  final double progress;
  final bool done;
}

/// Secuencia de pasos con tiempo (suelo pélvico, pausas activas, descanso
/// visual). Pura: dado el tiempo transcurrido devuelve el paso en curso.
class GuidedSequence<T> {
  GuidedSequence(List<GuidedStep<T>> steps)
    : steps = List<GuidedStep<T>>.unmodifiable(steps.where((GuidedStep<T> s) => s.seconds > 0)) {
    if (this.steps.isEmpty) throw ArgumentError('Una sesión necesita al menos un paso');
  }

  final List<GuidedStep<T>> steps;

  int get totalSeconds => steps.fold(0, (int sum, GuidedStep<T> s) => sum + s.seconds);

  GuidedMoment<T> at(double elapsedSeconds) {
    final double total = totalSeconds.toDouble();
    final double e = elapsedSeconds.isFinite ? elapsedSeconds.clamp(0.0, total) : 0;
    final bool done = e >= total;
    double rest = e;
    int index = 0;
    for (; index < steps.length - 1; index++) {
      if (rest < steps[index].seconds) break;
      rest -= steps[index].seconds;
    }
    final GuidedStep<T> step = steps[index];
    final double stepProgress = done ? 1 : (rest / step.seconds).clamp(0.0, 1.0);
    return GuidedMoment<T>(
      index: index,
      step: step,
      stepProgress: stepProgress,
      secondsLeftInStep: done ? 0 : math.max(1, (step.seconds - rest).ceil()),
      remainingSeconds: (total - e).ceil(),
      progress: total == 0 ? 1 : e / total,
      done: done,
    );
  }
}
