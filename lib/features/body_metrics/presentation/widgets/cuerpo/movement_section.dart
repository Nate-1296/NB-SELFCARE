import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/domain/activity_energy.dart';
import '../../../../../core/domain/enums.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_theme.dart';
import '../../../../../shared/theme/sc_tokens.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/card_header.dart';
import '../../../../../shared/widgets/health_card.dart';
import '../../../../../shared/widgets/tonal_badge.dart';
import '../../../../today/application/today_queries.dart';
import '../../../application/body_queries.dart';

extension WorkoutCategoryL10n on WorkoutCategory {
  String label(AppLocalizations l10n) => switch (this) {
        WorkoutCategory.weights => l10n.workoutWeights,
        WorkoutCategory.calisthenics => l10n.workoutCalisthenics,
        WorkoutCategory.cardio => l10n.workoutCardio,
        WorkoutCategory.sports => l10n.workoutSports,
      };
}

extension RpeIntensityL10n on RpeIntensity {
  String label(AppLocalizations l10n) => switch (this) {
        RpeIntensity.light => l10n.workoutLight,
        RpeIntensity.moderate => l10n.workoutModerate,
        RpeIntensity.intense => l10n.workoutIntense,
      };
}

/// Pasos del día y entrenamientos registrados hoy.
class MovementSection extends ConsumerWidget {
  const MovementSection({
    super.key,
    required this.dateKey,
    required this.stepsGoal,
    required this.onLogWorkout,
    required this.onDeleteWorkout,
  });

  final String dateKey;
  final int stepsGoal;
  final VoidCallback onLogWorkout;
  final ValueChanged<WorkoutBlock> onDeleteWorkout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final int steps = ref.watch(dailySummaryProvider(dateKey)).value?.stepsCount ?? 0;
    final List<WorkoutBlock> workouts =
        ref.watch(workoutsForDateProvider(dateKey)).value ?? const <WorkoutBlock>[];
    final int workoutKcal = workouts.fold<int>(0, (int sum, WorkoutBlock b) => sum + b.netCaloriesBurned);

    return Column(
      children: <Widget>[
        HealthCard(
          child: CardHeader(
            icon: AppIcons.pasos,
            tone: c.steps,
            title: l10n.cuerpoStepsTitle,
            subtitle: l10n.cuerpoStepsSummary(steps, stepsGoal, ActivityEnergy.kcalFromSteps(steps)),
          ),
        ),
        HealthCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              CardHeader(
                icon: AppIcons.pesa,
                title: l10n.cuerpoWorkoutsTitle,
                subtitle: workouts.isEmpty
                    ? l10n.cuerpoWorkoutsEmpty
                    : l10n.cuerpoWorkoutsSummary(workouts.length, workoutKcal),
                trailing: workoutKcal > 0 ? TonalBadge(label: '+$workoutKcal kcal') : null,
              ),
              if (workouts.isNotEmpty) ...<Widget>[
                const SizedBox(height: ScSpace.s),
                for (final WorkoutBlock block in workouts) ...<Widget>[
                  Divider(height: 1, color: c.line),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: ScSpace.xs),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(block.category.label(l10n), style: context.text.titleSmall),
                              Text(
                                l10n.cuerpoWorkoutLine(block.durationMinutes, block.rpeIntensity.label(l10n)),
                                style: context.text.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '+${block.netCaloriesBurned} kcal',
                          style: TextStyle(
                            fontFamily: ScFonts.display,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: c.isFlat ? c.text : c.accent,
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.cuerpoDeleteWorkout,
                          icon: Icon(AppIcons.delete, size: 18, color: c.text3),
                          onPressed: () => onDeleteWorkout(block),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              const SizedBox(height: ScSpace.m),
              FilledButton.tonalIcon(
                onPressed: onLogWorkout,
                icon: const Icon(AppIcons.add, size: 18),
                label: Text(l10n.cuerpoLogWorkout),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
