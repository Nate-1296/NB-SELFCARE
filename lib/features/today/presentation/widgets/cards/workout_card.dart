import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_tokens.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/metric_value.dart';
import '../../../../../shared/widgets/quick_action_button.dart';
import '../../../../body_metrics/presentation/widgets/quick_rpe_workout_sheet.dart';
import '../../../domain/hoy_widget_config.dart';
import 'bento_metric_card.dart';

// ============================================================================
// 7. WIDGET ENTRENAMIENTO RPE EN 5 SEGUNDOS — 2×2 / 4×2
// ============================================================================
class HoyWorkoutBentoCard extends ConsumerWidget {
  const HoyWorkoutBentoCard({
    super.key,
    required this.size,
    required this.workoutsToday,
    required this.profile,
  });

  final HoyWidgetSize size;
  final List<WorkoutBlock> workoutsToday;
  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final int totalNetKcal = workoutsToday.fold<int>(
      0,
      (int sum, WorkoutBlock w) => sum + w.netCaloriesBurned,
    );
    final int totalMinutes = workoutsToday.fold<int>(
      0,
      (int sum, WorkoutBlock w) => sum + w.durationMinutes,
    );
    final bool hasWorkout = workoutsToday.isNotEmpty;

    return BentoMetricCard(
      icon: AppIcons.pesa,
      label: l10n.todayEntrenamiento,
      tone: c.calories,
      metric: hasWorkout
          ? AnimatedMetricValue(
              value: totalNetKcal.toDouble(),
              format: (double v) => v.round().toString(),
              unit: l10n.unitKcal,
              size: size.isHalfWidth ? 28 : 32,
            )
          : Text(l10n.todaySinSesionHoy, style: context.type.metricS.copyWith(color: c.text2)),
      caption: hasWorkout
          ? l10n.todayBloqueSMinEfectivos(workoutsToday.length.toString(), totalMinutes.toString())
          : l10n.todayRegistraFuerzaCardioODeporte,
      actions: <Widget>[
        QuickActionButton(
          label: l10n.todayEntreno5s,
          icon: AppIcons.bolt,
          tone: c.calories,
          onPressed: () => QuickRpeWorkoutSheet.show(context: context, ref: ref, profile: profile),
        ),
      ],
    );
  }
}
