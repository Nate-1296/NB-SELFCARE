import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/clock/clock.dart';
import '../core/database/app_database.dart';
import '../core/l10n/l10n.dart';
import '../core/platform/system_permissions.dart';
import '../features/profile_goals/application/profile_queries.dart';
import '../shared/theme/sc_colors.dart';
import 'app_sync_coordinator.dart';
import 'router/app_router.dart';
import 'widgets/bottom_nav.dart';
import 'widgets/fasting_bar.dart';

/// Semilla fija por sesión de aplicación: se calcula una única vez al abrir la app
/// y no cambia mientras la sesión siga abierta (solo varía al cerrar y reabrir la app).
final hoySessionSeedProvider =
    Provider<({int seed, int startupHour})>((Ref ref) {
  final math.Random rng = math.Random();
  return (seed: rng.nextInt(10000) + 1, startupHour: ref.read(clockProvider).now().hour);
});

/// Semilla reactiva que rota cada vez que el usuario entra a la vista "Hoy"
/// o reanuda la aplicación, haciendo variar el pensamiento de Nibi.
class HoyVisitSeedNotifier extends Notifier<int> {
  final math.Random _rng = math.Random();

  @override
  int build() => _rng.nextInt(10000) + 1;

  void nextVisit() {
    int candidate = _rng.nextInt(10000) + 1;
    if (candidate == state) {
      candidate += 1;
    }
    state = candidate;
  }
}

final hoyVisitSeedProvider =
    NotifierProvider<HoyVisitSeedNotifier, int>(HoyVisitSeedNotifier.new);

enum BackAction { irInicio, confirmarSalida, salir }

BackAction decidirAtras({
  required int indiceActual,
  required bool dentroVentana,
}) {
  if (indiceActual != 0) {
    return BackAction.irInicio;
  }
  return dentroVentana ? BackAction.salir : BackAction.confirmarSalida;
}

/// Contenedor principal de la aplicación con navegación inferior persistente
/// y barra de ayuno activa (FastingBar en vistas secundarias para evitar duplicidad con el widget de Hoy).
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  static const Duration _ventanaSalida = Duration(seconds: 2);
  DateTime? _ultimoAtras;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(appSyncCoordinatorProvider).sync());
      unawaited(_handleLaunchAction());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(hoyVisitSeedProvider.notifier).nextVisit();
      unawaited(ref.read(appSyncCoordinatorProvider).sync());
      unawaited(_handleLaunchAction());
    }
  }

  /// Health Connect abre la app pidiendo la política de privacidad.
  Future<void> _handleLaunchAction() async {
    final String? action = await ref.read(systemPermissionsProvider).consumeLaunchAction();
    if (action == 'privacy_policy' && mounted) {
      unawaited(context.push<void>('/privacidad'));
    }
  }

  void _onTap(int index) {
    if (index == 0 && widget.navigationShell.currentIndex != 0) {
      ref.read(hoyVisitSeedProvider.notifier).nextVisit();
    }
    // Si el usuario toca el botón de la misma pestaña activa y hay una subpágina abierta,
    // actúa inmediatamente como botón de atrás regresando al nivel principal.
    if (index == widget.navigationShell.currentIndex) {
      if (index >= 0 && index < branchKeys.length) {
        final GlobalKey<NavigatorState> branchKey = branchKeys[index];
        if (branchKey.currentState?.canPop() == true) {
          branchKey.currentState?.pop();
          return;
        }
      }
      if (rootNavigatorKey.currentState?.canPop() == true) {
        rootNavigatorKey.currentState?.pop();
        return;
      }
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
        return;
      }
    }
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  void _onPop(bool didPop) {
    if (didPop) return;
    final DateTime ahora = ref.read(clockProvider).now();
    final bool dentroVentana = _ultimoAtras != null &&
        ahora.difference(_ultimoAtras!) <= _ventanaSalida;

    switch (decidirAtras(
      indiceActual: widget.navigationShell.currentIndex,
      dentroVentana: dentroVentana,
    )) {
      case BackAction.irInicio:
        _ultimoAtras = null;
        ref.read(hoyVisitSeedProvider.notifier).nextVisit();
        widget.navigationShell.goBranch(0);
      case BackAction.confirmarSalida:
        _ultimoAtras = ahora;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              duration: _ventanaSalida,
              content: Text(context.l10n.appPressBackToExit),
            ),
          );
      case BackAction.salir:
        unawaited(SystemNavigator.pop());
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final bool isOnHoy = widget.navigationShell.currentIndex == 0;
    final UserProfile? profile = ref.watch(userProfileStreamProvider).value;
    final bool isFastingActive = profile?.isFastingEnabled ?? true;

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) => _onPop(didPop),
      child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(bottom: false, child: widget.navigationShell),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (!isOnHoy && isFastingActive) const FastingBar(),
            BottomNav(
              currentIndex: widget.navigationShell.currentIndex,
              onTap: _onTap,
            ),
          ],
        ),
      ),
    );
  }
}

