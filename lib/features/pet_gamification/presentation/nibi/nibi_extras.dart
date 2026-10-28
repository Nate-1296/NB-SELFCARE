import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../../domain/nibi_activity.dart';
import 'nibi_painter.dart';
import 'nibi_palette.dart';
import 'nibi_pose.dart';

// Accesorios, objetos y efectos de Nibi. Todo en el lienzo de 200 × 200.

Paint _fill(Color c) => Paint()..color = c;

Paint _line(Color c, double w) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..color = c;

/// Aura de la cetosis: halo suave en color, anillo discontinuo en papel.
void paintAura(Canvas canvas, NibiPalette p, double aura, double t) {
  if (aura <= 0.01) return;
  const Offset center = Offset(100, 116);
  if (p.isInk) {
    final Paint dash = _line(p.outline, 1.5);
    const int n = 28;
    for (int i = 0; i < n; i++) {
      final double a = i / n * math.pi * 2;
      canvas.drawArc(Rect.fromCircle(center: center, radius: 90), a, math.pi / n, false, dash);
    }
    return;
  }
  canvas.drawCircle(
    center,
    94,
    Paint()
      ..shader = RadialGradient(
        colors: <Color>[p.aura.withValues(alpha: 0.32 * aura), p.aura.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: center, radius: 94)),
  );
}

/// Sombra en el suelo; se encoge cuando Nibi salta.
void paintGroundShadow(Canvas canvas, NibiPalette p, double scale) {
  final double k = scale.clamp(0.4, 1.0);
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(100, 191), width: 84 * k, height: 11 * k),
    p.isInk ? _line(p.shadow, 1.5) : _fill(p.shadow),
  );
}

/// Mini báscula bajo los pies mientras se pesa.
void paintScale(Canvas canvas, NibiPalette p, double t) {
  final RRect plate = RRect.fromRectAndRadius(const Rect.fromLTRB(60, 178, 140, 192), const Radius.circular(6));
  canvas.drawRRect(plate, _fill(p.white));
  canvas.drawRRect(plate, _line(p.outline, 2.4));
  final RRect display = RRect.fromRectAndRadius(const Rect.fromLTRB(88, 182, 112, 189), const Radius.circular(2));
  canvas.drawRRect(display, _fill(p.isInk ? p.outline : const Color(0xFF1F2A33)));
  // Dígitos que oscilan mientras la báscula estabiliza.
  final int ticks = 2 + ((t * 6).floor() % 3);
  for (int i = 0; i < ticks; i++) {
    canvas.drawRect(Rect.fromLTWH(91.5 + i * 5.5, 184, 3.5, 3), _fill(p.isInk ? p.white : p.water));
  }
}

