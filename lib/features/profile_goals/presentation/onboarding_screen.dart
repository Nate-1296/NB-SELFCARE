import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app.dart';
import '../../../core/clock/clock.dart';
import '../../../core/domain/enums.dart';
import '../../../core/l10n/l10n.dart';
import '../../../shared/theme/sc_colors.dart';
import '../../../shared/theme/sc_theme.dart';
import '../../../shared/theme/sc_tokens.dart';
import '../../../shared/theme/theme_controller.dart';
import '../../../shared/utils/date_formats.dart';
import '../../../shared/utils/diet_phase_policy.dart';
import '../../../shared/widgets/card_header.dart';
import '../../../shared/widgets/health_card.dart';
import '../application/onboarding_service.dart';

/// Bienvenida en cuatro pasos cortos: pantalla, sobre ti, metas y seguridad.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const int _stepCount = 4;

  final GlobalKey<FormState> _aboutFormKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _heightController = TextEditingController(text: '175');
  final TextEditingController _currentWeightController = TextEditingController(text: '75.0');
  final TextEditingController _targetWeightController = TextEditingController(text: '70.0');

  int _step = 0;
  late DateTime _birthDate;
  BiologicalSex _biologicalSex = BiologicalSex.male;

  /// Ritmo semanal en kg (siempre positivo); el sentido lo marca la meta.
  double _weeklyPaceKg = 0.5;
  int _dailyWaterGoalMl = 2500;
  int _dailyStepsGoal = 8000;
  double _dailySleepGoalHours = 7.5;
  bool _hasImpedanceContraindication = false;
  bool _hasEatingDisorderHistory = false;
  bool _takesHypoglycemicMedication = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _birthDate = ref.read(clockProvider).now().subtract(const Duration(days: 365 * 25));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currentWeightController.dispose();
    _heightController.dispose();
    _targetWeightController.dispose();
    super.dispose();
  }

  static double? _parse(String raw) => double.tryParse(raw.trim().replaceAll(',', '.'));

  double get _currentWeight => (_parse(_currentWeightController.text) ?? 75.0).clamp(30.0, 300.0);
  double get _targetWeight => (_parse(_targetWeightController.text) ?? 70.0).clamp(30.0, 300.0);

  /// Negativo para perder, positivo para ganar, 0 si la meta ya es el peso actual.
  double get _weeklyGoalRateKg {
    final double diff = _targetWeight - _currentWeight;
    if (diff.abs() < 0.5) return 0;
    return diff.isNegative ? -_weeklyPaceKg : _weeklyPaceKg.clamp(0.25, 0.5);
  }

  OnboardingAnswers _answers() {
    return OnboardingAnswers(
      name: _nameController.text,
      birthDate: _birthDate,
      sex: _biologicalSex,
      heightCm: (_parse(_heightController.text) ?? 175.0).clamp(100.0, 250.0),
      currentWeightKg: _currentWeight,
      targetWeightKg: _targetWeight,
      weeklyGoalRateKg: _weeklyGoalRateKg,
      dailyWaterGoalMl: _dailyWaterGoalMl,
      dailyStepsGoal: _dailyStepsGoal,
      dailySleepGoalHours: _dailySleepGoalHours,
      themeKey: ref.read(themeControllerProvider),
      hasImpedanceContraindication: _hasImpedanceContraindication,
      hasEatingDisorderHistory: _hasEatingDisorderHistory,
      takesHypoglycemicMedication: _takesHypoglycemicMedication,
    );
  }

  Future<void> _pickBirthDate() async {
    final DateTime now = ref.read(clockProvider).now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _birthDate,
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year - 14, now.month, now.day),
      helpText: context.l10n.onbBirthDatePicker,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  void _next() {
    if (_step == 1 && !(_aboutFormKey.currentState?.validate() ?? false)) return;
    unawaited(HapticFeedback.selectionClick());
    if (_step < _stepCount - 1) {
      setState(() => _step++);
    } else {
      unawaited(_submit());
    }
  }

  Future<void> _submit() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(onboardingServiceProvider).complete(_answers());
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.onbSaveError(e.toString()))));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final bool last = _step == _stepCount - 1;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(ScSpace.gutter, ScSpace.m, ScSpace.gutter, 0),
              child: Row(
                children: <Widget>[
                  if (_step > 0)
                    IconButton(
                      tooltip: l10n.onbBack,
                      onPressed: () => setState(() => _step--),
                      icon: Icon(Icons.arrow_back_rounded, color: c.text),
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: Semantics(
                      label: l10n.onbStepOf(_step + 1, _stepCount),
                      child: Row(
                        children: <Widget>[
                          for (int i = 0; i < _stepCount; i++) ...<Widget>[
                            if (i > 0) const SizedBox(width: ScSpace.xs),
                            Expanded(
                              child: Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  color: i <= _step ? (c.isFlat ? c.text : c.accent) : c.bg3,
                                  borderRadius: BorderRadius.circular(ScRadius.pill),
                                  border: c.isFlat ? Border.all(color: c.line2) : null,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                key: ValueKey<int>(_step),
                padding: const EdgeInsets.fromLTRB(ScSpace.gutter, ScSpace.l, ScSpace.gutter, ScSpace.l),
                children: <Widget>[
                  switch (_step) {
                    0 => const _WelcomeStep(),
                    1 => _aboutStep(l10n),
                    2 => _goalsStep(l10n),
                    _ => _safetyStep(l10n),
                  },
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(ScSpace.gutter, 0, ScSpace.gutter, ScSpace.l),
              child: FilledButton(
                onPressed: _isSaving ? null : _next,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(
                        last ? l10n.onbStart : l10n.onbNext,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _aboutStep(AppLocalizations l10n) {
    final double age = ref.read(clockProvider).now().difference(_birthDate).inDays / 365.25;
    return Form(
      key: _aboutFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l10n.onbAboutTitle, style: context.text.headlineSmall),
          const SizedBox(height: ScSpace.xs),
          Text(l10n.onbAboutBody, style: context.text.bodySmall),
          const SizedBox(height: ScSpace.xl),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(labelText: l10n.onbName, prefixIcon: const Icon(Icons.badge_outlined)),
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            validator: (String? v) {
              if (v == null || v.trim().isEmpty) return l10n.onbNameRequired;
              if (v.trim().length > 60) return l10n.onbNameTooLong;
              return null;
            },
          ),
          const SizedBox(height: ScSpace.l),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.cake_outlined),
            title: Text(l10n.onbBirthDate),
            subtitle: Text(
              l10n.onbBirthDateValue(DateFormats.shortDate(_birthDate, l10n.localeName), age.floor()),
            ),
            trailing: OutlinedButton(onPressed: _pickBirthDate, child: Text(l10n.commonEdit)),
          ),
          const SizedBox(height: ScSpace.s),
          Text(l10n.onbSex, style: context.text.labelLarge),
          const SizedBox(height: ScSpace.xs),
          Text(l10n.onbSexWhy, style: context.text.bodySmall),
          const SizedBox(height: ScSpace.s),
          SegmentedButton<BiologicalSex>(
            segments: <ButtonSegment<BiologicalSex>>[
              ButtonSegment<BiologicalSex>(
                value: BiologicalSex.male,
                icon: const Icon(Icons.male_rounded),
                label: Text(l10n.onbMale),
              ),
              ButtonSegment<BiologicalSex>(
                value: BiologicalSex.female,
                icon: const Icon(Icons.female_rounded),
                label: Text(l10n.onbFemale),
              ),
            ],
            selected: <BiologicalSex>{_biologicalSex},
            onSelectionChanged: (Set<BiologicalSex> s) => setState(() => _biologicalSex = s.first),
          ),
          const SizedBox(height: ScSpace.l),
          _NumberField(
            controller: _heightController,
            label: l10n.onbHeight,
            suffix: 'cm',
            icon: Icons.height_rounded,
            min: 100,
            max: 250,
            error: l10n.onbHeightError,
          ),
          const SizedBox(height: ScSpace.l),
          _NumberField(
            controller: _currentWeightController,
            label: l10n.onbCurrentWeight,
            suffix: 'kg',
            icon: Icons.monitor_weight_outlined,
            min: 30,
            max: 300,
            error: l10n.onbWeightError,
          ),
          const SizedBox(height: ScSpace.l),
          _NumberField(
            controller: _targetWeightController,
            label: l10n.onbTargetWeight,
            suffix: 'kg',
            icon: Icons.flag_outlined,
            min: 30,
            max: 300,
            error: l10n.onbWeightError,
          ),
        ],
      ),
    );
  }

  Widget _goalsStep(AppLocalizations l10n) {
    final ScColors c = context.sc;
    final double rate = _weeklyGoalRateKg;
    final int tdee = ref.read(onboardingServiceProvider).initialTdee(_answers());
    final int dailyKcal = (tdee +
            DietPhasePolicy.dailyAdjustmentKcal(
              phase: DietPhase.deficit,
              weeklyGoalRateKg: rate,
              phaseStartedAt: null,
              now: ref.read(clockProvider).now(),
              hasEatingDisorderHistory: _hasEatingDisorderHistory,
            ))
        .clamp(1200, 4500);
    final String paceLabel = rate == 0
        ? l10n.onbPaceMaintain
        : (rate < 0 ? l10n.onbPaceLose(rate.abs().toStringAsFixed(2)) : l10n.onbPaceGain(rate.toStringAsFixed(2)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(l10n.onbGoalsTitle, style: context.text.headlineSmall),
        const SizedBox(height: ScSpace.xs),
        Text(l10n.onbGoalsBody, style: context.text.bodySmall),
        const SizedBox(height: ScSpace.xl),
        _SliderRow(
          label: paceLabel,
          value: _weeklyPaceKg,
          min: 0.25,
          max: 1.0,
          divisions: 3,
          enabled: rate != 0,
          onChanged: (double v) => setState(() => _weeklyPaceKg = v),
        ),
        _SliderRow(
          label: l10n.onbWater(_dailyWaterGoalMl, (_dailyWaterGoalMl / 250).round()),
          value: _dailyWaterGoalMl.toDouble(),
          min: 1500,
          max: 4000,
          divisions: 10,
          onChanged: (double v) => setState(() => _dailyWaterGoalMl = v.round()),
        ),
        _SliderRow(
          label: l10n.onbSteps(_dailyStepsGoal),
          value: _dailyStepsGoal.toDouble(),
          min: 4000,
          max: 16000,
          divisions: 12,
          onChanged: (double v) => setState(() => _dailyStepsGoal = v.round()),
        ),
        _SliderRow(
          label: l10n.onbSleep(_dailySleepGoalHours.toStringAsFixed(1)),
          value: _dailySleepGoalHours,
          min: 6,
          max: 9.5,
          divisions: 7,
          onChanged: (double v) => setState(() => _dailySleepGoalHours = v),
        ),
        const SizedBox(height: ScSpace.m),
        HealthCard(
          margin: EdgeInsets.zero,
          backgroundColor: c.bg3,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(l10n.onbEstimateTitle, style: context.text.titleSmall),
                    const SizedBox(height: ScSpace.xxs),
                    Text(l10n.onbEstimateBody(tdee), style: context.text.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: ScSpace.m),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    '$dailyKcal',
                    style: TextStyle(
                      fontFamily: ScFonts.display,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: c.isFlat ? c.text : c.accent,
                    ),
                  ),
                  Text(l10n.onbKcalPerDay, style: context.text.bodySmall),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _safetyStep(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(l10n.onbSafetyTitle, style: context.text.headlineSmall),
        const SizedBox(height: ScSpace.xs),
        Text(l10n.onbSafetyBody, style: context.text.bodySmall),
        const SizedBox(height: ScSpace.l),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _hasImpedanceContraindication,
          onChanged: (bool v) => setState(() => _hasImpedanceContraindication = v),
          title: Text(l10n.onbImplants),
          subtitle: Text(l10n.onbImplantsHint),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _hasEatingDisorderHistory,
          onChanged: (bool v) => setState(() => _hasEatingDisorderHistory = v),
          title: Text(l10n.onbEatingDisorder),
          subtitle: Text(l10n.onbEatingDisorderHint),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _takesHypoglycemicMedication,
          onChanged: (bool v) => setState(() => _takesHypoglycemicMedication = v),
          title: Text(l10n.onbGlucose),
          subtitle: Text(l10n.onbGlucoseHint),
        ),
      ],
    );
  }
}

class _WelcomeStep extends ConsumerWidget {
  const _WelcomeStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String engine = ref.watch(themeEngineProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: ScSpace.l),
        Center(child: Image.asset('assets/images/logo.png', width: 96, height: 96, fit: BoxFit.contain)),
        const SizedBox(height: ScSpace.l),
        Text(l10n.onbWelcomeTitle, textAlign: TextAlign.center, style: context.text.headlineSmall),
        const SizedBox(height: ScSpace.s),
        Text(l10n.onbWelcomeBody, textAlign: TextAlign.center, style: context.text.bodyMedium),
        const SizedBox(height: ScSpace.xl),
        HealthCard(
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              CardHeader(
                icon: Icons.display_settings_outlined,
                title: l10n.onbScreenTitle,
                subtitle: l10n.onbScreenBody,
              ),
              const SizedBox(height: ScSpace.m),
              SegmentedButton<String>(
                segments: <ButtonSegment<String>>[
                  ButtonSegment<String>(
                    value: 'material_you',
                    icon: const Icon(Icons.palette_outlined),
                    label: Text(l10n.onbScreenColor),
                  ),
                  ButtonSegment<String>(
                    value: 'nxtpaper_eink',
                    icon: const Icon(Icons.menu_book_outlined),
                    label: Text(l10n.onbScreenPaper),
                  ),
                ],
                selected: <String>{engine},
                onSelectionChanged: (Set<String> s) {
                  if (s.first != engine) ref.read(themeEngineProvider.notifier).toggle();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.suffix,
    required this.icon,
    required this.min,
    required this.max,
    required this.error,
  });

  final TextEditingController controller;
  final String label;
  final String suffix;
  final IconData icon;
  final double min;
  final double max;
  final String error;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), suffixText: suffix),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      validator: (String? v) {
        final double? val = double.tryParse((v ?? '').trim().replaceAll(',', '.'));
        return val == null || val < min || val > max ? error : null;
      },
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: context.text.bodyMedium),
        Slider(value: value.clamp(min, max), min: min, max: max, divisions: divisions, onChanged: enabled ? onChanged : null),
        const SizedBox(height: ScSpace.xs),
      ],
    );
  }
}
