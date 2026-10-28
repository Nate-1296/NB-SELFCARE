import 'package:flutter/material.dart';

import '../theme/sc_colors.dart';
import '../theme/sc_tokens.dart';

/// Cifra destacada con su unidad ("82.7 kg", "1 014 kcal").
///
/// La unidad va más pequeña y en tono secundario, alineada a la línea base de
/// la cifra. Los dígitos son tabulares para que no salten al cambiar.
class MetricValue extends StatelessWidget {
  const MetricValue({
    super.key,
    required this.value,
    this.unit,
    this.size = 28,
    this.color,
    this.unitColor,
  });

  final String value;
  final String? unit;
  final double size;
  final Color? color;
  final Color? unitColor;

  @override
  Widget build(BuildContext context) {
    final ScType type = context.type;
    final TextStyle base = type.metricL.copyWith(
      fontSize: size,
      letterSpacing: -0.035 * size,
      color: color,
    );
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(text: value, style: base),
          if (unit != null && unit!.isNotEmpty)
            TextSpan(
              text: ' $unit',
              style: type.unit(size).copyWith(color: unitColor ?? context.sc.text2),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// [MetricValue] que, al cambiar el número, cuenta hasta el nuevo valor.
///
/// La primera vez se muestra directamente (sin animación de entrada) para que
/// abrir una pantalla no se sienta lento; en Modo Papel nunca se anima.
class AnimatedMetricValue extends StatefulWidget {
  const AnimatedMetricValue({
    super.key,
    required this.value,
    required this.format,
    this.unit,
    this.size = 28,
    this.color,
    this.unitColor,
  });

  final double value;
  final String Function(double value) format;
  final String? unit;
  final double size;
  final Color? color;
  final Color? unitColor;

  @override
  State<AnimatedMetricValue> createState() => _AnimatedMetricValueState();
}

class _AnimatedMetricValueState extends State<AnimatedMetricValue> {
  late double _from = widget.value;

  @override
  void didUpdateWidget(AnimatedMetricValue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _from = oldWidget.value;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _from, end: widget.value),
      duration: ScMotion.of(context, ScMotion.emphasized),
      curve: ScMotion.ease,
      builder: (BuildContext context, double v, Widget? _) => MetricValue(
        value: widget.format(v),
        unit: widget.unit,
        size: widget.size,
        color: widget.color,
        unitColor: widget.unitColor,
      ),
    );
  }
}