/// Sombreros sobre la cabeza (coordenadas de la cabeza, antes de inclinarla).
void paintHat(Canvas canvas, NibiPalette p, String? hatId, double t) {
  final Paint stroke = _line(p.outline, 2.4);
  switch (hatId) {
    case 'hat_chef':
      for (final (Offset c, double r) in <(Offset, double)>[
        (const Offset(85, 20), 11),
        (const Offset(115, 20), 11),
        (const Offset(100, 13), 13),
      ]) {
        canvas.drawCircle(c, r, _fill(p.white));
        canvas.drawCircle(c, r, stroke);
      }
      final RRect band = RRect.fromRectAndRadius(const Rect.fromLTRB(78, 24, 122, 38), const Radius.circular(3));
      canvas.drawRRect(band, _fill(p.white));
      canvas.drawRRect(band, stroke);
    case 'hat_headband':
      canvas.drawPath(
        Path()
          ..moveTo(56, 60)
          ..quadraticBezierTo(100, 30, 144, 60),
        _line(p.outline, 11),
      );
      canvas.drawPath(
        Path()
          ..moveTo(56, 60)
          ..quadraticBezierTo(100, 30, 144, 60),
        _line(p.red, 7.5),
      );
      for (final Offset end in const <Offset>[Offset(160, 70), Offset(156, 80)]) {
        final Path tail = Path()
          ..moveTo(144, 58)
          ..lineTo(end.dx, end.dy)
          ..lineTo(end.dx - 6, end.dy - 3)
          ..close();
        canvas.drawPath(tail, _fill(p.red));
        canvas.drawPath(tail, stroke);
      }
    case 'hat_zen_halo':
      final double bob = math.sin(t * 2) * 1.5;
      final Rect ring = Rect.fromCenter(center: Offset(100, 14 + bob), width: 54, height: 12);
      if (!p.isInk) canvas.drawOval(ring, _line(p.gold.withValues(alpha: 0.35), 9));
      canvas.drawOval(ring, _line(p.outline, 6.5));
      canvas.drawOval(ring, _line(p.gold, 3.5));
    case 'hat_crown':
      final Path crown = Path()
        ..moveTo(78, 36)
        ..lineTo(77, 16)
        ..lineTo(89, 26)
        ..lineTo(100, 8)
        ..lineTo(111, 26)
        ..lineTo(123, 16)
        ..lineTo(122, 36)
        ..close();
      canvas.drawPath(crown, _fill(p.gold));
      canvas.drawPath(crown, stroke);
      canvas.drawCircle(const Offset(100, 29), 3.6, _fill(p.red));
      canvas.drawCircle(const Offset(87, 31), 2.6, _fill(p.water));
      canvas.drawCircle(const Offset(113, 31), 2.6, _fill(p.water));
    case 'hat_party':
      final Path cone = Path()
        ..moveTo(82, 32)
        ..lineTo(108, -4)
        ..lineTo(122, 28)
        ..quadraticBezierTo(102, 36, 82, 32)
        ..close();
      canvas.drawPath(cone, _fill(_tint(p, const Color(0xFF8E6CD8), 0.75)));
      canvas.save();
      canvas.clipPath(cone);
      for (final double y in <double>[4, 16]) {
        canvas.drawLine(Offset(80, y + 16), Offset(126, y), _line(_tint(p, const Color(0xFFF2C14E), 0.55), 4));
      }
      canvas.restore();
      canvas.drawPath(cone, stroke);
      canvas.drawCircle(const Offset(108, -4), 5.5, _fill(p.gold));
      canvas.drawCircle(const Offset(108, -4), 5.5, _line(p.outline, 2));
    case 'hat_beanie':
      final Path dome = Path()
        ..moveTo(60, 42)
        ..cubicTo(60, 8, 140, 8, 140, 42)
        ..close();
      final Color wool = _tint(p, const Color(0xFFE5484D), 0.7);
      canvas.drawPath(dome, _fill(wool));
      canvas.drawPath(dome, stroke);
      final RRect cuff = RRect.fromRectAndRadius(const Rect.fromLTRB(57, 34, 143, 48), const Radius.circular(6));
      canvas.drawRRect(cuff, _fill(_tint(p, const Color(0xFFF7E4B5), 0.92)));
      for (double x = 64; x < 140; x += 7) {
        canvas.drawLine(Offset(x, 37), Offset(x, 45), _line(p.isInk ? p.outline : const Color(0xFFD8B87A), 1.4));
      }
      canvas.drawRRect(cuff, stroke);
      canvas.drawCircle(const Offset(100, 10), 8, _fill(_tint(p, const Color(0xFFF7E4B5), 0.92)));
      canvas.drawCircle(const Offset(100, 10), 8, _line(p.outline, 2));
    case 'hat_cap':
      final Color fabric = _tint(p, const Color(0xFF3E7BD6), 0.7);
      final Path visor = Path()
        ..moveTo(120, 36)
        ..quadraticBezierTo(152, 32, 160, 42)
        ..quadraticBezierTo(140, 46, 120, 44)
        ..close();
      canvas.drawPath(visor, _fill(p.isInk ? p.bodyShade : const Color(0xFF2A5DA8)));
      canvas.drawPath(visor, stroke);
      final Path crownPath = Path()
        ..moveTo(66, 40)
        ..cubicTo(66, 8, 134, 8, 134, 40)
        ..close();
      canvas.drawPath(crownPath, _fill(fabric));
      canvas.drawLine(const Offset(100, 15), const Offset(100, 40), _line(p.isInk ? p.outline : const Color(0xFF2A5DA8), 1.5));
      canvas.drawPath(crownPath, stroke);
      canvas.drawCircle(const Offset(100, 15), 3, _fill(p.outline));
    case 'hat_flowers':
      for (int i = 0; i < 7; i++) {
        final double a = math.pi + (i + 0.5) / 7 * math.pi;
        final Offset c = Offset(100 + math.cos(a) * 44, 52 + math.sin(a) * 26);
        if (i > 0) {
          final double pa = math.pi + i / 7 * math.pi;
          final Offset leaf = Offset(100 + math.cos(pa) * 46, 52 + math.sin(pa) * 28);
          canvas.drawOval(Rect.fromCenter(center: leaf, width: 8, height: 5), _fill(p.isInk ? p.bodyShade : const Color(0xFF5DAA4A)));
        }
        final Color petal = p.isInk
            ? p.white
            : const <Color>[Color(0xFFF7A1C4), Color(0xFFFFF4C2), Color(0xFFFFFFFF)][i % 3];
        for (int k = 0; k < 5; k++) {
          final double pa = k / 5 * math.pi * 2;
          final Offset q = c + Offset(math.cos(pa) * 4.2, math.sin(pa) * 4.2);
          canvas.drawCircle(q, 3.6, _fill(petal));
          canvas.drawCircle(q, 3.6, _line(p.outline, 1.2));
        }
        canvas.drawCircle(c, 2.6, _fill(p.isInk ? p.outline : const Color(0xFFF2A93B)));
      }
    case 'hat_wizard':
      final Color cloth = _tint(p, const Color(0xFF4C3F91), 0.45);
      final Path cone = Path()
        ..moveTo(76, 32)
        ..quadraticBezierTo(92, 12, 104, -6)
        ..quadraticBezierTo(112, 2, 124, 32)
        ..close();
      canvas.drawPath(cone, _fill(cloth));
      canvas.drawPath(cone, stroke);
      final Rect brim = Rect.fromCenter(center: const Offset(100, 33), width: 80, height: 14);
      canvas.drawOval(brim, _fill(cloth));
      canvas.drawOval(brim, stroke);
      canvas.drawLine(const Offset(80, 27), const Offset(120, 27), _line(p.gold, 3));
      for (final Offset star in const <Offset>[Offset(96, 14), Offset(108, 4), Offset(111, 20)]) {
        canvas.drawPath(_star(star, 3.2), _fill(p.isInk ? p.white : p.gold));
        if (p.isInk) canvas.drawPath(_star(star, 3.2), _line(p.outline, 1));
      }
  }
}

