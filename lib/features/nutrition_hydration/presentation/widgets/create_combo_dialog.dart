import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/utils/number_formats.dart';

/// Diálogo limpio y sin fugas de memoria para nombrar un nuevo combo casero.
class CreateComboDialog extends StatefulWidget {
  const CreateComboDialog({
    super.key,
    required this.suggestedName,
    required this.itemCount,
  });

  final String suggestedName;
  final int itemCount;

  @override
  State<CreateComboDialog> createState() => _CreateComboDialogState();
}

class _CreateComboDialogState extends State<CreateComboDialog> {
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.suggestedName);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return AlertDialog(
      backgroundColor: c.bg2,
      title: Text(context.l10n.foodGuardarComoCombo),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.l10n.foodSeGuardaranLosAlimentosActuales(NumberFormats.group(widget.itemCount)),
            softWrap: true,
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 13,
              color: c.text2,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: context.l10n.foodNombreDelCombo,
              hintText: context.l10n.foodEjDesayunoProteicoHabitual,
              filled: true,
              fillColor: c.bg3,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onSubmitted: (String val) {
              if (val.trim().isNotEmpty) {
                Navigator.of(context).pop(val.trim());
              }
            },
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () {
            final String name = _nameCtrl.text.trim();
            if (name.isNotEmpty) {
              Navigator.of(context).pop(name);
            }
          },
          child: Text(context.l10n.comerGuardarCombo),
        ),
      ],
    );
  }
}
