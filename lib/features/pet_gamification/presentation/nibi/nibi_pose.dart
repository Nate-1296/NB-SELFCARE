import 'dart:math' as math;
import 'dart:ui' show Offset, lerpDouble;

import 'package:flutter/foundation.dart';

import '../../domain/nibi_activity.dart';

/// Forma de los ojos.
enum NibiEyes { open, happy, closed, sparkle, focused }

/// Forma de la boca.
enum NibiMouth { smile, open, round, sleepy, grin }

/// Postura de Nibi en un instante: todo lo que el pintor necesita para dibujar
/// un fotograma. Las medidas están en unidades del lienzo de 200 × 200.
@immutable
class NibiPose {
  const NibiPose({
    this.bodyX = 0,
    this.turn = 1,
    this.bodyY = 0,
    this.squash = 1,
    this.headTilt = 0,
    this.breath = 0,
    this.eyeOpen = 1,
    this.eyes = NibiEyes.open,
    this.gaze = Offset.zero,
    this.browLift = 0,
    this.mouth = NibiMouth.smile,
    this.mouthOpen = 0,
    this.wingFlap = 0,
    this.tailSwing = 0,
    this.leftArm = 0.35,
    this.rightArm = -0.35,
    this.blush = 0.4,
    this.aura = 0,
    this.propLift = 0,
  });

  /// Desplazamiento horizontal del cuerpo (sacudidas).
  final double bodyX;

  /// Giro sobre sí mismo como escala horizontal: 1 de frente, −1 de espaldas
  /// (se dibuja reflejado), cerca de 0 de perfil.
  final double turn;

  /// Desplazamiento vertical del cuerpo (negativo = arriba).
  final double bodyY;

  /// Aplastamiento al aterrizar (1 = normal, > 1 más ancho y bajo).
  final double squash;

  /// Inclinación de la cabeza (radianes).
  final double headTilt;

  /// Respiración 0–1 (el pecho se expande levemente).
  final double breath;

  /// Apertura de los ojos 0–1 (parpadeo).
  final double eyeOpen;
  final NibiEyes eyes;

  /// Dirección de la mirada (−1…1 en cada eje).
  final Offset gaze;

  /// Ceja derecha levantada 0–1 (curiosidad).
  final double browLift;
  final NibiMouth mouth;

  /// Apertura de la boca 0–1 (masticar, celebrar).
  final double mouthOpen;

  /// Giro de las alas (radianes, positivo = arriba).
  final double wingFlap;

  /// Giro de la cola (radianes).
  final double tailSwing;

  /// Giro de cada brazo desde el hombro en el sentido de la pantalla
  /// (0 = colgando). Hacia fuera: positivo en el izquierdo, negativo en el
  /// derecho; ±2,5 rad ≈ brazo levantado.
  final double leftArm;
  final double rightArm;
  final double blush;

  /// Intensidad del aura 0–1.
  final double aura;

  /// Avance del objeto que sostiene (pesa) 0–1.
  final double propLift;

  NibiPose copyWith({
    double? bodyX,
    double? turn,
    double? bodyY,
    double? squash,
    double? headTilt,
    double? breath,
    double? eyeOpen,
    NibiEyes? eyes,
    Offset? gaze,
    double? browLift,
    NibiMouth? mouth,
    double? mouthOpen,
    double? wingFlap,
    double? tailSwing,
    double? leftArm,
    double? rightArm,
    double? blush,
    double? aura,
  }) =>
      NibiPose(
        bodyX: bodyX ?? this.bodyX,
        turn: turn ?? this.turn,
        bodyY: bodyY ?? this.bodyY,
        squash: squash ?? this.squash,
        headTilt: headTilt ?? this.headTilt,
        breath: breath ?? this.breath,
        eyeOpen: eyeOpen ?? this.eyeOpen,
        eyes: eyes ?? this.eyes,
        gaze: gaze ?? this.gaze,
        browLift: browLift ?? this.browLift,
        mouth: mouth ?? this.mouth,
        mouthOpen: mouthOpen ?? this.mouthOpen,
        wingFlap: wingFlap ?? this.wingFlap,
        tailSwing: tailSwing ?? this.tailSwing,
        leftArm: leftArm ?? this.leftArm,
        rightArm: rightArm ?? this.rightArm,
        blush: blush ?? this.blush,
        aura: aura ?? this.aura,
        propLift: propLift,
      );

