import 'package:flutter/widgets.dart';

/// Texto que reduce dinámicamente el tamaño de fuente para caber en [maxLines]
/// antes de truncar con puntos suspensivos.
class AutoFitText extends StatelessWidget {
  const AutoFitText(
    this.text, {
    super.key,
    required this.style,
    this.maxLines = 1,
    this.minFontSize = 12.0,
    this.textAlign,
  });

  final String text;
  final TextStyle style;
  final int maxLines;
  final double minFontSize;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxW = constraints.maxWidth;
        if (!maxW.isFinite || maxW <= 0) {
          return Text(
            text,
            style: style,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
          );
        }

        double size = style.fontSize ?? 14.0;
        final double minSize = minFontSize;

        while (size > minSize) {
          final TextPainter tp = TextPainter(
            text: TextSpan(text: text, style: style.copyWith(fontSize: size)),
            maxLines: maxLines,
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: maxW);

          if (!tp.didExceedMaxLines) {
            break;
          }
          size -= 1.0;
        }

        return Text(
          text,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: style.copyWith(fontSize: size),
        );
      },
    );
  }
}