/// Color propio de un objeto; en papel, un gris de tinta ([inkTone] 0 = tinta, 1 = papel).
Color _tint(NibiPalette p, Color color, double inkTone) =>
    p.isInk ? Color.lerp(p.outline, p.white, inkTone)! : color;

Path _star(Offset c, double r) {
  final Path star = Path();
  for (int i = 0; i < 10; i++) {
    final double rr = i.isEven ? r : r * 0.45;
    final double a = i * math.pi / 5 - math.pi / 2;
    final Offset q = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
    if (i == 0) {
      star.moveTo(q.dx, q.dy);
    } else {
      star.lineTo(q.dx, q.dy);
    }
  }
  return star..close();
}

/// Gafas sobre los ojos (coordenadas de la cabeza, ya inclinada).
void paintFaceAccessory(Canvas canvas, NibiPalette p, String? accessoryId, Offset gaze) {
  switch (accessoryId) {
    case 'acc_glasses':
      final Paint frame = _line(p.isInk ? p.outline : const Color(0xFF3A2E2A), 2.6);
      for (final double x in <double>[80, 120]) {
        final Offset c = Offset(x, 70);
        if (!p.isInk) canvas.drawCircle(c, 13, _fill(const Color(0x33FFFFFF)));
        canvas.drawCircle(c, 13, frame);
      }
      canvas.drawPath(
        Path()
          ..moveTo(93, 69)
          ..quadraticBezierTo(100, 64, 107, 69),
        frame,
      );
      canvas.drawLine(const Offset(67, 68), const Offset(56, 64), frame);
      canvas.drawLine(const Offset(133, 68), const Offset(144, 64), frame);
    case 'acc_sunglasses':
      final Paint frame = _line(p.outline, 2.4);
      for (final double x in <double>[80, 120]) {
        final RRect lens = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, 71), width: 30, height: 20),
          const Radius.circular(8),
        );
        canvas.drawRRect(lens, _fill(p.isInk ? p.outline : const Color(0xFF1F2430)));
        canvas.drawRRect(lens, frame);
        canvas.drawLine(Offset(x - 8, 66), Offset(x - 2, 64), _line(p.isInk ? p.white : const Color(0x88FFFFFF), 2));
      }
      canvas.drawLine(const Offset(95, 68), const Offset(105, 68), frame);
      canvas.drawLine(const Offset(65, 68), const Offset(56, 64), frame);
      canvas.drawLine(const Offset(135, 68), const Offset(144, 64), frame);
  }
}

