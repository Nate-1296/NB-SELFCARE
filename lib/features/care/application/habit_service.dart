import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock/clock.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/care_dao.dart';
import '../../pet_gamification/application/reward_service.dart';
import '../../pet_gamification/domain/reward_policy.dart';
import '../domain/treatment_schedule.dart';

/// Hábitos propios: hilo dental, protector solar, estirar… Un toque los marca.
class HabitService {
  HabitService(this._dao, this._rewards, this._clock);

  final CareDao _dao;
  final RewardService _rewards;
  final Clock _clock;

  static const int maxNameLength = 40;

  /// Iconos disponibles (clave → icono en la presentación).
  static const List<String> iconKeys = <String>[
    'spark',
    'tooth',
    'sun',
    'leaf',
    'book',
    'walk',
    'drop',
    'heart',
    'bed',
    'phone_off',
  ];

  Future<int?> add({required String name, required String iconKey, int daysMask = 127}) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) return Future<int?>.value();
    return _dao.insertHabit(
      name: trimmed.length > maxNameLength ? trimmed.substring(0, maxNameLength) : trimmed,
      iconKey: iconKeys.contains(iconKey) ? iconKey : iconKeys.first,
      daysMask: daysMask & 0x7F == 0 ? 127 : daysMask & 0x7F,
    );
  }

  Future<void> archive(int id) => _dao.archiveHabit(id, archived: true);

  Future<void> unarchive(int id) => _dao.archiveHabit(id, archived: false);

  /// Marca o desmarca; si con esto se completan todos los del día, da las monedas.
  Future<RewardGrant> setDone({
    required int habitId,
    required String dateKey,
    required bool done,
  }) async {
    await _dao.setHabitDone(habitId: habitId, dateKey: dateKey, done: done);
    if (!done) return const RewardGrant.alreadyClaimed();
    final DateTime? day = DateTime.tryParse(dateKey);
    final int weekday = (day ?? _clock.now()).weekday;
    final List<CustomHabit> due = (await _dao.getActiveHabits())
        .where((CustomHabit h) => TreatmentSchedule.appliesOn(h.daysOfWeekBitmask, weekday))
        .toList();
    final Set<int> doneIds = (await _dao.getHabitLogs(dateKey))
        .map((HabitLog l) => l.habitId)
        .toSet();
    final bool allDone = due.isNotEmpty && due.every((CustomHabit h) => doneIds.contains(h.id));
    return allDone
        ? _rewards.grant(RewardAction.habitsDone, dateKey: dateKey)
        : const RewardGrant.alreadyClaimed();
  }
}

final habitServiceProvider = Provider<HabitService>((Ref ref) {
  return HabitService(
    ref.watch(careDaoProvider),
    ref.watch(rewardServiceProvider),
    ref.watch(clockProvider),
  );
});
