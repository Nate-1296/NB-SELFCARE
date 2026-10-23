import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_shell.dart';
import '../../features/body_metrics/presentation/cuerpo_screen.dart';
import '../../features/fasting/presentation/fasting_screen.dart';
import '../../features/nutrition_hydration/presentation/nutricion_screen.dart';
import '../../features/pet_gamification/presentation/nibi_screen.dart';
import '../../features/profile_goals/presentation/onboarding_screen.dart';
import '../../features/profile_goals/presentation/perfil_yo_screen.dart';
import '../../features/today/presentation/hoy_screen.dart';
import '../database/app_database.dart';
import '../database/daos/user_profile_dao.dart';

/// Notificador de estado de autenticación / onboarding para GoRouter.
class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this._ref) {
    _ref.listen<AsyncValue<UserProfile?>>(
      userProfileStreamProvider,
      (previous, next) {
        final bool prevHasProfile = previous?.value != null;
        final bool nextHasProfile = next.value != null;
        final bool loadingEnded = (previous == null || previous.isLoading) && !next.isLoading;

        // Notificar si termina la carga inicial o si cambia la existencia del perfil
        if (loadingEnded || (prevHasProfile != nextHasProfile)) {
          notifyListeners();
        }
      },
    );
  }

  final Ref _ref;
  bool get hasProfile => _ref.read(userProfileStreamProvider).value != null;
  bool get isLoading => _ref.read(userProfileStreamProvider).isLoading;
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

/// Provider del enrutador central de NB Selfcare.
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  final GlobalKey<NavigatorState> rootKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');
  final RouterNotifier notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    navigatorKey: rootKey,
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
        parentNavigatorKey: rootKey,
        builder: (
          BuildContext context,
          GoRouterState state,
          StatefulNavigationShell navigationShell,
        ) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: <StatefulShellBranch>[
          // Pestaña 1: Hoy
          StatefulShellBranch(
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
            routes: <RouteBase>[
              GoRoute(
                path: '/cuerpo',
                pageBuilder: (BuildContext context, GoRouterState state) =>
                    const NoTransitionPage(child: CuerpoScreen()),
              ),
            ],
          ),
          // Pestaña 4: Nibi (Mascota Reactiva, Tienda y Armario de Sombreros)
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/nibi',
                pageBuilder: (BuildContext context, GoRouterState state) =>
                    const NoTransitionPage(child: NibiScreen()),
              ),
            ],
          ),
          // Pestaña 5: Perfil / Yo (Identidad, Metas, Diario, Respaldo SQLite y Temas)
          StatefulShellBranch(
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
        parentNavigatorKey: rootKey,
        path: '/ayuno',
        pageBuilder: (BuildContext context, GoRouterState state) =>
            CustomTransitionPage<void>(
          key: state.pageKey,
          child: const FastingScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
            final tween = Tween(begin: begin, end: end);
            return SlideTransition(position: tween.animate(curve), child: child);
          },
        ),
      ),

      GoRoute(
        parentNavigatorKey: rootKey,
        path: '/onboarding',
        pageBuilder: (BuildContext context, GoRouterState state) =>
            const MaterialPage(child: OnboardingScreen()),
      ),
    ],
  );
});

