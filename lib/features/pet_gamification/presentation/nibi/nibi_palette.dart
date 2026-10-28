import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../../../shared/theme/sc_colors.dart';

/// Pelaje de Nibi que se compra en la tienda (`color_*`).
@immutable
class NibiSkin {
  const NibiSkin({
    required this.body,
    required this.bodyShade,
    required this.outline,
    required this.muzzle,
    required this.crest,
    required this.crestShade,
    this.belly = const Color(0xFFF7E4B5),
    this.bellyLine = const Color(0xFFD8B87A),
    this.horn = const Color(0xFFF5E9CC),
    this.inkTone = 0,
  });

  final Color body;
  final Color bodyShade;
  final Color outline;
  final Color muzzle;
  final Color crest;
  final Color crestShade;
  final Color belly;
  final Color bellyLine;
  final Color horn;

  /// Gris del cuerpo en papel: 0 = color del papel, 1 = tinta.
  final double inkTone;

  static const NibiSkin jade = NibiSkin(
    body: Color(0xFF6DAA5C),
    bodyShade: Color(0xFF4F8A45),
    outline: Color(0xFF26432A),
    muzzle: Color(0xFF8DC47A),
    crest: Color(0xFFE5734A),
    crestShade: Color(0xFFB9502F),
  );

  static const Map<String, NibiSkin> byId = <String, NibiSkin>{
    'color_jade': jade,
    'color_ocean': NibiSkin(
      body: Color(0xFF5B9BD5),
      bodyShade: Color(0xFF3F7DB8),
      outline: Color(0xFF1E3A5C),
      muzzle: Color(0xFF8BBDE8),
      crest: Color(0xFFF2C14E),
      crestShade: Color(0xFFC99A2E),
      belly: Color(0xFFF4EBD0),
      inkTone: 0.1,
    ),
    'color_lilac': NibiSkin(
      body: Color(0xFFA48AD4),
      bodyShade: Color(0xFF8468B8),
      outline: Color(0xFF3D2A5F),
      muzzle: Color(0xFFC1ACE6),
      crest: Color(0xFF6FD0C0),
      crestShade: Color(0xFF46A595),
      belly: Color(0xFFF6ECF8),
      bellyLine: Color(0xFFD3BEDF),
      inkTone: 0.08,
    ),
    'color_coral': NibiSkin(
      body: Color(0xFFF08A7E),
      bodyShade: Color(0xFFD26A5F),
      outline: Color(0xFF5A2620),
      muzzle: Color(0xFFF6ABA1),
      crest: Color(0xFF6CC3D5),
      crestShade: Color(0xFF4398AA),
      inkTone: 0.12,
    ),
    'color_ember': NibiSkin(
      body: Color(0xFFD9534F),
      bodyShade: Color(0xFFB23A37),
      outline: Color(0xFF4A1716),
      muzzle: Color(0xFFE88480),
      crest: Color(0xFFFFB347),
      crestShade: Color(0xFFD98A1E),
      belly: Color(0xFFFBE3B8),
      inkTone: 0.22,
    ),
    'color_midnight': NibiSkin(
      body: Color(0xFF46557A),
      bodyShade: Color(0xFF323E5C),
      outline: Color(0xFF121726),
      muzzle: Color(0xFF64739A),
      crest: Color(0xFF8FD3FF),
      crestShade: Color(0xFF5BA8D9),
      belly: Color(0xFFD4DCEF),
      bellyLine: Color(0xFFA3B0CE),
      horn: Color(0xFFE5ECFA),
      inkTone: 0.4,
    ),
    'color_gold': NibiSkin(
      body: Color(0xFFE8B84A),
      bodyShade: Color(0xFFC7962C),
      outline: Color(0xFF5A3D0E),
      muzzle: Color(0xFFF2D07E),
      crest: Color(0xFFD9534F),
      crestShade: Color(0xFFA83A37),
      belly: Color(0xFFFFF3D1),
      inkTone: 0.04,
    ),
  };

