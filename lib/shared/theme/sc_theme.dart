import 'package:flutter/material.dart';

import 'sc_colors.dart';
import 'sc_tokens.dart';

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
  int carbs = 0xFFF59E0B,
  int fat = 0xFFFB7185,
  int water = 0xFF38BDF8,
  int steps = 0xFF84CC16,
  int fasting = 0xFFA855F7,
  int success = 0xFF10B981,
  int warning = 0xFFF59E0B,
  int danger = 0xFFEF4444,
  bool isFlat = false,
  bool isMonochromeEink = false,
}) {
  final Color accentCol = Color(accent);
  final Color textCol = Color(text);
  final Color text2Col = Color(text2);
  final Color resolvedInk = ink != null
      ? Color(ink)
      : (accentCol.computeLuminance() > 0.55 ? const Color(0xFF0A0C10) : const Color(0xFFFFFFFF));
  return ScColors(
    bg: Color(bg),
    bg2: Color(bg2),
    bg3: Color(bg3),
    line: Color(line),
    line2: Color(line2),
    text: textCol,
    text2: text2Col,
    text3: Color(text3),
    accent: accentCol,
    accent2: Color(accent2),
    ink: resolvedInk,
    soft: accentCol.withValues(alpha: isFlat ? 0.08 : 0.16),
    ambient: accentCol.withValues(alpha: isFlat ? 0.0 : 0.25),
    calories: isMonochromeEink ? textCol : Color(calories),
    protein: isMonochromeEink ? textCol : Color(protein),
    // En tinta, carbohidratos y grasas se distinguen por intensidad (tinta
    // diluida sobre el papel del propio tema, también en sepia).
    carbs: isMonochromeEink ? Color.lerp(textCol, Color(bg), 0.35)! : Color(carbs),
    fat: isMonochromeEink ? Color.lerp(textCol, Color(bg), 0.6)! : Color(fat),
    water: isMonochromeEink ? textCol : Color(water),
    steps: isMonochromeEink ? textCol : Color(steps),
    fasting: isMonochromeEink ? textCol : Color(fasting),
    success: isMonochromeEink ? textCol : Color(success),
    warning: isMonochromeEink ? textCol : Color(warning),
    danger: isMonochromeEink ? textCol : Color(danger),
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
  int carbs = 0xFFF59E0B,
  int fat = 0xFFFB7185,
  int water = 0xFF38BDF8,
  int steps = 0xFF84CC16,
  int fasting = 0xFFA855F7,
  int success = 0xFF10B981,
  int warning = 0xFFF59E0B,
  int danger = 0xFFEF4444,
  bool isFlat = false,
  bool isMonochromeEink = false,
}) {
  final Brightness brightness = Color(bg).computeLuminance() > 0.5
      ? Brightness.light
      : Brightness.dark;

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
      carbs: carbs,
      fat: fat,
      water: water,
      steps: steps,
      fasting: fasting,
      success: success,
      warning: warning,
      danger: danger,
      isFlat: isFlat,
      isMonochromeEink: isMonochromeEink,
    ),
  );
}

