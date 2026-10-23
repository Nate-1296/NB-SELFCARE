import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';

/// Anillo radial reactivo para visualizar calorías y macronutrientes.
///
/// En Modo Papel (NXTPAPER E-Ink) desactiva sombras y aplica trazos sólidos
/// de 2.0 px con codificación geométrica sin depender exclusivamente del color.
class ReactiveMacroRing extends ConsumerWidget {
  const ReactiveMacroRing({
    required this.consumedCalories,
    required this.targetCalories,
    super.key,
    this.proteinRatio = 0.0,
    this.carbsRatio = 0.0,
    this.fatRatio = 0.0,
    this.size = 180.0,
    this.strokeWidth = 14.0,
  });

  final double consumedCalories;
  final double targetCalories;
  final double proteinRatio;
  final double carbsRatio;
  final double fatRatio;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final String engine = ref.watch(themeEngineProvider);
    final bool isEink = engine == 'nxtpaper_eink';

    final double progress = targetCalories > 0
        ? (consumedCalories / targetCalories).clamp(0.0, 1.5)
        : 0.0;

    final double remaining = targetCalories - consumedCalories;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _MacroRingPainter(
              progress: progress,
              strokeWidth: strokeWidth,
              isEink: isEink,
              backgroundColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              progressColor: remaining >= 0
                  ? (isEink ? theme.colorScheme.onSurface : theme.colorScheme.primary)
                  : Colors.deepOrange,
              proteinRatio: proteinRatio.clamp(0.0, 1.0),
              carbsRatio: carbsRatio.clamp(0.0, 1.0),
              fatRatio: fatRatio.clamp(0.0, 1.0),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                remaining >= 0
                    ? remaining.toStringAsFixed(0)
                    : '+${(-remaining).toStringAsFixed(0)}',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: remaining >= 0
                      ? theme.colorScheme.onSurface
                      : Colors.deepOrange,
                ),
              ),
              Text(
                remaining >= 0 ? 'kcal restantes' : 'kcal excedente',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroRingPainter extends CustomPainter {
  const _MacroRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.isEink,
    required this.backgroundColor,
    required this.progressColor,
    required this.proteinRatio,
    required this.carbsRatio,
    required this.fatRatio,
  });

  final double progress;
  final double strokeWidth;
  final bool isEink;
  final Color backgroundColor;
  final Color progressColor;
  final double proteinRatio;
  final double carbsRatio;
  final double fatRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // 1. Círculo de Fondo
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, bgPaint);

    // 2. Arco de Progreso Principal (Calorías)
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeCap = isEink ? StrokeCap.butt : StrokeCap.round
      ..strokeWidth = strokeWidth;

    const startAngle = -math.pi / 2;
    final sweepAngle = (2 * math.pi * progress).clamp(0.0, 2 * math.pi * 1.5);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );

    // 3. Mini Anillo Interior de Macros (Proteína / Carbos / Grasa)
    final innerRadius = radius - strokeWidth * 0.85;
    if (innerRadius > 10) {
      final innerWidth = strokeWidth * 0.35;

      final pPaint = Paint()
        ..color = isEink ? Colors.grey.shade800 : Colors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = innerWidth;

      final cPaint = Paint()
        ..color = isEink ? Colors.grey.shade600 : Colors.amber.shade800
        ..style = PaintingStyle.stroke
        ..strokeWidth = innerWidth;

      final fPaint = Paint()
        ..color = isEink ? Colors.grey.shade400 : Colors.purple
        ..style = PaintingStyle.stroke
        ..strokeWidth = innerWidth;

      final rect = Rect.fromCircle(center: center, radius: innerRadius);
      double currentStart = startAngle;

      final double pSweep = 2 * math.pi * (proteinRatio * 0.33);
      canvas.drawArc(rect, currentStart, pSweep, false, pPaint);
      currentStart += pSweep;

      final double cSweep = 2 * math.pi * (carbsRatio * 0.33);
      canvas.drawArc(rect, currentStart, cSweep, false, cPaint);
      currentStart += cSweep;

      final double fSweep = 2 * math.pi * (fatRatio * 0.33);
      canvas.drawArc(rect, currentStart, fSweep, false, fPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MacroRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isEink != isEink ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.proteinRatio != proteinRatio ||
        oldDelegate.carbsRatio != carbsRatio ||
        oldDelegate.fatRatio != fatRatio;
  }
}
