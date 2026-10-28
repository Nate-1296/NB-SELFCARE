import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../shared/utils/date_formats.dart';
import '../../../../shared/widgets/top_bar.dart';
import '../../domain/day_part.dart';

/// Saludo de la sesión con la fecha del día y acceso al plan semanal.
class TodayHeader extends StatelessWidget {
  const TodayHeader({
    super.key,
    required this.name,
    required this.date,
    required this.sessionHour,
    required this.sessionSeed,
  });

  final String name;
  final DateTime date;
  final int sessionHour;
  final int sessionSeed;

  String _greeting(AppLocalizations l10n) {
    final String first = name.trim().split(' ').first;
    final int variant = sessionSeed.abs() % 3;
    return switch ((DayPart.forHour(sessionHour), variant)) {
      (DayPart.morning, 0) => l10n.todayGreetingMorning0(first),
      (DayPart.morning, 1) => l10n.todayGreetingMorning1(first),
      (DayPart.morning, _) => l10n.todayGreetingMorning2(first),
      (DayPart.afternoon, 0) => l10n.todayGreetingAfternoon0(first),
      (DayPart.afternoon, 1) => l10n.todayGreetingAfternoon1(first),
      (DayPart.afternoon, _) => l10n.todayGreetingAfternoon2(first),
      (DayPart.night, 0) => l10n.todayGreetingNight0(first),
      (DayPart.night, 1) => l10n.todayGreetingNight1(first),
      (DayPart.night, _) => l10n.todayGreetingNight2(first),
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String formatted = DateFormats.weekdayDayMonth(date, l10n.localeName);
    return TopBar(
      title: _greeting(l10n),
      subtitle: formatted[0].toUpperCase() + formatted.substring(1),
      large: true,
      trailing: TopBarAction(
        icon: Icons.calendar_month_rounded,
        tooltip: l10n.todayWeeklyPlanTooltip,
        onPressed: () {
          unawaited(HapticFeedback.lightImpact());
          unawaited(context.push<void>('/protocolo'));
        },
      ),
    );
  }
}