  static NibiSkin of(String? id) => byId[id] ?? jade;
}

/// Colores de Nibi. En color tiene su propia identidad (dragón verde con
/// crestas naranjas por defecto, igual en todos los temas, o el pelaje que se
/// compre); en papel es un dibujo de tinta sobre el papel del tema, con grises
/// para dar volumen.
@immutable
class NibiPalette {
  const NibiPalette({
    required this.body,
    required this.bodyShade,
    required this.outline,
    required this.belly,
    required this.bellyLine,
    required this.muzzle,
    required this.horn,
    required this.crest,
    required this.crestShade,
    required this.eye,
    required this.eyeShine,
    required this.blush,
    required this.mouth,
    required this.tongue,
    required this.aura,
    required this.water,
    required this.gold,
    required this.red,
    required this.white,
    required this.shadow,
    required this.isInk,
  });

  factory NibiPalette.of(ScColors c, {String? colorId}) =>
      c.isFlat ? NibiPalette.ink(c, colorId: colorId) : NibiPalette.color(c, colorId: colorId);

  factory NibiPalette.color(ScColors c, {String? colorId}) {
    final NibiSkin skin = NibiSkin.of(colorId);
    return NibiPalette(
        body: skin.body,
        bodyShade: skin.bodyShade,
        outline: skin.outline,
        belly: skin.belly,
        bellyLine: skin.bellyLine,
        muzzle: skin.muzzle,
        horn: skin.horn,
        crest: skin.crest,
        crestShade: skin.crestShade,
        eye: const Color(0xFF2B1D17),
        eyeShine: const Color(0xFFFFFFFF),
        blush: const Color(0xFFF29A93),
        mouth: const Color(0xFF3B241C),
        tongue: const Color(0xFFE8696B),
        aura: c.accent,
        water: const Color(0xFF55B6F0),
        gold: const Color(0xFFF2C14E),
        red: const Color(0xFFE5484D),
        white: const Color(0xFFFFFFFF),
        shadow: const Color(0x33000000),
        isInk: false,
      );
  }

  /// Tinta sobre papel: rellenos del color del papel y grises de tinta diluida.
  factory NibiPalette.ink(ScColors c, {String? colorId}) {
    final Color ink = c.text;
    final Color paper = c.bg2;
    Color tone(double t) => Color.lerp(ink, paper, t)!;
    // Cada pelaje es un gris distinto; el verde es el papel limpio.
    final double skin = NibiSkin.of(colorId).inkTone;
    return NibiPalette(
      body: tone(1 - skin),
      bodyShade: tone(0.85 - skin * 0.5),
      outline: ink,
      belly: paper,
      bellyLine: tone(0.45),
      muzzle: tone(0.92 - skin * 0.5),
      horn: paper,
      crest: tone(0.6),
      crestShade: tone(0.35),
      eye: ink,
      eyeShine: paper,
      blush: tone(0.85),
      mouth: ink,
      tongue: tone(0.55),
      aura: ink,
      water: tone(0.7),
      gold: tone(0.75),
      red: tone(0.5),
      white: paper,
      shadow: tone(0.8),
      isInk: true,
    );
  }

  final Color body;
  final Color bodyShade;
  final Color outline;
  final Color belly;
  final Color bellyLine;
  final Color muzzle;
  final Color horn;
  final Color crest;
  final Color crestShade;
  final Color eye;
  final Color eyeShine;
  final Color blush;
  final Color mouth;
  final Color tongue;
  final Color aura;
  final Color water;
  final Color gold;
  final Color red;
  final Color white;
  final Color shadow;

  /// Modo Papel: sin degradados, brillos ni transparencias.
  final bool isInk;

  @override
  bool operator ==(Object other) =>
      other is NibiPalette &&
      other.outline == outline &&
      other.body == body &&
      other.crest == crest &&
      other.belly == belly &&
      other.aura == aura &&
      other.isInk == isInk;

  @override
  int get hashCode => Object.hash(outline, body, crest, belly, aura, isInk);
}
