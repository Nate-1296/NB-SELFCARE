import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/protocol_dao.dart';
import '../../../core/domain/enums.dart';
import '../domain/weekly_protocol.dart';

/// Plan semanal guardado, o `null` si aún no se ha creado.
final activeProtocolProvider = StreamProvider<WeeklyProtocol?>((Ref ref) {
  return ref.watch(protocolDaoProvider).watchActiveProtocol().map(
        (ProtocolPlan? plan) => plan == null
            ? null
            : WeeklyProtocol.decode(fastingDays: plan.fastingDaysBitmask, workoutSlots: plan.workoutSlotsJson),
      );
});

class ProtocolService {
  ProtocolService(this._ref);

  final Ref _ref;

  Future<void> save(WeeklyProtocol protocol, {required DietArchetype archetype, required String planName}) {
    return _ref.read(protocolDaoProvider).saveActiveProtocol(
          planName: planName,
          fastingDaysBitmask: protocol.encodedFastingDays,
          workoutSlotsJson: protocol.encodedWorkoutSlots,
          dietArchetype: archetype.dbValue,
        );
  }
}

final protocolServiceProvider = Provider<ProtocolService>(ProtocolService.new);
