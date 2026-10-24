import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/database/app_database.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/utils/biometric_formulas.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/sheet.dart';

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
  static String translateSomatotype(String? code) {
    return switch (code) {
      'balanced' => 'Equilibrado',
      'balanced_muscular' => 'Atlético Muscular',
      'skinny_muscular' => 'Definido Muscular',
      'balanced_skinny' => 'Delgado Equilibrado',
      'skinny' => 'Constitución Ligera',
      'thick_set' => 'Complexión Fuerte',
      'lack_exercise' => 'En Activación Muscular',
      'overweight' => 'Reserva Energética Moderada',
      'obese' => 'Reserva Energética Alta',
      _ => 'Pendiente de pesaje',
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

  static List<BiometricMetricSpec> buildAll({
    required UserProfile profile,
    required BodyMeasurement? latest,
    DateTime? referenceDate,
  }) {
    final bool isMale = profile.biologicalSex == 'male';
    final double ageYears = BiometricFormulas.calculateDynamicAge(
      profile.birthDate,
      referenceDate,
    );
    final bool hasBia =
        latest?.impedanceOhms != null && latest!.impedanceOhms! >= 100;
    final String sourceHint = hasBia
        ? 'BIA ${latest.impedanceOhms} Ω'
        : (latest != null ? 'Estimación fisiológica' : 'Sin registro aún');

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
        ? 'Sin dato'
        : (bf >= bfOptLow && bf <= bfOptHigh
            ? 'Rango saludable'
            : (bf < bfOptLow ? 'Reserva baja' : 'Por encima del rango'));

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
        title: 'Grasa Corporal',
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
        title: 'Grasa Validada Navy',
        valueLabel:
            valFat != null ? '${valFat.toStringAsFixed(1)}%' : 'Usar cinta',
        subtitle: latest?.waistCm != null
            ? 'Cintura ${latest!.waistCm!.toStringAsFixed(1)} cm · 60/40'
            : '60% BIA + 40% US Navy',
        statusLabel: valFat != null ? 'Validada' : 'Quincenal',
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
        title: 'Masa Muscular',
        valueLabel: muscle != null ? '${muscle.toStringAsFixed(1)} kg' : '-- kg',
        subtitle: musclePct != null
            ? '${musclePct.toStringAsFixed(1)}% de tu peso'
            : 'Músculo total',
        statusLabel: musclePct == null
            ? 'Sin dato'
            : (musclePct >= minMusclePct ? 'Tono sólido' : 'En construcción'),
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
        title: 'Masa Libre de Grasa',
        valueLabel: lbm != null ? '${lbm.toStringAsFixed(1)} kg' : '-- kg',
        subtitle: 'Tejido magro activo (LBM)',
        statusLabel: lbm != null ? 'Base metabólica' : 'Sin dato',
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
        title: 'Agua Corporal',
        valueLabel: water != null ? '${water.toStringAsFixed(1)}%' : '-- %',
        subtitle: 'Hidratación tisular',
        statusLabel: water == null
            ? 'Sin dato'
            : (water >= waterMin ? 'Bien hidratado' : 'Hidratar más'),
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
        title: 'Proteína Corporal',
        valueLabel: prot != null ? '${prot.toStringAsFixed(1)}%' : '-- %',
        subtitle: 'Reserva estructural',
        statusLabel: prot == null
            ? 'Sin dato'
            : (prot >= 16.0 ? 'Óptimo' : 'Estable'),
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
        title: 'Grasa Visceral',
        valueLabel: visc != null ? 'Nivel $visc' : 'Nivel --',
        subtitle: 'Rango ideal: niveles 1 a 9',
        statusLabel: visc == null
            ? 'Sin dato'
            : (visc <= 9
                ? 'Saludable'
                : (visc <= 14 ? 'Moderado' : 'Priorizar movimiento')),
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
        title: 'Masa Ósea',
        valueLabel: bone != null ? '${bone.toStringAsFixed(2)} kg' : '-- kg',
        subtitle: 'Mineralización estimada',
        statusLabel: bone != null ? 'Estable' : 'Sin dato',
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
        title: 'Metabolismo Basal',
        valueLabel: bmr != null ? '$bmr kcal' : '-- kcal',
        subtitle: 'Gasto en reposo absoluto',
        statusLabel: bmr != null ? 'Katch-McArdle' : 'Sin dato',
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
        title: 'Edad Metabólica',
        valueLabel: metAge != null ? '$metAge años' : '-- años',
        subtitle: 'Edad actual: $chronoAge años',
        statusLabel: metAge == null
            ? 'Sin dato'
            : (metAge <= chronoAge ? 'Vitalidad alta' : 'Margen activo'),
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
        title: 'IMC',
        valueLabel: bmi != null ? bmi.toStringAsFixed(1) : '--',
        subtitle: 'Relación peso / estatura²',
        statusLabel: bmi == null
            ? 'Sin dato'
            : (bmi >= 18.5 && bmi < 25.0
                ? 'Rango estándar'
                : 'Interpretar con músculo'),
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
        title: 'Puntuación Corporal',
        valueLabel: score != null ? '$score/100' : '--/100',
        subtitle: 'Índice integral de equilibrio',
        statusLabel: score == null
            ? 'Sin dato'
            : (score >= 80
                ? 'Sobresaliente'
                : (score >= 65 ? 'Equilibrado' : 'En progreso')),
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
        title: 'Somatotipo',
        valueLabel: translateSomatotype(somato),
        subtitle: 'Fenotipo de composición actual',
        statusLabel: somato != null ? '9 fenotipos' : 'Pendiente',
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

/// Hoja modal guiada para pesaje manual con vista previa fisiológica en tiempo real.
class ManualWeighInSheet extends StatefulWidget {
  const ManualWeighInSheet({
    super.key,
    required this.initialWeightKg,
    required this.profile,
    this.latestMeasurement,
  });

  final double initialWeightKg;
  final UserProfile profile;
  final BodyMeasurement? latestMeasurement;

  static Future<({double weightKg, int? impedanceOhms})?> show({
    required BuildContext context,
    required double initialWeightKg,
    required UserProfile profile,
    BodyMeasurement? latestMeasurement,
  }) {
    return mostrarHojaMenu<({double weightKg, int? impedanceOhms})>(
      context,
      builder: (_) => ManualWeighInSheet(
        initialWeightKg: initialWeightKg,
        profile: profile,
        latestMeasurement: latestMeasurement,
      ),
    );
  }

  @override
  State<ManualWeighInSheet> createState() => _ManualWeighInSheetState();
}

class _ManualWeighInSheetState extends State<ManualWeighInSheet> {
  late final TextEditingController _weightCtrl;
  late final TextEditingController _impedanceCtrl;

  @override
  void initState() {
    super.initState();
    _weightCtrl = TextEditingController(
      text: widget.initialWeightKg.toStringAsFixed(1),
    )..addListener(_onChanged);
    _impedanceCtrl = TextEditingController()..addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _weightCtrl
      ..removeListener(_onChanged)
      ..dispose();
    _impedanceCtrl
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  double? get _parsedWeight {
    final double? val = double.tryParse(
      _weightCtrl.text.trim().replaceAll(',', '.'),
    );
    if (val == null || val <= 1.0 || val > 350.0) return null;
    return val;
  }

  int? get _parsedImpedance {
    final String raw = _impedanceCtrl.text.trim();
    if (raw.isEmpty) return null;
    final int? val = int.tryParse(raw);
    if (val == null || val < 100 || val > 3000) return null;
    return val;
  }

  void _stepWeight(double delta) {
    unawaited(HapticFeedback.selectionClick());
    final double base = _parsedWeight ?? widget.initialWeightKg;
    final double next = (base + delta).clamp(20.0, 300.0);
    _weightCtrl.text = next.toStringAsFixed(1);
    _weightCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _weightCtrl.text.length),
    );
  }

  void _submit() {
    final double? w = _parsedWeight;
    if (w == null) return;
    unawaited(HapticFeedback.mediumImpact());
    Navigator.of(context).pop((weightKg: w, impedanceOhms: _parsedImpedance));
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final double? weight = _parsedWeight;
    final double? liveBmi = weight != null
        ? BiometricFormulas.calculateBmi(
            weightKg: weight,
            heightCm: widget.profile.heightCm,
          )
        : null;
    final double? liveEma = weight != null
        ? BiometricFormulas.calculateWeightEma(
            currentWeightKg: weight,
            previousEmaKg: widget.latestMeasurement?.trendWeightKg,
          )
        : null;
    final double? deltaPrev =
        (weight != null && widget.latestMeasurement != null)
            ? weight - widget.latestMeasurement!.weightKg
            : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: c.soft,
                  borderRadius: BorderRadius.circular(14),
                  border: c.isFlat
                      ? Border.all(color: c.line2, width: 1.5)
                      : null,
                ),
                child: Icon(AppIcons.bascula, color: c.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pesaje Manual',
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                      ),
                    ),
                    Text(
                      'Actualiza tus 13 métricas y tendencia EMA al instante',
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 12.5,
                        color: c.text2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Controles rápidos de incremento/decremento táctil
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _StepChip(label: '-0.5 kg', onTap: () => _stepWeight(-0.5)),
              _StepChip(label: '-0.1 kg', onTap: () => _stepWeight(-0.1)),
              _StepChip(label: '+0.1 kg', onTap: () => _stepWeight(0.1)),
              _StepChip(label: '+0.5 kg', onTap: () => _stepWeight(0.5)),
            ],
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _weightCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
              fontFamily: ScFonts.display,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: c.text,
            ),
            decoration: const InputDecoration(
              labelText: 'Peso en kilogramos',
              suffixText: 'kg',
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _impedanceCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Impedancia BIA opcional (100 – 3000 Ω)',
              hintText: 'Vacío si tu báscula solo mide peso',
              suffixText: 'Ω',
            ),
          ),

          if (weight != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.bg3,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: c.isFlat ? c.line2 : c.line,
                  width: c.isFlat ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _PreviewMiniStat(
                      label: 'Tendencia EMA',
                      value: '${liveEma!.toStringAsFixed(1)} kg',
                    ),
                  ),
                  Expanded(
                    child: _PreviewMiniStat(
                      label: 'IMC calculado',
                      value: liveBmi!.toStringAsFixed(1),
                    ),
                  ),
                  Expanded(
                    child: _PreviewMiniStat(
                      label: 'Vs anterior',
                      value: deltaPrev == null
                          ? 'Primer dato'
                          : '${deltaPrev >= 0 ? '+' : ''}${deltaPrev.toStringAsFixed(1)} kg',
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: weight != null ? _submit : null,
            icon: const Icon(AppIcons.check, size: 18),
            label: const Text('Guardar'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
            ),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}

/// Hoja modal guiada para validación antropométrica quincenal (Fórmula US Navy).
class NavyTapeMeasureSheet extends StatefulWidget {
  const NavyTapeMeasureSheet({
    super.key,
    required this.profile,
    this.latestMeasurement,
  });

  final UserProfile profile;
  final BodyMeasurement? latestMeasurement;

  static Future<({double waistCm, double neckCm, double? hipCm})?> show({
    required BuildContext context,
    required UserProfile profile,
    BodyMeasurement? latestMeasurement,
  }) {
    return mostrarHojaMenu<({double waistCm, double neckCm, double? hipCm})>(
      context,
      builder: (_) => NavyTapeMeasureSheet(
        profile: profile,
        latestMeasurement: latestMeasurement,
      ),
    );
  }

  @override
  State<NavyTapeMeasureSheet> createState() => _NavyTapeMeasureSheetState();
}

class _NavyTapeMeasureSheetState extends State<NavyTapeMeasureSheet> {
  late final TextEditingController _waistCtrl;
  late final TextEditingController _neckCtrl;
  late final TextEditingController _hipCtrl;

  bool get _isFemale => widget.profile.biologicalSex == 'female';

  @override
  void initState() {
    super.initState();
    _waistCtrl = TextEditingController(
      text: (widget.latestMeasurement?.waistCm ?? 80.0).toStringAsFixed(1),
    )..addListener(_refresh);
    _neckCtrl = TextEditingController(
      text: (widget.latestMeasurement?.neckCm ?? 38.0).toStringAsFixed(1),
    )..addListener(_refresh);
    _hipCtrl = TextEditingController(
      text: (widget.latestMeasurement?.hipCm ?? 95.0).toStringAsFixed(1),
    )..addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _waistCtrl
      ..removeListener(_refresh)
      ..dispose();
    _neckCtrl
      ..removeListener(_refresh)
      ..dispose();
    _hipCtrl
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  double? _parsePositive(TextEditingController ctrl) {
    final double? v = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
    if (v == null || v <= 10.0 || v > 250.0) return null;
    return v;
  }

  void _submit() {
    final double? waist = _parsePositive(_waistCtrl);
    final double? neck = _parsePositive(_neckCtrl);
    final double? hip = _isFemale ? _parsePositive(_hipCtrl) : null;
    if (waist == null || neck == null) return;
    if (_isFemale && hip == null) return;

    unawaited(HapticFeedback.mediumImpact());
    Navigator.of(context).pop((
      waistCm: waist,
      neckCm: neck,
      hipCm: hip,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final double? waist = _parsePositive(_waistCtrl);
    final double? neck = _parsePositive(_neckCtrl);
    final double? hip = _isFemale ? _parsePositive(_hipCtrl) : null;
    final bool validInputs =
        waist != null && neck != null && (!_isFemale || hip != null);

    double? navyFat;
    double? validatedFat;
    double? waistToHeight;
    if (validInputs) {
      navyFat = BiometricFormulas.calculateNavyBodyFatPercentage(
        heightCm: widget.profile.heightCm,
        waistCm: waist,
        neckCm: neck,
        isMale: !_isFemale,
        hipCm: hip,
      );
      final double biaFat =
          widget.latestMeasurement?.bodyFatPercentage ?? navyFat;
      validatedFat = BiometricFormulas.calculateValidatedBodyFat(
        biaBodyFatPercentage: biaFat,
        navyBodyFatPercentage: navyFat,
      );
      if (widget.profile.heightCm > 0) {
        waistToHeight = waist / widget.profile.heightCm;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: c.soft,
                  borderRadius: BorderRadius.circular(14),
                  border: c.isFlat
                      ? Border.all(color: c.line2, width: 1.5)
                      : null,
                ),
                child: Icon(AppIcons.tape, color: c.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Validación US Navy (Cinta)',
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 18.5,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                      ),
                    ),
                    Text(
                      'Control quincenal sin sesgo por retención hídrica',
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 12.5,
                        color: c.text2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.bg3,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: c.isFlat ? c.line2 : c.line,
                width: c.isFlat ? 1.5 : 1.0,
              ),
            ),
            child: Text(
              _isFemale
                  ? 'Mide en ayunas sin comprimir la piel: cintura a nivel umbilical, cuello bajo la laringe y cadera en su contorno más amplio.'
                  : 'Mide en ayunas sin comprimir la piel: cintura a nivel umbilical al espirar suave y cuello justo debajo de la laringe.',
              style: TextStyle(
                fontFamily: ScFonts.ui,
                fontSize: 12,
                height: 1.35,
                color: c.text2,
              ),
            ),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _waistCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Circunferencia de cintura',
              suffixText: 'cm',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _neckCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Circunferencia de cuello',
              suffixText: 'cm',
            ),
          ),
          if (_isFemale) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _hipCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Circunferencia de cadera',
                suffixText: 'cm',
              ),
            ),
          ],

          if (navyFat != null && validatedFat != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.bg3,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: c.accent,
                  width: c.isFlat ? 1.5 : 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _PreviewMiniStat(
                          label: 'US Navy (cinta)',
                          value: '${navyFat.toStringAsFixed(1)}%',
                        ),
                      ),
                      Expanded(
                        child: _PreviewMiniStat(
                          label: 'Grasa Validada 60/40',
                          value: '${validatedFat.toStringAsFixed(1)}%',
                          highlight: true,
                        ),
                      ),
                    ],
                  ),
                  if (waistToHeight != null) ...[
                    const SizedBox(height: 8),
                    Divider(height: 1, color: c.line),
                    const SizedBox(height: 8),
                    Text(
                      'Índice cintura/estatura: ${waistToHeight.toStringAsFixed(2)} '
                      '(${waistToHeight < 0.50 ? "Rango metabólico saludable < 0.50" : "Objetivo saludable < 0.50"})',
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 12,
                        color: c.text2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: validInputs ? _submit : null,
            icon: const Icon(AppIcons.check, size: 18),
            label: const Text('Guardar validación'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
            ),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}

/// Hoja de configuración opcional de dirección MAC Bluetooth para Mi Scale 2.
class ScaleMacConfigSheet extends StatefulWidget {
  const ScaleMacConfigSheet({
    super.key,
    required this.currentMac,
  });

  final String? currentMac;

  static Future<String?> show({
    required BuildContext context,
    required String? currentMac,
  }) {
    return mostrarHojaMenu<String>(
      context,
      builder: (_) => ScaleMacConfigSheet(currentMac: currentMac),
    );
  }

  @override
  State<ScaleMacConfigSheet> createState() => _ScaleMacConfigSheetState();
}

class _ScaleMacConfigSheetState extends State<ScaleMacConfigSheet> {
  late final TextEditingController _macCtrl;

  @override
  void initState() {
    super.initState();
    _macCtrl = TextEditingController(text: widget.currentMac ?? '');
  }

  @override
  void dispose() {
    _macCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final bool hasExisting =
        widget.currentMac != null && widget.currentMac!.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: c.soft,
                  borderRadius: BorderRadius.circular(14),
                  border: c.isFlat
                      ? Border.all(color: c.line2, width: 1.5)
                      : null,
                ),
                child: Icon(AppIcons.bluetooth, color: c.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vínculo Xiaomi Mi Scale 2',
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 18.5,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                      ),
                    ),
                    Text(
                      'Lectura pasiva BLE 0x181B 100% local sin Zepp Life',
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 12.5,
                        color: c.text2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Si dejas el campo vacío, NB Selfcare detecta automáticamente cualquier Xiaomi Mi Body Composition Scale 2 cercana. Fija una dirección MAC solo si convives con varias básculas Bluetooth.',
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 12.5,
              height: 1.4,
              color: c.text2,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _macCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Dirección MAC opcional',
              hintText: 'Ej. A4:C1:38:12:34:56 (vacío = automático)',
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              if (hasExisting) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(''),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Modo automático'),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pop(_macCtrl.text.trim()),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Guardar ajuste'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Subpágina educativa de detalle al tocar cualquiera de las 13 métricas.
class BiometricMetricDetailSheet extends StatelessWidget {
  const BiometricMetricDetailSheet({
    super.key,
    required this.spec,
    this.onActionTap,
    this.actionLabel,
  });

  final BiometricMetricSpec spec;
  final VoidCallback? onActionTap;
  final String? actionLabel;

  static Future<void> show({
    required BuildContext context,
    required BiometricMetricSpec spec,
    VoidCallback? onActionTap,
    String? actionLabel,
  }) {
    return mostrarHojaMenu<void>(
      context,
      builder: (_) => BiometricMetricDetailSheet(
        spec: spec,
        onActionTap: onActionTap,
        actionLabel: actionLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final Color badgeColor = BiometricMetricCatalog.toneColor(c, spec.tone);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: c.soft,
                  borderRadius: BorderRadius.circular(14),
                  border: c.isFlat
                      ? Border.all(color: c.line2, width: 1.5)
                      : null,
                ),
                child: Icon(spec.icon, color: c.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spec.title,
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      spec.subtitle,
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 12.5,
                        color: c.text2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: c.bg3,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: badgeColor,
                    width: c.isFlat ? 1.5 : 1.1,
                  ),
                ),
                child: Text(
                  spec.statusLabel,
                  style: TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: c.isFlat ? c.text : badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.bg3,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: c.isFlat ? c.line2 : c.line,
                width: c.isFlat ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Valor actual',
                  style: TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: 12,
                    color: c.text3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  spec.valueLabel,
                  style: TextStyle(
                    fontFamily: ScFonts.display,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: c.text,
                  ),
                ),
                if (spec.progressFraction != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: spec.progressFraction,
                      minHeight: 7,
                      backgroundColor: c.bg2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        c.isFlat ? c.text : badgeColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          Text(
            '¿Qué representa?',
            style: TextStyle(
              fontFamily: ScFonts.display,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            spec.whatItMeans,
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 13,
              height: 1.42,
              color: c.text2,
            ),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.bg3,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: c.isFlat ? c.line2 : c.line,
                width: c.isFlat ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spec.referenceGuide,
                  style: TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  spec.formulaNote,
                  style: TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: 11.5,
                    height: 1.35,
                    color: c.text3,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),
          if (onActionTap != null && actionLabel != null) ...[
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onActionTap!();
              },
              icon: const Icon(AppIcons.tape, size: 18),
              label: Text(actionLabel!),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
            ),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: c.bg3,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: c.isFlat ? c.line2 : c.line,
            width: c.isFlat ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: ScFonts.display,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: c.text,
          ),
        ),
      ),
    );
  }
}

class _PreviewMiniStat extends StatelessWidget {
  const _PreviewMiniStat({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: ScFonts.ui,
            fontSize: 11,
            color: c.text3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontFamily: ScFonts.display,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: highlight ? c.accent : c.text,
          ),
        ),
      ],
    );
  }
}