/// Bufanda alrededor del cuello (se dibuja antes de la cabeza).
void paintScarf(Canvas canvas, NibiPalette p, double t) {
  final Color wool = _tint(p, const Color(0xFF2F80B7), 0.6);
  final Color stripe = _tint(p, const Color(0xFFF7E4B5), 0.95);
  final Path band = Path()
    ..moveTo(66, 110)
    ..quadraticBezierTo(100, 122, 134, 110)
    ..lineTo(134, 122)
    ..quadraticBezierTo(100, 134, 66, 122)
    ..close();
  canvas.drawPath(band, _fill(wool));
  canvas.drawPath(band, _line(p.outline, 2.4));
  final double sway = math.sin(t * 2.2) * 1.5;
  final Path end = Path()
    ..moveTo(112, 122)
    ..lineTo(124 + sway, 150)
    ..lineTo(112 + sway, 152)
    ..lineTo(104, 124)
    ..close();
  canvas.drawPath(end, _fill(wool));
  canvas.save();
  canvas.clipPath(end);
  for (final double y in <double>[132, 142]) {
    canvas.drawLine(Offset(100, y), Offset(130, y + 2), _line(stripe, 3));
  }
  canvas.restore();
  canvas.drawPath(end, _line(p.outline, 2.2));
}

/// Pajarita o cascabel bajo la barbilla (después de la cabeza).
void paintNeckAccessory(Canvas canvas, NibiPalette p, String? accessoryId, double t) {
  switch (accessoryId) {
    case 'acc_bowtie':
      final Color cloth = _tint(p, const Color(0xFFE5484D), 0.6);
      for (final double side in <double>[-1, 1]) {
        final Path wing = Path()
          ..moveTo(100, 121)
          ..lineTo(100 + side * 15, 113)
          ..quadraticBezierTo(100 + side * 18, 121, 100 + side * 15, 129)
          ..close();
        canvas.drawPath(wing, _fill(cloth));
        canvas.drawPath(wing, _line(p.outline, 2.2));
      }
      final RRect knot = RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(100, 121), width: 8, height: 9), const Radius.circular(2.5));
      canvas.drawRRect(knot, _fill(cloth));
      canvas.drawRRect(knot, _line(p.outline, 2));
    case 'acc_bell':
      canvas.drawPath(
        Path()
          ..moveTo(70, 113)
          ..quadraticBezierTo(100, 126, 130, 113),
        _line(p.outline, 7),
      );
      canvas.drawPath(
        Path()
          ..moveTo(70, 113)
          ..quadraticBezierTo(100, 126, 130, 113),
        _line(_tint(p, const Color(0xFFB0623A), 0.5), 4),
      );
      final double swing = math.sin(t * 3) * 0.12;
      canvas.save();
      canvas.translate(100, 120);
      canvas.rotate(swing);
      canvas.drawCircle(const Offset(0, 6), 7, _fill(p.gold));
      canvas.drawCircle(const Offset(0, 6), 7, _line(p.outline, 2));
      canvas.drawLine(const Offset(-4, 7), const Offset(4, 7), _line(p.outline, 1.6));
      canvas.drawCircle(const Offset(0, 10), 1.6, _fill(p.outline));
      canvas.restore();
  }
}

/// Pelota de playa que bota a la derecha de Nibi (actividad "jugar").
void paintBall(Canvas canvas, NibiPalette p, double t) {
  final double h = NibiChoreography.ballHeight(t);
  final Offset c = Offset(156, 180 - h * 74);
  const double r = 10;
  final double shadow = 1 - h * 0.6;
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(156, 191), width: 22 * shadow, height: 5 * shadow),
    p.isInk ? _line(p.shadow, 1.2) : _fill(p.shadow),
  );
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(t * 3);
  final Rect ball = Rect.fromCircle(center: Offset.zero, radius: r);
  final List<Color> slices = p.isInk
      ? <Color>[p.white, p.bodyShade, p.white, p.bodyShade]
      : const <Color>[Color(0xFFE5484D), Color(0xFFFFFFFF), Color(0xFF3E7BD6), Color(0xFFF2C14E)];
  for (int i = 0; i < 4; i++) {
    canvas.drawArc(ball, i * math.pi / 2, math.pi / 2, true, _fill(slices[i]));
  }
  canvas.drawCircle(Offset.zero, r, _line(p.outline, 2.2));
  canvas.restore();
}