/// Catálogo de temas de salud de alta gama (vibras diversas, modos de alto contraste y NXTPAPER).
final List<ScThemeDef> kScThemes = <ScThemeDef>[
  // 1. Esmeralda Nocturna
  _def(
    'samsung_dark',
    'Esmeralda Nocturna',
    'Fondo carbón satinado, tarjetas limpias y acento esmeralda radiante.',
    bg: 0xFF0B0E14,
    bg2: 0xFF151922,
    bg3: 0xFF1E2430,
    line: 0x24334155,
    line2: 0xFF2D3748,
    text: 0xFFFFFFFF,
    text2: 0xFFB2BAC6,
    text3: 0xFF7A8598,
    accent: 0xFF00E5A3,
    accent2: 0xFF00B882,
    ink: 0xFF07120E,
  ),

  // 2. Jardín de Jade (Claro)
  _def(
    'samsung_light',
    'Jardín de Jade',
    'Blanco clínico mate, tarjetas suaves y frescura visual de día.',
    bg: 0xFFF5F6FA,
    bg2: 0xFFFFFFFF,
    bg3: 0xFFEBEDF5,
    line: 0x33CBD5E1,
    line2: 0xFFCBD5E1,
    text: 0xFF0F172A,
    text2: 0xFF475569,
    text3: 0xFF627083,
    accent: 0xFF008461,
    accent2: 0xFF006249,
    ink: 0xFFFFFFFF,
    carbs: 0xFFD97706,
    fat: 0xFFE11D48,
    water: 0xFF0284C7,
    steps: 0xFF65A30D,
    fasting: 0xFF7C3AED,
  ),

  // 2b. Salvia y Lino (Claro)
  _def(
    'salvia_lino',
    'Salvia y Lino',
    'Lino cálido, verde salvia y cifras en tinta: calma de día sin blanco clínico.',
    bg: 0xFFF5F2EA,
    bg2: 0xFFFFFDF8,
    bg3: 0xFFECE7DC,
    line: 0x1F3A3328,
    line2: 0xFFDCD5C6,
    text: 0xFF1D221E,
    text2: 0xFF48514A,
    text3: 0xFF646D65,
    accent: 0xFF537E61,
    accent2: 0xFF3D624A,
    ink: 0xFFFFFFFF,
    calories: 0xFFC4472D,
    protein: 0xFF0E7C74,
    carbs: 0xFFA86A06,
    fat: 0xFFC23A5E,
    water: 0xFF2470B3,
    steps: 0xFF527A18,
    fasting: 0xFF6F45C4,
    success: 0xFF2F7D4F,
    warning: 0xFFA86A06,
    danger: 0xFFC62F2F,
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
    text3: 0xFF908479,
    accent: 0xFFE07A52,
    accent2: 0xFFC15F3C,
    ink: 0xFF1F0E06,
  ),

  // 4. Negro Puro OLED
  _def(
    'negro_oled',
    'Negro Puro AMOLED',
    'Contraste infinito a 0 nits para paneles AMOLED y ahorro de batería.',
    bg: 0xFF000000,
    bg2: 0xFF0A0C0F,
    bg3: 0xFF14181F,
    line: 0x3328303C,
    line2: 0xFF28303C,
    text: 0xFFFFFFFF,
    text2: 0xFFA6B2C3,
    text3: 0xFF717E91,
    accent: 0xFF00F0B5,
    accent2: 0xFF00C794,
    ink: 0xFF000000,
  ),

  // 5. NXTPAPER Color Paper
  _def(
    'nxtpaper_color_paper',
    'Papel en color',
    'Colores suaves sobre fondo mate, cómodo al sol.',
    bg: 0xFFF3EFE6,
    bg2: 0xFFFFFFFF,
    bg3: 0xFFEAE4D7,
    line: 0x66786E5F,
    line2: 0xFF645A4D,
    text: 0xFF221E19,
    text2: 0xFF5A5246,
    text3: 0xFF726A5D,
    accent: 0xFF0D7490,
    accent2: 0xFF085266,
    ink: 0xFFFFFFFF,
    calories: 0xFFC2410C,
    protein: 0xFF0F766E,
    carbs: 0xFFB45309,
    fat: 0xFFBE123C,
    water: 0xFF0369A1,
    steps: 0xFF4D7C0F,
    fasting: 0xFF6D28D9,
    isFlat: true,
  ),

  // 6. NXTPAPER E-Ink Tinta Claro
  _def(
    'nxtpaper_eink_light',
    'Papel claro',
    'Tinta negra sobre papel: máximo contraste y sin estelas.',
    bg: 0xFFF7F5F0,
    bg2: 0xFFFFFFFF,
    bg3: 0xFFF0EDE5,
    line: 0xFF121212,
    line2: 0xFF121212,
    text: 0xFF121212,
    text2: 0xFF333333,
    text3: 0xFF595959,
    accent: 0xFF121212,
    accent2: 0xFF000000,
    ink: 0xFFFFFFFF,
    isFlat: true,
    isMonochromeEink: true,
  ),

  // 7. NXTPAPER E-Ink Tinta Oscuro
  _def(
    'nxtpaper_eink_dark',
    'Papel oscuro',
    'Tinta clara sobre fondo oscuro, para leer de noche.',
    bg: 0xFF101214,
    bg2: 0xFF181A1D,
    bg3: 0xFF202327,
    line: 0xFFEAE6DF,
    line2: 0xFFEAE6DF,
    text: 0xFFEAE6DF,
    text2: 0xFFCCCCCC,
    text3: 0xFF999999,
    accent: 0xFFEAE6DF,
    accent2: 0xFFFFFFFF,
    ink: 0xFF101214,
    isFlat: true,
    isMonochromeEink: true,
  ),

  // 7b. NXTPAPER Sepia
  _def(
    'nxtpaper_sepia',
    'Papel sepia',
    'Tinta marrón sobre papel crema: menos luz azul para leer de noche.',
    bg: 0xFFF3EBDC,
    bg2: 0xFFFAF5EA,
    bg3: 0xFFEBE1CF,
    line: 0xFF3B2F22,
    line2: 0xFF3B2F22,
    text: 0xFF2E2418,
    text2: 0xFF4A3D2E,
    text3: 0xFF66584A,
    accent: 0xFF3B2F22,
    accent2: 0xFF2E2418,
    ink: 0xFFFAF5EA,
    isFlat: true,
    isMonochromeEink: true,
  ),

  // 8. Zafiro Profundo
  _def(
    'zafiro_profundo',
    'Zafiro Profundo',
    'Azul medianoche profundo con destellos zafiro y calma mental.',
    bg: 0xFF090E17,
    bg2: 0xFF101827,
    bg3: 0xFF19243A,
    line: 0x2638BDF8,
    line2: 0xFF233550,
    text: 0xFFF8FAFC,
    text2: 0xFF94A3B8,
    text3: 0xFF768499,
    accent: 0xFF38BDF8,
    accent2: 0xFF0284C7,
    ink: 0xFF03101C,
    calories: 0xFFFB7185,
    protein: 0xFF38BDF8,
    carbs: 0xFFFBBF24,
    water: 0xFF60A5FA,
  ),

  // 9. Amatista Mística
  _def(
    'amatista_zen',
    'Amatista Mística',
    'Misterio violeta y serenidad nocturna para un enfoque zen.',
    bg: 0xFF110D1A,
    bg2: 0xFF1B1429,
    bg3: 0xFF261D3A,
    line: 0x26C084FC,
    line2: 0xFF3D2F5C,
    text: 0xFFFAF5FF,
    text2: 0xFFD8B4FE,
    text3: 0xFF9576B9,
    accent: 0xFFC084FC,
    accent2: 0xFFA855F7,
    ink: 0xFF18082A,
    fasting: 0xFFE879F9,
  ),

  // 10. Atardecer Dorado
  _def(
    'atardecer_dorado',
    'Atardecer Dorado',
    'Calidez crepuscular, tonos cobrizos y energía dorada estimulante.',
    bg: 0xFF140F0A,
    bg2: 0xFF1E1710,
    bg3: 0xFF2C2117,
    line: 0x26F59E0B,
    line2: 0xFF4A3826,
    text: 0xFFFFFBEB,
    text2: 0xFFFDE68A,
    text3: 0xFFB49B60,
    accent: 0xFFF59E0B,
    accent2: 0xFFD97706,
    ink: 0xFF1F1200,
    calories: 0xFFF97316,
  ),

  // 11. Neón Cyberpunk
  _def(
    'cyberpunk_neon',
    'Neón Cyberpunk',
    'Pizarra negra con fluor cian ultra-eléctrico y máxima vibra futurista.',
    bg: 0xFF08080C,
    bg2: 0xFF11111A,
    bg3: 0xFF1B1B29,
    line: 0x3300F5D4,
    line2: 0xFF2D2D44,
    text: 0xFFFFFFFF,
    text2: 0xFFA5B4FC,
    text3: 0xFF7275F3,
    accent: 0xFF00F5D4,
    accent2: 0xFF00BB9F,
    ink: 0xFF001814,
    calories: 0xFFFF2A85,
    carbs: 0xFFFFDE59,
  ),

  // 12. Bosque Boreal
  _def(
    'bosque_boreal',
    'Bosque Boreal',
    'Pino nórdico oscuro, aire puro de montaña y concentración orgánica.',
    bg: 0xFF0A1310,
    bg2: 0xFF12201B,
    bg3: 0xFF192C26,
    line: 0x2634D399,
    line2: 0xFF28463D,
    text: 0xFFECFDF5,
    text2: 0xFFA7F3D0,
    text3: 0xFF64907E,
    accent: 0xFF34D399,
    accent2: 0xFF059669,
    ink: 0xFF031A11,
  ),

  // 13. Rubí Carmesí
  _def(
    'rubi_carmesi',
    'Rubí Carmesí',
    'Grafito de lujo con matices carmesí vibrantes y porte audaz.',
    bg: 0xFF140A0D,
    bg2: 0xFF1F1015,
    bg3: 0xFF2B171E,
    line: 0x26FB7185,
    line2: 0xFF4A2533,
    text: 0xFFFFF1F2,
    text2: 0xFFFECDD3,
    text3: 0xFFA7737D,
    accent: 0xFFFB7185,
    accent2: 0xFFE11D48,
    ink: 0xFF1C0207,
  ),

  // 14. Sakura Crepúsculo
  _def(
    'cerezo_sakura',
    'Sakura Crepúsculo',
    'Noche de primavera oriental con acentos florales suaves y equilibrio.',
    bg: 0xFF130D14,
    bg2: 0xFF1D141F,
    bg3: 0xFF291C2C,
    line: 0x26F472B6,
    line2: 0xFF472E4C,
    text: 0xFFFDF2F8,
    text2: 0xFFFBCFE8,
    text3: 0xFFA27592,
    accent: 0xFFF472B6,
    accent2: 0xFFDB2777,
    ink: 0xFF1E0213,
  ),

  // 15. Bronce & Espresso
  _def(
    'bronce_antiguo',
    'Bronce & Espresso',
    'Café de tueste natural y bronce vintage con textura reconfortante.',
    bg: 0xFF14110E,
    bg2: 0xFF1E1914,
    bg3: 0xFF29221C,
    line: 0x26D97706,
    line2: 0xFF473A2F,
    text: 0xFFFEF3C7,
    text2: 0xFFDEB887,
    text3: 0xFF97826A,
    accent: 0xFFD97706,
    accent2: 0xFFB45309,
    ink: 0xFF1F0E00,
  ),

  // 16. Hielo Ártico
  _def(
    'hielo_artico',
    'Hielo Ártico',
    'Frescura glaciar pura, calma respiratoria y claridad mental.',
    bg: 0xFF0B1319,
    bg2: 0xFF121E27,
    bg3: 0xFF1B2A37,
    line: 0x2667E8F9,
    line2: 0xFF2A4255,
    text: 0xFFECFEFF,
    text2: 0xFFA5F3FC,
    text3: 0xFF668B9A,
    accent: 0xFF67E8F9,
    accent2: 0xFF06B6D4,
    ink: 0xFF021B20,
  ),

  // 17. Lavanda Serenade (Claro)
  _def(
    'lavanda_calma',
    'Lavanda Serenade',
    'Luz matinal suave con tonos lila calmantes para bajar el cortisol.',
    bg: 0xFFF7F5FC,
    bg2: 0xFFFFFFFF,
    bg3: 0xFFEDE7F7,
    line: 0x338B5CF6,
    line2: 0xFFD6C8F2,
    text: 0xFF1E1430,
    text2: 0xFF554472,
    text3: 0xFF776693,
    accent: 0xFF8452F5,
    accent2: 0xFF6D28D9,
    ink: 0xFFFFFFFF,
  ),

  // 18. Menta Cristalina (Claro)
  _def(
    'menta_cristalina',
    'Menta Cristalina',
    'Frescor botánico matutino, ligereza diurna y claridad clínica.',
    bg: 0xFFF0FDF8,
    bg2: 0xFFFFFFFF,
    bg3: 0xFFE0F7ED,
    line: 0x3310B981,
    line2: 0xFFC0ECDB,
    text: 0xFF0D251C,
    text2: 0xFF356150,
    text3: 0xFF4E7968,
    accent: 0xFF0C855D,
    accent2: 0xFF065F46,
    ink: 0xFFFFFFFF,
  ),

  // 19. Duna Sahariana
  _def(
    'duna_sahara',
    'Duna Sahariana',
    'Arenas cálidas y viento del desierto con un naranja fuego revitalizante.',
    bg: 0xFF16120D,
    bg2: 0xFF211B14,
    bg3: 0xFF2E261C,
    line: 0x26F97316,
    line2: 0xFF4A3D2D,
    text: 0xFFFFF7ED,
    text2: 0xFFFED7AA,
    text3: 0xFF9E8062,
    accent: 0xFFF97316,
    accent2: 0xFFEA580C,
    ink: 0xFF1F0800,
  ),

  // 20. Nebulosa Cósmica
  _def(
    'nebulosa_cosmica',
    'Nebulosa Cósmica',
    'Cielo astronómico y misterio interestelar en cada indicador biométrico.',
    bg: 0xFF0B0916,
    bg2: 0xFF151128,
    bg3: 0xFF201A3C,
    line: 0x26818CF8,
    line2: 0xFF362C61,
    text: 0xFFEEF2FF,
    text2: 0xFFC7D2FE,
    text3: 0xFF7D87BA,
    accent: 0xFF818CF8,
    accent2: 0xFF6366F1,
    ink: 0xFF070420,
  ),

  // 21. Titanio Industrial
  _def(
    'titanio_minimal',
    'Titanio Industrial',
    'Titanio cepillado con verde lima atlético de alto rendimiento.',
    bg: 0xFF0F1215,
    bg2: 0xFF181C21,
    bg3: 0xFF22272E,
    line: 0x26A3E635,
    line2: 0xFF313B45,
    text: 0xFFF4F4F5,
    text2: 0xFFA1A1AA,
    text3: 0xFF86868E,
    accent: 0xFFA3E635,
    accent2: 0xFF84CC16,
    ink: 0xFF111E02,
  ),

  // 22. Coral Abisal
  _def(
    'coral_abisal',
    'Coral Abisal',
    'Profundidades marinas con destellos de coral vivo bioluminiscente.',
    bg: 0xFF091216,
    bg2: 0xFF101E24,
    bg3: 0xFF182931,
    line: 0x26FF5E57,
    line2: 0xFF27434F,
    text: 0xFFF0FDFA,
    text2: 0xFF99F6E4,
    text3: 0xFF5D969B,
    accent: 0xFFFF5E57,
    accent2: 0xFFFF3F34,
    ink: 0xFF200302,
  ),
];

