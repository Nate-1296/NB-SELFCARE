import 'package:flutter/material.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/database/models/food_models.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_theme.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/health_card.dart';
import '../meal_slot_selector.dart';

/// Bloque horario individual (Desayuno, Almuerzo, Cena, Snacks) con acciones inferiores cómodas.
class MealBlockCard extends StatelessWidget {
  const MealBlockCard({super.key, 
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
    final double mealF = items.fold(
      0.0,
      (double acc, FoodLogWithItem e) => acc + e.log.totalFatG,
    );

    return HealthCard(
      borderColor: isSuggestedNow && !c.isFlat
          ? tint.withValues(alpha: 0.45)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Cabecera del bloque
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.isFlat ? c.bg3 : tint.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: c.isFlat ? c.line2 : tint.withValues(alpha: 0.35),
                  ),
                ),
                child: Icon(
                  slot.icon,
                  size: 20,
                  color: c.isFlat ? c.text : tint,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(
                          slot.title(context.l10n),
                          style: TextStyle(
                            fontFamily: ScFonts.display,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: c.text,
                          ),
                        ),
                        if (isSuggestedNow)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: c.bg3,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: c.isFlat ? c.line2 : tint,
                              ),
                            ),
                            child: Text(
                              context.l10n.comerAhora,
                              style: TextStyle(
                                fontFamily: ScFonts.ui,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: c.isFlat ? c.text : tint,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      items.isEmpty
                          ? slot.timeHint(context.l10n)
                          : context.l10n.comerPGCGG(mealP.round().toString(), mealC.round().toString(), mealF.round().toString()),
                      softWrap: true,
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 12,
                        color: c.text2,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                context.l10n.comerKcal2(mealKcal.round().toString()),
                style: TextStyle(
                  fontFamily: ScFonts.display,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: items.isEmpty ? c.text3 : c.text,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: c.bg3.withValues(alpha: c.isFlat ? 1.0 : 0.6),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text(
                context.l10n.comerSinAlimentosRegistradosTodaviaEn(slot.title(context.l10n).toLowerCase().toString()),
                softWrap: true,
                style: TextStyle(
                  fontFamily: ScFonts.ui,
                  fontSize: 12.5,
                  color: c.text3,
                ),
              ),
            )
          else
            Column(
              children: <Widget>[
                for (int i = 0; i < items.length; i++) ...<Widget>[
                  if (i > 0) Divider(height: 12, color: c.line),
                  _LoggedFoodRow(
                    entry: items[i],
                    onTap: () => onTapEntry(items[i]),
                    onDelete: () => onDeleteEntry(items[i]),
                  ),
                ],
              ],
            ),

          const SizedBox(height: 12),

          // Botones inferiores cómodos (envolventes, nunca cortados)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.tonalIcon(
                onPressed: onAddFood,
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                icon: const Icon(AppIcons.add, size: 17),
                label: Text(
                  context.l10n.comerAnadir,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onRepeatYesterday,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                icon: const Icon(AppIcons.repeat, size: 16),
                label: Text(context.l10n.todayRepetirAyer),
              ),
              if (items.length >= 2)
                IconButton.outlined(
                  onPressed: () => onSaveCombo(items),
                  tooltip: context.l10n.comerGuardarCombo,
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                    side: BorderSide(color: c.isFlat ? c.line2 : c.line, width: c.isFlat ? 1.5 : 1),
                  ),
                  icon: const Icon(AppIcons.combos, size: 18),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoggedFoodRow extends StatelessWidget {
  const _LoggedFoodRow({
    required this.entry,
    required this.onTap,
    required this.onDelete,
  });

  final FoodLogWithItem entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final FoodLog log = entry.log;
    final String name = entry.foodItem?.name ?? context.l10n.comerAlimento;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    softWrap: true,
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.comerGPGCG(log.gramsConsumed.round().toString(), log.totalProteinG.toStringAsFixed(0).toString(), log.totalCarbsG.toStringAsFixed(0).toString(), log.totalFatG.toStringAsFixed(0).toString()),
                    softWrap: true,
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 11.5,
                      color: c.text2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              context.l10n.comerKcal3(log.totalKcal.round().toString()),
              style: TextStyle(
                fontFamily: ScFonts.display,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: c.text,
              ),
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
