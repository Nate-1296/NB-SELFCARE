import 'package:flutter/material.dart';

import '../theme/sc_colors.dart';

/// Presenta una hoja inferior de modal acotada y desplazable que nunca queda
/// truncada por el teclado o la barra de navegación del sistema operativo.
Future<T?> mostrarHojaMenu<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isDismissible = true,
}) {
  final ScColors c = context.sc;

  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: c.bg2,
    elevation: 0,
    showDragHandle: true,
    isScrollControlled: true,
    useRootNavigator: true,
    isDismissible: isDismissible,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      side: BorderSide(
        color: c.isFlat ? c.line2 : c.line,
        width: c.isFlat ? 1.5 : 1.0,
      ),
    ),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.90,
    ),
    builder: (BuildContext sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: builder(sheetContext),
      ),
    ),
  );
}
