import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_tokens.dart';
import '../../../../shared/utils/number_formats.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/health_card.dart';
import '../../../../shared/widgets/metric_value.dart';
import '../../../../shared/widgets/progress_bar.dart';
import '../../application/nibi_overview.dart';

/// Monedas, escudos y racha en píldoras sobre la esquina del escenario.
class NibiStatBadges extends StatelessWidget {
  const NibiStatBadges({super.key, required this.overview});

  final NibiOverview overview;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    Widget badge(IconData icon, Color tone, String label, String value) => Semantics(
          label: '$label: $value',
          excludeSemantics: true,
          child: Container(
            padding: const EdgeInsets.fromLTRB(ScSpace.s, ScSpace.xs, ScSpace.m - 2, ScSpace.xs),
            decoration: BoxDecoration(
              color: c.isFlat ? c.bg2 : c.bg2.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: c.isFlat ? c.line2 : c.line, width: c.isFlat ? 1.5 : 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 16, color: c.isFlat ? c.text : tone),
                const SizedBox(width: ScSpace.xs),
                MetricValue(value: value, size: 15),
              ],
            ),
          ),
        );
    return Wrap(
      spacing: ScSpace.s - 2,
      runSpacing: ScSpace.xs,
      children: <Widget>[
        badge(AppIcons.moneda, c.warning, l10n.nibiCoins, NumberFormats.integer(overview.pet.coinsBalance, l10n.localeName)),
        badge(AppIcons.shield, c.success, l10n.nibiShields, '${overview.pet.streakShieldsAvailable}'),
        badge(AppIcons.racha, c.calories, l10n.nibiStreak, l10n.nibiDays('${overview.pet.currentStreakDays}')),
      ],
    );
  }
}

/// Cómo le va a Nibi hoy: el reflejo de tus hábitos (agua, sueño, comidas).
class NibiTodayCard extends StatelessWidget {
  const NibiTodayCard({super.key, required this.overview});

  final NibiOverview overview;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final String locale = l10n.localeName;
    final List<(IconData, Color, String, String, double)> rows = <(IconData, Color, String, String, double)>[
      (
        AppIcons.water,
        c.water,
        l10n.nibiWater,
        l10n.nibiWaterValue(NumberFormats.integer(overview.waterMl, locale), NumberFormats.integer(overview.waterGoalMl, locale)),
        overview.hydrationRatio,
      ),
      (
        AppIcons.sueno,
        c.fasting,
        l10n.nibiSleep,
        l10n.nibiSleepValue(NumberFormats.oneDecimal(overview.sleepHours, locale), NumberFormats.oneDecimal(overview.sleepGoalHours, locale)),
        overview.sleepGoalHours > 0 ? overview.sleepHours / overview.sleepGoalHours : 0,
      ),
      (
        AppIcons.comer,
        c.calories,
        l10n.nibiMeals,
        l10n.nibiMealsValue('${overview.mealsLogged}'),
        (overview.mealsLogged / 3).clamp(0.0, 1.0),
      ),
    ];
    return HealthCard(
      margin: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          for (int i = 0; i < rows.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: ScSpace.m + 2),
            Row(
              children: <Widget>[
                Icon(rows[i].$1, size: 18, color: c.isFlat ? c.text : rows[i].$2),
                const SizedBox(width: ScSpace.s + 2),
                Expanded(child: Text(rows[i].$3, style: context.type.label)),
                Flexible(child: Text(rows[i].$4, textAlign: TextAlign.end, style: context.type.caption)),
              ],
            ),
            const SizedBox(height: ScSpace.s - 2),
            ScProgressBar(value: rows[i].$5, color: rows[i].$2, height: 6),
          ],
        ],
      ),
    );
  }
}