  /// Interpolación entre posturas (transición de una actividad a otra).
  static NibiPose lerp(NibiPose a, NibiPose b, double t) {
    double l(double x, double y) => lerpDouble(x, y, t)!;
    return NibiPose(
      bodyX: l(a.bodyX, b.bodyX),
      turn: l(a.turn, b.turn),
      bodyY: l(a.bodyY, b.bodyY),
      squash: l(a.squash, b.squash),
      headTilt: l(a.headTilt, b.headTilt),
      breath: l(a.breath, b.breath),
      eyeOpen: l(a.eyeOpen, b.eyeOpen),
      eyes: t < 0.5 ? a.eyes : b.eyes,
      gaze: Offset.lerp(a.gaze, b.gaze, t)!,
      browLift: l(a.browLift, b.browLift),
      mouth: t < 0.5 ? a.mouth : b.mouth,
      mouthOpen: l(a.mouthOpen, b.mouthOpen),
      wingFlap: l(a.wingFlap, b.wingFlap),
      tailSwing: l(a.tailSwing, b.tailSwing),
      leftArm: l(a.leftArm, b.leftArm),
      rightArm: l(a.rightArm, b.rightArm),
      blush: l(a.blush, b.blush),
      aura: l(a.aura, b.aura),
      propLift: l(a.propLift, b.propLift),
    );
  }

  /// Todos los valores son finitos (prueba de las coreografías).
  bool get isFinite => <double>[
        bodyX,
        turn,
        bodyY,
        squash,
        headTilt,
        breath,
        eyeOpen,
        gaze.dx,
        gaze.dy,
        browLift,
        mouthOpen,
        wingFlap,
        tailSwing,
        leftArm,
        rightArm,
        blush,
        aura,
        propLift,
      ].every((double v) => v.isFinite);
}

/// Coreografías: la postura de cada actividad en función del tiempo [t] (s).
///
/// Son funciones puras y deterministas (sin reloj ni azar): el mismo `t` da
/// siempre el mismo fotograma, así se pueden probar y en Modo Papel basta con
/// pintar `t = 0`.
abstract final class NibiChoreography {
  static const double _tau = math.pi * 2;

  /// Parpadeo natural: intervalos irregulares que se repiten cada 15,3 s.
  static double blink(double t) {
    const List<double> gaps = <double>[2.7, 4.1, 3.3, 5.2];
    const double cycle = 15.3;
    double local = t % cycle;
    for (final double gap in gaps) {
      if (local < gap) {
        final double d = gap - local;
        // Cierre y apertura en 0,16 s al final de cada intervalo.
        return d < 0.16 ? (d - 0.08).abs() / 0.08 : 1;
      }
      local -= gap;
    }
    return 1;
  }

  static double _wave(double t, double period, [double phase = 0]) => math.sin(_tau * t / period + phase);

  /// Periodo del bote de la pelota al jugar (s).
  static const double ballPeriod = 1.2;

  /// Altura de la pelota 0 (suelo) – 1 (arriba): parábola en cada bote.
  static double ballHeight(double t) {
    final double k = (t % ballPeriod) / ballPeriod;
    return 4 * k * (1 - k);
  }

  /// Envolvente suave de una reacción: entra, se mantiene y sale.
  static double envelope(double k) {
    if (k <= 0 || k >= 1) return 0;
    if (k < 0.15) return _easeOut(k / 0.15);
    if (k > 0.8) return _easeOut((1 - k) / 0.2);
    return 1;
  }

  static double _easeOut(double x) => 1 - (1 - x) * (1 - x);

