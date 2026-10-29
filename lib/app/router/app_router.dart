import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../features/body_metrics/presentation/cuerpo_screen.dart';
import '../../features/care/presentation/cuidado_screen.dart';
import '../../features/fasting/presentation/fasting_screen.dart';
import '../../features/nutrition_hydration/presentation/nutricion_screen.dart';
import '../../features/pet_gamification/presentation/nibi_screen.dart';
import '../../features/profile_goals/application/profile_queries.dart';
import '../../features/profile_goals/presentation/app_settings_screen.dart';
import '../../features/profile_goals/presentation/onboarding_screen.dart';
import '../../features/profile_goals/presentation/perfil_yo_screen.dart';
import '../../features/profile_goals/presentation/privacy_policy_screen.dart';
import '../../features/protocol/presentation/protocol_planner_screen.dart';
import '../../features/today/presentation/hoy_screen.dart';
import '../../shared/theme/sc_colors.dart';
import '../app_shell.dart';

/// Notificador de estado de onboarding para GoRouter.
class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this._ref) {
    _ref.listen<AsyncValue<UserProfile?>>(userProfileStreamProvider, (previous, next) {
      final bool prevHasProfile = previous?.value != null;
      final bool nextHasProfile = next.value != null;
      final bool loadingEnded = (previous == null || previous.isLoading) && !next.isLoading;

      if (loadingEnded || (prevHasProfile != nextHasProfile)) {
        notifyListeners();
      }
    });
  }

  final Ref _ref;
  bool get hasProfile => _ref.read(userProfileStreamProvider).value != null;
  bool get isLoading => _ref.read(userProfileStreamProvider).isLoading;
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  final notifier = RouterNotifier(ref);
  ref.onDispose(notifier.dispose);
  return notifier;
});

/// Clave global del navegador raíz para gestionar navegación y retroceso desde cualquier punto.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final GlobalKey<NavigatorState> branchHoyKey = GlobalKey<NavigatorState>(debugLabel: 'branch_hoy');
final GlobalKey<NavigatorState> branchComerKey = GlobalKey<NavigatorState>(
  debugLabel: 'branch_comer',
);
final GlobalKey<NavigatorState> branchCuerpoKey = GlobalKey<NavigatorState>(
  debugLabel: 'branch_cuerpo',
);
final GlobalKey<NavigatorState> branchCuidadoKey = GlobalKey<NavigatorState>(
  debugLabel: 'branch_cuidado',
);
final GlobalKey<NavigatorState> branchNibiKey = GlobalKey<NavigatorState>(
  debugLabel: 'branch_nibi',
);
final GlobalKey<NavigatorState> branchPerfilKey = GlobalKey<NavigatorState>(
  debugLabel: 'branch_perfil',
);

final List<GlobalKey<NavigatorState>> branchKeys = <GlobalKey<NavigatorState>>[
  branchHoyKey,
  branchComerKey,
  branchCuerpoKey,
  branchCuidadoKey,
  branchNibiKey,
  branchPerfilKey,
];

/// Provider del enrutador central de NB Selfcare.
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  final RouterNotifier notifier = ref.watch(routerNotifierProvider);

  final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/hoy',
    refreshListenable: notifier,
    redirect: (BuildContext context, GoRouterState state) {
      if (notifier.isLoading) return null;

      final bool hasProfile = notifier.hasProfile;
      final bool isOnboarding = state.matchedLocation == '/onboarding';

      if (!hasProfile && !isOnboarding) {
        return '/onboarding';
      }
      if (hasProfile && isOnboarding) {
        return '/hoy';
      }
      return null;
    },
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: rootNavigatorKey,
        builder:
            (BuildContext context, GoRouterState state, StatefulNavigationShell navigationShell) {
              return AppShell(navigationShell: navigationShell);
            },
        branches: <StatefulShellBranch>[
          // Pestaña 1: Hoy
          StatefulShellBranch(
            navigatorKey: branchHoyKey,
            routes: <RouteBase>[
              GoRoute(
                path: '/hoy',
                pageBuilder: (BuildContext context, GoRouterState state) =>
                    const NoTransitionPage(child: HoyScreen()),
              ),
            ],
          ),
          // Pestaña 2: Comer (Nutrición e Hidratación)
          StatefulShellBranch(
            navigatorKey: branchComerKey,
            routes: <RouteBase>[
              GoRoute(
                path: '/comer',
                pageBuilder: (BuildContext context, GoRouterState state) =>
                    const NoTransitionPage(child: NutricionScreen()),
              ),
            ],
          ),
          // Pestaña 3: Cuerpo (Báscula BLE, EMA, 13 Métricas y Cinta US Navy)
          StatefulShellBranch(
            navigatorKey: branchCuerpoKey,
            routes: <RouteBase>[
              GoRoute(
                path: '/cuerpo',
                pageBuilder: (BuildContext context, GoRouterState state) =>
                    const NoTransitionPage(child: CuerpoScreen()),
              ),
            ],
          ),
          // Pestaña 4: Cuidado (tratamientos, suelo pélvico, pausas, síntomas, chequeos…)
          StatefulShellBranch(
            navigatorKey: branchCuidadoKey,
            routes: <RouteBase>[
              GoRoute(
                path: '/cuidado',
                pageBuilder: (BuildContext context, GoRouterState state) =>
                    const NoTransitionPage(child: CuidadoScreen()),
              ),
            ],
          ),
          // Pestaña 5: Nibi (Mascota Reactiva, Tienda y Armario)
          StatefulShellBranch(
            navigatorKey: branchNibiKey,
            routes: <RouteBase>[
              GoRoute(
                path: '/nibi',
                pageBuilder: (BuildContext context, GoRouterState state) =>
                    const NoTransitionPage(child: NibiScreen()),
              ),
            ],
          ),
          // Pestaña 6: Perfil / Yo (Identidad, Metas, Analítica Cruzada y Respaldo)
          StatefulShellBranch(
            navigatorKey: branchPerfilKey,
            routes: <RouteBase>[
              GoRoute(
                path: '/perfil',
                pageBuilder: (BuildContext context, GoRouterState state) =>
                    const NoTransitionPage(child: PerfilYoScreen()),
              ),
            ],
          ),
        ],
      ),

      // Rutas a pantalla completa sobre el navegador raíz
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/ayuno',
        pageBuilder: (BuildContext context, GoRouterState state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const FastingScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            if (context.sc.isFlat) {
              return child;
            }
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
            final tween = Tween(begin: begin, end: end);
            return SlideTransition(position: tween.animate(curve), child: child);
          },
        ),
      ),

      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/onboarding',
        pageBuilder: (BuildContext context, GoRouterState state) =>
            const MaterialPage(child: OnboardingScreen()),
      ),

      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/ajustes',
        pageBuilder: (BuildContext context, GoRouterState state) =>
            const MaterialPage(child: AppSettingsScreen()),
      ),

      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/privacidad',
        pageBuilder: (BuildContext context, GoRouterState state) =>
            const MaterialPage(child: PrivacyPolicyScreen()),
      ),

      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/protocolo',
        pageBuilder: (BuildContext context, GoRouterState state) =>
            const MaterialPage(child: ProtocolPlannerScreen()),
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});
