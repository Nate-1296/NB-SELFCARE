import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_theme.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/health_card.dart';
import '../../../../body_metrics/presentation/widgets/quick_rpe_workout_sheet.dart';
import '../../../domain/hoy_widget_config.dart';

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
    final int totalNetKcal = workoutsToday.fold<int>(
      0,
      (int sum, WorkoutBlock w) => sum + w.netCaloriesBurned,
    );
    final int totalMinutes = workoutsToday.fold<int>(
      0,
      (int sum, WorkoutBlock w) => sum + w.durationMinutes,
    );

    return HealthCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(AppIcons.pesa, size: 19, color: c.calories),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      context.l10n.todayEntrenamiento,
                      softWrap: true,
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                workoutsToday.isNotEmpty
                    ? context.l10n.todayKcal2((totalNetKcal).toString()): context.l10n.todaySinSesionHoy,
                softWrap: true,
                style: TextStyle(
                  fontFamily: ScFonts.display,
                  fontSize: workoutsToday.isNotEmpty ? 22 : 18,
                  fontWeight: FontWeight.w800,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                workoutsToday.isNotEmpty
                    ? context.l10n.todayBloqueSMinEfectivos(workoutsToday.length.toString(), (totalMinutes).toString()): context.l10n.todayRegistraFuerzaCardioODeporte,
                softWrap: true,
                style: TextStyle(
                  fontFamily: ScFonts.ui,
                  fontSize: 11.5,
                  color: c.text2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => QuickRpeWorkoutSheet.show(
                context: context,
                ref: ref,
                profile: profile,
              ),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(vertical: 9),
              ),
              icon: const Icon(AppIcons.bolt, size: 16),
              label: Text(
                context.l10n.todayEntreno5s,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
