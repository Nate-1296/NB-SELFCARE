import '../../../core/l10n/l10n.dart';
import '../domain/hoy_widget_config.dart';

extension HoyWidgetIdL10n on HoyWidgetId {
  String title(AppLocalizations l10n) => switch (this) {
        HoyWidgetId.nibiCompanion => l10n.hoyWidgetNibi,
        HoyWidgetId.nutritionEnergy => l10n.hoyWidgetNutrition,
        HoyWidgetId.hydration => l10n.hoyWidgetHydration,
        HoyWidgetId.bodyWeight => l10n.hoyWidgetBody,
        HoyWidgetId.stepsNeat => l10n.hoyWidgetSteps,
        HoyWidgetId.sleepRecovery => l10n.hoyWidgetSleep,
        HoyWidgetId.workoutRpe => l10n.hoyWidgetWorkout,
        HoyWidgetId.fastingMetabolic => l10n.hoyWidgetFasting,
        HoyWidgetId.dailyJournal => l10n.hoyWidgetJournal,
      };
}
