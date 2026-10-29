import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/health_sync_dao.dart';
import '../../../shared/utils/current_date_provider.dart';
import '../../../shared/utils/date_time_extensions.dart';
import '../domain/sleep_regularity.dart';

/// Noches de las últimas dos semanas con hora de despertar.
final _recentNightsProvider = StreamProvider<List<DailySummary>>((Ref ref) {
  final DateTime today = ref.watch(currentDateProvider);
  return ref
      .watch(healthSyncDaoProvider)
      .watchSummariesBetween(today.addDays(-13).dateKey, today.dateKey);
});

/// Regularidad del horario de sueño, o `null` si aún no hay noches suficientes.
final sleepRegularityProvider = Provider<SleepRegularity?>((Ref ref) {
  final List<DailySummary> days = ref.watch(_recentNightsProvider).value ?? const <DailySummary>[];
  return SleepRegularity.from(<SleepNight>[
    for (final DailySummary d in days)
      if (d.wakeTimeMinutes != null && d.sleepDurationMinutes > 0)
        SleepNight(durationMinutes: d.sleepDurationMinutes, wakeMinutes: d.wakeTimeMinutes!),
  ]);
});
