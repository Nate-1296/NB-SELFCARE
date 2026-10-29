import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';

/// Confirmación breve de una acción con "Deshacer" (docs/01 §4: todo registro es reversible).
void showUndoSnackBar(BuildContext context, {required String message, VoidCallback? onUndo}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
        // Con acción, Flutter lo dejaría fijo hasta deslizarlo: se va solo.
        persist: false,
        action: onUndo == null
            ? null
            : SnackBarAction(label: context.l10n.commonUndo, onPressed: onUndo),
      ),
    );
}
