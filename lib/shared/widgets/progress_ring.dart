import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/sc_colors.dart';
import '../theme/sc_tokens.dart';

/// Segmento de un [ScProgressRing] de varios colores (reparto de macros).
@immutable
class RingSegment {
  const RingSegment({required this.fraction, required this.color});

  final double fraction;
  final Color color;
}

/// Anillo de progreso con extremos redondeados y avance animado.
///
/// Con [segments] dibuja un anillo repartido (p. ej. proteína/carbos/grasa);
/// si no, un solo arco de [value]. En Modo Papel el arco es de tinta y la
/// pista un círculo fino, sin degradados ni animación.
class ScProgressRing extends StatelessWidget {
  const ScProgressRing({
    super.key,
    this.value = 0,
    this.segments,
    required this.size,
    this.stroke = 10,
    this.color,
    this.child,
    this.semanticsLabel,
    this.ticks = const <double>[],
    this.animateChanges = true,
  });

  final double value;
  final List<RingSegment>? segments;
  final double size;
  final double stroke;
  final Color? color;
  final Widget? child;
  final String? semanticsLabel;

  /// Marcas sobre la pista (fracciones 0–1), p. ej. el inicio de cada fase.
  final List<double> ticks;

  /// Si es falso, solo se anima la entrada y los cambios posteriores se
  /// dibujan al instante (anillos que avanzan cada segundo: cronómetros).
  final bool animateChanges;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final Color fill = c.isFlat ? c.text : (color ?? c.accent);
    final Color track = c.isFlat
        ? c.line2
        : (segments == null ? fill : c.text).withValues(alpha: segments == null ? 0.15 : 0.07);
    final double target = value.isNaN ? 0 : value.clamp(0.0, 1.0);

    return Semantics(
      label: semanticsLabel,
      value: segments == null ? '${(target * 100).round()} %' : null,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            RepaintBoundary(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: segments == null ? target : 1),
                duration: animateChanges
                    ? ScMotion.of(context, const Duration(milliseconds: 900))
                    : Duration.zero,
                curve: Curves.easeOutQuart,
                builder: (BuildContext context, double t, Widget? _) => CustomPaint(
                  size: Size.square(size),
                  painter: _RingPainter(
                    progress: t,
                    segments: segments,
                    fill: fill,
                    track: track,
                    stroke: stroke,
                    trackStroke: c.isFlat ? 1.5 : stroke,
                    ticks: ticks,
                    tickColor: c.isFlat ? c.text : c.text.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ),
            if (child != null) Padding(padding: EdgeInsets.all(stroke + 6), child: child),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.segments,
    required this.fill,
    required this.track,
    required this.stroke,
    required this.trackStroke,
    required this.ticks,
    required this.tickColor,
  });

  final double progress;
  final List<RingSegment>? segments;
  final Color fill;
  final Color track;
  final double stroke;
  final double trackStroke;
  final List<double> ticks;
  final Color tickColor;

  static const double _start = -math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Rect arcRect = rect.deflate(stroke / 2);
    canvas.drawArc(
      arcRect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = trackStroke
        ..color = track,
    );

    if (ticks.isNotEmpty) {
      final Offset center = arcRect.center;
      final double r = arcRect.width / 2;
      final Paint tickPaint = Paint()..color = tickColor;
      for (final double f in ticks) {
        final double a = _start + math.pi * 2 * f;
        canvas.drawCircle(
          center + Offset(math.cos(a) * r, math.sin(a) * r),
          math.max(2, stroke * 0.16),
          tickPaint,
        );
      }
    }

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final List<RingSegment>? segs = segments;
    if (segs == null) {
      if (progress <= 0) return;
      canvas.drawArc(arcRect, _start, math.pi * 2 * progress, false, paint..color = fill);
      _drawTicksOver(canvas, arcRect);
      return;
    }

    // Segmentos con un pequeño hueco entre ellos; se revelan en orden.
    final double total = segs.fold(0, (double s, RingSegment e) => s + e.fraction);
    if (total <= 0) return;
    final double gap = segs.length > 1 ? (stroke / (arcRect.width / 2)) * 1.1 : 0;
    double cursor = _start;
    final double visible = math.pi * 2 * progress;
    double drawn = 0;
    for (int i = 0; i < segs.length; i++) {
      final double sweep = math.pi * 2 * segs[i].fraction / total;
      final double usable = math.max(0, sweep - gap);
      final double remaining = visible - drawn;
      if (remaining <= 0) break;
      final double shown = math.min(usable, remaining);
      if (shown > 0.001) {
        // En papel los colores de macros ya llegan como tintas de distinta intensidad.
        paint.color = segs[i].color;
        canvas.drawArc(arcRect, cursor + gap / 2, shown, false, paint);
      }
      cursor += sweep;
      drawn += sweep;
    }
  }

  /// Las marcas ya cubiertas por el arco se redibujan en el color del fondo
  /// del arco para que sigan visibles como "muescas".
  void _drawTicksOver(Canvas canvas, Rect arcRect) {
    if (ticks.isEmpty) return;
    final Offset center = arcRect.center;
    final double r = arcRect.width / 2;
    final Paint notch = Paint()
      ..color = tickColor.withValues(alpha: 1).computeLuminance() > 0.5
          ? const Color(0x99000000)
          : const Color(0x99FFFFFF);
    for (final double f in ticks) {
      if (f > progress) continue;
      final double a = _start + math.pi * 2 * f;
      canvas.drawCircle(
        center + Offset(math.cos(a) * r, math.sin(a) * r),
        math.max(2, stroke * 0.16),
        notch,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.fill != fill ||
      old.track != track ||
      old.segments != segments;
}
