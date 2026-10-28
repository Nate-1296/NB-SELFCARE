import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../../../shared/theme/sc_colors.dart';

/// Escenarios del santuario de Nibi, dibujados con vectores. En color son
/// escenas suaves que no compiten con el personaje y tienen algo de vida
/// (olas, nieve, pétalos, luciérnagas, estrellas que titilan) si se les da un
/// [time]; en papel, dibujos de línea sin rellenos ni movimiento (nada que
/// deje estela en la tinta).
class HabitatPainter extends CustomPainter {
  HabitatPainter({required this.habitatId, required this.colors, this.time}) : super(repaint: time);

  final String habitatId;
  final ScColors colors;

  /// Segundos de animación del ambiente; `null` = escena quieta.
  final ValueListenable<double>? time;

  late final bool _ink = colors.isFlat;

  late final Paint _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = _ink ? colors.text3 : colors.text.withValues(alpha: 0.08);

  /// Relleno en color; contorno de tinta en papel.
  Paint _shape(Color color) => _ink ? _line : (Paint()..color = color);

  Paint _stroke(Color color, {double width = 1.5}) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..color = _ink ? colors.text3 : color;

  @override
  void paint(Canvas canvas, Size size) {
    final double t = _ink ? 0 : (time?.value ?? 0);
    final Rect r = Offset.zero & size;
    final double floor = size.height * 0.78;
    switch (habitatId) {
      case 'bg_zen_garden':
        _zenGarden(canvas, size, r, floor, t);
      case 'bg_beach':
        _beach(canvas, size, r, floor, t);
      case 'bg_forest':
        _forest(canvas, size, r, floor, t);
      case 'bg_mountain_dawn':
        _mountainDawn(canvas, size, r, floor, t);
      case 'bg_snow':
        _snow(canvas, size, r, floor, t);
      case 'bg_starry_dojo':
        _starryDojo(canvas, size, r, floor, t);
      case 'bg_sakura':
        _sakura(canvas, size, r, floor, t);
      case 'bg_space':
        _space(canvas, size, r, floor, t);
      default:
        _room(canvas, size, r, floor);
    }
  }

  // ---------------------------------------------------------------- Escenas

