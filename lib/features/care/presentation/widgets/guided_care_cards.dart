import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_tokens.dart';
import '../../../../shared/widgets/card_header.dart';
import '../../../../shared/widgets/health_card.dart';
import '../../../../shared/widgets/quick_action_button.dart';
import '../../../../shared/widgets/science_on_demand_sheet.dart';
import '../../application/care_queries.dart';
import '../../domain/active_break_catalog.dart';
import '../../domain/pelvic_floor_program.dart';
import '../care_l10n.dart';
import '../care_sessions.dart';

/// Botón "Saber más" para la cabecera de una tarjeta.
class LearnMoreButton extends StatelessWidget {
  const LearnMoreButton({super.key, required this.spec});

  final ScienceSpec Function(AppLocalizations l10n) spec;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.l10n.careLearnMore,
      visualDensity: VisualDensity.compact,
      onPressed: () => unawaited(ScienceOnDemandSheet.show(context, spec(context.l10n))),
      icon: Icon(Icons.info_outline_rounded, color: context.sc.text3),
    );
  }
}

/// Suelo pélvico: nivel, sesiones de la semana y empezar.
class PelvicFloorCard extends ConsumerWidget {
  const PelvicFloorCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final PelvicProgress progress = ref.watch(pelvicProgressProvider);
    final int level = progress.level;
    final int minutes =
        (PelvicFloorProgram.session(variant: PelvicVariant.program, level: level).totalSeconds / 60)
            .ceil();
    final int? suggested = progress.suggestedLevel;
    return HealthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          CardHeader(
            icon: Icons.self_improvement_rounded,
            tone: c.fasting,
            title: l10n.carePelvicTitle,
            subtitle: l10n.carePelvicSubtitle('$level', '${progress.sessionsThisWeek}'),
            trailing: const LearnMoreButton(spec: CareScience.pelvicFloor),
          ),
          if (suggested != null) ...<Widget>[
            const SizedBox(height: ScSpace.s),
            Text(
              l10n.carePelvicLevelUp('${progress.sessionsAtLevel}', '$level', '$suggested'),
              style: context.type.caption.copyWith(color: c.text2),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => unawaited(
                  CareSessions.pelvicFloor(
                    context,
                    ref,
                    variant: PelvicVariant.program,
                    level: suggested,
                  ),
                ),
                child: Text(l10n.carePelvicLevelUpYes),
              ),
            ),
          ],
          const SizedBox(height: ScSpace.m),
          Row(
            children: <Widget>[
              Expanded(
                child: QuickActionButton(
                  emphasized: true,
                  tone: c.fasting,
                  icon: Icons.play_arrow_rounded,
                  label: l10n.carePelvicStart('$minutes'),
                  onPressed: () => unawaited(
                    CareSessions.pelvicFloor(
                      context,
                      ref,
                      variant: PelvicVariant.program,
                      level: level,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: ScSpace.s),
              Expanded(
                child: QuickActionButton(
                  tone: c.fasting,
                  icon: Icons.spa_outlined,
                  label: l10n.carePelvicRelax,
                  onPressed: () => unawaited(
                    CareSessions.pelvicFloor(
                      context,
                      ref,
                      variant: PelvicVariant.relaxOnly,
                      level: level,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (level > 1 || progress.sessionsAtLevel > 0) ...<Widget>[
            const SizedBox(height: ScSpace.s),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  for (final PelvicLevel l in PelvicLevel.all) ...<Widget>[
                    ChoiceChip(
                      label: Text(l10n.carePelvicLevel('${l.level}')),
                      selected: l.level == level,
                      onSelected: (_) => unawaited(
                        CareSessions.pelvicFloor(
                          context,
                          ref,
                          variant: PelvicVariant.program,
                          level: l.level,
                        ),
                      ),
                    ),
                    const SizedBox(width: ScSpace.xs),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pausas activas y descanso visual: una rutina por toque.
class ActiveBreaksCard extends ConsumerWidget {
  const ActiveBreaksCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final int today = ref.watch(breaksTodayProvider);
    return HealthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          CardHeader(
            icon: Icons.accessibility_new_rounded,
            tone: c.steps,
            title: l10n.careBreaksTitle,
            subtitle: today == 0 ? l10n.careBreaksNoneToday : l10n.careBreaksSubtitle('$today'),
            trailing: const LearnMoreButton(spec: CareScience.activeBreaks),
          ),
          const SizedBox(height: ScSpace.m),
          Wrap(
            spacing: ScSpace.s,
            runSpacing: ScSpace.s,
            children: <Widget>[
              for (final ActiveBreakRoutine r in ActiveBreakRoutine.all)
                ActionChip(
                  avatar: Icon(CareText.routineIcon(r.id), size: 18),
                  label: Text(
                    '${CareText.routine(l10n, r.id)} · ${l10n.breathMinutes('${(r.totalSeconds / 60).ceil()}')}',
                  ),
                  onPressed: () => unawaited(CareSessions.activeBreak(context, ref, r)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
