import 'package:flutter/material.dart';

import '../theme/sc_colors.dart';
import '../theme/sc_theme.dart';
import '../theme/sc_tokens.dart';
import 'pressable.dart';

/// Acción rápida dentro de una tarjeta ("+250 ml", "Pesarme").
///
/// Tonal y del color de la categoría para que cada tarjeta tenga su propia
/// identidad sin competir con la acción principal de la pantalla. En papel:
/// contorno de tinta (o relleno de tinta si es [emphasized]).
class QuickActionButton extends StatelessWidget {
  const QuickActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tone,
    this.emphasized = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? tone;

  /// Relleno sólido del color (la acción más probable de la tarjeta).
  final bool emphasized;

  /// Ocupa todo el ancho disponible.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final Color tint = tone ?? c.accent;
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    final Color background;
    final Color foreground;
    if (c.isFlat) {
      background = emphasized ? c.text : Colors.transparent;
      foreground = emphasized ? c.bg : c.text;
    } else if (emphasized) {
      background = tint;
      foreground = tint.computeLuminance() > 0.45 ? const Color(0xFF0A0C10) : Colors.white;
    } else {
      background = tint.withValues(alpha: dark ? 0.16 : 0.12);
      foreground = dark
          ? Color.lerp(tint, Colors.white, 0.15)!
          : Color.lerp(tint, Colors.black, 0.2)!;
    }

    // Se encoge antes que cortar: "+250 ml" debe leerse entero en media tarjeta.
    final Widget text = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        label,
        maxLines: 1,
        style: const TextStyle(fontFamily: ScFonts.ui, fontSize: 13.5, fontWeight: FontWeight.w700),
      ),
    );

    final Widget button = Pressable(
      enabled: onPressed != null,
      scale: 0.95,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledForegroundColor: c.text3,
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          tapTargetSize: MaterialTapTargetSize.padded,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ScRadius.controlOf(c)),
            side: c.isFlat ? BorderSide(color: c.line2, width: 1.5) : BorderSide.none,
          ),
        ),
        child: icon == null
            ? text
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(icon, size: 17),
                  const SizedBox(width: 6),
                  Flexible(child: text),
                ],
              ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