  /// Postura con una reacción encima; [age] son los segundos desde que empezó.
  static NibiPose react(NibiPose base, NibiReaction reaction, double age) {
    final double k = (age / reaction.seconds).clamp(0.0, 1.0);
    final double env = envelope(k);
    if (env <= 0) return base;
    NibiPose mix(NibiPose target) => NibiPose.lerp(base, target, env);
    switch (reaction) {
      case NibiReaction.pat:
        return mix(base.copyWith(
          eyes: NibiEyes.happy,
          mouth: NibiMouth.grin,
          headTilt: 0.16 + math.sin(age * 9) * 0.05,
          squash: 1.03,
          bodyY: 1,
          blush: 1,
          tailSwing: math.sin(age * 12) * 0.3,
        ));
      case NibiReaction.giggle:
        return mix(base.copyWith(
          bodyX: math.sin(age * 38) * 2.6,
          eyes: NibiEyes.happy,
          mouth: NibiMouth.open,
          mouthOpen: 0.45 + 0.25 * math.sin(age * 19).abs(),
          headTilt: math.sin(age * 19) * 0.07,
          leftArm: 1.0 + math.sin(age * 19) * 0.3,
          rightArm: -1.0 - math.sin(age * 19) * 0.3,
          blush: 1,
        ));
      case NibiReaction.spin:
        final double e = k < 0.5 ? 2 * k * k : 1 - math.pow(-2 * k + 2, 2) / 2;
        final double turn = math.cos(_tau * e);
        return NibiPose.lerp(
          base,
          base.copyWith(
            turn: turn.abs() < 0.08 ? 0.08 * (turn.isNegative ? -1 : 1) : turn,
            bodyY: -math.sin(math.pi * k) * 10,
            eyes: NibiEyes.sparkle,
            mouth: NibiMouth.grin,
            wingFlap: 0.45,
            leftArm: 1.3,
            rightArm: -1.3,
          ),
          // El giro no se suaviza con la envolvente (empieza y acaba de frente).
          k < 1 ? 1 : 0,
        );
      case NibiReaction.hop:
        final double air = math.sin(math.pi * k);
        return mix(base.copyWith(
          bodyY: -air * 26,
          squash: k < 0.12 || k > 0.88 ? 1.07 : 1 - air * 0.03,
          eyes: NibiEyes.happy,
          mouth: NibiMouth.open,
          mouthOpen: 0.5,
          wingFlap: 0.3 + math.sin(age * 30) * 0.3,
          leftArm: 2.5,
          rightArm: -2.5,
          tailSwing: -air * 0.4,
        ));
      case NibiReaction.puff:
        final bool inhaling = k < 0.35;
        return mix(base.copyWith(
          breath: inhaling ? k / 0.35 : 1 - (k - 0.35) / 0.65,
          bodyY: inhaling ? -2 : 0,
          eyes: inhaling ? NibiEyes.closed : NibiEyes.happy,
          eyeOpen: inhaling ? 0 : 1,
          mouth: NibiMouth.round,
          mouthOpen: inhaling ? 0.1 : 0.9,
          headTilt: inhaling ? 0.06 : -0.1,
          wingFlap: inhaling ? 0.3 : 0.12,
          blush: 0.9,
        ));
      case NibiReaction.purr:
        return mix(base.copyWith(
          eyes: NibiEyes.closed,
          eyeOpen: 0,
          mouth: NibiMouth.smile,
          headTilt: math.sin(age * 3.2) * 0.14,
          bodyX: math.sin(age * 3.2) * 2,
          blush: 1,
          tailSwing: math.sin(age * 2.4) * 0.35,
          wingFlap: 0.04,
        ));
      case NibiReaction.yawn:
        final double open = math.sin(math.pi * k);
        return mix(base.copyWith(
          eyes: NibiEyes.closed,
          eyeOpen: 0,
          mouth: NibiMouth.open,
          mouthOpen: open,
          headTilt: -0.1 * open,
          bodyY: -2 * open,
          leftArm: 0.35 + 2.2 * open,
          rightArm: -0.35 - 2.2 * open,
          wingFlap: 0.1 + 0.25 * open,
        ));
      case NibiReaction.lookAround:
        final double side = math.sin(_tau * k);
        return mix(base.copyWith(
          gaze: Offset(side * 1, -0.1),
          headTilt: side * 0.12,
          browLift: 0.5,
          mouth: NibiMouth.round,
          mouthOpen: 0.1,
        ));
      case NibiReaction.stretch:
        final double reach = math.sin(math.pi * k);
        return mix(base.copyWith(
          wingFlap: 0.1 + 0.65 * reach,
          bodyY: -3 * reach,
          eyes: NibiEyes.happy,
          tailSwing: 0.25 * reach,
          squash: 1 - 0.03 * reach,
        ));
      case NibiReaction.snort:
        return mix(base.copyWith(
          headTilt: -0.06 + math.sin(age * 20) * 0.02,
          eyes: NibiEyes.closed,
          eyeOpen: 0,
          mouth: NibiMouth.smile,
        ));
    }
  }

