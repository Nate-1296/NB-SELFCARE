import 'package:flutter/material.dart';

import '../theme/sc_colors.dart';
import '../theme/sc_theme.dart';
import '../utils/responsive.dart';
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
    this.pageIcon,
    this.large = false,
    this.subtitleBelowTitle = false,
    this.uppercaseSubtitle = true,
    this.avatarInicial = 'N',
    this.avatarText,
    this.avatarFoto,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onProfile;
  final Widget? trailing;
  final Widget? leading;

  /// Ícono temático de la pantalla que reemplaza a la foto de perfil en las vistas principales.
  final IconData? pageIcon;
  final bool large;
  final bool subtitleBelowTitle;
  final bool uppercaseSubtitle;
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

    final Widget leadingWidget;
    if (leading != null) {
      leadingWidget = leading!;
    } else if (pageIcon != null) {
      leadingWidget = GestureDetector(
        onTap: onProfile,
        child: Container(
          width: avatarSize,
          height: avatarSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.isFlat ? c.bg3 : c.soft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: c.isFlat ? c.line2 : c.accent.withValues(alpha: 0.35),
              width: c.isFlat ? 1.5 : 1.2,
            ),
          ),
          child: Icon(
            pageIcon,
            size: 21 * scale,
            color: c.isFlat ? c.text : c.accent,
          ),
        ),
      );
    } else {
      leadingWidget = GestureDetector(
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
    }

    final Widget? subtitleWidget = subtitle == null
        ? null
        : Text(
            uppercaseSubtitle ? subtitle!.toUpperCase() : subtitle!,
            softWrap: true,
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: (uppercaseSubtitle ? 11.5 : 13.0) * scale,
              fontWeight: uppercaseSubtitle ? FontWeight.w700 : FontWeight.w600,
              letterSpacing: uppercaseSubtitle ? 1.2 : 0.1,
              color: uppercaseSubtitle ? c.text3 : c.text2,
            ),
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          leadingWidget,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (subtitleWidget != null && !subtitleBelowTitle) ...<Widget>[
                  subtitleWidget,
                  const SizedBox(height: 2),
                ],
                AutoFitText(
                  title,
                  maxLines: 2,
                  minFontSize: titleSize * 0.70,
                  style: TextStyle(
                    fontFamily: ScFonts.display,
                    fontSize: titleSize,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.02 * titleSize,
                    color: c.text,
                    height: 1.15,
                  ),
                ),
                if (subtitleWidget != null && subtitleBelowTitle) ...<Widget>[
                  const SizedBox(height: 3),
                  subtitleWidget,
                ],
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}
