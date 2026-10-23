import 'package:flutter/material.dart';

/// Lienzo vectorial procedural para renderizar a la mascota virtual Nibi a 60 fps.
///
/// No requiere dependencias de archivos de imagen ni SVG externos; es 100% autónomo.
/// En Modo Papel (NXTPAPER E-Ink) dibuja con líneas sólidas de 1.5 px y suprime halos difusos.
class ProceduralPetCanvas extends StatelessWidget {
  const ProceduralPetCanvas({
    super.key,
    this.isFastingKetosis = false,
    this.hydrationRatio = 0.8,
    this.sleepHours = 7.5,
    this.isWeighingIn = false,
    this.equippedHatId,
    this.isEink = false,
    this.size = 140.0,
  });

  final bool isFastingKetosis;
  final double hydrationRatio;
  final double sleepHours;
  final bool isWeighingIn;
  final String? equippedHatId;
  final bool isEink;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _NibiPainter(
        isFastingKetosis: isFastingKetosis,
        hydrationRatio: hydrationRatio,
        sleepHours: sleepHours,
        isWeighingIn: isWeighingIn,
        equippedHatId: equippedHatId,
        isEink: isEink,
      ),
    );
  }
}

class _NibiPainter extends CustomPainter {
  const _NibiPainter({
    required this.isFastingKetosis,
    required this.hydrationRatio,
    required this.sleepHours,
    required this.isWeighingIn,
    required this.equippedHatId,
    required this.isEink,
  });

  final bool isFastingKetosis;
  final double hydrationRatio;
  final double sleepHours;
  final bool isWeighingIn;
  final String? equippedHatId;
  final bool isEink;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final center = Offset(w / 2, h * 0.55);
    final double petRadius = w * 0.30;

    final Color strokeColor = isEink ? const Color(0xFF121212) : const Color(0xFF2D3748);
    final Color bodyColor = isEink ? const Color(0xFFFFFFFF) : const Color(0xFFF7FAFC);
    final Color bellyColor = isEink ? const Color(0xFFF0F0F0) : const Color(0xFFEDF2F7);

    final linePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isEink ? 1.8 : 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = bodyColor
      ..style = PaintingStyle.fill;

    // 1. Aura de Cetosis de Ayuno (si ayunó >= 12h)
    if (isFastingKetosis) {
      final auraPaint = Paint()
        ..color = isEink
            ? Colors.grey.shade400
            : const Color(0xFFFFD700).withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isEink ? 2.0 : 4.0;

      canvas.drawCircle(center, petRadius * 1.35, auraPaint);
      if (!isEink) {
        // Segundo halo exterior
        final outerAura = Paint()
          ..color = const Color(0xFF00E5FF).withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawCircle(center, petRadius * 1.5, outerAura);
      }
    }

