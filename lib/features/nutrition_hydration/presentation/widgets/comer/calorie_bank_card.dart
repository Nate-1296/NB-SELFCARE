import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/services/calorie_cycling_service.dart';
import '../../../../../core/services/smart_meal_suggester.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_tokens.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/card_header.dart';
import '../../../../../shared/widgets/health_card.dart';
import '../../../../../shared/widgets/tonal_badge.dart';
import '../../../../profile_goals/application/profile_queries.dart';
import '../../../application/nutrition_day.dart';
import '../diet_archetype_sheets.dart';

/// Balance semanal: lo comido frente a la meta en los días ya cerrados de la semana.
class CalorieBankCard extends ConsumerWidget {
  const CalorieBankCard({super.key, required this.dateKey});

  final String dateKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final WeeklyCalorieBank? bank = ref.watch(weeklyCalorieBankProvider(dateKey)).value;
    if (bank == null) return const SizedBox.shrink();
    final String dietName = DietArchetypeInfo.getById(
      ref.watch(userProfileStreamProvider).value?.activeDietArchetype,
    ).name;

    final String message;
    if (bank.daysLogged == 0) {
      message = l10n.comerBankEmpty;
    } else if (bank.hasBankSavings) {
      message = l10n.comerBankSavings(bank.netBalanceKcal, bank.daysLogged);
    } else if (bank.isInSurplus) {
      message = l10n.comerBankOver(-bank.netBalanceKcal, bank.daysLogged);
    } else {
      message = l10n.comerBankEven(bank.daysLogged);
    }

    return HealthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CardHeader(
            icon: Icons.account_balance_wallet_rounded,
            tone: c.carbs,
            title: l10n.comerBankTitle,
            trailing: TonalBadge(label: l10n.comerBankDaysLeft(bank.remainingDaysInWeek)),
          ),
          const SizedBox(height: ScSpace.m),
          Text(message, style: context.type.caption),
          const SizedBox(height: ScSpace.m),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (bank.daysLogged > 0) ...<Widget>[
                  Expanded(
                    child: _BankStat(
                      label: l10n.comerBankEaten,
                      value: l10n.comerKcalOf(
                        bank.accumulatedConsumedKcal,
                        bank.accumulatedTargetKcal,
                      ),
                    ),
                  ),
                  const SizedBox(width: ScSpace.s),
                ],
                Expanded(
                  child: _BankStat(
                    label: l10n.comerDietType,
                    value: dietName,
                    onTap: () => DietArchetypePickerSheet.show(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BankStat extends StatelessWidget {
  const _BankStat({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Material(
      color: c.isFlat ? c.bg2 : c.bg3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ScRadius.tileOf(c)),
        side: c.isFlat ? BorderSide(color: c.line2, width: 1.5) : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: ScSpace.m, vertical: ScSpace.s + 2),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(label.toUpperCase(), style: context.type.overline),
                    const SizedBox(height: ScSpace.xs),
                    Text(value, style: context.type.label.copyWith(fontSize: 14.5)),
                  ],
                ),
              ),
              if (onTap != null) Icon(AppIcons.chevronRight, size: 18, color: c.text3),
            ],
          ),
        ),
      ),
    );
  }
}
