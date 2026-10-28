import 'package:flutter/material.dart';

import '../theme/sc_colors.dart';
import '../theme/sc_tokens.dart';

/// Presenta una hoja inferior de modal acotada y desplazable que nunca queda
/// truncada por el teclado o la barra de navegación del sistema operativo.
///
/// La forma, el color y el asa salen del tema; en Modo Papel la hoja aparece
/// sin deslizarse (un solo refresco de tinta).
Future<T?> mostrarHojaMenu<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isDismissible = true,
}) {
  final bool animate = ScMotion.enabled(context);

  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: context.sc.bg2,
    elevation: 0,
    showDragHandle: true,
    isScrollControlled: true,
    useRootNavigator: true,
    // Nunca bajo la barra de estado, aunque la hoja crezca.
    useSafeArea: true,
    isDismissible: isDismissible,
    sheetAnimationStyle: animate
        ? const AnimationStyle(
            duration: Duration(milliseconds: 340),
            reverseDuration: Duration(milliseconds: 220),
          )
        : AnimationStyle.noAnimation,
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.90),
    builder: (BuildContext sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: builder(sheetContext),
      ),
    ),
  );
}