/// Pesa sostenida entre las dos manos (entrenamiento).
void paintDumbbell(Canvas canvas, NibiPalette p, Offset lh, Offset rh, Paint stroke) {
  canvas.drawLine(lh, rh, _line(p.outline, 4));
  for (final Offset h in <Offset>[lh, rh]) {
    final Offset out = h - (lh + rh) / 2;
    final Offset dir = out / math.max(out.distance, 0.001);
    final Offset c = h + dir * 7;
    final RRect plate = RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: 9, height: 20), const Radius.circular(3));
    canvas.drawRRect(plate, _fill(p.isInk ? p.outline : const Color(0xFF45505C)));
  }
}

/// Vaso de agua en la mano derecha.
void paintGlass(Canvas canvas, NibiPalette p, Offset hand, double tilt, Paint stroke) {
  canvas.save();
  canvas.translate(hand.dx - 2, hand.dy - 6);
  canvas.rotate(-0.4 + tilt);
  final RRect glass = RRect.fromRectAndRadius(const Rect.fromLTWH(-6, -16, 12, 18), const Radius.circular(2.5));
  canvas.drawRRect(glass, _fill(p.white.withValues(alpha: p.isInk ? 1 : 0.7)));
  canvas.drawRRect(
    RRect.fromRectAndRadius(const Rect.fromLTWH(-6, -9, 12, 11), const Radius.circular(2.5)),
    _fill(p.water),
  );
  canvas.drawRRect(glass, _line(p.outline, 2));
  canvas.restore();
}

/// Manzana en la mano derecha.
void paintApple(Canvas canvas, NibiPalette p, Offset hand, Paint stroke) {
  final Offset c = hand + const Offset(1, -6);
  canvas.drawCircle(c, 8, _fill(p.red));
  canvas.drawCircle(c, 8, _line(p.outline, 2));
  canvas.drawLine(c + const Offset(0, -7), c + const Offset(1, -11), _line(p.outline, 1.8));
  final Path leaf = Path()
    ..moveTo(c.dx + 1, c.dy - 9)
    ..quadraticBezierTo(c.dx + 7, c.dy - 13, c.dx + 9, c.dy - 9)
    ..quadraticBezierTo(c.dx + 5, c.dy - 7, c.dx + 1, c.dy - 9)
    ..close();
  canvas.drawPath(leaf, _fill(p.isInk ? p.bodyShade : const Color(0xFF5DAA4A)));
  canvas.drawPath(leaf, _line(p.outline, 1.4));
}

Path _heart(Offset c, double s) => Path()
  ..moveTo(c.dx, c.dy + s * 0.9)
  ..cubicTo(c.dx - s * 1.4, c.dy, c.dx - s * 0.9, c.dy - s * 1.1, c.dx, c.dy - s * 0.35)
  ..cubicTo(c.dx + s * 0.9, c.dy - s * 1.1, c.dx + s * 1.4, c.dy, c.dx, c.dy + s * 0.9)
  ..close();

Path _zigzagZ(Offset o, double s) => Path()
  ..moveTo(o.dx, o.dy)
  ..lineTo(o.dx + s, o.dy)
  ..lineTo(o.dx, o.dy + s)
  ..lineTo(o.dx + s, o.dy + s);

