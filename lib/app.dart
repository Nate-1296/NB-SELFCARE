import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/database/app_database.dart';
import 'core/database/daos/user_profile_dao.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/nxtpaper_eink_theme.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/profile_goals/presentation/onboarding_screen.dart';

/// Notifier reactivo para conmutar entre Material You ('material_you') y Modo Papel ('nxtpaper_eink').
class ThemeEngineNotifier extends Notifier<String> {
  @override
  String build() => 'material_you';

  void setEngine(String engine) {
    if (state != engine) {
      state = engine;
    }
  }

  void toggle() {
    state = state == 'nxtpaper_eink' ? 'material_you' : 'nxtpaper_eink';
  }
}

final themeEngineProvider =
    NotifierProvider<ThemeEngineNotifier, String>(ThemeEngineNotifier.new);

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
          home: const _OnboardingGate(),
        );
      },
    );
  }
}

/// Compuerta reactiva que decide si mostrar Onboarding o el Dashboard principal.
class _OnboardingGate extends ConsumerWidget {
  const _OnboardingGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<UserProfile?> profileAsync = ref.watch(userProfileStreamProvider);

    return profileAsync.when(
      data: (UserProfile? profile) {
        if (profile == null) {
          return const OnboardingScreen();
        }

        // Si el perfil guardado tiene un tema específico, sincronizarlo si difiere
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(themeEngineProvider.notifier).setEngine(profile.themeMode);
        });

        return DashboardScreen(profile: profile);
      },
      loading: () => const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.spa_rounded, size: 64, color: Colors.teal),
              SizedBox(height: 16),
              Text(
                'Iniciando Santuario...',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              CircularProgressIndicator(),
            ],
          ),
        ),
      ),
      error: (Object error, StackTrace stack) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Error al inicializar base de datos local: $error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      ),
    );
  }
}
