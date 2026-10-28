import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../domain/nibi_activity.dart';
import '../../domain/pet_catalog.dart';
import 'nibi_extras.dart';
import 'nibi_palette.dart';
import 'nibi_pose.dart';

/// Fotograma de Nibi: actividad, postura y tiempo de la coreografía.
@immutable
class NibiFrame {
  const NibiFrame({required this.activity, required this.pose, this.t = 0, this.reaction, this.reactionAge = 0});

  final NibiActivity activity;
  final NibiPose pose;

  /// Segundos de la coreografía (para efectos: Zzz, confeti…).
  final double t;

  /// Reacción en curso (caricia, bostezo…), o `null`.
  final NibiReaction? reaction;

  /// Segundos desde que empezó [reaction].
  final double reactionAge;
}

/// Encuadre del dibujo.
enum NibiFraming {
  /// Cuerpo entero con su sombra.
  full,

  /// Solo la cabeza (avatar circular).
  head,
}

/// Nibi dibujado con vectores (ADR-09): un dragón de cabeza grande, crestas,
/// alas y cola, en un lienzo de 200 × 200 unidades que se escala al tamaño.
///
/// Se repinta cuando cambia [frame] (sin reconstruir widgets), así que una
/// animación a 60 fps solo cuesta la fase de pintado.
class NibiPainter extends CustomPainter {
  NibiPainter({required this.frame, required this.palette, this.look = const NibiLook(), this.framing = NibiFraming.full})
      : super(repaint: frame);

  final ValueListenable<NibiFrame> frame;
  final NibiPalette palette;
  final NibiLook look;
  final NibiFraming framing;

  static const Offset _neck = Offset(100, 112);
  static const double _ground = 186;

  late final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.6
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..color = palette.outline;

  Paint _fill(Color c) => Paint()..color = c;

  @override
  void paint(Canvas canvas, Size size) {
    final NibiFrame f = frame.value;
    final NibiPose p = f.pose;
    final double s = size.shortestSide / 200;
    canvas.save();
    canvas.translate((size.width - 200 * s) / 2, (size.height - 200 * s) / 2);
    canvas.scale(s);
    if (framing == NibiFraming.head) {
      // La cabeza (con cuernos y sombrero) ocupa el círculo.
      final bool hat = look.hatId != null;
      canvas.translate(100, 100);
      canvas.scale(hat ? 1.45 : 1.6);
      canvas.translate(-100, (hat ? -62 : -70) - p.bodyY);
    }

    if (framing == NibiFraming.full) {
      paintAura(canvas, palette, p.aura, f.t);
      final double lift = (-p.bodyY).clamp(0.0, 30.0);
      if (f.activity == NibiActivity.weighing) {
        paintGroundShadow(canvas, palette, 1);
        paintScale(canvas, palette, f.t);
      } else {
        paintGroundShadow(canvas, palette, 1 - lift / 40);
      }
    }

    canvas.save();
    // Salto, aplastamiento y giro con el punto de apoyo en el suelo.
    canvas.translate(100 + p.bodyX, _ground);
    canvas.scale(p.squash * p.turn, 1 / p.squash);
    canvas.translate(-100, -_ground + p.bodyY);

    _tail(canvas, p);
    _wing(canvas, p, left: true);
    _wing(canvas, p, left: false);
    _feet(canvas);
    _body(canvas, p);
    if (look.accessoryId == 'acc_scarf') paintScarf(canvas, palette, f.t);

    final bool armsOverHead = p.leftArm.abs() > 1.4 || p.rightArm.abs() > 1.4;
    if (!armsOverHead) _arms(canvas, p, f);

    canvas.save();
    canvas.translate(_neck.dx, _neck.dy);
    canvas.rotate(p.headTilt);
    canvas.translate(-_neck.dx, -_neck.dy);
    _head(canvas, p);
    paintFaceAccessory(canvas, palette, look.accessoryId, p.gaze);
    paintHat(canvas, palette, look.hatId, f.t);
    canvas.restore();
    paintNeckAccessory(canvas, palette, look.accessoryId, f.t);

    if (armsOverHead) _arms(canvas, p, f);
    canvas.restore();

    if (framing == NibiFraming.full) {
      paintEffects(canvas, palette, f, _stroke);
    }
    canvas.restore();
  }

