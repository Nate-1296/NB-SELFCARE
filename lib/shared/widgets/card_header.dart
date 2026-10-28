import 'package:flutter/material.dart';

import '../theme/sc_colors.dart';
import '../theme/sc_tokens.dart';

/// Encabezado de tarjeta: icono del color de su categoría, título y subtítulo
/// opcional debajo, con una acción a la derecha.
///
/// El icono va sin caja: la categoría la da el color, no un recuadro.
class CardHeader extends StatelessWidget {
  const CardHeader({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.tone,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color? tone;
  final Widget? trailing;

  static const double _trailingMaxWidth = 168;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final Color tint = c.isFlat ? c.text : (tone ?? c.accent);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 20, color: tint),
        ),
        const SizedBox(width: ScSpace.s + 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleLarge,
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: ScSpace.xxs),
                Text(
                  subtitle!,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.caption,
                ),
              ],
            ],
          ),
        ),
        // La acción ocupa solo lo que necesita, con un tope: una insignia
        // larga (o el texto grande del sistema) se recorta en vez de
        // desbordar, y el título conserva el resto del ancho. (Un Flexible le
        // reservaba la mitad de la fila aunque fuera pequeña.)
        if (trailing != null) ...<Widget>[
          const SizedBox(width: ScSpace.s),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _trailingMaxWidth),
            child: trailing!,
          ),
        ],
      ],
    );
  }
}

/// Rótulo compacto de tarjeta de métrica: icono pequeño de color + nombre.
class MetricLabel extends StatelessWidget {
  const MetricLabel({super.key, required this.icon, required this.label, this.tone, this.trailing});

  final IconData icon;
  final String label;
  final Color? tone;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Row(
      children: <Widget>[
        Icon(icon, size: 17, color: c.isFlat ? c.text : (tone ?? c.accent)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.type.label,
          ),
        ),
        if (trailing != null) Flexible(child: trailing!),
      ],
    );
  }
}
