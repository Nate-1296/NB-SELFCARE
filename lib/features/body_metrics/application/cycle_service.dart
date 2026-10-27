import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/daos/female_cycle_dao.dart';

/// Registro del ciclo menstrual (solo perfiles femeninos).
class CycleService {
  CycleService(this._ref);

  final Ref _ref;

  Future<int> logPeriodStart(DateTime start, {int cycleLengthDays = 28}) =>
      _ref.read(femaleCycleDaoProvider).logCycleStart(cycleStartDate: start, cycleLengthDays: cycleLengthDays);
}

final cycleServiceProvider = Provider<CycleService>(CycleService.new);
