import 'guided_sequence.dart';

/// Postura de la figura que guía una pausa activa, vista de frente.
///
/// Ángulos en grados. Brazos y piernas: 0 = colgando recto; positivo = se abre
/// hacia fuera del cuerpo (180 = brazo estirado por encima de la cabeza). El
/// antebrazo y la espinilla se miden respecto al segmento anterior: positivo =
/// se dobla hacia dentro (hacia la línea media).
class StickPose {
  const StickPose({
    this.torsoLean = 0,
    this.headTilt = 0,
    this.headTurn = 0,
    this.shoulderLift = 0,
    this.leftArm = 12,
    this.leftForearm = 0,
    this.rightArm = 12,
    this.rightForearm = 0,
    this.leftLeg = 6,
    this.leftShin = 0,
    this.rightLeg = 6,
    this.rightShin = 0,
    this.seated = false,
    this.eyesClosed = false,
  });

  /// Inclinación lateral del tronco (positivo = hacia la derecha de la pantalla).
  final double torsoLean;
  final double headTilt;

  /// Giro de la cabeza −1 (izquierda) a 1 (derecha).
  final double headTurn;

  /// Hombros encogidos 0–1.
  final double shoulderLift;
  final double leftArm;
  final double leftForearm;
  final double rightArm;
  final double rightForearm;
  final double leftLeg;
  final double leftShin;
  final double rightLeg;
  final double rightShin;
  final bool seated;
  final bool eyesClosed;
}

/// Un movimiento de la rutina: qué decir, cuánto dura y cómo se ve.
class BreakMove {
  const BreakMove(this.key, this.seconds, this.pose);

  /// Clave del texto (ver `care_l10n.dart`).
  final String key;
  final int seconds;
  final StickPose pose;
}

/// Rutina de pausa activa (1–3 minutos), pensada para hacerse en la silla o de pie.
class ActiveBreakRoutine {
  const ActiveBreakRoutine({required this.id, required this.moves});

  final String id;
  final List<BreakMove> moves;

  int get totalSeconds => moves.fold(0, (int s, BreakMove m) => s + m.seconds);

  GuidedSequence<BreakMove> sequence() => GuidedSequence<BreakMove>(<GuidedStep<BreakMove>>[
    for (final BreakMove m in moves) GuidedStep<BreakMove>(m, m.seconds),
  ]);

  static const StickPose _seated = StickPose(
    seated: true,
    leftLeg: 70,
    leftShin: 70,
    rightLeg: 70,
    rightShin: 70,
  );

  static const ActiveBreakRoutine neckShoulders = ActiveBreakRoutine(
    id: 'neck_shoulders',
    moves: <BreakMove>[
      BreakMove('neckTiltRight', 20, StickPose(headTilt: 28)),
      BreakMove('neckTiltLeft', 20, StickPose(headTilt: -28)),
      BreakMove('lookRight', 15, StickPose(headTurn: 1)),
      BreakMove('lookLeft', 15, StickPose(headTurn: -1)),
      BreakMove('shoulderShrug', 20, StickPose(shoulderLift: 1, leftArm: 6, rightArm: 6)),
      BreakMove(
        'shoulderRolls',
        20,
        StickPose(leftArm: 30, leftForearm: 120, rightArm: 30, rightForearm: 120),
      ),
      BreakMove(
        'armsOverhead',
        20,
        StickPose(leftArm: 170, leftForearm: 10, rightArm: 170, rightForearm: 10),
      ),
    ],
  );

  static const ActiveBreakRoutine back = ActiveBreakRoutine(
    id: 'back',
    moves: <BreakMove>[
      BreakMove(
        'armsOverhead',
        20,
        StickPose(leftArm: 170, leftForearm: 10, rightArm: 170, rightForearm: 10),
      ),
      BreakMove('sideBendRight', 20, StickPose(torsoLean: 18, leftArm: 165, rightArm: 20)),
      BreakMove('sideBendLeft', 20, StickPose(torsoLean: -18, leftArm: 20, rightArm: 165)),
      BreakMove('chestOpener', 25, StickPose(leftArm: 60, rightArm: 60, headTilt: 0)),
      BreakMove(
        'twistRight',
        20,
        StickPose(
          seated: true,
          headTurn: 1,
          leftArm: 40,
          leftForearm: 90,
          rightArm: 25,
          leftLeg: 70,
          leftShin: 70,
          rightLeg: 70,
          rightShin: 70,
        ),
      ),
      BreakMove(
        'twistLeft',
        20,
        StickPose(
          seated: true,
          headTurn: -1,
          leftArm: 25,
          rightArm: 40,
          rightForearm: 90,
          leftLeg: 70,
          leftShin: 70,
          rightLeg: 70,
          rightShin: 70,
        ),
      ),
    ],
  );

