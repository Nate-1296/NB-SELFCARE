import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/user_profile_dao.dart';
import 'sc_theme.dart';

/// Clave por defecto para el tema de la aplicación (Samsung Health Nocturno).
const String kDefaultThemeKey = 'samsung_dark';

/// Controlador reactivo del tema visual activo en NB Selfcare.
///
/// Gestiona la conmutación entre los temas del catálogo Samsung Health
/// y los modos optimizados para el TCL 50 Pro NXTPAPER (E-Ink & Color Paper).
class ThemeController extends Notifier<String> {
  @override
  String build() {
    // Si el perfil ya fue cargado, se usa su tema; de lo contrario el tema por defecto.
    final String? userTheme = ref.watch(_profileThemeKeyProvider).value;

    if (userTheme != null && userTheme.isNotEmpty) {
      // Mapear compatibilidad con versiones previas si venían con 'material_you' o 'nxtpaper_eink'
      if (userTheme == 'material_you') return 'samsung_dark';
      if (userTheme == 'nxtpaper_eink') return 'nxtpaper_eink_dark';
      return userTheme;
    }

    return kDefaultThemeKey;
  }

  /// Selecciona un tema por su clave identificadora y lo persiste en la base de datos local.
  Future<void> selectTheme(String key) async {
    state = key;
    final userProfileDao = ref.read(userProfileDaoProvider);
    await userProfileDao.updateThemeMode(key);
  }
}

/// Clave de tema guardada en el perfil (lectura directa: `shared/` no depende de features).
final _profileThemeKeyProvider = StreamProvider<String?>((Ref ref) {
  return ref
      .watch(userProfileDaoProvider)
      .watchProfile()
      .map((UserProfile? profile) => profile?.themeMode)
      .distinct();
});

/// Provider reactivo del tema activo (clave identificadora).
final themeControllerProvider =
    NotifierProvider<ThemeController, String>(ThemeController.new);

/// Provider de la definición activa del tema.
final activeScThemeDefProvider = Provider<ScThemeDef>((ref) {
  final String key = ref.watch(themeControllerProvider);
  return scThemeByKey(key);
});

