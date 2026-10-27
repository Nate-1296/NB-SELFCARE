import 'package:flutter/material.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/domain/enums.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/utils/biometric_formulas.dart';
import '../../../../../shared/widgets/app_icons.dart';

// Etiquetas cortas desde el ARB; las explicaciones largas ("¿qué representa?",
// guía y fórmula) son contenido editorial con sus referencias.

/// Identificadores de las 13 métricas fisiológicas + validación antropométrica.
enum BiometricMetricKind {
  bodyFat,
  validatedNavyFat,
  muscleMass,
  leanBodyMass,
  water,
  protein,
  visceralFat,
  boneMass,
  bmr,
  metabolicAge,
  bmi,
  bodyScore,
  somatotype,
}

/// Estado orientativo positivo (sin lenguaje alarmista ni punitivo).
enum MetricStatusTone {
  optimal,
  balanced,
  gentleAttention,
  neutral,
}

/// Información estructurada para presentar y explicar cada métrica fisiológica.
class BiometricMetricSpec {
  const BiometricMetricSpec({
    required this.kind,
    required this.title,
    required this.valueLabel,
    required this.subtitle,
    required this.statusLabel,
    required this.tone,
    required this.icon,
    required this.whatItMeans,
    required this.referenceGuide,
    required this.formulaNote,
    this.progressFraction,
  });

  final BiometricMetricKind kind;
  final String title;
  final String valueLabel;
  final String subtitle;
  final String statusLabel;
  final MetricStatusTone tone;
  final IconData icon;
  final String whatItMeans;
  final String referenceGuide;
  final String formulaNote;
  final double? progressFraction;
}

/// Constructor determinista de especificaciones educativas para las 13 métricas.
abstract final class BiometricMetricCatalog {
  static String translateSomatotype(AppLocalizations l10n, String? code) {
    return switch (code) {
      'balanced' => l10n.bodySomatoBalanced,
      'balanced_muscular' => l10n.bodySomatoBalancedMuscular,
      'skinny_muscular' => l10n.bodySomatoSkinnyMuscular,
      'balanced_skinny' => l10n.bodySomatoBalancedSkinny,
      'skinny' => l10n.bodySomatoSkinny,
      'thick_set' => l10n.bodySomatoThickSet,
      'lack_exercise' => l10n.bodySomatoLackExercise,
      'overweight' => l10n.bodySomatoOverweight,
      'obese' => l10n.bodySomatoObese,
      _ => l10n.bodySomatoPending,
    };
  }

  static Color toneColor(ScColors c, MetricStatusTone tone) {
    return switch (tone) {
      MetricStatusTone.optimal => c.success,
      MetricStatusTone.balanced => c.accent,
      MetricStatusTone.gentleAttention => c.warning,
      MetricStatusTone.neutral => c.text3,
    };
  }