  /// Respiración guiada: [lung] 0 (vacío) – 1 (lleno). Nibi flota en zen y
  /// sube, se expande y abre las alas al ritmo de la persona.
  static NibiPose guided(NibiPose base, double lung) => base.copyWith(
        breath: lung,
        bodyY: -5 - lung * 7,
        squash: 1 + lung * 0.025,
        wingFlap: 0.08 + lung * 0.38,
        eyes: NibiEyes.closed,
        eyeOpen: 0,
        mouth: NibiMouth.smile,
        headTilt: -0.04 * lung,
        tailSwing: 0.05 * lung,
        // El anillo de respiración sustituye al aura.
        aura: 0,
      );

  static NibiPose pose(NibiActivity activity, double t, {bool aura = false}) {
    final double breath = 0.5 + 0.5 * _wave(t, 3.2);
    final double blinkOpen = blink(t);
    final double auraLevel = aura ? 0.75 + 0.25 * _wave(t, 2.4) : 0;
    switch (activity) {
      case NibiActivity.idle:
        return NibiPose(
          bodyY: _wave(t, 3.2) * 1.2,
          headTilt: _wave(t, 9) * 0.05,
          breath: breath,
          eyeOpen: blinkOpen,
          gaze: Offset(_wave(t, 12) * 0.6, _wave(t, 17) * 0.2),
          wingFlap: 0.06 + _wave(t, 3.2) * 0.04,
          tailSwing: _wave(t, 4.8) * 0.18,
          aura: auraLevel,
        );
      case NibiActivity.happy:
        final double hop = _wave(t, 0.9).abs();
        return NibiPose(
          bodyY: -hop * 5,
          squash: 1 + (1 - hop) * 0.03,
          headTilt: _wave(t, 1.8) * 0.08,
          breath: breath,
          eyes: NibiEyes.happy,
          mouth: NibiMouth.grin,
          wingFlap: 0.2 + _wave(t, 0.45) * 0.14,
          tailSwing: _wave(t, 0.9) * 0.32,
          rightArm: -2.3 + _wave(t, 0.5) * 0.35,
          blush: 0.9,
          aura: auraLevel,
        );
      case NibiActivity.eating:
        return NibiPose(
          bodyY: _wave(t, 2) * 0.8,
          breath: breath,
          eyes: (t % 3) < 1.6 ? NibiEyes.happy : NibiEyes.open,
          eyeOpen: blinkOpen,
          mouth: NibiMouth.open,
          mouthOpen: 0.15 + 0.6 * (0.5 + 0.5 * _wave(t, 0.42)),
          tailSwing: _wave(t, 1.6) * 0.22,
          wingFlap: 0.08,
          rightArm: 2.15 + _wave(t, 0.84) * 0.12,
          blush: 0.8,
          aura: auraLevel,
        );
      case NibiActivity.drinking:
        final double sip = 0.5 + 0.5 * _wave(t, 1.4);
        return NibiPose(
          bodyY: _wave(t, 1.4) * 0.8,
          headTilt: -0.12 - sip * 0.06,
          breath: breath,
          eyes: NibiEyes.closed,
          mouth: NibiMouth.round,
          mouthOpen: 0.4 + sip * 0.3,
          tailSwing: _wave(t, 2.4) * 0.16,
          wingFlap: 0.06,
          rightArm: 2.25 + sip * 0.15,
          blush: 0.7,
          aura: auraLevel,
        );
      case NibiActivity.sleeping:
        final double slow = 0.5 + 0.5 * _wave(t, 4.6);
        return NibiPose(
          bodyY: 3,
          squash: 1.04 + slow * 0.02,
          headTilt: 0.2,
          breath: slow,
          eyes: NibiEyes.closed,
          eyeOpen: 0,
          mouth: NibiMouth.sleepy,
          wingFlap: -0.18,
          tailSwing: 0.42 + _wave(t, 9) * 0.04,
          leftArm: 0.15,
          rightArm: -0.15,
          blush: 0.5,
          aura: auraLevel,
        );
      case NibiActivity.zen:
        return NibiPose(
          bodyY: -7 + _wave(t, 3.6) * 3,
          breath: 0.5 + 0.5 * _wave(t, 5),
          eyes: NibiEyes.closed,
          eyeOpen: 0,
          wingFlap: 0.12 + _wave(t, 3.6) * 0.05,
          tailSwing: _wave(t, 7) * 0.08,
          leftArm: -0.75,
          rightArm: 0.75,
          blush: 0.5,
          aura: math.max(auraLevel, 0.55 + 0.25 * _wave(t, 3.6)),
        );
      case NibiActivity.workout:
        final double lift = 0.5 + 0.5 * _wave(t, 1.3);
        return NibiPose(
          bodyY: -lift * 2,
          squash: 1 + (1 - lift) * 0.025,
          breath: lift,
          eyes: NibiEyes.focused,
          eyeOpen: blinkOpen,
          mouth: NibiMouth.grin,
          wingFlap: 0.1,
          tailSwing: _wave(t, 1.3) * 0.2,
          leftArm: 2.55 + lift * 0.25,
          rightArm: -2.55 - lift * 0.25,
          blush: 0.85,
          propLift: lift,
          aura: auraLevel,
        );
      case NibiActivity.weighing:
        return NibiPose(
          bodyY: -9 + _wave(t, 0.7) * 0.6,
          headTilt: _wave(t, 2.8) * 0.05,
          breath: breath,
          eyeOpen: blinkOpen,
          gaze: const Offset(0, 0.9),
          browLift: 0.5,
          mouth: NibiMouth.round,
          mouthOpen: 0.3,
          wingFlap: 0.14 + _wave(t, 0.7) * 0.05,
          tailSwing: _wave(t, 1.4) * 0.25,
          leftArm: 0.9,
          rightArm: -0.9,
          aura: auraLevel,
        );
      case NibiActivity.celebrating:
        final double jump = _wave(t, 1.1).abs();
        return NibiPose(
          bodyY: -jump * 14,
          squash: jump < 0.15 ? 1.06 : 1 - jump * 0.02,
          headTilt: _wave(t, 2.2) * 0.06,
          breath: breath,
          eyes: NibiEyes.sparkle,
          mouth: NibiMouth.open,
          mouthOpen: 0.55,
          wingFlap: 0.35 + _wave(t, 0.4) * 0.25,
          tailSwing: _wave(t, 0.55) * 0.35,
          leftArm: 2.7,
          rightArm: -2.7,
          blush: 1,
          aura: auraLevel,
        );
      case NibiActivity.playing:
        // Mira la pelota que bota a su derecha y salta al ritmo.
        final double bounce = ballHeight(t);
        final double hop = _wave(t, ballPeriod).abs();
        return NibiPose(
          bodyY: -hop * 4,
          squash: 1 + (1 - hop) * 0.03,
          headTilt: -0.08 - bounce * 0.12,
          breath: breath,
          eyeOpen: blinkOpen,
          gaze: Offset(0.9, 0.6 - bounce * 1.4),
          mouth: NibiMouth.grin,
          wingFlap: 0.18 + _wave(t, 0.5) * 0.1,
          tailSwing: _wave(t, ballPeriod) * 0.35,
          rightArm: -0.9 - bounce * 1.2,
          blush: 0.8,
          aura: auraLevel,
        );
      case NibiActivity.curious:
        return NibiPose(
          bodyY: _wave(t, 3) * 1,
          headTilt: 0.22 + _wave(t, 4) * 0.04,
          breath: breath,
          eyeOpen: blinkOpen,
          gaze: const Offset(0.7, -0.35),
          browLift: 1,
          mouth: NibiMouth.round,
          mouthOpen: 0.15,
          wingFlap: 0.05,
          tailSwing: _wave(t, 2) * 0.28,
          rightArm: 1.2,
          aura: auraLevel,
        );
    }
  }
}
