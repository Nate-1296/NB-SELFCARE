import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/fasting_dao.dart';

/// Consultas reactivas de lectura para la capa de presentación.

/// StreamProvider con la sesión de ayuno activa en tiempo real.
final activeFastingSessionStreamProvider = StreamProvider<FastingSession?>((ref) {
  final FastingDao dao = ref.watch(fastingDaoProvider);
  return dao.watchActiveSession();
});

/// Ayunos terminados, del más reciente al más antiguo.
final recentFastsProvider = StreamProvider<List<FastingSession>>((ref) {
  return ref.watch(fastingDaoProvider).watchRecentSessions(limit: 10);
});
