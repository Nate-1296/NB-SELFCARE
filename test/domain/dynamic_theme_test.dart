import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/shared/theme/sc_colors.dart';
import 'package:nb_selfcare/shared/theme/sc_theme.dart';

void main() {
  test('El tema del fondo usa el acento del sistema sobre la base clara u oscura', () {
    final ColorScheme dark = ColorScheme.fromSeed(seedColor: Colors.deepOrange, brightness: Brightness.dark);
    final ScThemeDef def = dynamicThemeDef(dark);
    expect(def.brightness, Brightness.dark);
    expect(def.colors.accent, dark.primary);
    expect(def.colors.bg, scThemeByKey('samsung_dark').colors.bg);
    expect(def.colors.isFlat, isFalse);

    final ThemeData theme = ScTheme.build(kDynamicThemeKey, override: def);
    expect(theme.extension<ScColors>()!.accent, dark.primary);
  });
}