    // 2. Mini Báscula al estar en pesaje en vivo (isWeighingIn)
    if (isWeighingIn) {
      final scaleRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy + petRadius * 1.05),
          width: petRadius * 2.4,
          height: 16.0,
        ),
        const Radius.circular(8),
      );

      final scaleFill = Paint()
        ..color = isEink ? Colors.grey.shade300 : const Color(0xFFCBD5E0)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(scaleRect, scaleFill);
      canvas.drawRRect(scaleRect, linePaint);

      // Pantallita LED de la báscula
      final ledRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy + petRadius * 1.05),
          width: 32.0,
          height: 8.0,
        ),
        const Radius.circular(3),
      );
      final ledPaint = Paint()
        ..color = isEink ? Colors.black : const Color(0xFF10B981)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(ledRect, ledPaint);
    }

    // 3. Orejas Redondeadas de Nibi
    final leftEarCenter = Offset(center.dx - petRadius * 0.70, center.dy - petRadius * 0.85);
    final rightEarCenter = Offset(center.dx + petRadius * 0.70, center.dy - petRadius * 0.85);
    final double earRadius = petRadius * 0.35;

    canvas.drawCircle(leftEarCenter, earRadius, fillPaint);
    canvas.drawCircle(leftEarCenter, earRadius, linePaint);

    canvas.drawCircle(rightEarCenter, earRadius, fillPaint);
    canvas.drawCircle(rightEarCenter, earRadius, linePaint);

    // Interior de las orejas
    final innerEarPaint = Paint()
      ..color = isEink ? const Color(0xFFE2E8F0) : const Color(0xFFFED7E2)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(leftEarCenter, earRadius * 0.60, innerEarPaint);
    canvas.drawCircle(rightEarCenter, earRadius * 0.60, innerEarPaint);

    // 4. Cuerpo de Nibi (Elipse suave)
    final bodyRect = Rect.fromCenter(center: center, width: petRadius * 2.1, height: petRadius * 2.0);
    canvas.drawOval(bodyRect, fillPaint);

    // Pancita
    final bellyPaint = Paint()
      ..color = bellyColor
      ..style = PaintingStyle.fill;
    final bellyRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + petRadius * 0.25),
      width: petRadius * 1.4,
      height: petRadius * 1.2,
    );
    canvas.drawOval(bellyRect, bellyPaint);
    canvas.drawOval(bodyRect, linePaint);

    // 5. Ojos de Nibi (Reactivos al sueño)
    final double eyeSpacing = petRadius * 0.45;
    final double eyeY = center.dy - petRadius * 0.15;
    final isWellRested = sleepHours >= 7.0;

    final eyePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.fill;

    if (isWellRested) {
      // Ojos abiertos y vivaces
      final leftEye = Offset(center.dx - eyeSpacing, eyeY);
      final rightEye = Offset(center.dx + eyeSpacing, eyeY);
      final double eyeRadius = isEink ? 4.5 : 5.5;

      canvas.drawCircle(leftEye, eyeRadius, eyePaint);
      canvas.drawCircle(rightEye, eyeRadius, eyePaint);

      // Brillo blanco en ojos
      final glintPaint = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(leftEye.dx - 1.5, leftEye.dy - 1.5), 1.8, glintPaint);
      canvas.drawCircle(Offset(rightEye.dx - 1.5, rightEye.dy - 1.5), 1.8, glintPaint);
    } else {
      // Ojitos en arco sereno ^ ^
      final leftEyePath = Path()
        ..moveTo(center.dx - eyeSpacing - 6, eyeY + 2)
        ..quadraticBezierTo(center.dx - eyeSpacing, eyeY - 4, center.dx - eyeSpacing + 6, eyeY + 2);
      final rightEyePath = Path()
        ..moveTo(center.dx + eyeSpacing - 6, eyeY + 2)
        ..quadraticBezierTo(center.dx + eyeSpacing, eyeY - 4, center.dx + eyeSpacing + 6, eyeY + 2);

      canvas.drawPath(leftEyePath, linePaint);
      canvas.drawPath(rightEyePath, linePaint);
    }

    // 6. Mejillas Sonrojadas
    final blushColor = isEink
        ? Colors.grey.shade400
        : const Color(0xFFFEB2B2).withValues(alpha: 0.65);
    final blushPaint = Paint()
      ..color = blushColor
      ..style = PaintingStyle.fill;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx - eyeSpacing - 6, eyeY + 12),
        width: 14,
        height: 7,
      ),
      blushPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx + eyeSpacing + 6, eyeY + 12),
        width: 14,
        height: 7,
      ),
      blushPaint,
    );

    // 7. Nariz y Boca Sonriente
    final mouthPath = Path()
      ..moveTo(center.dx - 8, eyeY + 10)
      ..quadraticBezierTo(center.dx, eyeY + 17, center.dx + 8, eyeY + 10);
    canvas.drawPath(mouthPath, linePaint);

    // 8. Efecto de Hidratación (gotita de agua alegre al lado)
    if (hydrationRatio >= 0.7) {
      final dropPaint = Paint()
        ..color = isEink ? Colors.grey.shade600 : const Color(0xFF38BDF8)
        ..style = PaintingStyle.fill;

      final dropCenter = Offset(center.dx + petRadius * 0.95, center.dy - petRadius * 0.40);
      final dropPath = Path()
        ..moveTo(dropCenter.dx, dropCenter.dy - 8)
        ..quadraticBezierTo(dropCenter.dx + 6, dropCenter.dy + 4, dropCenter.dx, dropCenter.dy + 6)
        ..quadraticBezierTo(dropCenter.dx - 6, dropCenter.dy + 4, dropCenter.dx, dropCenter.dy - 8);

      canvas.drawPath(dropPath, dropPaint);
      canvas.drawPath(dropPath, linePaint);
    }

    // 9. Sombrero / Accesorio Equipado
    _drawAccessory(canvas, center, petRadius, linePaint);
  }

  void _drawAccessory(Canvas canvas, Offset center, double petRadius, Paint linePaint) {
    if (equippedHatId == null) return;

    final hatTop = Offset(center.dx, center.dy - petRadius * 1.05);

    switch (equippedHatId) {
      case 'hat_chef':
        // Gorro de Chef
        final chefFill = Paint()
          ..color = isEink ? Colors.white : const Color(0xFFF8FAFC)
          ..style = PaintingStyle.fill;

        final chefPath = Path()
          ..moveTo(hatTop.dx - 18, hatTop.dy + 4)
          ..lineTo(hatTop.dx + 18, hatTop.dy + 4)
          ..lineTo(hatTop.dx + 22, hatTop.dy - 12)
          ..quadraticBezierTo(hatTop.dx + 16, hatTop.dy - 26, hatTop.dx, hatTop.dy - 24)
          ..quadraticBezierTo(hatTop.dx - 16, hatTop.dy - 26, hatTop.dx - 22, hatTop.dy - 12)
          ..close();

        canvas.drawPath(chefPath, chefFill);
        canvas.drawPath(chefPath, linePaint);
        break;

      case 'hat_headband':
        // Vincha deportiva con estrella
        final bandFill = Paint()
          ..color = isEink ? Colors.grey.shade400 : Colors.deepOrange
          ..style = PaintingStyle.fill;

        final bandRect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(hatTop.dx, hatTop.dy + 12), width: petRadius * 1.8, height: 10),
          const Radius.circular(5),
        );
        canvas.drawRRect(bandRect, bandFill);
        canvas.drawRRect(bandRect, linePaint);
        break;

      case 'hat_zen_halo':
        // Halo flotante zen
        final haloPaint = Paint()
          ..color = isEink ? Colors.grey.shade600 : const Color(0xFFFBBF24)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5;

        canvas.drawOval(
          Rect.fromCenter(center: Offset(hatTop.dx, hatTop.dy - 16), width: 44, height: 14),
          haloPaint,
        );
        break;

      case 'hat_crown':
        // Corona dorada
        final crownFill = Paint()
          ..color = isEink ? Colors.grey.shade300 : const Color(0xFFF59E0B)
          ..style = PaintingStyle.fill;

        final crownPath = Path()
          ..moveTo(hatTop.dx - 18, hatTop.dy + 4)
          ..lineTo(hatTop.dx - 22, hatTop.dy - 14)
          ..lineTo(hatTop.dx - 10, hatTop.dy - 6)
          ..lineTo(hatTop.dx, hatTop.dy - 18)
          ..lineTo(hatTop.dx + 10, hatTop.dy - 6)
          ..lineTo(hatTop.dx + 22, hatTop.dy - 14)
          ..lineTo(hatTop.dx + 18, hatTop.dy + 4)
          ..close();

        canvas.drawPath(crownPath, crownFill);
        canvas.drawPath(crownPath, linePaint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _NibiPainter oldDelegate) {
    return oldDelegate.isFastingKetosis != isFastingKetosis ||
        oldDelegate.hydrationRatio != hydrationRatio ||
        oldDelegate.sleepHours != sleepHours ||
        oldDelegate.isWeighingIn != isWeighingIn ||
        oldDelegate.equippedHatId != equippedHatId ||
        oldDelegate.isEink != isEink;
  }
}
