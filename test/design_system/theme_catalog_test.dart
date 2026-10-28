import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/shared/theme/sc_colors.dart';
import 'package:nb_selfcare/shared/theme/sc_theme.dart';

/// Contraste WCAG 2.1 entre dos colores opacos.
double _contrast(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  final double hi = la > lb ? la : lb;
  final double lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('Catálogo de temas', () {
    test('incluye los dos temas de la Fase 5 (uno de papel y uno de color)', () {
      final ScThemeDef sepia = scThemeByKey('nxtpaper_sepia');
      final ScThemeDef salvia = scThemeByKey('salvia_lino');
      expect(sepia.key, 'nxtpaper_sepia');
      expect(sepia.colors.isFlat, isTrue);
      expect(sepia.brightness, Brightness.light);
      expect(salvia.key, 'salvia_lino');
      expect(salvia.colors.isFlat, isFalse);
      expect(salvia.brightness, Brightness.light);
      expect(kScThemes.map((ScThemeDef d) => d.key).toSet(), hasLength(kScThemes.length));
    });

    test('todos los temas cumplen contraste AA en texto, botones y acentos', () {
      for (final ScThemeDef def in kScThemes) {
        final ScColors c = def.colors;
        String why(String what, double ratio) => '${def.key}: $what = ${ratio.toStringAsFixed(2)}';
        for (final Color surface in <Color>[c.bg, c.bg2]) {
          final double text = _contrast(c.text, surface);
          final double text2 = _contrast(c.text2, surface);
          final double text3 = _contrast(c.text3, surface);
          expect(text, greaterThanOrEqualTo(7), reason: why('text', text));
          expect(text2, greaterThanOrEqualTo(4.5), reason: why('text2', text2));
          expect(text3, greaterThanOrEqualTo(4.5), reason: why('text3', text3));
        }
        final double onBg3 = _contrast(c.text2, c.bg3);
        final double ink = _contrast(c.ink, c.accent);
        final double accent = _contrast(c.accent, c.bg2);
        expect(onBg3, greaterThanOrEqualTo(4.5), reason: why('text2/bg3', onBg3));
        expect(ink, greaterThanOrEqualTo(4.5), reason: why('ink/accent', ink));
        expect(accent, greaterThanOrEqualTo(3), reason: why('accent/bg2', accent));
      }
    });

    test('en tinta (papel claro, oscuro y sepia) los macros se distinguen por intensidad', () {
      for (final String key in <String>[
        'nxtpaper_eink_light',
        'nxtpaper_eink_dark',
        'nxtpaper_sepia',
      ]) {
        final ScColors c = scThemeByKey(key).colors;
        expect(c.protein, isNot(equals(c.carbs)), reason: key);
        expect(c.carbs, isNot(equals(c.fat)), reason: key);
        // La tinta diluida conserva el tono del papel (sepia sigue siendo cálida).
        expect(_contrast(c.carbs, c.bg), greaterThan(_contrast(c.fat, c.bg)), reason: key);
      }
      final ScColors sepia = scThemeByKey('nxtpaper_sepia').colors;
      expect(sepia.carbs.r, greaterThan(sepia.carbs.b));
    });

    test('Modo Papel: sin ondas de toque ni transiciones de página animadas', () {
      for (final ScThemeDef def in kScThemes.where((ScThemeDef d) => d.colors.isFlat)) {
        final ThemeData theme = ScTheme.build(def.key);
        expect(theme.splashFactory, same(NoSplash.splashFactory), reason: def.key);
        final PageTransitionsBuilder builder =
            theme.pageTransitionsTheme.builders[TargetPlatform.android]!;
        expect(builder, isNot(isA<FadeForwardsPageTransitionsBuilder>()), reason: def.key);
        expect(theme.cardTheme.elevation, 0, reason: def.key);
      }
      final ThemeData color = ScTheme.build('samsung_dark');
      expect(
        color.pageTransitionsTheme.builders[TargetPlatform.android],
        isA<FadeForwardsPageTransitionsBuilder>(),
      );
    });

    test('FilledButton.tonal usa el contenedor tonal del tema, no el acento sólido', () {
      final ThemeData theme = ScTheme.build('samsung_dark');
      final ScColors c = scThemeByKey('samsung_dark').colors;
      expect(theme.filledButtonTheme.style?.backgroundColor?.resolve(<WidgetState>{}), isNull);
      expect(theme.colorScheme.secondaryContainer, isNot(equals(c.accent)));
      expect(theme.colorScheme.primary, c.accent);
    });
  });
}
