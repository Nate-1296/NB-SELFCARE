import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/active_break_catalog.dart';

/// Figura de trazo que muestra la postura de cada movimiento de una pausa.
/// Vectorial y sin imágenes, como Nibi; en papel se dibuja en tinta.
class StickFigurePainter extends CustomPainter {
  StickFigurePainter({
    required this.pose,
    required this.ink,
    required this.accent,
    required this.floor,
  });

  final StickPose pose;
  final Color ink;
  final Color accent;
  final Color floor;

  static double _rad(double degrees) => degrees * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final double u = math.min(size.width, size.height) / 10;
    final Paint limb = Paint()
      ..color = ink
      ..strokeWidth = u * 0.42
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final Paint torsoPaint = Paint()
      ..color = accent
      ..strokeWidth = u * 0.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final double cx = size.width / 2;
    final double hipY = pose.seated ? size.height * 0.62 : size.height * 0.56;
    final Offset hip = Offset(cx, hipY);
    final double torsoLen = u * 2.8;
    final double lean = _rad(pose.torsoLean);
    final Offset neck = hip + Offset(math.sin(lean), -math.cos(lean)) * torsoLen;
    final Offset shoulderAxis = Offset(math.cos(lean), math.sin(lean));
    final double shoulderHalf = u * 0.95;
    final double lift = pose.shoulderLift * u * 0.35;
    final Offset shoulderL = neck - shoulderAxis * shoulderHalf + Offset(0, u * 0.25 - lift);
    final Offset shoulderR = neck + shoulderAxis * shoulderHalf + Offset(0, u * 0.25 - lift);

    // Suelo y silla.
    final Paint ground = Paint()
      ..color = floor
      ..strokeWidth = u * 0.12
      ..strokeCap = StrokeCap.round;
    final double floorY = size.height * 0.94;
    canvas.drawLine(Offset(u, floorY), Offset(size.width - u, floorY), ground);
    if (pose.seated) {
      final Paint chair = Paint()
        ..color = floor
        ..strokeWidth = u * 0.22
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(cx - u * 1.6, hipY + u * 0.3),
        Offset(cx + u * 1.6, hipY + u * 0.3),
        chair,
      );
      canvas.drawLine(Offset(cx - u * 1.4, hipY + u * 0.3), Offset(cx - u * 1.4, floorY), chair);
      canvas.drawLine(Offset(cx + u * 1.4, hipY + u * 0.3), Offset(cx + u * 1.4, floorY), chair);
    }

    // Piernas: el muslo se abre hacia fuera; la espinilla se dobla hacia dentro.
    final double legLen = pose.seated ? u * 1.7 : u * 2.0;
    void leg(double side, double thigh, double shin) {
      final Offset start = hip + Offset(side * u * 0.45, 0);
      final double a1 = _rad(thigh) * side;
      final Offset knee = start + Offset(math.sin(a1), math.cos(a1)) * legLen;
      final double a2 = a1 - _rad(shin) * side;
      final Offset foot = knee + Offset(math.sin(a2), math.cos(a2)) * legLen;
      canvas.drawLine(start, knee, limb);
      canvas.drawLine(knee, foot, limb);
    }

    leg(-1, pose.leftLeg, pose.leftShin);
    leg(1, pose.rightLeg, pose.rightShin);

    // Tronco.
    canvas.drawLine(hip, neck, torsoPaint);
    canvas.drawLine(shoulderL, shoulderR, limb);

    // Brazos.
    final double armLen = u * 1.35;
    void arm(Offset shoulder, double side, double upper, double fore) {
      final double a1 = _rad(upper) * side + lean;
      final Offset elbow = shoulder + Offset(math.sin(a1), math.cos(a1)) * armLen;
      final double a2 = a1 - _rad(fore) * side;
      final Offset hand = elbow + Offset(math.sin(a2), math.cos(a2)) * armLen;
      canvas.drawLine(shoulder, elbow, limb);
      canvas.drawLine(elbow, hand, limb);
      canvas.drawCircle(hand, u * 0.24, Paint()..color = ink);
    }

    arm(shoulderL, -1, pose.leftArm, pose.leftForearm);
    arm(shoulderR, 1, pose.rightArm, pose.rightForearm);

    // Cabeza: inclinación y giro (la nariz marca hacia dónde mira).
    final double tilt = lean + _rad(pose.headTilt);
    final double headR = u * 0.85;
    final Offset up = Offset(math.sin(tilt), -math.cos(tilt));
    final Offset head = neck + up * (headR + u * 0.35);
    // Cuello: une el tronco con la cabeza aunque esté inclinada.
    canvas.drawLine(neck, head - up * headR, limb);
    canvas.drawCircle(
      head,
      headR,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * 0.32,
    );
    final Offset eyeAxis = Offset(math.cos(tilt), math.sin(tilt));
    final Offset eyeCenter = head + eyeAxis * (pose.headTurn * headR * 0.45);
    final Paint eye = Paint()
      ..color = ink
      ..strokeWidth = u * 0.14
      ..strokeCap = StrokeCap.round;
    for (final double s in <double>[-1, 1]) {
      final Offset e =
          eyeCenter +
          eyeAxis * (s * headR * 0.36) -
          Offset(math.sin(tilt), -math.cos(tilt)) * (headR * 0.12);
      if (pose.eyesClosed) {
        canvas.drawLine(e - eyeAxis * (u * 0.16), e + eyeAxis * (u * 0.16), eye);
      } else {
        canvas.drawCircle(e, u * 0.11, Paint()..color = ink);
      }
    }
  }

  @override
  bool shouldRepaint(StickFigurePainter old) =>
      old.pose != pose || old.ink != ink || old.accent != accent || old.floor != floor;
}