final Map<String, ScThemeDef> _porKey = <String, ScThemeDef>{
  for (final ScThemeDef def in kScThemes) def.key: def,
};

/// Resuelve la definición de un tema a partir de su clave.
ScThemeDef scThemeByKey(String key) => _porKey[key] ?? kScThemes.first;

/// Tema "Colores de tu fondo" (Material You, Android 12+): las superficies de
/// Esmeralda/Jade según el modo del sistema y el acento del fondo de pantalla.
const String kDynamicThemeKey = 'dynamic_wallpaper';

ScThemeDef dynamicThemeDef(ColorScheme wallpaper) {
  final bool dark = wallpaper.brightness == Brightness.dark;
  final ScThemeDef base = scThemeByKey(dark ? 'samsung_dark' : 'samsung_light');
  return ScThemeDef(
    key: kDynamicThemeKey,
    label: base.label,
    description: base.description,
    brightness: wallpaper.brightness,
    colors: base.colors.copyWith(
      accent: wallpaper.primary,
      accent2: wallpaper.secondary,
      ink: wallpaper.onPrimary,
      soft: wallpaper.primaryContainer.withValues(alpha: dark ? 0.35 : 0.6),
    ),
  );
}

/// Transición instantánea entre páginas (Modo Papel: un solo refresco de tinta).
class _InstantPageTransitionsBuilder extends PageTransitionsBuilder {
  const _InstantPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

/// Constructor del [ThemeData] final con tipografías y extensiones de tokens.
abstract final class ScTheme {
  static ThemeData build(String key, {ScThemeDef? override}) {
    final ScThemeDef def = override ?? scThemeByKey(key);
    final ScColors c = def.colors;
    final Brightness brightness = def.brightness;
    final bool dark = brightness == Brightness.dark;
    final bool flat = c.isFlat;

    final double cardRadius = ScRadius.cardOf(c);
    final double controlRadius = ScRadius.controlOf(c);

    // Contenedor tonal propio del tema (en lugar del derivado del color
    // semilla, que tiñe los controles con un tono ajeno a la paleta).
    final Color tonal = flat
        ? c.bg3
        : Color.alphaBlend(c.accent.withValues(alpha: dark ? 0.18 : 0.14), c.bg2);
    final Color onTonal = flat
        ? c.text
        : (dark ? Color.lerp(c.accent, Colors.white, 0.2)! : c.accent2);

    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: c.accent,
      brightness: brightness,
      surface: c.bg,
      onSurface: c.text,
      onSurfaceVariant: c.text2,
      primary: c.accent,
      onPrimary: c.ink,
      primaryContainer: tonal,
      onPrimaryContainer: onTonal,
      secondary: flat ? c.text : c.accent2,
      onSecondary: flat ? c.bg : c.ink,
      secondaryContainer: tonal,
      onSecondaryContainer: onTonal,
      error: c.danger,
      outline: c.line2,
      outlineVariant: flat ? c.line2 : c.line,
      surfaceTint: Colors.transparent,
      surfaceContainerLowest: c.bg,
      surfaceContainerLow: c.bg2,
      surfaceContainer: c.bg2,
      surfaceContainerHigh: c.bg3,
      surfaceContainerHighest: c.bg3,
    );

