import 'package:flutter/material.dart';

import '../theme/sc_colors.dart';
import '../theme/sc_theme.dart';
import '../util/responsive.dart';
import 'auto_fit_text.dart';

/// Barra superior unificada de las vistas principales con avatar y saludo adaptable.
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onProfile,
    this.trailing,
    this.leading,
    this.large = false,
    this.avatarInicial = 'N',
    this.avatarText,
    this.avatarFoto,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onProfile;
  final Widget? trailing;
  final Widget? leading;
  final bool large;
  final String avatarInicial;
  final String? avatarText;
  final ImageProvider? avatarFoto;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final double scale = context.uiScale;
    final double titleSize = (large ? 24.0 : 20.0) * scale;
    final double avatarSize = 42.0 * scale;
    final String initial = avatarText ?? avatarInicial;

    final Widget leadingWidget = leading ??
        GestureDetector(
          onTap: onProfile,
          child: Container(
            width: avatarSize,
            height: avatarSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.bg3,
              shape: BoxShape.circle,
              border: Border.all(
                color: c.isFlat ? c.line2 : c.line,
                width: c.isFlat ? 1.5 : 1.2,
              ),
              image: avatarFoto != null
                  ? DecorationImage(image: avatarFoto!, fit: BoxFit.cover)
                  : null,
            ),
            child: avatarFoto != null
                ? null
                : Text(
                    initial.length == 1 ? initial.toUpperCase() : initial,
                    style: TextStyle(
                      fontFamily: ScFonts.display,
                      fontSize: (initial.length == 1 ? 16.0 : 18.0) * scale,
                      fontWeight: FontWeight.w800,
                      color: c.accent,
                    ),
                  ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
      child: Row(
        children: <Widget>[
          leadingWidget,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (subtitle != null) ...<Widget>[
                  Text(
                    subtitle!.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 11.5 * scale,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.3,
                      color: c.text3,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                AutoFitText(
                  title,
                  maxLines: 2,
                  minFontSize: titleSize * 0.65,
                  style: TextStyle(
                    fontFamily: ScFonts.display,
                    fontSize: titleSize,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.02 * titleSize,
                    color: c.text,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
