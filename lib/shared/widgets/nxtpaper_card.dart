import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';

/// Tarjeta adaptativa que en Modo Papel (NXTPAPER E-Ink) aplica elevación 0,
/// bordes sólidos de 1.5 px y suprime sombras difusas para evitar ghosting.
class NxtpaperCard extends ConsumerWidget {
  const NxtpaperCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(16.0),
    this.onTap,
    this.color,
    this.borderWidth = 1.5,
    this.borderRadius = 16.0,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final double borderWidth;
  final double borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final String engine = ref.watch(themeEngineProvider);
    final bool isEink = engine == 'nxtpaper_eink';

    final Color effectiveBorderColor = isEink
        ? theme.colorScheme.outline
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.5);

    final ShapeBorder shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      side: BorderSide(
        color: effectiveBorderColor,
        width: isEink ? borderWidth : 1.0,
      ),
    );

    return Card(
      elevation: isEink ? 0.0 : null,
      shadowColor: isEink ? Colors.transparent : null,
      shape: shape,
      color: color ?? theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
