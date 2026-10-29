import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/domain/enums.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/services/smart_meal_suggester.dart';
import '../../../shared/theme/sc_colors.dart';
import '../../../shared/theme/sc_theme.dart';
import '../../../shared/theme/sc_tokens.dart';
import '../../../shared/widgets/app_icons.dart';
import '../../../shared/widgets/card_header.dart';
import '../../../shared/widgets/health_card.dart';
import '../../../shared/widgets/top_bar.dart';
import '../../../shared/widgets/undo_snackbar.dart';
import '../../care/presentation/widgets/treatment_sheets.dart';
import '../../nutrition_hydration/presentation/widgets/diet_archetype_sheets.dart';
import '../../profile_goals/application/profile_queries.dart';
import '../../profile_goals/application/supplement_service.dart';
import '../application/protocol_service.dart';
import '../domain/weekly_protocol.dart';

String dietPhaseLabel(AppLocalizations l10n, DietPhase phase) => switch (phase) {
  DietPhase.deficit => l10n.protocolPhaseDeficit,
  DietPhase.maintenance => l10n.protocolPhaseMaintenance,
  DietPhase.dietBreak => l10n.protocolPhaseBreak,
  DietPhase.reverseDiet => l10n.protocolPhaseReverse,
};

/// "Mi protocolo": plan semanal de dieta, ayuno, entrenamiento y suplementos.
class ProtocolPlannerScreen extends ConsumerStatefulWidget {
  const ProtocolPlannerScreen({super.key});

  @override
  ConsumerState<ProtocolPlannerScreen> createState() => _ProtocolPlannerScreenState();
}

class _ProtocolPlannerScreenState extends ConsumerState<ProtocolPlannerScreen> {
  /// Borrador editable; se rellena con el plan guardado la primera vez que llega.
  WeeklyProtocol? _draft;

  static const List<int> _fastingOptions = <int>[14, 16, 18, 20];

  void _toggle(Set<int> days, int day, WeeklyProtocol Function(Set<int>) apply) {
    unawaited(HapticFeedback.selectionClick());
    final Set<int> next = Set<int>.of(days);
    if (!next.remove(day)) next.add(day);
    setState(() => _draft = apply(next));
  }

