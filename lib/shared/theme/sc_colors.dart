import 'package:flutter/material.dart';

/// Tokens de color del sistema de diseño NB Selfcare.
///
/// Expuestos como [ThemeExtension] para que cualquier widget los lea vía
/// `Theme.of(context).extension<ScColors>()` o el helper `context.sc`.
@immutable
class ScColors extends ThemeExtension<ScColors> {
  const ScColors({
    required this.bg,
    required this.bg2,
    required this.bg3,
    required this.line,
    required this.line2,
    required this.text,
    required this.text2,
    required this.text3,
    required this.accent,
    required this.accent2,
    required this.ink,
    required this.soft,
    required this.ambient,
    required this.calories,
    required this.protein,
    required this.water,
    required this.steps,
    required this.fasting,
    this.isFlat = false,
  });

  /// Fondo base de la app.
  final Color bg;

  /// Superficie elevada (tarjetas principales, hojas inferiores).
  final Color bg2;

  /// Superficie secundaria (chips, inputs, botones de acción).
  final Color bg3;

  /// Línea / borde sutil.
  final Color line;

  /// Línea / borde con alto contraste (definición nítida en E-Ink y Samsung Health).
  final Color line2;

  /// Texto primario de máximo contraste.
  final Color text;

  /// Texto secundario.
  final Color text2;

  /// Texto terciario / descriptivo / apagado.
  final Color text3;

  /// Color de acento de salud principal.
  final Color accent;

  /// Variante oscura o presionada del acento.
  final Color accent2;

  /// Color de contraste sobre el acento (texto/íconos en botones activos).
  final Color ink;

  /// Tinte translúcido suave del acento para fondos activos.
  final Color soft;

  /// Resplandor ambiental suave.
  final Color ambient;

  /// Color para métricas de calorías y energía (coral / naranja cálido).
  final Color calories;

  /// Color para métricas de proteína y músculo (cian / turquesa).
  final Color protein;

  /// Color para hidratación y agua (azul cielo).
  final Color water;

  /// Color para pasos y actividad física (verde lima salud).
  final Color steps;

  /// Color para ayuno intermitente y autofagia (púrpura / violeta místico).
  final Color fasting;

  /// Indica si el modo actual es plano (E-Ink NXTPAPER), suprimiendo desenfoques y sombras.
  final bool isFlat;

  @override
  ScColors copyWith({
    Color? bg,
    Color? bg2,
    Color? bg3,
    Color? line,
    Color? line2,
    Color? text,
    Color? text2,
    Color? text3,
    Color? accent,
    Color? accent2,
    Color? ink,
    Color? soft,
    Color? ambient,
    Color? calories,
    Color? protein,
    Color? water,
    Color? steps,
    Color? fasting,
    bool? isFlat,
  }) {
    return ScColors(
      bg: bg ?? this.bg,
      bg2: bg2 ?? this.bg2,
      bg3: bg3 ?? this.bg3,
      line: line ?? this.line,
      line2: line2 ?? this.line2,
      text: text ?? this.text,
      text2: text2 ?? this.text2,
      text3: text3 ?? this.text3,
      accent: accent ?? this.accent,
      accent2: accent2 ?? this.accent2,
      ink: ink ?? this.ink,
      soft: soft ?? this.soft,
      ambient: ambient ?? this.ambient,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      water: water ?? this.water,
      steps: steps ?? this.steps,
      fasting: fasting ?? this.fasting,
      isFlat: isFlat ?? this.isFlat,
    );
  }

  @override
  ScColors lerp(ThemeExtension<ScColors>? other, double t) {
    if (other is! ScColors) return this;
    return ScColors(
      bg: Color.lerp(bg, other.bg, t)!,
      bg2: Color.lerp(bg2, other.bg2, t)!,
      bg3: Color.lerp(bg3, other.bg3, t)!,
      line: Color.lerp(line, other.line, t)!,
      line2: Color.lerp(line2, other.line2, t)!,
      text: Color.lerp(text, other.text, t)!,
      text2: Color.lerp(text2, other.text2, t)!,
      text3: Color.lerp(text3, other.text3, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accent2: Color.lerp(accent2, other.accent2, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      soft: Color.lerp(soft, other.soft, t)!,
      ambient: Color.lerp(ambient, other.ambient, t)!,
      calories: Color.lerp(calories, other.calories, t)!,
      protein: Color.lerp(protein, other.protein, t)!,
      water: Color.lerp(water, other.water, t)!,
      steps: Color.lerp(steps, other.steps, t)!,
      fasting: Color.lerp(fasting, other.fasting, t)!,
      isFlat: t < 0.5 ? isFlat : other.isFlat,
    );
  }
}

/// Acceso ergonómico a los tokens vía `context.sc`.
extension ScColorsBuildContextX on BuildContext {
  ScColors get sc =>
      Theme.of(this).extension<ScColors>() ??
      const ScColors(
        bg: Color(0xFF0E1116),
        bg2: Color(0xFF181C24),
        bg3: Color(0xFF222732),
        line: Color(0x333A4454),
        line2: Color(0xFF3A4454),
        text: Color(0xFFFFFFFF),
        text2: Color(0xFFB5BDCA),
        text3: Color(0xFF7E8899),
        accent: Color(0xFF00D2A0),
        accent2: Color(0xFF00A381),
        ink: Color(0xFF0A0C10),
        soft: Color(0x2400D2A0),
        ambient: Color(0x3800D2A0),
        calories: Color(0xFFFF6B4A),
        protein: Color(0xFF00D2C4),
        water: Color(0xFF38BDF8),
        steps: Color(0xFF84CC16),
        fasting: Color(0xFFA855F7),
      );
}

