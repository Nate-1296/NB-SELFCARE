import 'package:flutter/material.dart';

import 'sc_colors.dart';

/// Familias tipográficas incluidas en la aplicación.
abstract final class ScFonts {
  /// Titulares, cifras numéricas destacadas y métricas de salud.
  static const String display = 'SpaceGrotesk';

  /// Texto de interfaz, botones, etiquetas y subtítulos.
  static const String ui = 'Manrope';
}

/// Definición de un tema oficial en NB Selfcare.
@immutable
class ScThemeDef {
  const ScThemeDef({
    required this.key,
    required this.label,
    required this.description,
    required this.brightness,
    required this.colors,
  });

  final String key;
  final String label;
  final String description;
  final Brightness brightness;
  final ScColors colors;
}

ScColors _buildColors({
  required int bg,
  required int bg2,
  required int bg3,
  required int line,
  required int line2,
  required int text,
  required int text2,
  required int text3,
  required int accent,
  required int accent2,
  int? ink,
  int calories = 0xFFFF6B4A,
  int protein = 0xFF00D2C4,
  int water = 0xFF38BDF8,
  int steps = 0xFF84CC16,
  int fasting = 0xFFA855F7,
  bool isFlat = false,
}) {
  final Color accentCol = Color(accent);
  final Color resolvedInk = ink != null
      ? Color(ink)
      : (accentCol.computeLuminance() > 0.55
          ? const Color(0xFF0A0C10)
          : const Color(0xFFFFFFFF));

  return ScColors(
    bg: Color(bg),
    bg2: Color(bg2),
    bg3: Color(bg3),
    line: Color(line),
    line2: Color(line2),
    text: Color(text),
    text2: Color(text2),
    text3: Color(text3),
    accent: accentCol,
    accent2: Color(accent2),
    ink: resolvedInk,
    soft: accentCol.withValues(alpha: isFlat ? 0.08 : 0.16),
    ambient: accentCol.withValues(alpha: isFlat ? 0.0 : 0.25),
    calories: Color(calories),
    protein: Color(protein),
    water: Color(water),
    steps: Color(steps),
    fasting: Color(fasting),
    isFlat: isFlat,
  );
}

ScThemeDef _def(
  String key,
  String label,
  String description, {
  required int bg,
  required int bg2,
  required int bg3,
  required int line,
  required int line2,
  required int text,
  required int text2,
  required int text3,
  required int accent,
  required int accent2,
  int? ink,
  int calories = 0xFFFF6B4A,
  int protein = 0xFF00D2C4,
  int water = 0xFF38BDF8,
  int steps = 0xFF84CC16,
  int fasting = 0xFFA855F7,
  bool isFlat = false,
}) {
  final Brightness brightness =
      Color(bg).computeLuminance() > 0.5 ? Brightness.light : Brightness.dark;

  return ScThemeDef(
    key: key,
    label: label,
    description: description,
    brightness: brightness,
    colors: _buildColors(
      bg: bg,
      bg2: bg2,
      bg3: bg3,
      line: line,
      line2: line2,
      text: text,
      text2: text2,
      text3: text3,
      accent: accent,
      accent2: accent2,
      ink: ink,
      calories: calories,
      protein: protein,
      water: water,
      steps: steps,
      fasting: fasting,
      isFlat: isFlat,
    ),
  );
}

