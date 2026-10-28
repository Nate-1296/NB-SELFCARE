import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/utils/number_formats.dart';
import '../../../../shared/widgets/app_icons.dart';

/// Hoja de selección de vaso personalizado de hidratación (ml).
class CustomWaterSheet extends StatefulWidget {
  const CustomWaterSheet({super.key});

  @override
  State<CustomWaterSheet> createState() => _CustomWaterSheetState();
}

class _CustomWaterSheetState extends State<CustomWaterSheet> {
  final TextEditingController _mlCtrl = TextEditingController(text: '350');

  List<({int ml, String label})> _presets(AppLocalizations l10n) => <({int ml, String label})>[
    (ml: 150, label: l10n.foodTazaPequena),
    (ml: 200, label: l10n.foodVasoCorto),
    (ml: 330, label: l10n.foodBotellin),
    (ml: 600, label: l10n.foodTermo),
    (ml: 750, label: l10n.foodCaramanola),
    (ml: 1000, label: l10n.foodBotella1L),
  ];

  @override
  void dispose() {
    _mlCtrl.dispose();
    super.dispose();
  }

  void _selectPreset(int ml) {
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _mlCtrl.text = ml.toString();
    });
  }

  void _submit() {
    final int? parsed = int.tryParse(_mlCtrl.text.trim());
    if (parsed != null && parsed >= 10 && parsed <= 5000) {
      Navigator.of(context).pop(parsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final int currentMl = int.tryParse(_mlCtrl.text.trim()) ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(AppIcons.gota, color: c.isFlat ? c.text : c.water, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.foodVasoOBotellaAMedida,
                  softWrap: true,
                  style: TextStyle(
                    fontFamily: ScFonts.display,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
              ),
              IconButton(
                tooltip: context.l10n.commonClose,
                icon: Icon(AppIcons.close, color: c.text2),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Cuadrícula 2×3 de medidas frecuentes
          for (int row = 0; row < 3; row++) ...<Widget>[
            Row(
              children: <Widget>[
                for (int col = 0; col < 2; col++) ...<Widget>[
                  if (col > 0) const SizedBox(width: 10),
                  Expanded(
                    child: Builder(
                      builder: (BuildContext context) {
                        final ({int ml, String label}) item = _presets(context.l10n)[row * 2 + col];
                        final bool selected = currentMl == item.ml;
                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _selectPreset(item.ml),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                            decoration: BoxDecoration(
                              color: selected
                                  ? (c.isFlat ? c.bg3 : c.water.withValues(alpha: 0.16))
                                  : c.bg3,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected
                                    ? (c.isFlat ? c.text : c.water)
                                    : (c.isFlat ? c.line2 : c.line),
                                width: selected ? 1.8 : 1.0,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  context.l10n.foodMl(NumberFormats.group(item.ml)),
                                  style: TextStyle(
                                    fontFamily: ScFonts.display,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: c.text,
                                  ),
                                ),
                                Text(
                                  item.label,
                                  softWrap: true,
                                  style: TextStyle(
                                    fontFamily: ScFonts.ui,
                                    fontSize: 11.5,
                                    color: c.text2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
          ],

          const SizedBox(height: 6),
          TextField(
            controller: _mlCtrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
            style: TextStyle(
              fontFamily: ScFonts.display,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
            decoration: InputDecoration(
              labelText: context.l10n.foodVolumenExactoEnMililitros,
              suffixText: 'ml',
              filled: true,
              fillColor: c.bg3,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),

          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: (currentMl >= 10 && currentMl <= 5000) ? _submit : null,
              style: FilledButton.styleFrom(
                backgroundColor: c.isFlat ? c.accent : c.water,
                foregroundColor: c.isFlat ? c.ink : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(AppIcons.gota),
              label: Text(
                currentMl > 0
                    ? context.l10n.foodRegistrarMl(NumberFormats.group(currentMl))
                    : context.l10n.foodIntroduceUnVolumenValido,
                style: const TextStyle(
                  fontFamily: ScFonts.display,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
