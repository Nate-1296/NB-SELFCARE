import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_theme.dart';
import '../../../../../shared/utils/date_time_extensions.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/health_card.dart';
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
    final DateTime weekMonday = normalized.subtract(Duration(days: normalized.weekday - 1));
    final List<DateTime> weekDays = List<DateTime>.generate(
      7,
      (int i) => DateTime(weekMonday.year, weekMonday.month, weekMonday.day + i),
    );

    final Set<String> loggedKeys =
        ref.watch(loggedDaysInWeekProvider(activeDate.dateKey)).value ?? const <String>{};
    final AppLocalizations l10n = context.l10n;
    final List<String> weekdayInitials = l10n.comerWeekdayInitials.split(',');
    final bool isToday = activeDate.dateKey == today.dateKey;

    return HealthCard(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton(
                tooltip: l10n.comerPreviousDay,
                icon: Icon(AppIcons.chevronLeft, color: c.text2),
                onPressed: () => onSelectDate(normalized.subtract(const Duration(days: 1))),
              ),
              Expanded(
                child: Center(
                  child: isToday
                      ? Text(
                          l10n.comerThisWeek,
                          style: TextStyle(
                            fontFamily: ScFonts.ui,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: c.text2,
                          ),
                        )
                      : InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => onSelectDate(today),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: c.isFlat ? c.bg3 : c.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: c.isFlat ? c.line2 : c.accent),
                            ),
                            child: Text(
                              l10n.comerBackToToday,
                              style: TextStyle(
                                fontFamily: ScFonts.ui,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: c.isFlat ? c.text : c.accent,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              IconButton(
                tooltip: l10n.comerNextDay,
                icon: Icon(AppIcons.chevronRight, color: c.text2),
                onPressed: () => onSelectDate(normalized.add(const Duration(days: 1))),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: List<Widget>.generate(7, (int index) {
              final DateTime d = weekDays[index];
              final String key = d.dateKey;
              final bool selected = key == activeDate.dateKey;
              final bool isCurrentToday = key == today.dateKey;
              final bool hasLogs = loggedKeys.contains(key);

              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onSelectDate(d),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? c.accent : (isCurrentToday ? c.bg3 : Colors.transparent),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? c.accent
                              : (isCurrentToday
                                    ? (c.isFlat ? c.line2 : c.line)
                                    : Colors.transparent),
                          width: selected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            weekdayInitials[index],
                            style: TextStyle(
                              fontFamily: ScFonts.ui,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: selected ? c.ink : c.text3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${d.day}',
                            style: TextStyle(
                              fontFamily: ScFonts.display,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: selected ? c.ink : c.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: hasLogs ? (selected ? c.ink : c.accent) : Colors.transparent,
                            ),
                          ),
                        ],
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