  // ---------------------------------------------------------------- Cuerpo

  void _tail(Canvas canvas, NibiPose p) {
    const Offset base = Offset(122, 168);
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.rotate(-p.tailSwing);
    canvas.translate(-base.dx, -base.dy);

    // Línea central de la cola y su contorno con grosor decreciente.
    Offset at(double t) {
      const Offset c = Offset(170, 192);
      const Offset e = Offset(176, 140);
      final double u = 1 - t;
      return base * (u * u) + c * (2 * u * t) + e * (t * t);
    }

    const int n = 14;
    final List<Offset> left = <Offset>[];
    final List<Offset> right = <Offset>[];
    for (int i = 0; i <= n; i++) {
      final double t = i / n;
      final Offset a = at(t);
      final Offset b = at(math.min(1, t + 0.01)) - at(math.max(0, t - 0.01));
      final Offset normal = Offset(-b.dy, b.dx) / b.distance;
      final double w = 10 * (1 - t) + 2.2 * t;
      left.add(a + normal * w);
      right.add(a - normal * w);
    }
    final Path tail = Path()..addPolygon(<Offset>[...left, ...right.reversed], true);

    // Crestas a lo largo del lomo de la cola.
    for (final double t in <double>[0.3, 0.52, 0.72]) {
      final Offset a = at(t);
      final Offset b = at(t + 0.06) - at(t - 0.06);
      final Offset dir = b / b.distance;
      final Offset normal = Offset(-dir.dy, dir.dx);
      final double w = 10 * (1 - t) + 2.2 * t;
      final Path spike = Path()
        ..moveTo((a + normal * w - dir * 5).dx, (a + normal * w - dir * 5).dy)
        ..lineTo((a + normal * (w + 8)).dx, (a + normal * (w + 8)).dy)
        ..lineTo((a + normal * w + dir * 5).dx, (a + normal * w + dir * 5).dy)
        ..close();
      canvas.drawPath(spike, _fill(palette.crest));
      canvas.drawPath(spike, _stroke);
    }
    canvas.drawPath(tail, _fill(palette.body));
    canvas.drawPath(tail, _stroke);

    // Punta en forma de pica.
    final Offset tip = at(1);
    final Offset d = at(1) - at(0.9);
    final Offset dir = d / d.distance;
    final Offset normal = Offset(-dir.dy, dir.dx);
    final Path spade = Path()
      ..moveTo((tip - dir * 2).dx, (tip - dir * 2).dy)
      ..quadraticBezierTo((tip + normal * 9).dx, (tip + normal * 9).dy, (tip + dir * 12).dx, (tip + dir * 12).dy)
      ..quadraticBezierTo((tip - normal * 9).dx, (tip - normal * 9).dy, (tip - dir * 2).dx, (tip - dir * 2).dy)
      ..close();
    canvas.drawPath(spade, _fill(palette.crest));
    canvas.drawPath(spade, _stroke);
    canvas.restore();
  }

