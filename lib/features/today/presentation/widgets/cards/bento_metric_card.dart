import 'package:flutter/material.dart';

import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_tokens.dart';
import '../../../../../shared/widgets/card_header.dart';
import '../../../../../shared/widgets/health_card.dart';
import '../../../../../shared/widgets/progress_bar.dart';

/// Esqueleto común de las tarjetas de métrica de Hoy: rótulo de color, cifra
/// protagonista, una línea de contexto, progreso opcional y acciones abajo.
///
/// Todas comparten ritmo vertical, de modo que en la cuadrícula las cifras y
/// los botones de tarjetas vecinas quedan alineados.
class BentoMetricCard extends StatelessWidget {
  const BentoMetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.tone,
    required this.metric,
    this.labelTrailing,
    this.caption,
    this.captionEmphasis = false,
    this.secondaryCaption,
    this.progress,
    this.side,
    this.actions = const <Widget>[],
  });

  final IconData icon;
  final String label;
  final Color tone;
  final Widget? labelTrailing;
  final Widget metric;
  final String? caption;

  /// Resalta [caption] con el color de la tarjeta (un logro, una fase).
  final bool captionEmphasis;
  final String? secondaryCaption;
  final double? progress;

  /// Gráfico pequeño a la derecha de la cifra (solo en tarjetas anchas).
  final Widget? side;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final ScType type = context.type;

    final Widget figures = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        metric,
        if (caption != null) ...<Widget>[
          const SizedBox(height: ScSpace.xs + 2),
          Text(
            caption!,
            style: captionEmphasis
                ? type.caption.copyWith(
                    color: c.isFlat ? c.text : tone,
                    fontWeight: FontWeight.w700,
                  )
                : type.caption,
          ),
        ],
        if (secondaryCaption != null) ...<Widget>[
          const SizedBox(height: ScSpace.xxs),
          Text(secondaryCaption!, style: type.caption),
        ],
      ],
    );

    return HealthCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(ScSpace.l, ScSpace.l - 2, ScSpace.l, ScSpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                height: 32,
                child: MetricLabel(icon: icon, label: label, tone: tone, trailing: labelTrailing),
              ),
              const SizedBox(height: ScSpace.s),
              if (side == null)
                figures
              else
                Row(
                  children: <Widget>[
                    Expanded(child: figures),
                    const SizedBox(width: ScSpace.m),
                    side!,
                  ],
                ),
              if (progress != null) ...<Widget>[
                const SizedBox(height: ScSpace.m),
                ScProgressBar(value: progress!, color: tone, height: 6),
              ],
            ],
          ),
          if (actions.isNotEmpty) ...<Widget>[
            const SizedBox(height: ScSpace.l),
            Row(
              children: <Widget>[
                for (int i = 0; i < actions.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: ScSpace.s - 2),
                  Expanded(child: actions[i]),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
