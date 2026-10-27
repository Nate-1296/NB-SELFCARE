import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/sheet.dart';

/// Hoja de configuración opcional de dirección MAC Bluetooth para Mi Scale 2.
class ScaleMacConfigSheet extends StatefulWidget {
  const ScaleMacConfigSheet({
    super.key,
    required this.currentMac,
  });

  final String? currentMac;

  static Future<String?> show({
    required BuildContext context,
    required String? currentMac,
  }) {
    return mostrarHojaMenu<String>(
      context,
      builder: (_) => ScaleMacConfigSheet(currentMac: currentMac),
    );
  }

  @override
  State<ScaleMacConfigSheet> createState() => _ScaleMacConfigSheetState();
}

class _ScaleMacConfigSheetState extends State<ScaleMacConfigSheet> {
  late final TextEditingController _macCtrl;

  @override
  void initState() {
    super.initState();
    _macCtrl = TextEditingController(text: widget.currentMac ?? '');
  }

  @override
  void dispose() {
    _macCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final bool hasExisting =
        widget.currentMac != null && widget.currentMac!.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: c.soft,
                  borderRadius: BorderRadius.circular(14),
                  border: c.isFlat
                      ? Border.all(color: c.line2, width: 1.5)
                      : null,
                ),
                child: Icon(AppIcons.bluetooth, color: c.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.bodyVinculoXiaomiMiScale2,
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 18.5,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                      ),
                    ),
                    Text(
                      context.l10n.bodyLecturaPasivaBle0x181b100,
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 12.5,
                        color: c.text2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            context.l10n.bodySiDejasElCampoVacio,
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 12.5,
              height: 1.4,
              color: c.text2,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _macCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: context.l10n.bodyDireccionMacOpcional,
              hintText: context.l10n.bodyEjA4C13812,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              if (hasExisting) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(''),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(context.l10n.bodyModoAutomatico),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pop(_macCtrl.text.trim()),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(context.l10n.bodyGuardarAjuste),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
