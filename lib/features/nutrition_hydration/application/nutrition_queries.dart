import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/food_dao.dart';
import '../../../core/database/daos/hydration_dao.dart';
import '../../../core/database/daos/recipe_dao.dart';

/// Consultas reactivas de lectura para la capa de presentación.

/// StreamProvider reactivo que expone todas las recetas caseras ordenadas por uso reciente.
final allRecipesStreamProvider = StreamProvider<List<Recipe>>((ref) {
  final RecipeDao dao = ref.watch(recipeDaoProvider);
  return dao.watchAllRecipes();
});

/// Registros de comida de un día.
final foodLogsForDateProvider =
    StreamProvider.family<List<FoodLog>, String>((Ref ref, String dateKey) {
  return ref.watch(foodDaoProvider).watchLogsForDate(dateKey);
});

/// Vasos de agua de un día (orden cronológico).
final waterLogsForDateProvider =
    StreamProvider.family<List<HydrationLog>, String>((Ref ref, String dateKey) {
  return ref.watch(hydrationDaoProvider).watchLogsForDate(dateKey);
});
