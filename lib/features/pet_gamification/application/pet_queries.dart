import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/pet_dao.dart';

/// Consultas reactivas de lectura para la capa de presentación.

/// StreamProvider que expone el estado de la mascota a la UI.
final petStatusStreamProvider = StreamProvider<PetStatusData?>((ref) {
  final PetDao dao = ref.watch(petDaoProvider);
  return dao.watchPetStatus();
});
