import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'shared/theme/sc_theme.dart';
import 'shared/theme/theme_controller.dart';

/// Notifier de compatibilidad con widgets existentes que consultan el motor dual ('material_you' | 'nxtpaper_eink').
class ThemeEngineNotifier extends Notifier<String> {
  @override
  String build() {
    final activeTheme = ref.watch(themeControllerProvider);
    return activeTheme.startsWith('nxtpaper_eink') ? 'nxtpaper_eink' : 'material_you';
  }

  void setEngine(String engine) {
    if (engine == 'nxtpaper_eink') {
      unawaited(ref.read(themeControllerProvider.notifier).selectTheme('nxtpaper_eink_dark'));
    } else {
      unawaited(ref.read(themeControllerProvider.notifier).selectTheme('samsung_dark'));
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
/// Gestiona la inyección del enrutador central declarativo [appRouterProvider]
/// y la aplicación reactiva del tema visual activo del catálogo [ScTheme].
class NbSelfcareApp extends ConsumerWidget {
  const NbSelfcareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String activeThemeKey = ref.watch(themeControllerProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: ScTheme.build(activeThemeKey),
      routerConfig: router,
    );
  }
}
