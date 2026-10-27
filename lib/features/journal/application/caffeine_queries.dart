import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock/clock.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/caffeine_dao.dart';
import '../../../core/services/caffeine_pharmacokinetics_service.dart';
import '../../profile_goals/application/profile_queries.dart';

/// Ingestas de cafeína de un día y su estado farmacocinético.
class CaffeineDay {
  const CaffeineDay({
    required this.logs,
    required this.status,
    required this.targetBedtime,
    required this.now,
  });

  final List<CaffeineLog> logs;
  final CaffeineStatus status;
  final DateTime targetBedtime;
  final DateTime now;
}

final _caffeineLogsProvider =
    StreamProvider.family<List<CaffeineLog>, String>((Ref ref, String dateKey) {
  return ref.watch(caffeineDaoProvider).watchLogsForDate(dateKey);
});

/// Estado de la cafeína del día con la hora límite que eligió el usuario
/// (`caffeineBedtimeCutoffHours`, 8 h antes de dormir por defecto).
final caffeineDayProvider =
    Provider.family<AsyncValue<CaffeineDay>, String>((Ref ref, String dateKey) {
  final AsyncValue<List<CaffeineLog>> logs = ref.watch(_caffeineLogsProvider(dateKey));
  if (logs.hasError) return AsyncValue<CaffeineDay>.error(logs.error!, logs.stackTrace!);
  final List<CaffeineLog>? entries = logs.value;
  if (entries == null) return const AsyncValue<CaffeineDay>.loading();

  final DateTime now = ref.watch(clockProvider).now();
  final DateTime day = DateTime.parse(dateKey);
  final DateTime bedtime = DateTime(day.year, day.month, day.day, AppConstants.defaultBedtimeHour);
  final double? cutoffHours = ref.watch(userProfileStreamProvider).value?.caffeineBedtimeCutoffHours;
  return AsyncValue<CaffeineDay>.data(
    CaffeineDay(
      logs: entries,
      targetBedtime: bedtime,
      now: now,
      status: ref.watch(caffeinePharmacokineticsServiceProvider).evaluateStatus(
            logs: entries,
            targetBedtime: bedtime,
            currentTime: now,
            cutoffHoursBeforeBed: cutoffHours,
          ),
    ),
  );
});

/// Registro y borrado de ingestas (escrituras fuera de la presentación).
class CaffeineService {
  CaffeineService(this._ref);

  final Ref _ref;

  Future<int> log({required String dateKey, required String sourceName, required double mg}) =>
      _ref.read(caffeineDaoProvider).logCaffeine(dateKey: dateKey, sourceName: sourceName, caffeineMg: mg);

  Future<int> delete(int id) => _ref.read(caffeineDaoProvider).deleteLog(id);

  Future<void> restore(CaffeineLog log) => _ref.read(caffeineDaoProvider).restoreLog(log);
}

final caffeineServiceProvider = Provider<CaffeineService>(CaffeineService.new);
