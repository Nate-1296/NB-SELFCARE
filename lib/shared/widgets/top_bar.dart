import 'package:flutter/material.dart';

import '../theme/sc_colors.dart';
import '../theme/sc_theme.dart';
import '../theme/sc_tokens.dart';
import '../utils/responsive.dart';
import 'auto_fit_text.dart';

/// Cabecera de las vistas.
///
/// * [large]: título grande de pestaña principal con la línea de contexto
///   (fecha) encima, como una portada.
/// * compacta: para subpáginas con botón atrás; el subtítulo va debajo.
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.leading,
    this.large = false,
    this.avatarFoto,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;
  final bool large;

  /// Imagen circular opcional a la izquierda del título (p. ej. la mascota).
  final ImageProvider? avatarFoto;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final double scale = context.uiScale;
    final double titleSize = (large ? 30.0 : 21.0) * scale;

    final Widget titleText = AutoFitText(
      title,
      maxLines: 2,
      minFontSize: titleSize * 0.7,
      style: TextStyle(
        fontFamily: ScFonts.display,
        fontSize: titleSize,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.035 * titleSize,
        color: c.text,
        height: 1.1,
      ),
    );
    final Widget? subtitleText = subtitle == null
        ? null
        : Text(
            subtitle!,
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: (large ? 13.5 : 13) * scale,
              fontWeight: FontWeight.w600,
              color: large ? (c.isFlat ? c.text2 : c.accent) : c.text2,
              height: 1.3,
            ),
          );

    final Widget? leadingWidget =
        leading ??
        (avatarFoto == null
            ? null
            : Container(
                width: 44 * scale,
                height: 44 * scale,
                decoration: BoxDecoration(
                  color: c.bg3,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.isFlat ? c.line2 : c.line, width: c.isFlat ? 1.5 : 1),
                  image: DecorationImage(image: avatarFoto!, fit: BoxFit.cover),
                ),
              ));

    return Padding(
      padding: large
          ? const EdgeInsets.fromLTRB(ScSpace.gutter + 4, ScSpace.l, ScSpace.gutter, ScSpace.m)
          : const EdgeInsets.fromLTRB(ScSpace.xs, ScSpace.s, ScSpace.gutter, ScSpace.s),
      child: Row(
        crossAxisAlignment: large ? CrossAxisAlignment.end : CrossAxisAlignment.center,
        children: <Widget>[
          if (leadingWidget != null) ...<Widget>[
            leadingWidget,
            const SizedBox(width: ScSpace.m),
          ] else if (!large)
            const SizedBox(width: ScSpace.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (large && subtitleText != null) ...<Widget>[
                  subtitleText,
                  const SizedBox(height: ScSpace.xs),
                ],
                titleText,
                if (!large && subtitleText != null) ...<Widget>[
                  const SizedBox(height: ScSpace.xxs),
                  subtitleText,
                ],
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[const SizedBox(width: ScSpace.s), trailing!],
        ],
      ),
    );
  }
}

/// Acción circular de cabecera (ajustes, calendario…), con zona táctil de 48 dp.
class TopBarAction extends StatelessWidget {
  const TopBarAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: c.isFlat ? Colors.transparent : c.bg3,
        foregroundColor: c.text,
        fixedSize: const Size(44, 44),
        side: c.isFlat ? BorderSide(color: c.line2, width: 1.5) : BorderSide.none,
      ),
      icon: Icon(icon, size: 21),
    );
  }
}