  static const ActiveBreakRoutine wrists = ActiveBreakRoutine(
    id: 'wrists',
    moves: <BreakMove>[
      BreakMove('wristExtensionRight', 20, StickPose(rightArm: 90, leftArm: 50, leftForearm: 40)),
      BreakMove('wristExtensionLeft', 20, StickPose(leftArm: 90, rightArm: 50, rightForearm: 40)),
      BreakMove(
        'wristFlexionRight',
        20,
        StickPose(rightArm: 90, rightForearm: -10, leftArm: 50, leftForearm: 40),
      ),
      BreakMove(
        'wristFlexionLeft',
        20,
        StickPose(leftArm: 90, leftForearm: -10, rightArm: 50, rightForearm: 40),
      ),
      BreakMove(
        'fistOpen',
        20,
        StickPose(leftArm: 40, leftForearm: 50, rightArm: 40, rightForearm: 50),
      ),
      BreakMove('shakeHands', 15, StickPose(leftArm: 25, rightArm: 25)),
    ],
  );

  static const ActiveBreakRoutine hipsLegs = ActiveBreakRoutine(
    id: 'hips_legs',
    moves: <BreakMove>[
      BreakMove(
        'marchInPlace',
        30,
        StickPose(leftLeg: 45, leftShin: 80, leftArm: 30, rightArm: -10),
      ),
      BreakMove(
        'quadStretchRight',
        20,
        StickPose(rightLeg: -10, rightShin: -150, rightArm: 20, leftArm: 60),
      ),
      BreakMove(
        'quadStretchLeft',
        20,
        StickPose(leftLeg: -10, leftShin: -150, leftArm: 20, rightArm: 60),
      ),
      BreakMove('calfRaises', 30, StickPose(leftLeg: 2, rightLeg: 2, leftArm: 20, rightArm: 20)),
      BreakMove(
        'hipCircles',
        20,
        StickPose(torsoLean: 8, leftArm: 35, leftForearm: 110, rightArm: 35, rightForearm: 110),
      ),
    ],
  );

  /// Descanso visual: la regla 20-20-20 ampliada (mirar lejos, parpadear, palmear).
  static const ActiveBreakRoutine eyes = ActiveBreakRoutine(
    id: 'eyes',
    moves: <BreakMove>[
      BreakMove('lookFar', 20, _seated),
      BreakMove(
        'slowBlinks',
        10,
        StickPose(
          seated: true,
          eyesClosed: true,
          leftLeg: 70,
          leftShin: 70,
          rightLeg: 70,
          rightShin: 70,
        ),
      ),
      BreakMove(
        'palming',
        30,
        StickPose(
          seated: true,
          eyesClosed: true,
          leftArm: 30,
          leftForearm: 150,
          rightArm: 30,
          rightForearm: 150,
          leftLeg: 70,
          leftShin: 70,
          rightLeg: 70,
          rightShin: 70,
        ),
      ),
      BreakMove(
        'eyeFigureEight',
        20,
        StickPose(
          seated: true,
          headTurn: 0.4,
          leftLeg: 70,
          leftShin: 70,
          rightLeg: 70,
          rightShin: 70,
        ),
      ),
    ],
  );

  static const List<ActiveBreakRoutine> all = <ActiveBreakRoutine>[
    neckShoulders,
    back,
    wrists,
    hipsLegs,
    eyes,
  ];

  static ActiveBreakRoutine byId(String id) =>
      all.firstWhere((ActiveBreakRoutine r) => r.id == id, orElse: () => neckShoulders);
}
