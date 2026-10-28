import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/database/app_database.dart';

import '../support/app_harness.dart';
import '../support/layout_probe.dart';

/// "Mono" que toca la app al azar: botones, tarjetas, chips, hojas que se
/// abren y se cierran con el botón atrás. Los complementos nativos (cámara,
/// selector de archivos, compartir) responden "cancelado", como si el usuario
/// cerrara el diálogo del sistema. Cualquier excepción hace fallar la prueba.
///
/// El árbol de semántica (lectores de pantalla) se desactiva aquí: tras
/// recorridos largos, el motor de semántica de Flutter 3.47 lanza a veces un
/// `Null check` interno en `_updateSemanticsNodeGeometry` que no se pudo
/// aislar a un widget de la app (en el teléfono, 300 toques al azar con la
/// semántica activa no lo reprodujeron; ver docs/10 §2). La accesibilidad se
/// prueba aparte en `test/accessibility/`.
const int _taps = 45;

bool _tappable(Widget w) =>
    (w is InkWell && w.onTap != null) ||
    (w is ButtonStyleButton && w.onPressed != null) ||
    (w is IconButton && w.onPressed != null) ||
    (w is Switch && w.onChanged != null) ||
    (w is Checkbox && w.onChanged != null);

/// Texto visible o descripción del control tocado, para poder reproducir el recorrido.
String _describe(Element target) {
  final Widget w = target.widget;
  if (w is IconButton && w.tooltip != null) return '[${w.tooltip}]';
  String? text;
  void visit(Element e) {
    if (text != null) return;
    final Widget child = e.widget;
    if (child is Text) text = child.data ?? child.textSpan?.toPlainText();
    if (child is Icon) text ??= 'icono ${child.icon?.codePoint.toRadixString(16)}';
    e.visitChildren(visit);
  }

  target.visitChildren(visit);
  return '${w.runtimeType}(${text ?? ''})';
}

void _silencePlugins() {
  // Todo canal que no sea del motor de Flutter responde "nada" (cancelado).
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.allMessagesHandler =
      (String channel, MessageHandler? handler, ByteData? message) async {
        if (channel.startsWith('flutter/')) return handler?.call(message);
        return const StandardMethodCodec().encodeSuccessEnvelope(null);
      };
}

void main() {
  setUp(_silencePlugins);
  tearDown(
    () =>
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.allMessagesHandler = null,
  );

  for (final int round in <int>[1, 2, 3]) {
    for (final String theme in <String>['samsung_dark', 'nxtpaper_eink_light']) {
      for (final String route in <String>[
        '/hoy',
        '/comer',
        '/cuerpo',
        '/nibi',
        '/perfil',
        '/ayuno',
        '/ajustes',
        '/protocolo',
      ]) {
        testWidgets('ronda $round $theme $route', semanticsEnabled: false, (
          WidgetTester tester,
        ) async {
          final Random rng = Random(route.hashCode ^ theme.hashCode ^ (round * 7919));
          final AppDatabase db = harnessDatabase();
          await tester.runAsync(() => seedHarness(db, SeedProfile.typical, theme));
          await pumpHarness(tester, db: db, themeKey: theme, route: route);

          final List<String> trail = <String>[];
          for (int i = 0; i < _taps; i++) {
            final List<Element> candidates = find
                .byWidgetPredicate(_tappable)
                .hitTestable()
                .evaluate()
                .toList();
            if (candidates.isEmpty || rng.nextDouble() < 0.15) {
              trail.add('atrás');
              await tester.binding.handlePopRoute();
            } else {
              final Element target = candidates[rng.nextInt(candidates.length)];
              final String label = _describe(target);
              trail.add(label);
              await tester.tap(
                find.byElementPredicate((Element e) => e == target),
                warnIfMissed: false,
              );
            }
            await settleHarness(tester, rounds: 2);
            final String overflows = describeOverflows(tester);
            final Object? error = tester.takeException();
            expect(
              error,
              isNull,
              reason:
                  'tras: ${trail.join(' → ')}\n$overflows${error is Error ? error.stackTrace : ''}',
            );
          }
          // Volver al inicio cerrando todo lo abierto.
          for (int i = 0; i < 4; i++) {
            await tester.binding.handlePopRoute();
            await settleHarness(tester, rounds: 1);
          }
          expect(tester.takeException(), isNull);
          await unmountHarness(tester, db);
        });
      }
    }
  }
}
