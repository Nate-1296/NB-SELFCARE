import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/nxtpaper_eink_theme.dart';

/// Provider reactivo para conmutar entre Material You ('material_you') y Modo Papel ('nxtpaper_eink').
final themeEngineProvider = StateProvider<String>((ref) => 'material_you');

/// Widget raíz de la aplicación NB Selfcare.
class NbSelfcareApp extends ConsumerWidget {
  const NbSelfcareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String currentEngine = ref.watch(themeEngineProvider);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final ThemeData lightTheme;
        final ThemeData darkTheme;

        if (currentEngine == 'nxtpaper_eink') {
          lightTheme = NxtpaperEinkTheme.light();
          darkTheme = NxtpaperEinkTheme.dark();
        } else {
          lightTheme = AppTheme.light(lightDynamic);
          darkTheme = AppTheme.dark(darkDynamic);
        }

        return MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: ThemeMode.system,
          home: const _BootstrapScreen(),
        );
      },
    );
  }
}

class _BootstrapScreen extends ConsumerWidget {
  const _BootstrapScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentEngine = ref.watch(themeEngineProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            tooltip: currentEngine == 'nxtpaper_eink'
                ? 'Cambiar a Material You'
                : 'Cambiar a Modo Papel NXTPAPER',
            icon: Icon(
              currentEngine == 'nxtpaper_eink'
                  ? Icons.palette_outlined
                  : Icons.menu_book_outlined,
            ),
            onPressed: () {
              ref.read(themeEngineProvider.notifier).state =
                  currentEngine == 'nxtpaper_eink'
                      ? 'material_you'
                      : 'nxtpaper_eink';
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.spa_rounded,
                size: 72.0,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16.0),
              Text(
                AppConstants.appName,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8.0),
              Text(
                'Santuario 100% Offline-First de Autocuidado',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 24.0),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Motor Visual Activo:',
                        style: theme.textTheme.labelMedium,
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        currentEngine == 'nxtpaper_eink'
                            ? 'Modo Papel E-Ink (TCL NXTPAPER)'
                            : 'Material You (Android 16 Monet)',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
