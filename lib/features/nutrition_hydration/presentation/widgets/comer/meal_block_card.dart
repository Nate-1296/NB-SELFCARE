import 'package:flutter/material.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/database/models/food_models.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_tokens.dart';
import '../../../../../shared/utils/number_formats.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/health_card.dart';
import '../../../../../shared/widgets/metric_value.dart';
import '../../../../../shared/widgets/quick_action_button.dart';
import '../../../../../shared/widgets/tonal_badge.dart';
import '../../../domain/food_units.dart';
import '../meal_slot_selector.dart';

/// Bloque horario individual (Desayuno, Almuerzo, Cena, Snacks) con acciones inferiores cómodas.
class MealBlockCard extends StatelessWidget {
  const MealBlockCard({
    super.key,
    required this.slot,
    required this.isSuggestedNow,
    required this.items,
    required this.onAddFood,
    required this.onRepeatYesterday,
    required this.onSaveCombo,
    required this.onTapEntry,
    required this.onDeleteEntry,
  });

  final MealSlotMeta slot;
  final bool isSuggestedNow;
  final List<FoodLogWithItem> items;
  final VoidCallback onAddFood;
  final VoidCallback onRepeatYesterday;
  final ValueChanged<List<FoodLogWithItem>> onSaveCombo;
  final ValueChanged<FoodLogWithItem> onTapEntry;
  final ValueChanged<FoodLogWithItem> onDeleteEntry;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final Color tint = slot.accentColor(c);

    final double mealKcal = items.fold(
      0.0,
      (double acc, FoodLogWithItem e) => acc + e.log.totalKcal,
    );
    final double mealP = items.fold(
      0.0,
      (double acc, FoodLogWithItem e) => acc + e.log.totalProteinG,
    );
    final double mealC = items.fold(
      0.0,
      (double acc, FoodLogWithItem e) => acc + e.log.totalCarbsG,
    );
    final double mealF = items.fold(0.0, (double acc, FoodLogWithItem e) => acc + e.log.totalFatG);

    final AppLocalizations l10n = context.l10n;
    final Color iconTint = c.isFlat ? c.text : tint;

    final Widget title = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Icon(slot.icon, size: 22, color: iconTint),
        const SizedBox(width: ScSpace.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: ScSpace.s,
                runSpacing: ScSpace.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(slot.title(l10n), style: context.text.titleLarge),
                  if (isSuggestedNow) TonalBadge(label: l10n.comerAhora, tone: tint),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                items.isEmpty
                    ? slot.timeHint(l10n)
                    : l10n.comerPGCGG(
                        NumberFormats.group(mealP),
                        NumberFormats.group(mealC),
                        NumberFormats.group(mealF),
                      ),
                style: context.type.caption,
              ),
            ],
          ),
        ),
      ],
    );

    // Comida vacía: una sola fila compacta con sus dos accesos.
    if (items.isEmpty) {
      return HealthCard(
        padding: const EdgeInsets.fromLTRB(ScSpace.l + 2, ScSpace.m, ScSpace.s, ScSpace.m),
        borderColor: isSuggestedNow && !c.isFlat ? tint.withValues(alpha: 0.5) : null,
        child: Row(
          children: <Widget>[
            Expanded(child: title),
            IconButton(
              tooltip: l10n.todayRepetirAyer,
              onPressed: onRepeatYesterday,
              icon: Icon(AppIcons.repeat, size: 20, color: c.text2),
            ),
            QuickActionButton(
              label: l10n.comerAnadir,
              icon: AppIcons.add,
              tone: tint,
              emphasized: isSuggestedNow,
              expand: false,
              onPressed: onAddFood,
            ),
          ],
        ),
      );
    }

    return HealthCard(
      borderColor: isSuggestedNow && !c.isFlat ? tint.withValues(alpha: 0.5) : null,
      padding: const EdgeInsets.fromLTRB(ScSpace.l + 2, ScSpace.l, ScSpace.l, ScSpace.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: title),
              const SizedBox(width: ScSpace.s),
              MetricValue(value: NumberFormats.group(mealKcal), unit: l10n.unitKcal, size: 20),
            ],
          ),
          const SizedBox(height: ScSpace.m),
          for (int i = 0; i < items.length; i++) ...<Widget>[
            if (i > 0) const Divider(height: 1),
            _LoggedFoodRow(
              entry: items[i],
              onTap: () => onTapEntry(items[i]),
              onDelete: () => onDeleteEntry(items[i]),
            ),
          ],
          const SizedBox(height: ScSpace.xs),
          Row(
            children: <Widget>[
              // En pantallas estrechas las dos acciones bajan de línea en vez de desbordar.
              Expanded(
                child: Wrap(
                  children: <Widget>[
                    TextButton.icon(
                      onPressed: onAddFood,
                      style: TextButton.styleFrom(foregroundColor: iconTint),
                      icon: const Icon(AppIcons.add, size: 18),
                      label: Text(l10n.comerAnadir),
                    ),
                    TextButton.icon(
                      onPressed: onRepeatYesterday,
                      style: TextButton.styleFrom(foregroundColor: c.text2),
                      icon: const Icon(AppIcons.repeat, size: 17),
                      label: Text(l10n.todayRepetirAyer),
                    ),
                  ],
                ),
              ),
              if (items.length >= 2)
                IconButton(
                  onPressed: () => onSaveCombo(items),
                  tooltip: l10n.comerGuardarCombo,
                  icon: Icon(AppIcons.combos, size: 20, color: c.text2),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoggedFoodRow extends StatelessWidget {
  const _LoggedFoodRow({required this.entry, required this.onTap, required this.onDelete});

  final FoodLogWithItem entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final FoodLog log = entry.log;
    final String name = entry.foodItem?.name ?? context.l10n.comerAlimento;

    return InkWell(
      borderRadius: BorderRadius.circular(ScRadius.controlOf(c)),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: ScSpace.s),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    style: context.type.label.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    (entry.foodItem.isMeasuredInMl
                        ? context.l10n.comerMlPGCG
                        : context.l10n.comerGPGCG)(
                      NumberFormats.group(log.gramsConsumed),
                      NumberFormats.fixed(log.totalProteinG, 0),
                      NumberFormats.fixed(log.totalCarbsG, 0),
                      NumberFormats.fixed(log.totalFatG, 0),
                    ),
                    softWrap: true,
                    style: context.type.caption.copyWith(fontSize: 12, color: c.text3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              context.l10n.comerKcal3(NumberFormats.group(log.totalKcal)),
              style: context.type.metricS.copyWith(fontSize: 14.5),
            ),
            IconButton(
              tooltip: context.l10n.comerEliminarRegistro,
              visualDensity: VisualDensity.compact,
              onPressed: onDelete,
              icon: Icon(AppIcons.delete, size: 18, color: c.text3),
            ),
          ],
        ),
      ),
    );
  }
}
