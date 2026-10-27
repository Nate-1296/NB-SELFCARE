import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/health_sync_dao.dart';

/// Resumen diario (pasos, sueño, FC en reposo) de una fecha.
final dailySummaryProvider =
    StreamProvider.family<DailySummary?, String>((Ref ref, String dateKey) {
  return ref.watch(healthSyncDaoProvider).watchDailySummary(dateKey);
});
