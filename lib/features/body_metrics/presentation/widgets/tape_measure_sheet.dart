import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/utils/biometric_formulas.dart';
import '../../../../shared/utils/number_formats.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/sheet.dart';
import 'preview_mini_stat.dart';

/// Hoja modal guiada para validación antropométrica quincenal (Fórmula US Navy).
class NavyTapeMeasureSheet extends StatefulWidget {
  const NavyTapeMeasureSheet({super.key, required this.profile, this.latestMeasurement});

  final UserProfile profile;
  final BodyMeasurement? latestMeasurement;

  static Future<({double waistCm, double neckCm, double? hipCm})?> show({
    required BuildContext context,
    required UserProfile profile,
    BodyMeasurement? latestMeasurement,
  }) {
    return mostrarHojaMenu<({double waistCm, double neckCm, double? hipCm})>(
      context,
      builder: (_) => NavyTapeMeasureSheet(profile: profile, latestMeasurement: latestMeasurement),
    );
  }

  @override
  State<NavyTapeMeasureSheet> createState() => _NavyTapeMeasureSheetState();
}

class _NavyTapeMeasureSheetState extends State<NavyTapeMeasureSheet> {
  late final TextEditingController _waistCtrl;
  late final TextEditingController _neckCtrl;
  late final TextEditingController _hipCtrl;

  bool get _isFemale => widget.profile.biologicalSex == BiologicalSex.female;

  @override
  void initState() {
    super.initState();
    _waistCtrl = TextEditingController(
      text: NumberFormats.input((widget.latestMeasurement?.waistCm ?? 80.0), maxDigits: 1),
    )..addListener(_refresh);
    _neckCtrl = TextEditingController(
      text: NumberFormats.input((widget.latestMeasurement?.neckCm ?? 38.0), maxDigits: 1),
    )..addListener(_refresh);
    _hipCtrl = TextEditingController(
      text: NumberFormats.input((widget.latestMeasurement?.hipCm ?? 95.0), maxDigits: 1),
    )..addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _waistCtrl
      ..removeListener(_refresh)
      ..dispose();
    _neckCtrl
      ..removeListener(_refresh)
      ..dispose();
    _hipCtrl
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  double? _parsePositive(TextEditingController ctrl) {
    final double? v = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
    if (v == null || v <= 10.0 || v > 250.0) return null;
    return v;
  }

  void _submit() {
    final double? waist = _parsePositive(_waistCtrl);
    final double? neck = _parsePositive(_neckCtrl);
    final double? hip = _isFemale ? _parsePositive(_hipCtrl) : null;
    if (waist == null || neck == null) return;
    if (_isFemale && hip == null) return;

    unawaited(HapticFeedback.mediumImpact());
    Navigator.of(context).pop((waistCm: waist, neckCm: neck, hipCm: hip));
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final double? waist = _parsePositive(_waistCtrl);
    final double? neck = _parsePositive(_neckCtrl);
    final double? hip = _isFemale ? _parsePositive(_hipCtrl) : null;
    final bool validInputs = waist != null && neck != null && (!_isFemale || hip != null);

    double? navyFat;
    double? validatedFat;
    double? waistToHeight;
    if (validInputs) {
      navyFat = BiometricFormulas.calculateNavyBodyFatPercentage(
        heightCm: widget.profile.heightCm,
        waistCm: waist,
        neckCm: neck,
        isMale: !_isFemale,
        hipCm: hip,
      );
      final double biaFat = widget.latestMeasurement?.bodyFatPercentage ?? navyFat;
      validatedFat = BiometricFormulas.calculateValidatedBodyFat(
        biaBodyFatPercentage: biaFat,
        navyBodyFatPercentage: navyFat,
      );
      if (widget.profile.heightCm > 0) {
        waistToHeight = waist / widget.profile.heightCm;
      }
    }

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
                  border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
                ),
                child: Icon(AppIcons.tape, color: c.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.bodyValidacionUsNavyCinta,
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 18.5,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                    ),
                    Text(
                      context.l10n.bodyControlQuincenalSinSesgoPor,
                      style: TextStyle(fontFamily: ScFonts.ui, fontSize: 12.5, color: c.text2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.bg3,
              borderRadius: BorderRadius.circular(14),
              border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
            ),
            child: Text(
              _isFemale
                  ? context.l10n.bodyMideEnAyunasSinComprimir
                  : context.l10n.bodyMideEnAyunasSinComprimir2,
              style: TextStyle(fontFamily: ScFonts.ui, fontSize: 12, height: 1.35, color: c.text2),
            ),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _waistCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: context.l10n.bodyCircunferenciaDeCintura,
              suffixText: 'cm',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _neckCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: context.l10n.bodyCircunferenciaDeCuello,
              suffixText: 'cm',
            ),
          ),
          if (_isFemale) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _hipCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: context.l10n.bodyCircunferenciaDeCadera,
                suffixText: 'cm',
              ),
            ),
          ],

          if (navyFat != null && validatedFat != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.bg3,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.accent, width: c.isFlat ? 1.5 : 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: PreviewMiniStat(
                          label: context.l10n.bodyUsNavyCinta,
                          value: '${NumberFormats.fixed(navyFat, 1)}%',
                        ),
                      ),
                      Expanded(
                        child: PreviewMiniStat(
                          label: context.l10n.bodyGrasaValidada6040,
                          value: '${NumberFormats.fixed(validatedFat, 1)}%',
                          highlight: true,
                        ),
                      ),
                    ],
                  ),
                  if (waistToHeight != null) ...[
                    const SizedBox(height: 8),
                    Divider(height: 1, color: c.line),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.bodyIndiceCinturaEstatura(
                        NumberFormats.fixed(waistToHeight, 2),
                        (waistToHeight < 0.50
                                ? 'Rango metabólico saludable < 0.50'
                                : 'Objetivo saludable < 0.50')
                            .toString(),
                      ),
                      style: TextStyle(fontFamily: ScFonts.ui, fontSize: 12, color: c.text2),
                    ),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: validInputs ? _submit : null,
            icon: const Icon(AppIcons.check, size: 18),
            label: Text(context.l10n.bodyGuardarValidacion),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
            child: Text(context.l10n.commonCancel),
          ),
        ],
      ),
    );
  }
}
