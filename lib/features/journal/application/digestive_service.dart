import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/digestive_dao.dart';

/// Registros digestivos (escala de Bristol) de un día.
final digestiveLogsProvider = StreamProvider.family<List<DigestiveLog>, String>((Ref ref, String dateKey) {
  return ref.watch(digestiveDaoProvider).watchLogsForDate(dateKey);
});

class DigestiveService {
  DigestiveService(this._ref);

  final Ref _ref;

  DigestiveDao get _dao => _ref.read(digestiveDaoProvider);

  Future<int> log({
    required String dateKey,
    required int bristolType,
    required int discomfortLevel,
    required List<String> symptoms,
    String? notes,
  }) {
    return _dao.logDigestiveEvent(
      dateKey: dateKey,
      bristolType: bristolType,
      discomfortLevel: discomfortLevel,
      symptomsJson: jsonEncode(symptoms),
      notes: notes,
    );
  }

  Future<void> delete(DigestiveLog log) => _dao.deleteLog(log.id);

  Future<void> restore(DigestiveLog log) => _dao.restoreLog(log);
}

final digestiveServiceProvider = Provider<DigestiveService>(DigestiveService.new);