  void _room(Canvas canvas, Size size, Rect r, double floor) {
    _sky(canvas, r, colors.bg3, colors.bg2);
    final Rect window = Rect.fromLTWH(size.width * 0.66, size.height * 0.12, size.width * 0.22, size.height * 0.3);
    final RRect frame = RRect.fromRectAndRadius(window, const Radius.circular(6));
    canvas.drawRRect(frame, _shape(const Color(0xFFBFE3F7).withValues(alpha: 0.6)));
    canvas.drawLine(window.topCenter, window.bottomCenter, _line);
    canvas.drawLine(window.centerLeft, window.centerRight, _line);
    canvas.drawRRect(frame, _stroke(colors.text.withValues(alpha: 0.08), width: 2));
    // Cuadro con una montañita.
    final Rect picture = Rect.fromLTWH(size.width * 0.1, size.height * 0.16, size.width * 0.16, size.height * 0.14);
    canvas.drawRect(picture, _shape(const Color(0xFFF7E4B5)));
    canvas.drawPath(
      Path()
        ..moveTo(picture.left + 4, picture.bottom - 4)
        ..lineTo(picture.center.dx, picture.top + 8)
        ..lineTo(picture.right - 4, picture.bottom - 4),
      _stroke(const Color(0xFF8DB36A), width: 2),
    );
    canvas.drawRect(picture, _stroke(colors.text.withValues(alpha: 0.08), width: 2));
    _ground(canvas, size, floor, colors.text.withValues(alpha: 0.05));
    // Alfombra.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(size.width * 0.5, floor + (size.height - floor) * 0.45), width: size.width * 0.62, height: (size.height - floor) * 0.55),
      _shape(const Color(0xFFE5734A).withValues(alpha: 0.18)),
    );
    final Offset pot = Offset(size.width * 0.14, floor);
    final Path potPath = Path()
      ..moveTo(pot.dx - 12, pot.dy - 18)
      ..lineTo(pot.dx + 12, pot.dy - 18)
      ..lineTo(pot.dx + 9, pot.dy)
      ..lineTo(pot.dx - 9, pot.dy)
      ..close();
    for (final double a in <double>[-0.5, 0, 0.5]) {
      final Offset tip = pot + Offset(math.sin(a) * 24, -18 - math.cos(a) * 28);
      canvas.drawLine(pot + const Offset(0, -18), tip, _stroke(const Color(0xFF5DAA4A), width: 4));
    }
    canvas.drawPath(potPath, _shape(const Color(0xFFD9825B)));
  }

  void _zenGarden(Canvas canvas, Size size, Rect r, double floor, double t) {
    _sky(canvas, r, const Color(0xFFDDF3E4), const Color(0xFF9BD3B0));
    _ground(canvas, size, floor, const Color(0xFFE9DCC0));
    // Arena rastrillada.
    for (int i = 1; i < 4; i++) {
      final double y = floor + i * (size.height - floor) / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), _stroke(const Color(0x55A8916A)));
    }
    // Bambús que se mecen.
    for (final (int i, double x) in <double>[0.08, 0.15, 0.88].indexed) {
      final double cx = size.width * x;
      final double sway = math.sin(t * 0.8 + i) * 3;
      final Paint bamboo = _stroke(const Color(0xFF4F9B5C), width: size.width * 0.025);
      canvas.drawLine(Offset(cx, floor), Offset(cx + sway, size.height * 0.1), bamboo);
      for (double y = size.height * 0.2; y < floor; y += size.height * 0.14) {
        final double dx = sway * (1 - y / floor);
        canvas.drawLine(Offset(cx + dx - 5, y), Offset(cx + dx + 5, y), _stroke(const Color(0xFF2F6B3A)));
      }
    }
    final Rect stone = Rect.fromCenter(center: Offset(size.width * 0.8, floor + 10), width: 46, height: 22);
    canvas.drawOval(stone, _shape(const Color(0xFF9AA39A)));
    // Hoja que cae.
    if (!_ink) {
      final double k = (t / 9) % 1;
      final Offset leaf = Offset(size.width * (0.3 + k * 0.4) + math.sin(t * 2) * 10, size.height * (0.05 + k * 0.7));
      canvas.save();
      canvas.translate(leaf.dx, leaf.dy);
      canvas.rotate(math.sin(t * 2) * 0.8);
      canvas.drawOval(const Rect.fromLTWH(-5, -2.5, 10, 5), Paint()..color = const Color(0xFF6DAA5C));
      canvas.restore();
    }
  }

  void _beach(Canvas canvas, Size size, Rect r, double floor, double t) {
    _sky(canvas, r, const Color(0xFFFFC98B), const Color(0xFFFFE9C7));
    final double horizon = size.height * 0.52;
    final Offset sun = Offset(size.width * 0.72, horizon);
    canvas.drawCircle(sun, size.width * 0.1, _shape(const Color(0xFFFF9F5A)));
    final Rect sea = Rect.fromLTRB(0, horizon, size.width, floor);
    if (_ink) {
      canvas.drawLine(sea.topLeft, sea.topRight, _line);
    } else {
      canvas.drawRect(
        sea,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF4FA3C7), Color(0xFF8ACFE0)],
          ).createShader(sea),
      );
    }
    // Olas que se desplazan.
    for (int i = 0; i < 3; i++) {
      final double y = horizon + (floor - horizon) * (0.25 + i * 0.25);
      final double shift = (t * (8 + i * 4)) % 40;
      final Path wave = Path()..moveTo(-40 + shift, y);
      for (double x = -40 + shift; x < size.width + 40; x += 20) {
        wave.relativeQuadraticBezierTo(5, -4, 10, 0);
        wave.relativeQuadraticBezierTo(5, 4, 10, 0);
      }
      canvas.drawPath(wave, _stroke(const Color(0xAAFFFFFF), width: 1.6));
    }
    _ground(canvas, size, floor, const Color(0xFFF1D9A6));
    // Palmera.
    final Offset base = Offset(size.width * 0.12, floor + 6);
    final Offset top = Offset(size.width * 0.2, size.height * 0.3);
    canvas.drawPath(
      Path()
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo(base.dx - 4, (base.dy + top.dy) / 2, top.dx, top.dy),
      _stroke(const Color(0xFF9C6E45), width: size.width * 0.03),
    );
    final double sway = math.sin(t * 1.1) * 0.06;
    for (final double a in <double>[-2.6, -2.0, -1.2, -0.5, 0.1]) {
      final double angle = a + sway;
      final Offset tip = top + Offset(math.cos(angle) * size.width * 0.13, math.sin(angle) * size.width * 0.07 + 10);
      final Offset mid = top + Offset(math.cos(angle) * size.width * 0.07, math.sin(angle) * size.width * 0.07 - 4);
      canvas.drawPath(
        Path()
          ..moveTo(top.dx, top.dy)
          ..quadraticBezierTo(mid.dx, mid.dy, tip.dx, tip.dy),
        _stroke(const Color(0xFF3F8F4E), width: 5),
      );
    }
    // Concha.
    final Offset shell = Offset(size.width * 0.82, floor + (size.height - floor) * 0.5);
    canvas.drawPath(
      Path()
        ..moveTo(shell.dx - 8, shell.dy + 4)
        ..quadraticBezierTo(shell.dx, shell.dy - 10, shell.dx + 8, shell.dy + 4)
        ..close(),
      _shape(const Color(0xFFF6B3A6)),
    );
  }

  void _forest(Canvas canvas, Size size, Rect r, double floor, double t) {
    _sky(canvas, r, const Color(0xFFCFE8D5), const Color(0xFFEAF5E4));
    for (final (double depth, Color color) in <(double, Color)>[
      (0.62, const Color(0xFF9CC7A0)),
      (0.42, const Color(0xFF6BA273)),
    ]) {
      for (int i = -1; i < 7; i++) {
        final double x = size.width * (i / 6 + (depth == 0.62 ? 0.08 : 0));
        if (depth == 0.42 && x > size.width * 0.3 && x < size.width * 0.7) continue;
        final double h = size.height * depth * (0.8 + (i % 3) * 0.1);
        final Path pine = Path()
          ..moveTo(x, floor - h)
          ..lineTo(x + size.width * 0.08, floor)
          ..lineTo(x - size.width * 0.08, floor)
          ..close();
        canvas.drawPath(pine, _shape(color));
      }
    }
    _ground(canvas, size, floor, const Color(0xFF7DB561));
    // Setas.
    for (final double x in <double>[0.2, 0.86]) {
      final Offset c = Offset(size.width * x, floor + 4);
      canvas.drawRect(Rect.fromCenter(center: c + const Offset(0, 4), width: 6, height: 10), _shape(const Color(0xFFF7E4B5)));
      final Path cap = Path()
        ..moveTo(c.dx - 11, c.dy)
        ..quadraticBezierTo(c.dx, c.dy - 16, c.dx + 11, c.dy)
        ..close();
      canvas.drawPath(cap, _shape(const Color(0xFFE5484D)));
      if (!_ink) {
        canvas.drawCircle(c + const Offset(-4, -5), 1.8, Paint()..color = const Color(0xFFFFFFFF));
        canvas.drawCircle(c + const Offset(3, -7), 1.6, Paint()..color = const Color(0xFFFFFFFF));
      }
    }
    // Luciérnagas.
    if (!_ink) {
      for (int i = 0; i < 7; i++) {
        final Offset c = Offset(
          size.width * (0.1 + i * 0.13) + math.sin(t * 0.7 + i * 2) * 14,
          size.height * (0.3 + (i % 3) * 0.12) + math.cos(t * 0.9 + i) * 10,
        );
        final double glow = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(t * 2.4 + i * 1.7));
        canvas.drawCircle(c, 5, Paint()..color = const Color(0xFFFFF3A0).withValues(alpha: 0.25 * glow));
        canvas.drawCircle(c, 1.8, Paint()..color = const Color(0xFFFFF3A0).withValues(alpha: glow));
      }
    }
  }

  void _mountainDawn(Canvas canvas, Size size, Rect r, double floor, double t) {
    _sky(canvas, r, const Color(0xFFFFD8A8), const Color(0xFFFFF4E0));
    final Offset sun = Offset(size.width * 0.72, size.height * 0.3);
    canvas.drawCircle(sun, size.width * 0.09, _shape(const Color(0xFFFFB347)));
    // Nubes que pasan.
    for (int i = 0; i < 2; i++) {
      final double x = ((t * (6 + i * 3) / size.width + i * 0.5) % 1.3 - 0.15) * size.width;
      _cloud(canvas, Offset(x, size.height * (0.14 + i * 0.12)), 1 - i * 0.25);
    }
    for (final (double x, double h, Color c) in <(double, double, Color)>[
      (0.0, 0.42, const Color(0xFFB98A6A)),
      (0.35, 0.55, const Color(0xFF9C6E55)),
      (0.7, 0.38, const Color(0xFFB98A6A)),
    ]) {
      final Path m = Path()
        ..moveTo(size.width * (x - 0.2), floor)
        ..lineTo(size.width * (x + 0.18), floor - size.height * h)
        ..lineTo(size.width * (x + 0.56), floor)
        ..close();
      canvas.drawPath(m, _shape(c.withValues(alpha: 0.85)));
      if (!_ink) {
        final Offset top = Offset(size.width * (x + 0.18), floor - size.height * h);
        canvas.drawPath(
          Path()
            ..moveTo(top.dx, top.dy)
            ..lineTo(top.dx - 12, top.dy + 14)
            ..lineTo(top.dx + 12, top.dy + 14)
            ..close(),
          Paint()..color = const Color(0xFFFFFBF2),
        );
      }
    }
    _ground(canvas, size, floor, const Color(0xFF8DB36A));
  }

  void _snow(Canvas canvas, Size size, Rect r, double floor, double t) {
    _sky(canvas, r, const Color(0xFFCFE0F4), const Color(0xFFF1F6FC));
    for (final (double cx, double w, double h) in <(double, double, double)>[(0.2, 0.8, 0.22), (0.85, 0.7, 0.16)]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(size.width * cx, floor), width: size.width * w, height: size.height * h * 2),
        _shape(const Color(0xFFE3EDF8)),
      );
    }
    // Pino nevado.
    final Offset pine = Offset(size.width * 0.84, floor);
    for (int i = 0; i < 3; i++) {
      final double y = pine.dy - 24 - i * 26;
      final double w = 34 - i * 8.0;
      final Path tier = Path()
        ..moveTo(pine.dx, y - 30)
        ..lineTo(pine.dx + w, y)
        ..lineTo(pine.dx - w, y)
        ..close();
      canvas.drawPath(tier, _shape(const Color(0xFF3F7F5C)));
      if (!_ink) {
        canvas.drawPath(
          Path()
            ..moveTo(pine.dx, y - 30)
            ..lineTo(pine.dx + w * 0.4, y - 18)
            ..lineTo(pine.dx - w * 0.4, y - 18)
            ..close(),
          Paint()..color = const Color(0xFFFFFFFF),
        );
      }
    }
    _ground(canvas, size, floor, const Color(0xFFF7FAFF));
    // Copos de nieve.
    final math.Random rng = math.Random(11);
    for (int i = 0; i < (_ink ? 14 : 34); i++) {
      final double speed = 10 + rng.nextDouble() * 14;
      final double x0 = rng.nextDouble() * size.width;
      final double y0 = rng.nextDouble() * size.height;
      final double y = (y0 + t * speed) % size.height;
      final double x = x0 + math.sin(t * 0.8 + i) * 6;
      final double radius = 1.2 + rng.nextDouble() * 1.8;
      canvas.drawCircle(Offset(x, y), radius, _ink ? _line : (Paint()..color = const Color(0xE6FFFFFF)));
    }
  }

  void _starryDojo(Canvas canvas, Size size, Rect r, double floor, double t) {
    _sky(canvas, r, const Color(0xFF1E1B4B), const Color(0xFF4C3F91));
    _stars(canvas, size, floor, t, seed: 7, count: 26);
    canvas.drawCircle(Offset(size.width * 0.18, size.height * 0.2), size.width * 0.06, _shape(const Color(0xFFFFF4C2)));
    _ground(canvas, size, floor, const Color(0xFFC9B27C));
    for (int i = 1; i < 5; i++) {
      final double x = size.width * i / 5;
      canvas.drawLine(Offset(x, floor), Offset(x, size.height), _stroke(const Color(0x668A6F3A)));
    }
    // Farolillo.
    final Offset lamp = Offset(size.width * 0.86, size.height * 0.22);
    canvas.drawLine(Offset(lamp.dx, 0), lamp - const Offset(0, 14), _stroke(const Color(0xFF8A6F3A)));
    canvas.drawOval(Rect.fromCenter(center: lamp, width: 20, height: 28), _shape(const Color(0xFFE5734A)));
    if (!_ink) {
      final double glow = 0.5 + 0.2 * math.sin(t * 1.6);
      canvas.drawCircle(lamp, 24, Paint()..color = const Color(0xFFFFB347).withValues(alpha: 0.18 * glow));
    }
  }

  void _sakura(Canvas canvas, Size size, Rect r, double floor, double t) {
    _sky(canvas, r, const Color(0xFFFFDDE8), const Color(0xFFFFF5F8));
    canvas.drawOval(
      Rect.fromCenter(center: Offset(size.width * 0.35, floor), width: size.width * 1.1, height: size.height * 0.3),
      _shape(const Color(0xFFF3C9D6)),
    );
    _ground(canvas, size, floor, const Color(0xFFD4E8BE));
    // Rama del cerezo desde la derecha.
    final Path branch = Path()
      ..moveTo(size.width * 1.02, size.height * 0.48)
      ..quadraticBezierTo(size.width * 0.82, size.height * 0.3, size.width * 0.6, size.height * 0.16);
    canvas.drawPath(branch, _stroke(const Color(0xFF6B4636), width: 7));
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.84, size.height * 0.34)
        ..quadraticBezierTo(size.width * 0.8, size.height * 0.46, size.width * 0.7, size.height * 0.5),
      _stroke(const Color(0xFF6B4636), width: 4),
    );
    for (final Offset c in <Offset>[
      Offset(size.width * 0.62, size.height * 0.16),
      Offset(size.width * 0.72, size.height * 0.22),
      Offset(size.width * 0.86, size.height * 0.3),
      Offset(size.width * 0.7, size.height * 0.5),
      Offset(size.width * 0.95, size.height * 0.42),
      Offset(size.width * 0.78, size.height * 0.4),
    ]) {
      _blossom(canvas, c);
    }
    // Pétalos que caen.
    if (!_ink) {
      final math.Random rng = math.Random(5);
      for (int i = 0; i < 12; i++) {
        final double speed = 12 + rng.nextDouble() * 10;
        final double x0 = size.width * (0.3 + rng.nextDouble() * 0.7);
        final double y = (rng.nextDouble() * size.height + t * speed) % size.height;
        final double x = x0 - (y / size.height) * size.width * 0.25 + math.sin(t * 1.3 + i) * 8;
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(t + i);
        canvas.drawOval(const Rect.fromLTWH(-3.5, -2, 7, 4), Paint()..color = const Color(0xFFF7A1C4));
        canvas.restore();
      }
    }
  }

  void _space(Canvas canvas, Size size, Rect r, double floor, double t) {
    _sky(canvas, r, const Color(0xFF0B1026), const Color(0xFF2B2466));
    _stars(canvas, size, floor, t, seed: 3, count: 40);
    // Planeta con anillo.
    final Offset planet = Offset(size.width * 0.78, size.height * 0.24);
    final double pr = size.width * 0.08;
    final Rect ring = Rect.fromCenter(center: planet, width: pr * 3.4, height: pr * 0.9);
    canvas.drawArc(ring, math.pi, math.pi, false, _stroke(const Color(0xFFF3D19C), width: 3));
    canvas.drawCircle(planet, pr, _shape(const Color(0xFFE6A86B)));
    canvas.drawArc(ring, 0, math.pi, false, _stroke(const Color(0xFFF3D19C), width: 3));
    // Estrella fugaz cada 6 s.
    if (!_ink) {
      final double k = (t % 6) / 1.2;
      if (k < 1) {
        final Offset head = Offset(size.width * (0.15 + k * 0.4), size.height * (0.08 + k * 0.18));
        canvas.drawLine(
          head,
          head - Offset(size.width * 0.08, size.height * 0.036),
          Paint()
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xFFFFFFFF).withValues(alpha: 1 - k),
        );
      }
    }
    // Suelo lunar con cráteres.
    _ground(canvas, size, floor, const Color(0xFFB9B9C6));
    for (final (double x, double w) in <(double, double)>[(0.15, 34), (0.7, 22), (0.9, 28)]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(size.width * x, floor + (size.height - floor) * 0.45), width: w, height: w * 0.32),
        _shape(const Color(0xFF9C9CAD)),
      );
    }
  }

  // ---------------------------------------------------------------- Piezas

  void _stars(Canvas canvas, Size size, double floor, double t, {required int seed, required int count}) {
    final math.Random rng = math.Random(seed);
    for (int i = 0; i < count; i++) {
      final Offset star = Offset(rng.nextDouble() * size.width, rng.nextDouble() * floor * 0.85);
      final double radius = 0.8 + rng.nextDouble() * 1.4;
      final double twinkle = 0.45 + 0.55 * (0.5 + 0.5 * math.sin(t * (1 + rng.nextDouble() * 2) + i));
      canvas.drawCircle(
        star,
        radius,
        Paint()..color = _ink ? colors.text3 : const Color(0xFFFFF7D6).withValues(alpha: 0.9 * twinkle),
      );
    }
  }

  void _cloud(Canvas canvas, Offset c, double scale) {
    final Paint paint = _ink ? _line : (Paint()..color = const Color(0xCCFFFFFF));
    for (final (Offset o, double rr) in <(Offset, double)>[
      (const Offset(-14, 2), 9),
      (const Offset(0, -4), 12),
      (const Offset(14, 2), 9),
    ]) {
      canvas.drawCircle(c + o * scale, rr * scale, paint);
    }
  }

  void _blossom(Canvas canvas, Offset c) {
    for (int i = 0; i < 5; i++) {
      final double a = i / 5 * math.pi * 2;
      canvas.drawCircle(c + Offset(math.cos(a) * 7, math.sin(a) * 7), 6, _shape(const Color(0xFFF7A1C4)));
    }
    canvas.drawCircle(c, 4, _shape(const Color(0xFFFBC4D9)));
  }

  void _sky(Canvas canvas, Rect r, Color top, Color bottom) {
    if (_ink) return;
    canvas.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[top, bottom],
        ).createShader(r),
    );
  }

  void _ground(Canvas canvas, Size size, double floor, Color color) {
    if (_ink) {
      canvas.drawLine(Offset(0, floor), Offset(size.width, floor), _line);
      return;
    }
    canvas.drawRect(Rect.fromLTRB(0, floor, size.width, size.height), Paint()..color = color);
  }

  @override
  bool shouldRepaint(HabitatPainter old) => old.habitatId != habitatId || old.colors != colors || old.time != time;
}