/// Catálogo de temas de salud de alta gama (estilo nuevo Samsung Health y NXTPAPER).
final List<ScThemeDef> kScThemes = <ScThemeDef>[
  // 1. Samsung Health Dark
  _def(
    'samsung_dark',
    'Samsung Health Nocturno',
    'Fondo carbón satinado, tarjetas limpias y acento esmeralda radiante.',
    bg: 0xFF0B0E14,
    bg2: 0xFF151922,
    bg3: 0xFF1E2430,
    line: 0x24334155,
    line2: 0xFF2D3748,
    text: 0xFFFFFFFF,
    text2: 0xFFB2BAC6,
    text3: 0xFF717D91,
    accent: 0xFF00E5A3,
    accent2: 0xFF00B882,
    ink: 0xFF07120E,
  ),

  // 2. Samsung Health Light
  _def(
    'samsung_light',
    'Samsung Health Puro',
    'Blanco clínico mate, tarjetas suaves y frescura visual de día.',
    bg: 0xFFF5F6FA,
    bg2: 0xFFFFFFFF,
    bg3: 0xFFEBEDF5,
    line: 0x33CBD5E1,
    line2: 0xFFCBD5E1,
    text: 0xFF0F172A,
    text2: 0xFF475569,
    text3: 0xFF8292A6,
    accent: 0xFF00A87B,
    accent2: 0xFF007E5B,
    ink: 0xFFFFFFFF,
  ),

  // 3. Arcilla Nocturna
  _def(
    'arcilla_nocturna',
    'Arcilla Cálida',
    'Tonos tierra cálidos y relajantes para reducir fatiga visual.',
    bg: 0xFF181513,
    bg2: 0xFF221C18,
    bg3: 0xFF302823,
    line: 0x334B3F37,
    line2: 0xFF4B3F37,
    text: 0xFFF6F3EE,
    text2: 0xFFC5B9B0,
    text3: 0xFF8E8277,
    accent: 0xFFE07A52,
    accent2: 0xFFC15F3C,
    ink: 0xFFFFFFFF,
  ),

  // 4. Negro Puro OLED
  _def(
    'negro_oled',
    'Negro Puro (OLED)',
    'Contraste infinito a 0 nits para paneles AMOLED y ahorro de batería.',
    bg: 0xFF000000,
    bg2: 0xFF0A0C0F,
    bg3: 0xFF14181F,
    line: 0x3328303C,
    line2: 0xFF28303C,
    text: 0xFFFFFFFF,
    text2: 0xFFA6B2C3,
    text3: 0xFF68768A,
    accent: 0xFF00F0B5,
    accent2: 0xFF00C794,
    ink: 0xFF000000,
  ),

  // 5. NXTPAPER Color Paper
  _def(
    'nxtpaper_color_paper',
    'NXTPAPER Color Paper',
    'Pantalla mate con acabado de papel satinado para exteriores.',
    bg: 0xFFF3EFE6,
    bg2: 0xFFFFFFFF,
    bg3: 0xFFEAE4D7,
    line: 0x40948979,
    line2: 0xFF948979,
    text: 0xFF221E19,
    text2: 0xFF5A5246,
    text3: 0xFF867D6F,
    accent: 0xFF0D7490,
    accent2: 0xFF085266,
    ink: 0xFFFFFFFF,
    isFlat: true,
  ),

  // 6. NXTPAPER E-Ink Tinta Claro
  _def(
    'nxtpaper_eink_light',
    'Modo Papel E-Ink Claro',
    'Bordes sólidos de 1.5px, cero sombras, cero desenfoques y cero estelas.',
    bg: 0xFFF7F5F0,
    bg2: 0xFFFFFFFF,
    bg3: 0xFFFFFFFF,
    line: 0xFF121212,
    line2: 0xFF121212,
    text: 0xFF121212,
    text2: 0xFF333333,
    text3: 0xFF666666,
    accent: 0xFF121212,
    accent2: 0xFF000000,
    ink: 0xFFFFFFFF,
    isFlat: true,
  ),

  // 7. NXTPAPER E-Ink Tinta Oscuro
  _def(
    'nxtpaper_eink_dark',
    'Modo Papel E-Ink Oscuro',
    'Tinta marfil sobre pizarra mate con definición milimétrica sin ghosting.',
    bg: 0xFF101214,
    bg2: 0xFF181A1D,
    bg3: 0xFF181A1D,
    line: 0xFFEAE6DF,
    line2: 0xFFEAE6DF,
    text: 0xFFEAE6DF,
    text2: 0xFFCCCCCC,
    text3: 0xFF999999,
    accent: 0xFFEAE6DF,
    accent2: 0xFFFFFFFF,
    ink: 0xFF101214,
    isFlat: true,
  ),
];

final Map<String, ScThemeDef> _porKey = <String, ScThemeDef>{
  for (final ScThemeDef def in kScThemes) def.key: def,
};

/// Resuelve la definición de un tema a partir de su clave.
ScThemeDef scThemeByKey(String key) => _porKey[key] ?? kScThemes.first;

/// Constructor del [ThemeData] final con tipografías y extensiones de tokens.
abstract final class ScTheme {
  static ThemeData build(String key) {
    final ScThemeDef def = scThemeByKey(key);
    final ScColors c = def.colors;
    final Brightness brightness = def.brightness;

    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: c.accent,
      brightness: brightness,
      surface: c.bg,
      onSurface: c.text,
      primary: c.accent,
      onPrimary: c.ink,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      fontFamily: ScFonts.ui,
      splashFactory: c.isFlat ? NoSplash.splashFactory : InkSparkle.splashFactory,
      extensions: <ThemeExtension<dynamic>>[c],
      textTheme: _textTheme(c),
      iconTheme: IconThemeData(color: c.text, size: 22),
      dividerColor: c.line,
      cardTheme: CardThemeData(
        color: c.bg2,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: c.isFlat
              ? BorderSide(color: c.line2, width: 1.5)
              : BorderSide(color: c.line, width: 1.0),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: ScFonts.display,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: c.text,
        ),
      ),
    );
  }

  static TextTheme _textTheme(ScColors c) {
    TextStyle display(double size, FontWeight w) => TextStyle(
          fontFamily: ScFonts.display,
          fontSize: size,
          fontWeight: w,
          letterSpacing: -0.02 * size,
          color: c.text,
          height: 1.15,
        );

    TextStyle ui(double size, FontWeight w, Color color) => TextStyle(
          fontFamily: ScFonts.ui,
          fontSize: size,
          fontWeight: w,
          color: color,
        );

    return TextTheme(
      displayLarge: display(32, FontWeight.w800),
      displayMedium: display(26, FontWeight.w800),
      displaySmall: display(22, FontWeight.w800),
      headlineMedium: display(20, FontWeight.w800),
      headlineSmall: display(18, FontWeight.w700),
      titleLarge: display(17, FontWeight.w700),
      titleMedium: ui(15, FontWeight.w600, c.text),
      titleSmall: ui(13.5, FontWeight.w600, c.text),
      bodyLarge: ui(15, FontWeight.w500, c.text),
      bodyMedium: ui(13.5, FontWeight.w500, c.text2),
      bodySmall: ui(12.5, FontWeight.w500, c.text3),
      labelLarge: ui(13.5, FontWeight.w700, c.text),
      labelMedium: ui(12, FontWeight.w600, c.text2),
      labelSmall: ui(11, FontWeight.w600, c.text3),
    );
  }
}