  void _wing(Canvas canvas, NibiPose p, {required bool left}) {
    canvas.save();
    if (left) {
      canvas.translate(200, 0);
      canvas.scale(-1, 1);
    }
    // Ala derecha en coordenadas locales: el anclaje es el origen.
    canvas.translate(124, 124);
    canvas.rotate(-p.wingFlap);
    final Path wing = Path()
      ..moveTo(0, -3)
      ..quadraticBezierTo(14, -32, 44, -38)
      ..quadraticBezierTo(39, -24, 42, -12)
      ..quadraticBezierTo(32, -13, 29, -2)
      ..quadraticBezierTo(21, -5, 16, 6)
      ..quadraticBezierTo(8, 2, 0, 9)
      ..close();
    canvas.drawPath(wing, _fill(palette.crest));
    final Paint rib = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = palette.crestShade;
    for (final Offset end in const <Offset>[Offset(41, -13), Offset(28, -3), Offset(15, 5)]) {
      canvas.drawLine(const Offset(3, 0), end, rib);
    }
    canvas.drawPath(wing, _stroke);
    canvas.restore();
  }

  void _feet(Canvas canvas) {
    for (final double x in <double>[83, 117]) {
      final Rect foot = Rect.fromCenter(center: Offset(x, 181), width: 30, height: 15);
      canvas.drawOval(foot, _fill(palette.body));
      canvas.drawOval(foot, _stroke);
      final Paint toe = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = palette.outline;
      for (final double dx in <double>[-6, 0, 6]) {
        canvas.drawLine(Offset(x + dx, 184), Offset(x + dx, 188), toe);
      }
    }
  }

  void _body(Canvas canvas, NibiPose p) {
    final double grow = 1 + p.breath * 0.03;
    final Rect body = Rect.fromCenter(center: const Offset(100, 148), width: 70 * grow, height: 72);
    canvas.drawOval(body, _fill(palette.body));
    canvas.drawOval(body, _stroke);
    final Rect belly = Rect.fromCenter(center: const Offset(100, 153), width: 44 * grow, height: 52);
    canvas.drawOval(belly, _fill(palette.belly));
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = palette.bellyLine;
    for (final double y in <double>[138, 149, 160, 170]) {
      final double half = 22 * grow * math.sqrt(math.max(0, 1 - math.pow((y - 153) / 26, 2)));
      canvas.drawPath(
        Path()
          ..moveTo(100 - half + 3, y)
          ..quadraticBezierTo(100, y + 3.5, 100 + half - 3, y),
        line,
      );
    }
    canvas.drawOval(belly, _stroke..strokeWidth = 1.8);
    _stroke.strokeWidth = 2.6;
  }

  /// Posición de la mano para un hombro y un ángulo.
  static Offset hand(Offset shoulder, double angle) =>
      shoulder + Offset(-24 * math.sin(angle), 24 * math.cos(angle));

  void _arms(Canvas canvas, NibiPose p, NibiFrame f) {
    const Offset leftShoulder = Offset(74, 126);
    const Offset rightShoulder = Offset(126, 126);
    final Offset lh = hand(leftShoulder, p.leftArm);
    final Offset rh = hand(rightShoulder, p.rightArm);
    if (f.activity == NibiActivity.workout) paintDumbbell(canvas, palette, lh, rh, _stroke);
    for (final (Offset shoulder, double angle) in <(Offset, double)>[
      (leftShoulder, p.leftArm),
      (rightShoulder, p.rightArm),
    ]) {
      canvas.save();
      canvas.translate(shoulder.dx, shoulder.dy);
      canvas.rotate(angle);
      final RRect arm = RRect.fromRectAndRadius(const Rect.fromLTWH(-6.5, -3, 13, 26), const Radius.circular(6.5));
      canvas.drawRRect(arm, _fill(palette.body));
      canvas.drawRRect(arm, _stroke);
      canvas.restore();
    }
    if (f.activity == NibiActivity.drinking) paintGlass(canvas, palette, rh, p.headTilt, _stroke);
    if (f.activity == NibiActivity.eating) paintApple(canvas, palette, rh, _stroke);
  }

  // ---------------------------------------------------------------- Cabeza