  static List<BiometricMetricSpec> buildAll(
    AppLocalizations l10n, {
    required UserProfile profile,
    required BodyMeasurement? latest,
    required DateTime referenceDate,
  }) {
    final bool isMale = profile.biologicalSex == BiologicalSex.male;
    final double ageYears = BiometricFormulas.calculateDynamicAge(
      profile.birthDate,
      referenceDate,
    );
    final bool hasBia =
        latest?.impedanceOhms != null && latest!.impedanceOhms! >= 100;
    final String sourceHint = hasBia
        ? l10n.bodySourceBia
        : (latest != null ? l10n.bodySourceEstimate : l10n.bodySourceNone);

    // 1. Grasa Corporal (%)
    final double? bf = latest?.bodyFatPercentage;
    final double bfOptLow = isMale ? 10.0 : 18.0;
    final double bfOptHigh = isMale ? 20.0 : 28.0;
    final MetricStatusTone bfTone = bf == null
        ? MetricStatusTone.neutral
        : (bf >= bfOptLow && bf <= bfOptHigh
            ? MetricStatusTone.optimal
            : (bf < bfOptLow - 3 || bf > bfOptHigh + 5
                ? MetricStatusTone.gentleAttention
                : MetricStatusTone.balanced));
    final String bfStatus = bf == null
        ? l10n.bodyNoData
        : (bf >= bfOptLow && bf <= bfOptHigh
            ? l10n.bodyStatusHealthyRange
            : (bf < bfOptLow ? l10n.bodyStatusLowReserve : l10n.bodyStatusAboveRange));

    // 2. Grasa Validada US Navy (%)
    final double? valFat = latest?.validatedBodyFatPercentage;
    final MetricStatusTone valTone = valFat == null
        ? MetricStatusTone.neutral
        : (valFat >= bfOptLow && valFat <= bfOptHigh
            ? MetricStatusTone.optimal
            : MetricStatusTone.balanced);

    // 3. Masa Muscular (kg)
    final double? muscle = latest?.muscleMassKg;
    final double? weight = latest?.weightKg;
    final double? musclePct =
        (muscle != null && weight != null && weight > 0)
            ? (muscle / weight) * 100.0
            : null;
    final double minMusclePct = isMale ? 40.0 : 32.0;
    final MetricStatusTone muscleTone = musclePct == null
        ? MetricStatusTone.neutral
        : (musclePct >= minMusclePct
            ? MetricStatusTone.optimal
            : MetricStatusTone.balanced);

    // 4. Masa Libre de Grasa / LBM (kg)
    final double? lbm = latest?.leanBodyMassKg;

    // 5. Agua Corporal (%)
    final double? water = latest?.waterPercentage;
    final double waterMin = isMale ? 50.0 : 45.0;
    final double waterMax = isMale ? 65.0 : 60.0;
    final MetricStatusTone waterTone = water == null
        ? MetricStatusTone.neutral
        : (water >= waterMin && water <= waterMax
            ? MetricStatusTone.optimal
            : MetricStatusTone.gentleAttention);

    // 6. Proteína Corporal (%)
    final double? prot = latest?.proteinPercentage;
    final MetricStatusTone protTone = prot == null
        ? MetricStatusTone.neutral
        : (prot >= 16.0
            ? MetricStatusTone.optimal
            : (prot >= 14.0
                ? MetricStatusTone.balanced
                : MetricStatusTone.gentleAttention));

    // 7. Grasa Visceral (1-30)
    final int? visc = latest?.visceralFatIndex;
    final MetricStatusTone viscTone = visc == null
        ? MetricStatusTone.neutral
        : (visc <= 9
            ? MetricStatusTone.optimal
            : (visc <= 14
                ? MetricStatusTone.balanced
                : MetricStatusTone.gentleAttention));

    // 8. Masa Ósea (kg)
    final double? bone = latest?.boneMassKg;
    final double boneRef = isMale ? 2.8 : 2.2;
    final MetricStatusTone boneTone = bone == null
        ? MetricStatusTone.neutral
        : (bone >= boneRef * 0.85
            ? MetricStatusTone.optimal
            : MetricStatusTone.balanced);

    // 9. Metabolismo Basal BMR (kcal)
    final int? bmr = latest?.basalMetabolicRateKcal;

    // 10. Edad Metabólica (años)
    final int? metAge = latest?.metabolicAge;
    final int chronoAge = ageYears.floor();
    final MetricStatusTone metAgeTone = metAge == null
        ? MetricStatusTone.neutral
        : (metAge <= chronoAge
            ? MetricStatusTone.optimal
            : (metAge <= chronoAge + 3
                ? MetricStatusTone.balanced
                : MetricStatusTone.gentleAttention));

    // 11. IMC (kg/m²)
    final double? bmi = latest?.bmi;
    final MetricStatusTone bmiTone = bmi == null
        ? MetricStatusTone.neutral
        : (bmi >= 18.5 && bmi < 25.0
            ? MetricStatusTone.optimal
            : MetricStatusTone.balanced);

    // 12. Puntuación Corporal (0-100)
    final int? score = latest?.bodyScore;
    final MetricStatusTone scoreTone = score == null
        ? MetricStatusTone.neutral
        : (score >= 75
            ? MetricStatusTone.optimal
            : (score >= 60
                ? MetricStatusTone.balanced
                : MetricStatusTone.gentleAttention));

    // 13. Somatotipo
    final String? somato = latest?.somatotype;

    return <BiometricMetricSpec>[
      BiometricMetricSpec(
        kind: BiometricMetricKind.bodyFat,
        title: l10n.bodyMetricFat,
        valueLabel: bf != null ? '${bf.toStringAsFixed(1)}%' : '-- %',
        subtitle: sourceHint,
        statusLabel: bfStatus,
        tone: bfTone,
        icon: AppIcons.corazon,
        progressFraction: bf != null ? (bf / 45.0).clamp(0.05, 1.0) : null,
        whatItMeans:
            'Representa la proporción de tejido adiposo respecto a tu peso total. El tejido graso es esencial para la regulación hormonal, protección térmica y reserva energética.',
        referenceGuide: isMale
            ? 'Referencia general adulta (hombre): 10% – 20% saludable/atlético.'
            : 'Referencia general adulta (mujer): 18% – 28% saludable/atlético.',
        formulaNote: hasBia
            ? 'Derivada de la impedancia bioeléctrica (${latest.impedanceOhms} Ω), estatura, peso y edad dinámica.'
            : 'Estimada mediante ecuación antropométrica de Deurenberg al no disponer de ohmios BIA.',
      ),
      BiometricMetricSpec(
        kind: BiometricMetricKind.validatedNavyFat,
        title: l10n.bodyMetricTapeFat,
        valueLabel: valFat != null ? '${valFat.toStringAsFixed(1)}%' : l10n.bodyTapeMeasure,
        subtitle: latest?.waistCm != null
            ? l10n.bodyTapeWaist(latest!.waistCm!.toStringAsFixed(1))
            : l10n.bodyTapeHint,
        statusLabel: valFat != null ? l10n.bodyTapeValidated : l10n.bodyTapeEvery2Weeks,
        tone: valTone,
        icon: AppIcons.tape,
        progressFraction:
            valFat != null ? (valFat / 45.0).clamp(0.05, 1.0) : null,
        whatItMeans:
            'Combina la bioimpedancia con los perímetros anatómicos de cintura y cuello (ecuación US Navy). Es ideal cada 14 días porque corrige variaciones de hidratación y detecta recomposición corporal real.',
        referenceGuide:
            'Úsala cada 2 semanas en ayunas para confirmar que la pérdida o ganancia proviene de tejido real y no solo de agua.',
        formulaNote:
            'Fusión ponderada: 0.60 × Grasa BIA + 0.40 × Grasa US Navy logarítmica.',
      ),
      BiometricMetricSpec(
        kind: BiometricMetricKind.muscleMass,
        title: l10n.bodyMetricMuscle,
        valueLabel: muscle != null ? '${muscle.toStringAsFixed(1)} kg' : '-- kg',
        subtitle: musclePct != null
            ? l10n.bodyPctOfWeight(musclePct.toStringAsFixed(1))
            : l10n.bodyMuscleTotal,
        statusLabel: musclePct == null
            ? l10n.bodyNoData
            : (musclePct >= minMusclePct ? l10n.bodyStatusSolid : l10n.bodyStatusBuilding),
        tone: muscleTone,
        icon: AppIcons.pesa,
        progressFraction:
            musclePct != null ? (musclePct / 60.0).clamp(0.1, 1.0) : null,
        whatItMeans:
            'Incluye el músculo esquelético, liso y el agua intramiocelular. Mantener o incrementar la masa muscular sostiene tu sensibilidad a la insulina, postura y gasto energético diario.',
        referenceGuide: isMale
            ? 'Referencia orientativa (hombre): > 40% del peso corporal total.'
            : 'Referencia orientativa (mujer): > 32% del peso corporal total.',
        formulaNote:
            'Masa Muscular = Peso Total − Masa Grasa − Masa Mineral Ósea.',
      ),
      BiometricMetricSpec(
        kind: BiometricMetricKind.leanBodyMass,
        title: l10n.bodyMetricLean,
        valueLabel: lbm != null ? '${lbm.toStringAsFixed(1)} kg' : '-- kg',
        subtitle: l10n.bodyLeanSubtitle,
        statusLabel: lbm != null ? l10n.bodyLeanStatus : l10n.bodyNoData,
        tone: lbm != null ? MetricStatusTone.balanced : MetricStatusTone.neutral,
        icon: Icons.accessibility_new_rounded,
        progressFraction: (lbm != null && weight != null && weight > 0)
            ? (lbm / weight).clamp(0.2, 0.98)
            : null,
        whatItMeans:
            'Es todo el peso de tu cuerpo exceptuando el tejido graso: músculos, huesos, órganos, sangre y agua. Es el principal determinante de cuántas calorías quemas en reposo.',
        referenceGuide:
            'En etapas de pérdida de grasa, el objetivo es conservar estable la Masa Libre de Grasa con suficiente proteína y entrenamiento de fuerza.',
        formulaNote: 'LBM = Peso × (1 − % Grasa Corporal / 100).',
      ),
      BiometricMetricSpec(
        kind: BiometricMetricKind.water,
        title: l10n.bodyMetricWater,
        valueLabel: water != null ? '${water.toStringAsFixed(1)}%' : '-- %',
        subtitle: l10n.bodyWaterSubtitle,
        statusLabel: water == null
            ? l10n.bodyNoData
            : (water >= waterMin ? l10n.bodyStatusHydrated : l10n.bodyStatusDrinkMore),
        tone: waterTone,
        icon: AppIcons.gota,
        progressFraction:
            water != null ? (water / 75.0).clamp(0.1, 1.0) : null,
        whatItMeans:
            'Porcentaje de agua total intracelular y extracelular. El tejido muscular retiene mucha más agua (~73%) que el tejido adiposo (~10%), por lo que mayor masa magra eleva naturalmente este valor.',
        referenceGuide: isMale
            ? 'Rango habitual (hombre): 50% – 65%.'
            : 'Rango habitual (mujer): 45% – 60%.',
        formulaNote:
            'Derivada de la conductividad eléctrica de la masa magra y balance hídrico.',
      ),
      BiometricMetricSpec(
        kind: BiometricMetricKind.protein,
        title: l10n.bodyMetricProtein,
        valueLabel: prot != null ? '${prot.toStringAsFixed(1)}%' : '-- %',
        subtitle: l10n.bodyProteinSubtitle,
        statusLabel: prot == null
            ? l10n.bodyNoData
            : (prot >= 16.0 ? l10n.bodyStatusOptimal : l10n.bodyStatusStable),
        tone: protTone,
        icon: Icons.egg_alt_rounded,
        progressFraction: prot != null ? (prot / 26.0).clamp(0.1, 1.0) : null,
        whatItMeans:
            'Estima la fracción sólida proteica presente en fibras musculares, colágeno, órganos y enzimas una vez descontada el agua corporal.',
        referenceGuide: 'Rango saludable orientativo: 16% – 20% del peso total.',
        formulaNote:
            'Derivada de la proporción muscular neta descontando el agua asociada.',
      ),
      BiometricMetricSpec(
        kind: BiometricMetricKind.visceralFat,
        title: l10n.bodyMetricVisceral,
        valueLabel: l10n.bodyVisceralLevel(visc?.toString() ?? '--'),
        subtitle: l10n.bodyVisceralSubtitle,
        statusLabel: visc == null
            ? l10n.bodyNoData
            : (visc <= 9
                ? l10n.bodyStatusHealthy
                : (visc <= 14 ? l10n.bodyStatusModerate : l10n.bodyStatusMoveMore)),
        tone: viscTone,
        icon: AppIcons.fuego,
        progressFraction:
            visc != null ? (1.0 - ((visc - 1) / 25.0)).clamp(0.1, 1.0) : null,
        whatItMeans:
            'Índice estimativo de la grasa almacenada en la cavidad abdominal alrededor de los órganos internos. Responde muy favorablemente al ejercicio aeróbico, descanso reparador y reducción de ultraprocesados.',
        referenceGuide:
            'Niveles 1 – 9: óptimo · 10 – 14: moderado · 15+: conviene acompañar con actividad diaria constante.',
        formulaNote:
            'Índice antropométrico-impedanciométrico acotado en escala 1 a 30.',
      ),
      BiometricMetricSpec(
        kind: BiometricMetricKind.boneMass,
        title: l10n.bodyMetricBone,
        valueLabel: bone != null ? '${bone.toStringAsFixed(2)} kg' : '-- kg',
        subtitle: l10n.bodyBoneSubtitle,
        statusLabel: bone != null ? l10n.bodyStatusStable : l10n.bodyNoData,
        tone: boneTone,
        icon: Icons.shield_outlined,
        progressFraction: bone != null ? (bone / 4.2).clamp(0.15, 1.0) : null,
        whatItMeans:
            'Estima el peso del mineral óseo (calcio, fósforo y matriz estructural). No mide densidad mineral clínica (DEXA), pero acompaña de cerca el desarrollo de tu masa magra.',
        referenceGuide: isMale
            ? 'Promedio orientativo (hombre adulto): 2.5 – 3.5 kg según estatura.'
            : 'Promedio orientativo (mujer adulta): 1.9 – 2.8 kg según estatura.',
        formulaNote:
            'Estimación lineal derivada de la masa libre de grasa (LBM).',
      ),
      BiometricMetricSpec(
        kind: BiometricMetricKind.bmr,
        title: l10n.bodyMetricBmr,
        valueLabel: bmr != null ? '$bmr kcal' : '-- kcal',
        subtitle: l10n.bodyBmrSubtitle,
        statusLabel: bmr != null ? l10n.bodyBmrStatus : l10n.bodyNoData,
        tone: bmr != null ? MetricStatusTone.optimal : MetricStatusTone.neutral,
        icon: AppIcons.bolt,
        progressFraction: bmr != null ? (bmr / 2500.0).clamp(0.2, 1.0) : null,
        whatItMeans:
            'Energía mínima diaria que tu cuerpo necesita en reposo completo para sostener latidos, respiración, temperatura y regeneración celular. Tu meta calórica nunca debe bajar de este piso fisiológico.',
        referenceGuide:
            'A mayor masa libre de grasa (músculo), mayor es tu metabolismo basal diario.',
        formulaNote: 'Ecuación Katch-McArdle: TMB = 370 + (21.6 × LBM en kg).',
      ),
      BiometricMetricSpec(
        kind: BiometricMetricKind.metabolicAge,
        title: l10n.bodyMetricMetabolicAge,
        valueLabel: l10n.bodyYears(metAge?.toString() ?? '--'),
        subtitle: l10n.bodyCurrentAge(chronoAge),
        statusLabel: metAge == null
            ? l10n.bodyNoData
            : (metAge <= chronoAge ? l10n.bodyStatusYoung : l10n.bodyStatusRoomToImprove),
        tone: metAgeTone,
        icon: Icons.cake_rounded,
        progressFraction: metAge != null
            ? (chronoAge / (metAge > 0 ? metAge : chronoAge)).clamp(0.25, 1.0)
            : null,
        whatItMeans:
            'Compara tu tasa metabólica basal real frente al promedio estadístico de personas de tu misma edad cronológica. Una edad metabólica igual o menor refleja buena proporción muscular.',
        referenceGuide:
            'Entrenar fuerza 2–4 veces por semana suele rejuvenecer este indicador progresivamente.',
        formulaNote:
            'Relación entre tu TMB Katch-McArdle y la TMB media Harris-Benedict para ${ageYears.toStringAsFixed(1)} años.',
      ),
      BiometricMetricSpec(
        kind: BiometricMetricKind.bmi,
        title: l10n.bodyMetricBmi,
        valueLabel: bmi != null ? bmi.toStringAsFixed(1) : '--',
        subtitle: l10n.bodyBmiSubtitle,
        statusLabel: bmi == null
            ? l10n.bodyNoData
            : (bmi >= 18.5 && bmi < 25.0 ? l10n.bodyStatusStandard : l10n.bodyStatusBmiContext),
        tone: bmiTone,
        icon: Icons.speed_rounded,
        progressFraction: bmi != null ? (bmi / 35.0).clamp(0.15, 1.0) : null,
        whatItMeans:
            'El Índice de Masa Corporal relaciona únicamente peso y estatura, sin distinguir entre músculo y grasa. En personas que entrenan fuerza puede marcar valores > 25 teniendo un % de grasa muy saludable.',
        referenceGuide:
            'Rango poblacional OMS: 18.5 – 24.9 kg/m². Prioriza siempre % Grasa y Cintura sobre el IMC aislado.',
        formulaNote:
            'IMC = Peso (${weight?.toStringAsFixed(1) ?? "--"} kg) / (${(profile.heightCm / 100.0).toStringAsFixed(2)} m)².',
      ),
      BiometricMetricSpec(
        kind: BiometricMetricKind.bodyScore,
        title: l10n.bodyMetricScore,
        valueLabel: score != null ? '$score/100' : '--/100',
        subtitle: l10n.bodyScoreSubtitle,
        statusLabel: score == null
            ? l10n.bodyNoData
            : (score >= 80
                ? l10n.bodyStatusExcellent
                : (score >= 65 ? l10n.bodyStatusBalanced : l10n.bodyStatusInProgress)),
        tone: scoreTone,
        icon: AppIcons.starFilled,
        progressFraction: score != null ? (score / 100.0).clamp(0.1, 1.0) : null,
        whatItMeans:
            'Resumen integrador de 10 a 100 puntos que pondera simultáneamente % de grasa, masa muscular relativa, grasa visceral e hidratación corporal.',
        referenceGuide:
            'Más que un número aislado, observa su tendencia mensual conforme consolidas sueño, nutrición y movimiento.',
        formulaNote:
            'Ponderación compuesta de balance adiposo, muscular, visceral e hídrico.',
      ),
      BiometricMetricSpec(
        kind: BiometricMetricKind.somatotype,
        title: l10n.bodyMetricSomatotype,
        valueLabel: translateSomatotype(l10n, somato),
        subtitle: l10n.bodySomatoSubtitle,
        statusLabel: somato != null ? l10n.bodySomatoStatus : l10n.bodySomatoStatusPending,
        tone: somato != null ? MetricStatusTone.optimal : MetricStatusTone.neutral,
        icon: AppIcons.perfil,
        whatItMeans:
            'Clasifica de forma descriptiva y libre de juicios la combinación actual entre tu masa muscular y tu reserva de tejido adiposo dentro de la matriz clásica de 9 fenotipos corporales.',
        referenceGuide:
            'Tu fenotipo es dinámico: se adapta gradualmente con tus hábitos de entrenamiento y descanso.',
        formulaNote:
            'Matriz bidimensional (% Grasa Corporal × Proporción Muscular por sexo biológico).',
      ),
    ];
  }
}