/// Efectos de cada actividad: Zzz al dormir, confeti al celebrar, gota de
/// esfuerzo, interrogación de curiosidad y corazones al acariciarlo.
void paintEffects(Canvas canvas, NibiPalette p, NibiFrame f, Paint stroke) {
  final double t = f.t;
  switch (f.activity) {
    case NibiActivity.sleeping:
      for (int i = 0; i < 3; i++) {
        final double phase = p.isInk ? i / 3 : (t * 0.32 + i / 3) % 1;
        final double size = 6 + phase * 7;
        final Color color = p.isInk ? p.outline : p.outline.withValues(alpha: 1 - phase);
        canvas.drawPath(_zigzagZ(Offset(138 + phase * 24, 50 - phase * 40), size), _line(color, 2.4));
      }
    case NibiActivity.celebrating:
      final List<Color> colors = <Color>[p.crest, p.gold, p.water, p.aura, p.red];
      for (int i = 0; i < 18; i++) {
        final double fall = p.isInk ? (i * 0.137) % 1 : (t * 0.55 + i * 0.137) % 1;
        final double x = 100 + math.cos(i * 2.4) * (24 + (i * 13) % 64);
        final double y = 6 + fall * 150;
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(i + t * 3);
        const Rect piece = Rect.fromLTWH(-2, -3.5, 4, 7);
        if (p.isInk) {
          canvas.drawRect(piece, _line(p.outline, 1.2));
        } else {
          canvas.drawRect(piece, _fill(colors[i % colors.length].withValues(alpha: 1 - fall * 0.6)));
        }
        canvas.restore();
      }
    case NibiActivity.workout:
      final double drip = p.isInk ? 0 : (t * 0.8) % 1;
      final Offset c = Offset(146, 52 + drip * 10);
      final Path drop = Path()
        ..moveTo(c.dx, c.dy - 8)
        ..quadraticBezierTo(c.dx + 6, c.dy, c.dx, c.dy + 3)
        ..quadraticBezierTo(c.dx - 6, c.dy, c.dx, c.dy - 8)
        ..close();
      canvas.drawPath(drop, _fill(p.water.withValues(alpha: p.isInk ? 1 : 1 - drip * 0.7)));
      canvas.drawPath(drop, _line(p.outline, 1.5));
    case NibiActivity.curious:
      final double bob = p.isInk ? 0 : math.sin(t * 3) * 2;
      final Paint mark = _line(p.outline, 3.4);
      final Offset o = Offset(150, 20 + bob);
      canvas.drawPath(
        Path()
          ..moveTo(o.dx - 6, o.dy + 2)
          ..quadraticBezierTo(o.dx - 6, o.dy - 7, o.dx + 1, o.dy - 7)
          ..quadraticBezierTo(o.dx + 8, o.dy - 6, o.dx + 6, o.dy + 1)
          ..quadraticBezierTo(o.dx + 4, o.dy + 5, o.dx, o.dy + 7)
          ..lineTo(o.dx, o.dy + 11),
        mark,
      );
      canvas.drawCircle(Offset(o.dx, o.dy + 18), 2.2, _fill(p.outline));
    case NibiActivity.playing:
      paintBall(canvas, p, t);
    case NibiActivity.idle:
    case NibiActivity.happy:
    case NibiActivity.eating:
    case NibiActivity.drinking:
    case NibiActivity.zen:
    case NibiActivity.weighing:
      break;
  }

  final NibiReaction? reaction = f.reaction;
  if (reaction != null) _paintReaction(canvas, p, reaction, f.reactionAge, f.pose);
}