  void _head(Canvas canvas, NibiPose p) {
    // Crestas de la coronilla (detrás de la cabeza).
    for (final double x in <double>[86, 100, 114]) {
      final double h = x == 100 ? 17 : 13;
      final Path spike = Path()
        ..moveTo(x - 7, 36)
        ..quadraticBezierTo(x - 2, 34 - h * 0.6, x + 1, 34 - h)
        ..quadraticBezierTo(x + 3, 34 - h * 0.4, x + 7, 36)
        ..close();
      canvas.drawPath(spike, _fill(palette.crest));
      canvas.drawPath(spike, _stroke);
    }
    // Cuernos.
    for (final bool left in <bool>[true, false]) {
      canvas.save();
      if (left) {
        canvas.translate(200, 0);
        canvas.scale(-1, 1);
      }
      final Path horn = Path()
        ..moveTo(118, 42)
        ..quadraticBezierTo(130, 22, 140, 10)
        ..quadraticBezierTo(141, 28, 134, 44)
        ..close();
      canvas.drawPath(horn, _fill(palette.horn));
      canvas.drawPath(horn, _stroke);
      canvas.restore();
    }

    final Rect head = Rect.fromCenter(center: const Offset(100, 74), width: 100, height: 86);
    canvas.drawOval(head, _fill(palette.body));
    if (!palette.isInk) {
      // Volumen: media luna más oscura en la parte baja de la cabeza.
      canvas.save();
      canvas.clipPath(Path()..addOval(head));
      canvas.drawOval(head, _fill(palette.bodyShade));
      canvas.drawOval(head.shift(const Offset(0, -7)), _fill(palette.body));
      canvas.restore();
    }
    canvas.drawOval(head, _stroke);

    // Hocico y orificios nasales.
    final Rect muzzle = Rect.fromCenter(center: const Offset(100, 96), width: 58, height: 30);
    canvas.drawOval(muzzle, _fill(palette.muzzle));
    canvas.drawOval(muzzle, _stroke..strokeWidth = 2);
    _stroke.strokeWidth = 2.6;
    for (final double x in <double>[92, 108]) {
      canvas.drawOval(Rect.fromCenter(center: Offset(x, 91), width: 4, height: 3), _fill(palette.outline));
    }

    // Mejillas.
    if (p.blush > 0.05 && !palette.isInk) {
      final Paint blush = Paint()..color = palette.blush.withValues(alpha: 0.55 * p.blush);
      canvas.drawOval(Rect.fromCenter(center: const Offset(66, 88), width: 16, height: 9), blush);
      canvas.drawOval(Rect.fromCenter(center: const Offset(134, 88), width: 16, height: 9), blush);
    }

    _eyes(canvas, p);
    _brows(canvas, p);
    _mouth(canvas, p);
  }

  void _eyes(Canvas canvas, NibiPose p) {
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = palette.eye;
    for (final double x in <double>[80, 120]) {
      final Offset c = Offset(x, 70);
      final bool closed = p.eyes == NibiEyes.closed || p.eyeOpen < 0.15;
      if (closed) {
        canvas.drawPath(Path()
          ..moveTo(c.dx - 9, c.dy - 1)
          ..quadraticBezierTo(c.dx, c.dy + 7, c.dx + 9, c.dy - 1), line);
        continue;
      }
      switch (p.eyes) {
        case NibiEyes.happy:
          canvas.drawPath(Path()
            ..moveTo(c.dx - 9, c.dy + 3)
            ..quadraticBezierTo(c.dx, c.dy - 9, c.dx + 9, c.dy + 3), line);
        case NibiEyes.sparkle:
          // Ojos abiertos con brillos de estrella: emoción, no mareo.
          final Rect iris = Rect.fromCenter(center: c, width: 19, height: 23);
          canvas.drawOval(iris, _fill(palette.eye));
          final Path star = Path();
          final Offset sc = c + const Offset(2.5, -3.5);
          for (int i = 0; i < 8; i++) {
            final double r = i.isEven ? 6.5 : 2;
            final double a = i * math.pi / 4 - math.pi / 2;
            final Offset q = sc + Offset(math.cos(a) * r, math.sin(a) * r);
            if (i == 0) {
              star.moveTo(q.dx, q.dy);
            } else {
              star.lineTo(q.dx, q.dy);
            }
          }
          star.close();
          canvas.drawPath(star, _fill(palette.eyeShine));
          canvas.drawCircle(c + const Offset(-3.4, 4.6), 1.8, _fill(palette.eyeShine));
        case NibiEyes.open:
        case NibiEyes.focused:
        case NibiEyes.closed:
          final Offset g = Offset(p.gaze.dx * 3, p.gaze.dy * 3);
          final Rect iris = Rect.fromCenter(center: c + g, width: 19, height: 23 * p.eyeOpen);
          canvas.drawOval(iris, _fill(palette.eye));
          if (p.eyeOpen > 0.5) {
            canvas.drawCircle(c + g + const Offset(3.4, -4.6), 3.8, _fill(palette.eyeShine));
            canvas.drawCircle(c + g + const Offset(-3.4, 4.4), 1.7, _fill(palette.eyeShine));
          }
      }
    }
  }

