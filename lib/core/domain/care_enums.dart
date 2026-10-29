import 'dart:convert';

/// Módulos de la pestaña Cuidado. Cada persona elige cuáles ve (Ajustes → Módulos).
enum CareModule {
  treatments('treatments'),
  pelvicFloor('pelvic_floor'),
  activeBreaks('active_breaks'),
  symptoms('symptoms'),
  checkups('checkups'),
  habits('habits'),

  /// Alcohol y tabaco: apagado por defecto, solo para quien quiera llevarlo.
  substances('substances');

  const CareModule(this.key);

  final String key;

  static const Set<CareModule> defaults = <CareModule>{
    CareModule.treatments,
    CareModule.pelvicFloor,
    CareModule.activeBreaks,
    CareModule.symptoms,
    CareModule.checkups,
    CareModule.habits,
  };

  static CareModule? fromKey(String raw) {
    for (final CareModule m in values) {
      if (m.key == raw) return m;
    }
    return null;
  }
}

/// Signos vitales que se registran cuando la persona dice tener el aparato.
enum VitalKind {
  bloodPressure('blood_pressure'),
  glucose('glucose'),
  oxygen('oxygen'),
  temperature('temperature');

  const VitalKind(this.key);

  final String key;

  static VitalKind? fromKey(String raw) {
    for (final VitalKind k in values) {
      if (k.key == raw) return k;
    }
    return null;
  }
}

/// Lectura tolerante de las listas JSON del perfil: una entrada desconocida o un
/// JSON corrupto nunca rompe la app, solo se ignora.
abstract final class ProfileSets {
  static List<String> _decode(String raw) {
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return const <String>[];
      return decoded.whereType<String>().toList();
    } on FormatException {
      return const <String>[];
    }
  }

  static Set<CareModule> careModules(String raw) =>
      _decode(raw).map(CareModule.fromKey).whereType<CareModule>().toSet();

  static Set<VitalKind> vitalDevices(String raw) =>
      _decode(raw).map(VitalKind.fromKey).whereType<VitalKind>().toSet();

  static String encodeModules(Set<CareModule> modules) => jsonEncode(<String>[
    for (final CareModule m in CareModule.values)
      if (modules.contains(m)) m.key,
  ]);

  static String encodeVitals(Set<VitalKind> kinds) => jsonEncode(<String>[
    for (final VitalKind k in VitalKind.values)
      if (kinds.contains(k)) k.key,
  ]);
}
