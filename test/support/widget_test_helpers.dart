import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nb_selfcare/core/l10n/l10n.dart';

/// Desmonta el árbol y deja correr los temporizadores con que Drift cierra sus
/// streams, para que el test no termine con timers pendientes.
Future<void> unmountAndFlush(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 100));
  // Animaciones de transición de go_router y temporizadores de cierre de Drift.
  await tester.pump(const Duration(seconds: 1));
}

/// App mínima con go_router para probar pantallas que navegan con `context.push`.
Widget routedTestApp({
  required Widget home,
  required ThemeData theme,
  Map<String, Widget> routes = const <String, Widget>{},
}) {
  final GoRouter router = GoRouter(
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (BuildContext context, GoRouterState state) => home),
      for (final MapEntry<String, Widget> r in routes.entries)
        GoRoute(path: r.key, builder: (BuildContext context, GoRouterState state) => r.value),
    ],
  );
  return MaterialApp.router(
    locale: const Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: theme,
    routerConfig: router,
  );
}
