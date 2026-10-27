import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/utils/biometric_formulas.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/sheet.dart';
import 'preview_mini_stat.dart';

/// Hoja modal guiada para pesaje manual con vista previa fisiológica en tiempo real.
class ManualWeighInSheet extends StatefulWidget {
  const ManualWeighInSheet({
    super.key,
    required this.initialWeightKg,
    required this.profile,
    this.latestMeasurement,
  });

  final double initialWeightKg;
  final UserProfile profile;
  final BodyMeasurement? latestMeasurement;

  static Future<({double weightKg, int? impedanceOhms})?> show({
    required BuildContext context,
    required double initialWeightKg,
    required UserProfile profile,
    BodyMeasurement? latestMeasurement,
  }) {
    return mostrarHojaMenu<({double weightKg, int? impedanceOhms})>(
      context,
      builder: (_) => ManualWeighInSheet(
        initialWeightKg: initialWeightKg,
        profile: profile,
        latestMeasurement: latestMeasurement,
      ),
    );
  }

  @override
  State<ManualWeighInSheet> createState() => _ManualWeighInSheetState();
}

class _ManualWeighInSheetState extends State<ManualWeighInSheet> {
  late final TextEditingController _weightCtrl;
  late final TextEditingController _impedanceCtrl;

  @override
  void initState() {
    super.initState();
    _weightCtrl = TextEditingController(
      text: widget.initialWeightKg.toStringAsFixed(1),
    )..addListener(_onChanged);
    _impedanceCtrl = TextEditingController()..addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _weightCtrl
      ..removeListener(_onChanged)
      ..dispose();
    _impedanceCtrl
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  double? get _parsedWeight {
    final double? val = double.tryParse(
      _weightCtrl.text.trim().replaceAll(',', '.'),
    );
    if (val == null || val <= 1.0 || val > 350.0) return null;
    return val;
  }

  int? get _parsedImpedance {
    final String raw = _impedanceCtrl.text.trim();
    if (raw.isEmpty) return null;
    final int? val = int.tryParse(raw);
    if (val == null || val < 100 || val > 3000) return null;
    return val;
  }

  void _stepWeight(double delta) {
    unawaited(HapticFeedback.selectionClick());
    final double base = _parsedWeight ?? widget.initialWeightKg;
    final double next = (base + delta).clamp(20.0, 300.0);
    _weightCtrl.text = next.toStringAsFixed(1);
    _weightCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _weightCtrl.text.length),
    );
  }

  void _submit() {
    final double? w = _parsedWeight;
    if (w == null) return;
    unawaited(HapticFeedback.mediumImpact());
    Navigator.of(context).pop((weightKg: w, impedanceOhms: _parsedImpedance));
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final double? weight = _parsedWeight;
    final double? liveBmi = weight != null
        ? BiometricFormulas.calculateBmi(
            weightKg: weight,
            heightCm: widget.profile.heightCm,
          )
        : null;
    final double? liveEma = weight != null
        ? BiometricFormulas.calculateWeightEma(
            currentWeightKg: weight,
            previousEmaKg: widget.latestMeasurement?.trendWeightKg,
          )
        : null;
    final double? deltaPrev =
        (weight != null && widget.latestMeasurement != null)
            ? weight - widget.latestMeasurement!.weightKg
            : null;

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
                child: Icon(AppIcons.bascula, color: c.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.bodyPesajeManual,
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                      ),
                    ),
                    Text(
                      context.l10n.bodyActualizaTus13MetricasY,
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
          const SizedBox(height: 18),

          // Controles rápidos de incremento/decremento táctil
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _StepChip(label: context.l10n.body05Kg, onTap: () => _stepWeight(-0.5)),
              _StepChip(label: context.l10n.body01Kg, onTap: () => _stepWeight(-0.1)),
              _StepChip(label: context.l10n.body01Kg2, onTap: () => _stepWeight(0.1)),
              _StepChip(label: context.l10n.body05Kg2, onTap: () => _stepWeight(0.5)),
            ],
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _weightCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
              fontFamily: ScFonts.display,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: c.text,
            ),
            decoration: InputDecoration(
              labelText: context.l10n.bodyPesoEnKilogramos,
              suffixText: 'kg',
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _impedanceCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.l10n.bodyImpedanciaBiaOpcional1003000,
              hintText: context.l10n.bodyVacioSiTuBasculaSolo,
              suffixText: 'Ω',
            ),
          ),

          if (weight != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.bg3,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: c.isFlat ? c.line2 : c.line,
                  width: c.isFlat ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: PreviewMiniStat(
                      label: context.l10n.bodyTendenciaEma,
                      value: context.l10n.bodyKg(liveEma!.toStringAsFixed(1).toString()),
                    ),
                  ),
                  Expanded(
                    child: PreviewMiniStat(
                      label: context.l10n.bodyImcCalculado,
                      value: liveBmi!.toStringAsFixed(1),
                    ),
                  ),
                  Expanded(
                    child: PreviewMiniStat(
                      label: context.l10n.bodyVsAnterior,
                      value: deltaPrev == null
                          ? context.l10n.bodyPrimerDato: '${deltaPrev >= 0 ? '+' : ''}${deltaPrev.toStringAsFixed(1)} kg',
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: weight != null ? _submit : null,
            icon: const Icon(AppIcons.check, size: 18),
            label: Text(context.l10n.commonSave),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
            ),
            child: Text(context.l10n.commonCancel),
          ),
        ],
      ),
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: c.bg3,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: c.isFlat ? c.line2 : c.line,
            width: c.isFlat ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: ScFonts.display,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: c.text,
          ),
        ),
      ),
    );
  }
}