/// Efectos de las reacciones. En papel se pintan en un instante fijo y con
/// trazo (sin transparencias).
void _paintReaction(Canvas canvas, NibiPalette p, NibiReaction reaction, double age, NibiPose pose) {
  final double k = (age / reaction.seconds).clamp(0.0, 1.0);
  if (k >= 1) return;
  final double fade = p.isInk ? 1 : 1 - k;
  // Boca y orificios nasales siguen al cuerpo.
  final Offset body = Offset(pose.bodyX, pose.bodyY);
  switch (reaction) {
    case NibiReaction.pat:
      for (int i = 0; i < 3; i++) {
        final Offset c = Offset(100 + (i - 1) * 26 + math.sin(age * 6 + i) * 3, 52 - k * 44 - i * 6) + body;
        final Path heart = _heart(c, 7 + i * 1.5);
        if (p.isInk) {
          canvas.drawPath(heart, _line(p.outline, 1.8));
        } else {
          canvas.drawPath(heart, _fill(const Color(0xFFF26B8A).withValues(alpha: fade)));
        }
      }
    case NibiReaction.giggle:
      for (int i = 0; i < 4; i++) {
        final double a = i * math.pi / 2 + 0.6;
        final double grow = math.sin(math.pi * ((k * 2 + i * 0.25) % 1));
        final Offset c = Offset(100 + math.cos(a) * 64, 120 + math.sin(a) * 40) + body;
        final Path star = _star(c, 3 + grow * 4);
        if (p.isInk) {
          canvas.drawPath(star, _line(p.outline, 1.4));
        } else {
          canvas.drawPath(star, _fill(p.gold.withValues(alpha: fade)));
        }
      }
    case NibiReaction.spin:
      final Paint swoosh = _line(p.isInk ? p.outline : p.outline.withValues(alpha: 0.5 * fade), 2.2);
      for (int i = 0; i < 2; i++) {
        final Rect r = Rect.fromCenter(center: Offset(100, 128 + pose.bodyY), width: 150 - i * 20, height: 46 - i * 10);
        canvas.drawArc(r, math.pi * 0.15 + k * 4 + i, math.pi * 0.55, false, swoosh);
      }
    case NibiReaction.hop:
      if (k > 0.8 || p.isInk) {
        final double d = p.isInk ? 0.5 : (k - 0.8) / 0.2;
        for (final double side in <double>[-1, 1]) {
          for (int i = 0; i < 2; i++) {
            final Offset c = Offset(100 + side * (40 + d * 18 + i * 9), 186 - i * 4);
            canvas.drawCircle(c, 4 - i * 1.2, p.isInk ? _line(p.outline, 1.2) : _fill(p.shadow.withValues(alpha: 0.6 * (1 - d))));
          }
        }
      }
    case NibiReaction.puff:
      if (k < 0.35 && !p.isInk) return;
      final double b = p.isInk ? 0.4 : (k - 0.35) / 0.65;
      final Offset mouth = const Offset(112, 104) + body;
      if (b < 0.45) {
        // Llamita: crece y se apaga.
        final double size = math.sin(math.pi * (b / 0.45)) * 20 + 6;
        final Path flame = Path()
          ..moveTo(mouth.dx, mouth.dy)
          ..quadraticBezierTo(mouth.dx + size * 0.9, mouth.dy - size * 0.6, mouth.dx + size * 1.6, mouth.dy - size * 0.1)
          ..quadraticBezierTo(mouth.dx + size * 0.9, mouth.dy + size * 0.5, mouth.dx, mouth.dy)
          ..close();
        if (p.isInk) {
          canvas.drawPath(flame, _line(p.outline, 1.6));
        } else {
          canvas.drawPath(flame, _fill(const Color(0xFFFFA43A)));
          canvas.drawPath(flame.shift(const Offset(2, 0)), _fill(const Color(0xFFFFE07A).withValues(alpha: 0.8)));
        }
      }
      for (int i = 0; i < 3; i++) {
        final double q = (b - i * 0.15).clamp(0.0, 1.0);
        if (q <= 0) continue;
        final Offset c = mouth + Offset(18 + q * 40, -q * 30 - i * 4);
        final double r = 4 + q * 7;
        canvas.drawCircle(c, r, p.isInk ? _line(p.outline, 1.4) : _line(p.shadow.withValues(alpha: 0.9 * (1 - q)), 2.4));
      }
    case NibiReaction.purr:
      for (int i = 0; i < 3; i++) {
        final double q = (k * 1.6 + i * 0.33) % 1;
        final Offset c = Offset(140 + math.sin(q * 6 + i) * 6, 70 - q * 50) + body;
        final Paint ink = p.isInk ? _fill(p.outline) : _fill(p.outline.withValues(alpha: 1 - q));
        canvas.drawOval(Rect.fromCenter(center: c, width: 7, height: 5.5), ink);
        canvas.drawLine(c + const Offset(3.2, 0), c + const Offset(3.2, -12), _line(ink.color, 1.6));
        canvas.drawLine(c + const Offset(3.2, -12), c + const Offset(8, -9), _line(ink.color, 1.6));
      }
    case NibiReaction.snort:
      for (final double side in <double>[-1, 1]) {
        final Offset c = Offset(100 + side * (12 + k * 10), 96 + k * 8) + body;
        canvas.drawCircle(c, 3 + k * 4, p.isInk ? _line(p.outline, 1.2) : _fill(p.shadow.withValues(alpha: 0.8 * fade)));
      }
    case NibiReaction.yawn:
    case NibiReaction.lookAround:
    case NibiReaction.stretch:
      break;
  }
}
