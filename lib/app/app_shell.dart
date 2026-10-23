import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shared/theme/sc_colors.dart';
import '../shared/widgets/bottom_nav.dart';
import '../shared/widgets/fasting_bar.dart';

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
/// y barra de ayuno activa (FastingBar).
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const Duration _ventanaSalida = Duration(seconds: 2);
  DateTime? _ultimoAtras;

  void _onTap(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  void _onPop(bool didPop) {
    if (didPop) return;
    final DateTime ahora = DateTime.now();
    final bool dentroVentana = _ultimoAtras != null &&
        ahora.difference(_ultimoAtras!) <= _ventanaSalida;

    switch (decidirAtras(
      indiceActual: widget.navigationShell.currentIndex,
      dentroVentana: dentroVentana,
    )) {
      case BackAction.irInicio:
        _ultimoAtras = null;
        widget.navigationShell.goBranch(0);
      case BackAction.confirmarSalida:
        _ultimoAtras = ahora;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              duration: _ventanaSalida,
              content: Text('Presiona atrás nuevamente para salir'),
            ),
          );
      case BackAction.salir:
        unawaited(SystemNavigator.pop());
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) => _onPop(didPop),
      child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(bottom: false, child: widget.navigationShell),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const FastingBar(),
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