  void _brows(Canvas canvas, NibiPose p) {
    if (p.eyes == NibiEyes.happy || p.eyes == NibiEyes.sparkle) return;
    final Paint brow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..color = palette.outline;
    final bool focused = p.eyes == NibiEyes.focused;
    // Izquierda.
    canvas.drawPath(
      Path()
        ..moveTo(72, focused ? 52 : 53)
        ..quadraticBezierTo(80, focused ? 52 : 49, 88, focused ? 56 : 52),
      brow,
    );
    // Derecha (se levanta con la curiosidad).
    final double lift = p.browLift * 6;
    canvas.drawPath(
      Path()
        ..moveTo(112, (focused ? 56 : 52) - lift)
        ..quadraticBezierTo(120, (focused ? 52 : 49) - lift * 1.2, 128, (focused ? 52 : 53) - lift * 0.6),
      brow,
    );
  }

  void _mouth(Canvas canvas, NibiPose p) {
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..color = palette.mouth;
    switch (p.mouth) {
      case NibiMouth.smile:
        canvas.drawPath(Path()
          ..moveTo(89, 102)
          ..quadraticBezierTo(100, 110, 111, 102), line);
      case NibiMouth.sleepy:
        canvas.drawPath(Path()
          ..moveTo(94, 104)
          ..quadraticBezierTo(100, 107, 106, 104), line);
      case NibiMouth.grin:
        final Path grin = Path()
          ..moveTo(87, 100)
          ..quadraticBezierTo(100, 118, 113, 100)
          ..quadraticBezierTo(100, 104, 87, 100)
          ..close();
        canvas.drawPath(grin, _fill(palette.mouth));
        canvas.drawOval(Rect.fromCenter(center: const Offset(100, 109), width: 9, height: 4), _fill(palette.tongue));
      case NibiMouth.open:
        final double depth = 6 + 14 * p.mouthOpen;
        final Path open = Path()
          ..moveTo(90, 101)
          ..quadraticBezierTo(100, 101 + depth, 110, 101)
          ..quadraticBezierTo(100, 99, 90, 101)
          ..close();
        canvas.drawPath(open, _fill(palette.mouth));
        if (p.mouthOpen > 0.3) {
          canvas.drawOval(
            Rect.fromCenter(center: Offset(100, 101 + depth * 0.62), width: 10, height: depth * 0.35),
            _fill(palette.tongue),
          );
        }
      case NibiMouth.round:
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(100, 104), width: 7 + 4 * p.mouthOpen, height: 8 + 6 * p.mouthOpen),
          _fill(palette.mouth),
        );
    }
  }

  @override
  bool shouldRepaint(NibiPainter old) =>
      old.frame != frame || old.palette != palette || old.look != look || old.framing != framing;
}
