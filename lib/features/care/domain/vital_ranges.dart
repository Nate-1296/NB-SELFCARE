import '../../../core/domain/care_enums.dart';

/// Lectura orientativa de un signo vital. No es un diagnóstico: los rangos son
/// los de referencia general y el médico define los de cada persona.
enum VitalBand {
  /// Por debajo de lo habitual (glucosa < 70, temperatura < 35,5).
  low,
  normal,

  /// Algo por encima de lo habitual: vale la pena seguirlo.
  elevated,

  /// Alto de forma sostenida: conviene comentarlo en la próxima consulta.
  high,

  /// Muy alto o muy bajo: conviene consultar pronto.
  consultSoon,
}

/// Contexto de una medición de glucosa.
enum GlucoseContext {
  fasting('fasting'),
  afterMeal('after_meal'),
  random('random');

  const GlucoseContext(this.key);

  final String key;

  static GlucoseContext fromKey(String? raw) =>
      values.firstWhere((GlucoseContext c) => c.key == raw, orElse: () => GlucoseContext.random);
}

abstract final class VitalRanges {
  /// Límites aceptados al guardar: fuera de ellos el dato no puede ser real.
  static bool isPlausible(VitalKind kind, double primary, double? secondary) => switch (kind) {
    VitalKind.bloodPressure =>
      primary >= 60 &&
          primary <= 260 &&
          secondary != null &&
          secondary >= 30 &&
          secondary <= 160 &&
          secondary < primary,
    VitalKind.glucose => primary >= 20 && primary <= 600,
    VitalKind.oxygen => primary >= 50 && primary <= 100,
    VitalKind.temperature => primary >= 32 && primary <= 43,
  };

  /// Tensión arterial (AHA/ACC 2017): normal < 120/80; elevada 120–129/< 80;
  /// alta ≥ 130 o ≥ 80; muy alta ≥ 180 o ≥ 120.
  static VitalBand bloodPressure(double systolic, double diastolic) {
    if (systolic >= 180 || diastolic >= 120) return VitalBand.consultSoon;
    if (systolic < 90 || diastolic < 60) return VitalBand.low;
    if (systolic >= 130 || diastolic >= 80) return VitalBand.high;
    if (systolic >= 120) return VitalBand.elevated;
    return VitalBand.normal;
  }

  /// Glucosa en mg/dL (ADA): en ayunas normal 70–99, 100–125 por encima,
  /// ≥ 126 alta; después de comer normal < 140, 140–199 por encima, ≥ 200 alta.
  static VitalBand glucose(double mgDl, GlucoseContext context) {
    if (mgDl < 54 || mgDl >= 300) return VitalBand.consultSoon;
    if (mgDl < 70) return VitalBand.low;
    return switch (context) {
      GlucoseContext.fasting =>
        mgDl >= 126 ? VitalBand.high : (mgDl >= 100 ? VitalBand.elevated : VitalBand.normal),
      GlucoseContext.afterMeal || GlucoseContext.random =>
        mgDl >= 200 ? VitalBand.high : (mgDl >= 140 ? VitalBand.elevated : VitalBand.normal),
    };
  }

  /// Saturación de oxígeno (%): ≥ 95 normal; 92–94 a seguir; < 92 consultar.
  static VitalBand oxygen(double percent) {
    if (percent < 92) return VitalBand.consultSoon;
    if (percent < 95) return VitalBand.elevated;
    return VitalBand.normal;
  }

  /// Temperatura (°C): 35,5–37,2 normal; 37,3–37,9 febrícula; ≥ 38 fiebre;
  /// ≥ 39,5 o < 35 consultar.
  static VitalBand temperature(double celsius) {
    if (celsius >= 39.5 || celsius < 35) return VitalBand.consultSoon;
    if (celsius < 35.5) return VitalBand.low;
    if (celsius >= 38) return VitalBand.high;
    if (celsius >= 37.3) return VitalBand.elevated;
    return VitalBand.normal;
  }

  static VitalBand bandFor({
    required VitalKind kind,
    required double primary,
    double? secondary,
    String? context,
  }) => switch (kind) {
    VitalKind.bloodPressure => bloodPressure(primary, secondary ?? 0),
    VitalKind.glucose => glucose(primary, GlucoseContext.fromKey(context)),
    VitalKind.oxygen => oxygen(primary),
    VitalKind.temperature => temperature(primary),
  };
}
