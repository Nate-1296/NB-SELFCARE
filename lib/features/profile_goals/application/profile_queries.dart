import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/reminders_dao.dart';
import '../../../core/database/daos/tdee_dao.dart';
import '../../../core/database/daos/user_profile_dao.dart';
import '../../../core/services/cross_analytics_engine.dart';

/// Consultas reactivas de lectura para la capa de presentación.

/// StreamProvider que expone el perfil actual de forma reactiva a la UI.
final userProfileStreamProvider = StreamProvider<UserProfile?>((ref) {
  final UserProfileDao dao = ref.watch(userProfileDaoProvider);
  return dao.watchProfile();
});

/// StreamProvider con la calibración más reciente del TDEE.
final latestTdeeCalibrationStreamProvider =
    StreamProvider.autoDispose<TdeeCalibration?>((ref) {
  return ref.watch(tdeeDaoProvider).watchLatestCalibration();
});

/// StreamProvider reactivo con los recordatorios configurados.
final allRemindersStreamProvider =
    StreamProvider.autoDispose<List<Reminder>>((ref) {
  return ref.watch(remindersDaoProvider).watchAllReminders();
});

/// Correlaciones entre hábitos (se recalculan al invalidar el provider).
final crossInsightsProvider = FutureProvider.autoDispose<List<CrossCorrelationInsight>>((ref) {
  return ref.watch(crossAnalyticsEngineProvider).computeInsights();
});