    final BorderSide hairline = BorderSide(color: flat ? c.line2 : c.line, width: flat ? 1.5 : 1.0);
    final RoundedRectangleBorder controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(controlRadius),
      side: flat ? BorderSide(color: c.line2, width: 1.5) : BorderSide.none,
    );
    const TextStyle buttonText = TextStyle(
      fontFamily: ScFonts.ui,
      fontSize: 14.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.1,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      fontFamily: ScFonts.ui,
      // InkRipple: más ligero que InkSparkle (sin sombreador) y más sobrio.
      splashFactory: flat ? NoSplash.splashFactory : InkRipple.splashFactory,
      highlightColor: flat ? Colors.transparent : c.text.withValues(alpha: 0.04),
      splashColor: flat ? Colors.transparent : c.text.withValues(alpha: 0.08),
      extensions: <ThemeExtension<dynamic>>[c],
      textTheme: _textTheme(c),
      iconTheme: IconThemeData(color: c.text, size: 22),
      dividerColor: flat ? c.line2 : c.line,
      // Separadores de lista: en papel, tinta gris fina (los bordes de tarjeta
      // siguen siendo de 1,5 px en tinta plena).
      dividerTheme: DividerThemeData(color: flat ? c.text3 : c.line, thickness: 1, space: 1),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          for (final TargetPlatform p in TargetPlatform.values)
            p: flat
                ? const _InstantPageTransitionsBuilder()
                : const FadeForwardsPageTransitionsBuilder(),
        },
      ),
      cardTheme: CardThemeData(
        color: c.bg2,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: hairline,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        // Sin colores fijos: FilledButton toma primary/onPrimary y
        // FilledButton.tonal el contenedor tonal del esquema.
        style: FilledButton.styleFrom(
          elevation: 0,
          disabledBackgroundColor: c.bg3,
          disabledForegroundColor: c.text3,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: buttonText,
          shape: controlShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        // Botón secundario: superficie tonal sin contorno en color; contorno de
        // tinta en papel.
        style: OutlinedButton.styleFrom(
          elevation: 0,
          foregroundColor: c.text,
          backgroundColor: flat ? Colors.transparent : c.bg3,
          disabledForegroundColor: c.text3,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: buttonText,
          side: flat ? BorderSide(color: c.line2, width: 1.5) : BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(controlRadius)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: flat ? c.text : c.accent,
          minimumSize: const Size(48, 48),
          textStyle: buttonText,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(controlRadius)),
        ),
      ),
      // Sin color fijo: el estándar toma onSurfaceVariant (text2) y las
      // variantes rellenas su color sobre el acento (antes el icono de
      // IconButton.filled quedaba gris sobre el acento).
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.accent,
        foregroundColor: c.ink,
        elevation: flat ? 0 : 2,
        focusElevation: flat ? 0 : 2,
        hoverElevation: flat ? 0 : 3,
        highlightElevation: flat ? 0 : 3,
        shape: controlShape,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((Set<WidgetState> s) {
          if (s.contains(WidgetState.selected)) return c.ink;
          return flat ? c.text : c.text3;
        }),
        trackColor: WidgetStateProperty.resolveWith((Set<WidgetState> s) {
          if (s.contains(WidgetState.selected)) return c.accent;
          return flat ? c.bg : c.bg3;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((Set<WidgetState> s) {
          if (flat) return c.line2;
          return s.contains(WidgetState.selected) ? c.accent : c.line2;
        }),
        trackOutlineWidth: WidgetStatePropertyAll<double>(flat ? 1.5 : 1),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> s) => s.contains(WidgetState.selected) ? c.accent : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll<Color>(c.ink),
        side: BorderSide(color: flat ? c.line2 : c.text3, width: flat ? 1.5 : 1.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(flat ? 3 : 6)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> s) => s.contains(WidgetState.selected) ? c.accent : c.text3,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.accent,
        inactiveTrackColor: flat ? c.bg3 : c.accent.withValues(alpha: 0.18),
        thumbColor: c.accent,
        overlayColor: flat ? Colors.transparent : c.accent.withValues(alpha: 0.12),
        valueIndicatorColor: c.accent,
        valueIndicatorTextStyle: TextStyle(
          fontFamily: ScFonts.display,
          fontWeight: FontWeight.w700,
          color: c.ink,
        ),
        trackHeight: 6,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (Set<WidgetState> s) =>
                s.contains(WidgetState.selected) ? (flat ? c.text : tonal) : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (Set<WidgetState> s) =>
                s.contains(WidgetState.selected) ? (flat ? c.bg : onTonal) : c.text2,
          ),
          side: WidgetStatePropertyAll<BorderSide>(
            BorderSide(color: flat ? c.line2 : c.line2, width: flat ? 1.5 : 1),
          ),
          textStyle: const WidgetStatePropertyAll<TextStyle>(
            TextStyle(fontFamily: ScFonts.ui, fontSize: 13, fontWeight: FontWeight.w700),
          ),
          minimumSize: const WidgetStatePropertyAll<Size>(Size(48, 44)),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(controlRadius)),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: flat ? c.bg2 : c.bg3,
        selectedColor: flat ? c.text : tonal,
        disabledColor: c.bg3,
        // Seleccionado en papel: tinta invertida (texto del color del papel).
        labelStyle: TextStyle(
          fontFamily: ScFonts.ui,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: WidgetStateColor.resolveWith(
            (Set<WidgetState> states) =>
                states.contains(WidgetState.selected) ? (flat ? c.bg : onTonal) : c.text,
          ),
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: ScFonts.ui,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: flat ? c.bg : onTonal,
        ),
        checkmarkColor: flat ? c.bg : onTonal,
        side: flat ? BorderSide(color: c.line2, width: 1.5) : BorderSide.none,
        shape: StadiumBorder(side: flat ? BorderSide(color: c.line2, width: 1.5) : BorderSide.none),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: flat ? c.bg3 : c.text.withValues(alpha: dark ? 0.08 : 0.07),
        circularTrackColor: flat ? c.bg3 : c.text.withValues(alpha: dark ? 0.08 : 0.07),
        linearMinHeight: 6,
        borderRadius: BorderRadius.circular(99),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.text2,
        textColor: c.text,
        titleTextStyle: TextStyle(
          fontFamily: ScFonts.ui,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: c.text,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: ScFonts.ui,
          fontSize: 12.5,
          color: c.text2,
          height: 1.35,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(controlRadius)),
        minVerticalPadding: 10,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: flat ? c.bg2 : c.bg3,
        hintStyle: TextStyle(fontFamily: ScFonts.ui, fontSize: 14.5, color: c.text3),
        labelStyle: TextStyle(fontFamily: ScFonts.ui, color: c.text2),
        floatingLabelStyle: TextStyle(
          fontFamily: ScFonts.ui,
          fontWeight: FontWeight.w700,
          color: flat ? c.text : c.accent,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: flat ? hairline : BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: flat ? hairline : BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: flat ? c.text : c.accent, width: flat ? 2.5 : 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: c.danger, width: 1.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.bg2,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: ScFonts.display,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: c.text,
        ),
        contentTextStyle: TextStyle(
          fontFamily: ScFonts.ui,
          fontSize: 14,
          color: c.text2,
          height: 1.45,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(flat ? cardRadius : 28),
          side: hairline,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.bg2,
        elevation: 0,
        modalElevation: 0,
        dragHandleColor: flat ? c.line2 : c.text3.withValues(alpha: 0.5),
        dragHandleSize: const Size(36, 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(flat ? cardRadius : 28)),
          side: hairline,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.bg2,
        elevation: flat ? 0 : 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          side: hairline,
        ),
        textStyle: TextStyle(fontFamily: ScFonts.ui, fontSize: 14, color: c.text),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: flat ? c.bg2 : c.text,
          borderRadius: BorderRadius.circular(8),
          border: flat ? Border.all(color: c.line2, width: 1.5) : null,
        ),
        textStyle: TextStyle(
          fontFamily: ScFonts.ui,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: flat ? c.text : c.bg,
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: c.bg2,
        elevation: 0,
        headerBackgroundColor: flat ? c.bg2 : tonal,
        headerForegroundColor: flat ? c.text : onTonal,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(flat ? cardRadius : 28),
          side: hairline,
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: c.bg2,
        elevation: 0,
        hourMinuteColor: WidgetStateColor.resolveWith(
          (Set<WidgetState> s) => s.contains(WidgetState.selected) ? tonal : c.bg3,
        ),
        hourMinuteTextColor: WidgetStateColor.resolveWith(
          (Set<WidgetState> s) => s.contains(WidgetState.selected) ? onTonal : c.text,
        ),
        dialBackgroundColor: c.bg3,
        // Los campos del modo "escribir la hora" no heredan el relleno amplio de
        // los formularios: el número queda centrado en su casilla.
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: c.bg3,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(controlRadius),
            borderSide: flat ? hairline : BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(controlRadius),
            borderSide: BorderSide(color: flat ? c.text : c.accent, width: 2),
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(flat ? cardRadius : 28),
          side: hairline,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: flat ? c.bg2 : c.text,
        contentTextStyle: TextStyle(
          fontFamily: ScFonts.ui,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: flat ? c.text : c.bg,
        ),
        actionTextColor: flat
            ? c.text
            : (dark ? c.accent2 : Color.lerp(c.accent, Colors.white, 0.35)),
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          side: flat ? BorderSide(color: c.line2, width: 1.5) : BorderSide.none,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        foregroundColor: c.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: ScFonts.display,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
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
      letterSpacing: -0.025 * size,
      color: c.text,
      height: 1.15,
    );

    TextStyle ui(double size, FontWeight w, Color color, {double height = 1.35}) => TextStyle(
      fontFamily: ScFonts.ui,
      fontSize: size,
      fontWeight: w,
      color: color,
      height: height,
    );

    return TextTheme(
      displayLarge: display(34, FontWeight.w700),
      displayMedium: display(28, FontWeight.w700),
      displaySmall: display(24, FontWeight.w700),
      headlineMedium: display(21, FontWeight.w700),
      headlineSmall: display(19, FontWeight.w700),
      titleLarge: display(17, FontWeight.w700),
      titleMedium: ui(15, FontWeight.w700, c.text),
      titleSmall: ui(13.5, FontWeight.w700, c.text),
      bodyLarge: ui(15, FontWeight.w500, c.text, height: 1.45),
      bodyMedium: ui(13.5, FontWeight.w500, c.text2, height: 1.45),
      bodySmall: ui(12.5, FontWeight.w500, c.text3),
      labelLarge: ui(14, FontWeight.w700, c.text, height: 1.2),
      labelMedium: ui(12, FontWeight.w600, c.text2, height: 1.2),
      labelSmall: ui(11, FontWeight.w600, c.text3, height: 1.2),
    );
  }
}
