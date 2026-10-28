import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/domain/activity_energy.dart';
import '../../../../../core/domain/enums.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_tokens.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/card_header.dart';
import '../../../../../shared/widgets/health_card.dart';
import '../../../../../shared/widgets/progress_bar.dart';
import '../../../../../shared/widgets/quick_action_button.dart';
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
    final int workoutKcal = workouts.fold<int>(
      0,
      (int sum, WorkoutBlock b) => sum + b.netCaloriesBurned,
    );

    return Column(
      children: <Widget>[
        HealthCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              CardHeader(
                icon: AppIcons.pasos,
                tone: c.steps,
                title: l10n.cuerpoStepsTitle,
                subtitle: l10n.cuerpoStepsSummary(
                  steps,
                  stepsGoal,
                  ActivityEnergy.kcalFromSteps(steps),
                ),
              ),
              const SizedBox(height: ScSpace.m),
              ScProgressBar(value: stepsGoal > 0 ? steps / stepsGoal : 0, color: c.steps),
            ],
          ),
        ),
        HealthCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              CardHeader(
                icon: AppIcons.pesa,
                tone: c.calories,
                title: l10n.cuerpoWorkoutsTitle,
                subtitle: workouts.isEmpty
                    ? l10n.cuerpoWorkoutsEmpty
                    : l10n.cuerpoWorkoutsSummary(workouts.length, workoutKcal),
                trailing: workoutKcal > 0
                    ? TonalBadge(label: '+$workoutKcal kcal', tone: c.calories)
                    : null,
              ),
              if (workouts.isNotEmpty) ...<Widget>[
                const SizedBox(height: ScSpace.s),
                for (final WorkoutBlock block in workouts) ...<Widget>[
                  const Divider(height: 1),
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
                                l10n.cuerpoWorkoutLine(
                                  block.durationMinutes,
                                  block.rpeIntensity.label(l10n),
                                ),
                                style: context.text.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '+${block.netCaloriesBurned} kcal',
                          style: context.type.metricS.copyWith(fontSize: 14.5),
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
              QuickActionButton(
                label: l10n.cuerpoLogWorkout,
                icon: AppIcons.add,
                tone: c.calories,
                onPressed: onLogWorkout,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
