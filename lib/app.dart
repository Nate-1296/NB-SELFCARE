import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router/app_router.dart';
import 'core/constants/app_constants.dart';
import 'core/l10n/generated/app_localizations.dart';
import 'shared/theme/sc_theme.dart';
import 'shared/theme/theme_controller.dart';

/// Notifier de compatibilidad con widgets que consultan el motor dual ('material_you' | 'nxtpaper_eink').
class ThemeEngineNotifier extends Notifier<String> {
  @override
  String build() {
    final activeTheme = ref.watch(themeControllerProvider);
    return scThemeByKey(activeTheme).colors.isFlat
        ? 'nxtpaper_eink'
        : 'material_you';
  }

  void setEngine(String engine) {
    if (engine == 'nxtpaper_eink') {
      unawaited(
        ref.read(themeControllerProvider.notifier).selectTheme('nxtpaper_eink_light'),
      );
    } else {
      unawaited(
        ref.read(themeControllerProvider.notifier).selectTheme('samsung_dark'),
      );
    }
  }

  void toggle() {
    if (state == 'nxtpaper_eink') {
      setEngine('material_you');
    } else {
      setEngine('nxtpaper_eink');
    }
  }
}

final themeEngineProvider =
    NotifierProvider<ThemeEngineNotifier, String>(ThemeEngineNotifier.new);

/// Widget raíz de la aplicación NB Selfcare.
///
/// Gestiona la inyección del enrutador central declarativo [appRouterProvider],
/// delegados de localización en español y el tema visual activo del catálogo [ScTheme].
class NbSelfcareApp extends ConsumerWidget {
  const NbSelfcareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String activeThemeKey = ref.watch(themeControllerProvider);
    final router = ref.watch(appRouterProvider);

    return DynamicColorBuilder(
      builder: (ColorScheme? light, ColorScheme? dark) {
        final bool dynamicTheme = activeThemeKey == kDynamicThemeKey && light != null && dark != null;
        return MaterialApp.router(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: dynamicTheme
              ? ScTheme.build(activeThemeKey, override: dynamicThemeDef(light))
              : ScTheme.build(activeThemeKey),
          darkTheme: dynamicTheme ? ScTheme.build(activeThemeKey, override: dynamicThemeDef(dark)) : null,
          themeMode: dynamicTheme ? ThemeMode.system : ThemeMode.light,
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        );
      },
    );
  }
}
