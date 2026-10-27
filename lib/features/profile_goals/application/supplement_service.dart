import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/supplement_dao.dart';

/// Suplementos activos.
final activeSupplementsProvider = StreamProvider<List<SupplementsTrackerData>>((Ref ref) {
  return ref.watch(supplementDaoProvider).watchActiveSupplements();
});

/// Tomas registradas en un día.
final supplementLogsProvider = StreamProvider.family<List<SupplementLog>, String>((Ref ref, String dateKey) {
  return ref.watch(supplementDaoProvider).watchLogsForDate(dateKey);
});

class SupplementService {
  SupplementService(this._ref);

  final Ref _ref;

  SupplementDao get _dao => _ref.read(supplementDaoProvider);

  Future<int> add({required String name, required String dosage, required bool affectsWaterRetention}) =>
      _dao.createSupplement(name: name, dosage: dosage, affectsWaterRetention: affectsWaterRetention);

  Future<void> setTaken({required String dateKey, required int supplementId, required bool taken}) =>
      _dao.toggleSupplementIntake(dateKey: dateKey, supplementId: supplementId, wasTaken: taken);

  Future<void> remove(int supplementId) => _dao.deleteSupplement(supplementId);
}

final supplementServiceProvider = Provider<SupplementService>(SupplementService.new);
