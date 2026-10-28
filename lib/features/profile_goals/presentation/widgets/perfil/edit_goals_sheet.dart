import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/domain/enums.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_theme.dart';
import '../../../../../shared/utils/number_formats.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../nutrition_hydration/presentation/widgets/diet_archetype_sheets.dart';
import '../../../application/profile_service.dart';

/// Hoja modal rediseñada para ajustar metas personales sin desbordes.
class EditGoalsSheet extends ConsumerStatefulWidget {
  const EditGoalsSheet({super.key, required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<EditGoalsSheet> createState() => _EditGoalsSheetState();
}

class _EditGoalsSheetState extends ConsumerState<EditGoalsSheet> {
  late final TextEditingController _weightCtrl;
  late final TextEditingController _waterCtrl;
  late final TextEditingController _stepsCtrl;
  late final TextEditingController _sleepCtrl;
  late final TextEditingController _manualKcalCtrl;
  late final TextEditingController _manualProteinCtrl;
  late final TextEditingController _manualCarbsCtrl;
  late final TextEditingController _manualFatCtrl;

  late double _weeklyRateKg;
  late bool _isManualMode;
  late DietPhase _activeDietPhase;

  @override
  void initState() {
    super.initState();
    _weightCtrl = TextEditingController(text: NumberFormats.input(widget.profile.targetWeightKg, maxDigits: 1));
    _waterCtrl = TextEditingController(text: widget.profile.dailyWaterGoalMl.toString());
    _stepsCtrl = TextEditingController(text: widget.profile.dailyStepsGoal.toString());
    _sleepCtrl = TextEditingController(text: NumberFormats.input(widget.profile.dailySleepGoalHours, maxDigits: 1));
    _manualKcalCtrl = TextEditingController(
      text: (widget.profile.manualKcalTarget ?? 2000).toString(),
    );
    _manualProteinCtrl = TextEditingController(
      text: (widget.profile.manualProteinG ?? 150).toString(),
    );
    _manualCarbsCtrl = TextEditingController(text: (widget.profile.manualCarbsG ?? 200).toString());
    _manualFatCtrl = TextEditingController(text: (widget.profile.manualFatG ?? 60).toString());

    _weeklyRateKg = widget.profile.weeklyGoalRateKg.clamp(-1.0, 0.5);
    _isManualMode = widget.profile.isManualMacroMode;
    _activeDietPhase = widget.profile.activeDietPhase;
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _waterCtrl.dispose();
    _stepsCtrl.dispose();
    _sleepCtrl.dispose();
    _manualKcalCtrl.dispose();
    _manualProteinCtrl.dispose();
    _manualCarbsCtrl.dispose();
    _manualFatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Flexible(child: Text(
                  context.l10n.perfilAjustarMetasNutricionales,
                  style: TextStyle(
                    fontFamily: ScFonts.display,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: c.text,
                  ),
                )),
                IconButton(
                  icon: Icon(AppIcons.close, color: c.text2),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Selector de Modo: Adaptativo vs Manual
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                segments: <ButtonSegment<bool>>[
                  ButtonSegment<bool>(
                    value: false,
                    label: Text(context.l10n.perfilModoAdaptativo),
                    icon: const Icon(Icons.auto_awesome_rounded),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text(context.l10n.perfilModoManual),
                    icon: const Icon(Icons.tune_rounded),
                  ),
                ],
                selected: <bool>{_isManualMode},
                onSelectionChanged: (Set<bool> sel) {
                  setState(() => _isManualMode = sel.first);
                },
              ),
            ),
            const SizedBox(height: 14),

            if (_isManualMode) ...<Widget>[
              // Sección de Macros Manuales
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.bg3,
                  borderRadius: BorderRadius.circular(14),
                  border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.l10n.perfilPrescripcionManualDeMacronutrientes,
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.perfilSobrescribeElAlgoritmoAdaptativoCon,
                      style: TextStyle(fontFamily: ScFonts.ui, fontSize: 11, color: c.text2),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: _manualKcalCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: context.l10n.foodCalorias,
                              suffixText: 'kcal',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _manualProteinCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: context.l10n.todayProteina,
                              suffixText: 'g',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: _manualCarbsCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: context.l10n.todayCarbohidratos,
                              suffixText: 'g',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _manualFatCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: context.l10n.todayGrasas,
                              suffixText: 'g',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else ...<Widget>[
              // Selector de Fase de Dieta
              Text(
                context.l10n.perfilFaseMetabolicaActiva,
                style: TextStyle(
                  fontFamily: ScFonts.ui,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<DietPhase>(
                isExpanded: true,
                initialValue: _activeDietPhase,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                items: <DropdownMenuItem<DietPhase>>[
                  DropdownMenuItem<DietPhase>(
                    value: DietPhase.deficit,
                    child: Text(context.l10n.perfilDeficitCaloricoPerdidaDeGrasa),
                  ),
                  DropdownMenuItem<DietPhase>(
                    value: DietPhase.maintenance,
                    child: Text(context.l10n.perfilMantenimientoConsolidacion),
                  ),
                  DropdownMenuItem<DietPhase>(
                    value: DietPhase.dietBreak,
                    child: Text(context.l10n.perfilDescansoDieteticoRefeedTdeeCompleto),
                  ),
                  DropdownMenuItem<DietPhase>(
                    value: DietPhase.reverseDiet,
                    child: Text(context.l10n.perfilDietaInversaRecuperacion100Kcal),
                  ),
                ],
                onChanged: (DietPhase? val) {
                  if (val != null) setState(() => _activeDietPhase = val);
                },
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  unawaited(DietArchetypePickerSheet.show(context));
                },
                icon: const Icon(Icons.restaurant_menu_rounded, size: 16),
                label: Text(context.l10n.perfilConfigurarArquetipoYCalorieCycling),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Flexible(child: Text(
                    context.l10n.perfilRitmoSemanal,
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  )),
                  Text(
                    _weeklyRateKg == 0.0
                        ? context.l10n.perfilMantenimiento
                        : context.l10n.perfilKgSem2(
                            (_weeklyRateKg > 0 ? '+' : '').toString(),
                            NumberFormats.fixed(_weeklyRateKg, 2),
                          ),
                    style: TextStyle(
                      fontFamily: ScFonts.display,
                      fontWeight: FontWeight.w700,
                      color: c.accent,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _weeklyRateKg,
                min: -1.0,
                max: 0.5,
                divisions: 6,
                label: context.l10n.perfilKgSem(NumberFormats.fixed(_weeklyRateKg, 2)),
                onChanged: (double v) => setState(() => _weeklyRateKg = v),
              ),
            ],

            const SizedBox(height: 14),

            // Metas de Estilo de Vida
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _weightCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: context.l10n.perfilPesoObjetivo,
                      suffixText: 'kg',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _waterCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.l10n.perfilAguaDiaria,
                      suffixText: 'ml',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _stepsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.l10n.perfilMetaPasos,
                      suffixText: 'pasos',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _sleepCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: context.l10n.perfilSuenoMeta,
                      suffixText: 'horas',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: () async {
                  final double targetWeight =
                      double.tryParse(_weightCtrl.text.replaceAll(',', '.')) ??
                      widget.profile.targetWeightKg;
                  final int water =
                      int.tryParse(_waterCtrl.text) ?? widget.profile.dailyWaterGoalMl;
                  final int steps = int.tryParse(_stepsCtrl.text) ?? widget.profile.dailyStepsGoal;
                  final double sleep =
                      double.tryParse(_sleepCtrl.text.replaceAll(',', '.')) ??
                      widget.profile.dailySleepGoalHours;

                  final int? manualKcal = int.tryParse(_manualKcalCtrl.text);
                  final int? manualProtein = int.tryParse(_manualProteinCtrl.text);
                  final int? manualCarbs = int.tryParse(_manualCarbsCtrl.text);
                  final int? manualFat = int.tryParse(_manualFatCtrl.text);

                  await ref
                      .read(profileServiceProvider)
                      .update(
                        UserProfilesCompanion(
                          targetWeightKg: drift.Value(targetWeight),
                          weeklyGoalRateKg: drift.Value(_weeklyRateKg),
                          dailyWaterGoalMl: drift.Value(water),
                          dailyStepsGoal: drift.Value(steps),
                          dailySleepGoalHours: drift.Value(sleep),
                          isManualMacroMode: drift.Value(_isManualMode),
                          manualKcalTarget: drift.Value(_isManualMode ? manualKcal : null),
                          manualProteinG: drift.Value(_isManualMode ? manualProtein : null),
                          manualCarbsG: drift.Value(_isManualMode ? manualCarbs : null),
                          manualFatG: drift.Value(_isManualMode ? manualFat : null),
                          activeDietPhase: drift.Value(_activeDietPhase),
                        ),
                      );

                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: Text(
                  context.l10n.perfilGuardarMetas,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.l10n.commonCancel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
