import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/shared/theme/sc_theme.dart';

import '../support/app_harness.dart';
import '../support/layout_probe.dart';

/// Pantallas reales con condiciones extremas. Cualquier excepción de layout
/// (desbordes, restricciones infinitas) o de construcción hace fallar la prueba.
const List<String> _mainRoutes = <String>[
  '/hoy',
  '/comer',
  '/cuerpo',
  '/nibi',
  '/perfil',
  '/ayuno',
  '/ajustes',
  '/protocolo',
];

Future<void> _render(
  WidgetTester tester, {
  required String theme,
  required String route,
  SeedProfile seed = SeedProfile.typical,
  Size size = const Size(393, 873),
  double textScale = 1,
}) async {
  final AppDatabase db = harnessDatabase();
  await tester.runAsync(() => seedHarness(db, seed, theme));
  await pumpHarness(
    tester,
    db: db,
    themeKey: theme,
    route: route,
    size: size,
    textScale: textScale,
  );
  // Recorrer la pantalla entera para construir todas las tarjetas perezosas.
  // Se revisan los desbordes en cada tramo, antes de que salgan de la caché.
  String overflows = describeOverflows(tester);
  final Finder scrollable = find.byType(Scrollable);
  if (scrollable.evaluate().isNotEmpty) {
    for (int i = 0; i < 12; i++) {
      await tester.drag(scrollable.first, const Offset(0, -500), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 120));
      overflows += describeOverflows(tester);
    }
  }
  final Object? error = tester.takeException();
  expect(
    error,
    isNull,
    reason:
        '$theme $route ${size.width}×${size.height} ×$textScale $seed\n${error == null ? '' : overflows}',
  );
  await unmountHarness(tester, db);
}

void main() {
  group('Los ${kScThemes.length} temas en las pantallas principales', () {
    for (final ScThemeDef def in kScThemes) {
      testWidgets(def.key, (WidgetTester tester) async {
        for (final String route in <String>['/hoy', '/comer', '/cuerpo', '/nibi', '/perfil']) {
          await _render(tester, theme: def.key, route: route);
        }
      });
    }
  });

  group('Texto grande (accesibilidad)', () {
    for (final String theme in <String>['samsung_dark', 'nxtpaper_eink_light']) {
      for (final String route in _mainRoutes) {
        testWidgets('$theme $route', (WidgetTester tester) async {
          await _render(tester, theme: theme, route: route, textScale: 2);
        });
      }
    }
  });

  group('Tamaños de pantalla', () {
    for (final (String name, Size size) in <(String, Size)>[
      ('teléfono pequeño 320×568', const Size(320, 568)),
      ('horizontal 873×393', const Size(873, 393)),
      ('tableta 800×1280', const Size(800, 1280)),
      ('plegable abierto 1100×900', const Size(1100, 900)),
    ]) {
      for (final String route in _mainRoutes) {
        testWidgets('$name $route', (WidgetTester tester) async {
          await _render(tester, theme: 'salvia_lino', route: route, size: size);
        });
      }
    }
  });

  group('Datos', () {
    for (final String route in _mainRoutes) {
      testWidgets('recién instalada (sin datos) $route', (WidgetTester tester) async {
        await _render(tester, theme: 'nxtpaper_sepia', route: route, seed: SeedProfile.fresh);
      });
      testWidgets('volúmenes extremos y textos larguísimos $route', (WidgetTester tester) async {
        await _render(
          tester,
          theme: 'samsung_dark',
          route: route,
          seed: SeedProfile.extreme,
          size: const Size(360, 780),
        );
      });
    }
  });
}
