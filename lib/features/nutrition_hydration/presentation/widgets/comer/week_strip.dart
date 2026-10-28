import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_tokens.dart';
import '../../../../../shared/utils/date_time_extensions.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../application/nutrition_day.dart';

/// Franja semanal interactiva (L a D) con indicadores de registro y botón rápido a Hoy.
class ComerWeekStrip extends ConsumerWidget {
  const ComerWeekStrip({
    super.key,
    required this.activeDate,
    required this.today,
    required this.onSelectDate,
  });

  final DateTime activeDate;
  final DateTime today;
  final ValueChanged<DateTime> onSelectDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final DateTime normalized = DateTime(activeDate.year, activeDate.month, activeDate.day);
    final DateTime weekMonday = normalized.addDays(1 - normalized.weekday);
    final List<DateTime> weekDays = List<DateTime>.generate(
      7,
      (int i) => DateTime(weekMonday.year, weekMonday.month, weekMonday.day + i),
    );

    final Set<String> loggedKeys =
        ref.watch(loggedDaysInWeekProvider(activeDate.dateKey)).value ?? const <String>{};
    final AppLocalizations l10n = context.l10n;
    final List<String> weekdayInitials = l10n.comerWeekdayInitials.split(',');
    final bool isToday = activeDate.dateKey == today.dateKey;

    // Sin tarjeta: la semana es navegación, no contenido.
    return Padding(
      padding: const EdgeInsets.fromLTRB(ScSpace.s, 0, ScSpace.s, ScSpace.s),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton(
                tooltip: l10n.comerPreviousDay,
                icon: Icon(AppIcons.chevronLeft, color: c.text2),
                onPressed: () => onSelectDate(normalized.addDays(-1)),
              ),
              Expanded(
                child: Center(
                  child: isToday
                      ? Text(
                          l10n.comerThisWeek,
                          style: context.type.overline.copyWith(color: c.text2),
                        )
                      : TextButton.icon(
                          onPressed: () => onSelectDate(today),
                          icon: const Icon(Icons.today_rounded, size: 17),
                          label: Text(l10n.comerBackToToday),
                        ),
                ),
              ),
              IconButton(
                tooltip: l10n.comerNextDay,
                icon: Icon(AppIcons.chevronRight, color: c.text2),
                onPressed: () => onSelectDate(normalized.addDays(1)),
              ),
            ],
          ),
          Row(
            children: List<Widget>.generate(7, (int index) {
              final DateTime d = weekDays[index];
              final String key = d.dateKey;
              final bool selected = key == activeDate.dateKey;
              final bool isCurrentToday = key == today.dateKey;
              final bool hasLogs = loggedKeys.contains(key);
              final Color dayInk = selected ? (c.isFlat ? c.bg : c.ink) : c.text;

              return Expanded(
                child: Semantics(
                  selected: selected,
                  button: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(ScRadius.tileOf(c)),
                    onTap: () => onSelectDate(d),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: AnimatedContainer(
                        duration: ScMotion.of(context, ScMotion.standard),
                        curve: ScMotion.ease,
                        padding: const EdgeInsets.symmetric(vertical: ScSpace.s + 2),
                        decoration: BoxDecoration(
                          color: selected ? (c.isFlat ? c.text : c.accent) : Colors.transparent,
                          borderRadius: BorderRadius.circular(ScRadius.tileOf(c)),
                          border: Border.all(
                            color: selected || isCurrentToday
                                ? (c.isFlat ? c.line2 : c.accent)
                                : Colors.transparent,
                            width: c.isFlat ? 1.5 : 1.2,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              weekdayInitials[index],
                              style: context.type.overline.copyWith(
                                color: selected ? dayInk.withValues(alpha: 0.75) : c.text3,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: ScSpace.xs),
                            Text(
                              '${d.day}',
                              style: context.type.metricS.copyWith(fontSize: 17, color: dayInk),
                            ),
                            const SizedBox(height: ScSpace.xs + 1),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: hasLogs
                                    ? (selected ? dayInk : (c.isFlat ? c.text : c.accent))
                                    : Colors.transparent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
