import 'guided_sequence.dart';

/// Indicación de un ejercicio de suelo pélvico.
enum PelvicCue {
  /// Contraer y sostener (fibras lentas).
  squeeze,

  /// Soltar del todo y descansar.
  release,

  /// Contracción rápida (fibras rápidas: tos, estornudo, risa).
  quickSqueeze,
  quickRelease,

  /// Inhalar dejando que el suelo pélvico baje y se ablande.
  lengthenInhale,

  /// Exhalar sin apretar.
  lengthenExhale,

  /// Pausa entre bloques.
  rest,
}

/// Variante de sesión: el programa por niveles o solo relajación (para quien
/// nota tensión o dolor: un suelo pélvico tenso no necesita más fuerza).
enum PelvicVariant { program, relaxOnly }

/// Nivel del programa: sostener más tiempo y más repeticiones, siempre con un
/// descanso al menos igual de largo que la contracción.
class PelvicLevel {
  const PelvicLevel({
    required this.level,
    required this.holdSeconds,
    required this.slowReps,
    required this.quickReps,
  });

  final int level;
  final int holdSeconds;
  final int slowReps;
  final int quickReps;

  /// Basado en la pauta habitual de fisioterapia (hasta 10 s × 10 lentas y 10
  /// rápidas), en cinco escalones para empezar sin forzar.
  static const List<PelvicLevel> all = <PelvicLevel>[
    PelvicLevel(level: 1, holdSeconds: 3, slowReps: 5, quickReps: 5),
    PelvicLevel(level: 2, holdSeconds: 5, slowReps: 8, quickReps: 8),
    PelvicLevel(level: 3, holdSeconds: 7, slowReps: 10, quickReps: 10),
    PelvicLevel(level: 4, holdSeconds: 10, slowReps: 10, quickReps: 10),
    PelvicLevel(level: 5, holdSeconds: 10, slowReps: 12, quickReps: 15),
  ];

  static PelvicLevel of(int level) => all[(level - 1).clamp(0, all.length - 1)];
}

abstract final class PelvicFloorProgram {
  /// Sesiones completas en un nivel antes de sugerir el siguiente.
  static const int sessionsToLevelUp = 6;

  static const int _quickSeconds = 1;
  static const int _lengthenCycles = 3;

  static GuidedSequence<PelvicCue> session({required PelvicVariant variant, required int level}) {
    if (variant == PelvicVariant.relaxOnly) {
      return GuidedSequence<PelvicCue>(<GuidedStep<PelvicCue>>[
        for (int i = 0; i < 6; i++) ...<GuidedStep<PelvicCue>>[
          const GuidedStep<PelvicCue>(PelvicCue.lengthenInhale, 5),
          const GuidedStep<PelvicCue>(PelvicCue.lengthenExhale, 6),
        ],
      ]);
    }
    final PelvicLevel l = PelvicLevel.of(level);
    return GuidedSequence<PelvicCue>(<GuidedStep<PelvicCue>>[
      for (int i = 0; i < l.slowReps; i++) ...<GuidedStep<PelvicCue>>[
        GuidedStep<PelvicCue>(PelvicCue.squeeze, l.holdSeconds),
        GuidedStep<PelvicCue>(PelvicCue.release, l.holdSeconds),
      ],
      const GuidedStep<PelvicCue>(PelvicCue.rest, 5),
      for (int i = 0; i < l.quickReps; i++) ...<GuidedStep<PelvicCue>>[
        const GuidedStep<PelvicCue>(PelvicCue.quickSqueeze, _quickSeconds),
        const GuidedStep<PelvicCue>(PelvicCue.quickRelease, _quickSeconds),
      ],
      const GuidedStep<PelvicCue>(PelvicCue.rest, 3),
      // Siempre se termina soltando: tan importante como apretar.
      for (int i = 0; i < _lengthenCycles; i++) ...<GuidedStep<PelvicCue>>[
        const GuidedStep<PelvicCue>(PelvicCue.lengthenInhale, 4),
        const GuidedStep<PelvicCue>(PelvicCue.lengthenExhale, 6),
      ],
    ]);
  }

  /// Nivel que conviene proponer tras [sessionsAtLevel] sesiones completas en
  /// [current]. Solo sugiere: la persona decide si sube.
  static int? suggestedNextLevel({required int current, required int sessionsAtLevel}) {
    if (current >= PelvicLevel.all.length) return null;
    return sessionsAtLevel >= sessionsToLevelUp ? current + 1 : null;
  }

  /// Si la indicación es de contraer (para la vibración y el anillo).
  static bool isEffort(PelvicCue cue) => cue == PelvicCue.squeeze || cue == PelvicCue.quickSqueeze;
}