  Future<void> _save(WeeklyProtocol plan, DietArchetype archetype) async {
    unawaited(HapticFeedback.lightImpact());
    final AppLocalizations l10n = context.l10n;
    await ref
        .read(protocolServiceProvider)
        .save(
          plan,
          archetype: archetype,
          planName: l10n.protocolPlanName(DietArchetypeInfo.getById(archetype).name),
        );
    if (mounted) showUndoSnackBar(context, message: l10n.protocolSaved);
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<WeeklyProtocol?> saved = ref.watch(activeProtocolProvider);
    final UserProfile? profile = ref.watch(userProfileStreamProvider).value;
    final List<SupplementsTrackerData> supplements =
        ref.watch(activeSupplementsProvider).value ?? const <SupplementsTrackerData>[];

    if (saved.isLoading && _draft == null) {
      return Scaffold(
        backgroundColor: c.bg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final WeeklyProtocol plan = _draft ?? saved.value ?? WeeklyProtocol.defaults;
    final DietArchetype archetype = profile?.activeDietArchetype ?? DietArchetype.flexible;
    final DietPhase phase = profile?.activeDietPhase ?? DietPhase.deficit;
    final List<String> initials = l10n.comerWeekdayInitials.split(',');

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: ScSpace.xxl),
          children: <Widget>[
            TopBar(
              title: l10n.protocolTitle,
              subtitle: l10n.protocolSubtitle,
              leading: BackButton(
                color: c.text,
                onPressed: () => context.canPop() ? context.pop() : context.go('/perfil'),
              ),
            ),
            _CoherenceNotice(plan: plan, phase: phase, archetype: archetype),
            HealthCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  CardHeader(
                    icon: Icons.restaurant_menu_rounded,
                    title: l10n.protocolDietTitle,
                    subtitle: l10n.protocolDietSummary(
                      DietArchetypeInfo.getById(archetype).name,
                      dietPhaseLabel(l10n, phase),
                    ),
                    trailing: TextButton(
                      onPressed: () => unawaited(DietArchetypePickerSheet.show(context)),
                      child: Text(l10n.commonEdit),
                    ),
                  ),
                ],
              ),
            ),
            HealthCard(
              padding: const EdgeInsets.symmetric(horizontal: ScSpace.s, vertical: ScSpace.l + 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  CardHeader(
                    icon: AppIcons.ayuno,
                    tone: c.fasting,
                    title: l10n.protocolFastingTitle,
                  ),
                  const SizedBox(height: ScSpace.m),
                  Text(l10n.protocolFastingDays, style: context.text.bodySmall),
                  const SizedBox(height: ScSpace.s),
                  _DayPicker(
                    initials: initials,
                    selected: plan.fastingDays,
                    tone: c.fasting,
                    onToggle: (int d) =>
                        _toggle(plan.fastingDays, d, (Set<int> s) => plan.copyWith(fastingDays: s)),
                  ),
                  const SizedBox(height: ScSpace.m),
                  Text(l10n.protocolFastingHours, style: context.text.bodySmall),
                  const SizedBox(height: ScSpace.s),
                  Wrap(
                    spacing: ScSpace.s,
                    runSpacing: ScSpace.s,
                    children: <Widget>[
                      for (final int h in _fastingOptions)
                        ChoiceChip(
                          label: Text('$h:${24 - h}'),
                          selected: plan.fastingHours == h,
                          onSelected: (_) =>
                              setState(() => _draft = plan.copyWith(fastingHours: h)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            HealthCard(
              padding: const EdgeInsets.symmetric(horizontal: ScSpace.s, vertical: ScSpace.l + 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  CardHeader(
                    icon: Icons.fitness_center_rounded,
                    tone: c.steps,
                    title: l10n.protocolWorkoutTitle,
                  ),
                  const SizedBox(height: ScSpace.m),
                  Text(l10n.protocolWorkoutDays, style: context.text.bodySmall),
                  const SizedBox(height: ScSpace.s),
                  _DayPicker(
                    initials: initials,
                    selected: plan.workoutDays,
                    tone: c.steps,
                    onToggle: (int d) =>
                        _toggle(plan.workoutDays, d, (Set<int> s) => plan.copyWith(workoutDays: s)),
                  ),
                  const SizedBox(height: ScSpace.m),
                  Text(l10n.protocolWorkoutTime, style: context.text.bodySmall),
                  const SizedBox(height: ScSpace.s),
                  SegmentedButton<WorkoutTimeOfDay>(
                    showSelectedIcon: false,
                    segments: <ButtonSegment<WorkoutTimeOfDay>>[
                      ButtonSegment<WorkoutTimeOfDay>(
                        value: WorkoutTimeOfDay.morning,
                        label: Text(l10n.protocolMorning),
                      ),
                      ButtonSegment<WorkoutTimeOfDay>(
                        value: WorkoutTimeOfDay.afternoon,
                        label: Text(l10n.protocolAfternoon),
                      ),
                      ButtonSegment<WorkoutTimeOfDay>(
                        value: WorkoutTimeOfDay.evening,
                        label: Text(l10n.protocolEvening),
                      ),
                    ],
                    selected: <WorkoutTimeOfDay>{plan.workoutTime},
                    onSelectionChanged: (Set<WorkoutTimeOfDay> sel) =>
                        setState(() => _draft = plan.copyWith(workoutTime: sel.first)),
                  ),
                ],
              ),
            ),
            HealthCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  CardHeader(
                    icon: Icons.medication_rounded,
                    title: l10n.protocolSupplementsTitle(supplements.length),
                    trailing: TextButton(
                      onPressed: () => unawaited(TreatmentsManageSheet.show(context)),
                      child: Text(l10n.commonEdit),
                    ),
                  ),
                  const SizedBox(height: ScSpace.s),
                  if (supplements.isEmpty)
                    Text(l10n.protocolSupplementsEmpty, style: context.text.bodySmall)
                  else
                    Wrap(
                      spacing: ScSpace.s,
                      runSpacing: ScSpace.xs,
                      children: <Widget>[
                        for (final SupplementsTrackerData s in supplements)
                          Chip(
                            label: Text('${s.name} · ${s.dosage}'),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(ScSpace.gutter, ScSpace.m, ScSpace.gutter, 0),
              child: FilledButton.icon(
                onPressed: () => _save(plan, archetype),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                icon: const Icon(Icons.check_circle_rounded),
                label: Text(l10n.protocolSave),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayPicker extends StatelessWidget {
  const _DayPicker({
    required this.initials,
    required this.selected,
    required this.tone,
    required this.onToggle,
  });

  final List<String> initials;
  final Set<int> selected;
  final Color tone;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final Color tint = c.isFlat ? c.text : tone;
    return Row(
      children: <Widget>[
        for (int d = 1; d <= 7; d++)
          Expanded(
            // La celda completa (≥ 48 dp) es la zona táctil; el recuadro visible va 2 dp por dentro.
            child: Semantics(
              selected: selected.contains(d),
              button: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(ScRadius.control),
                onTap: () => onToggle(d),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected.contains(d)
                          ? (c.isFlat ? c.bg3 : tint.withValues(alpha: 0.16))
                          : c.bg3,
                      borderRadius: BorderRadius.circular(ScRadius.control - 2),
                      border: Border.all(
                        color: selected.contains(d) ? tint : (c.isFlat ? c.line2 : c.line),
                        width: selected.contains(d) ? 2 : (c.isFlat ? 1.5 : 1),
                      ),
                    ),
                    child: Text(
                      initials[d - 1],
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: selected.contains(d) ? tint : c.text2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CoherenceNotice extends StatelessWidget {
  const _CoherenceNotice({required this.plan, required this.phase, required this.archetype});

  final WeeklyProtocol plan;
  final DietPhase phase;
  final DietArchetype archetype;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final bool recovery = plan.needsRecovery(inDeficit: phase == DietPhase.deficit);
    return HealthCard(
      backgroundColor: c.isFlat ? null : c.accent.withValues(alpha: 0.08),
      child: CardHeader(
        icon: recovery ? Icons.self_improvement_rounded : Icons.check_circle_outline_rounded,
        tone: recovery ? c.warning : c.accent,
        title: recovery ? l10n.protocolRecoveryTitle : l10n.protocolBalancedTitle,
        subtitle: recovery
            ? l10n.protocolRecoveryBody
            : l10n.protocolBalancedBody(plan.workoutDays.length, plan.fastingDays.length),
      ),
    );
  }
}
