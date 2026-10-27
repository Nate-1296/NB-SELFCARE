import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/science_on_demand_sheet.dart';

// Fichas divulgativas de "Ciencia a demanda" para electrolitos y fibra.
// Son contenido editorial (con sus referencias), no textos de interfaz.

void showSodiumScience(BuildContext context) {
  unawaited(
    ScienceOnDemandSheet.show(
      context,
      const ScienceSpec(
        title: 'Sodio (Na) y Retención Hídrica',
        badgeLabel: 'Electrolito Extracelular • UL: 2,300 mg/día',
        icon: AppIcons.bolt,
        quickTake:
            'El sodio regula el volumen sanguíneo, la presión osmótica y la transmisión neuromuscular.',
        howItWorks:
            'Consumir más de 2,300 mg de sodio al día estimula la vasopresina (ADH) y retiene agua extracelular. Cada gramo extra de sal retiene hasta 200 ml de agua, generando subidas de +1 a +2 kg en báscula que no corresponden a ganancia de grasa.',
        formula: 'UL Sodio = 2,300 mg/día (≈ 5.75 g de sal común)',
        scientificReferences: <String>[
          'World Health Organization (WHO). Guideline: Sodium intake for adults and children.',
          'He, F. J. & MacGregor, G. A. (2002). Effect of modest salt reduction on blood pressure.',
        ],
        actionableAdvice:
            'Si tu peso sube tras una comida salada, no hagas recortes drásticos de calorías. Aumenta agua y potasio para restaurar el balance.',
      ),
    ),
  );
}

void showPotassiumScience(BuildContext context) {
  unawaited(
    ScienceOnDemandSheet.show(
      context,
      const ScienceSpec(
        title: 'Potasio (K) y Balance Celular',
        badgeLabel: 'Electrolito Intracelular • Meta: 3,500 - 4,700 mg',
        icon: AppIcons.bolt,
        quickTake:
            'El potasio contrarresta los efectos del sodio, relaja los vasos sanguíneos y facilita la síntesis de glucógeno.',
        howItWorks:
            'La bomba Na+/K+ ATPasa requiere una relación K:Na superior a 2:1. En alimentos naturales no hay techo tóxico para riñones sanos; en suplementos concentrados el límite seguro es 4,700 mg.',
        formula: 'Relación K:Na Óptima ≥ 2.0 : 1',
        scientificReferences: <String>[
          'NASEM. Dietary Reference Intakes for Sodium and Potassium.',
          'Whelton, P. K. et al. (1997). Effects of oral potassium on blood pressure.',
        ],
        actionableAdvice:
            'Prioriza frutas, verduras, aguacates y patatas. El potasio alimentario acelera la excreción del exceso de sodio.',
      ),
    ),
  );
}

void showMagnesiumScience(BuildContext context) {
  unawaited(
    ScienceOnDemandSheet.show(
      context,
      const ScienceSpec(
        title: 'Magnesio (Mg) y Tolerancia Suplementaria',
        badgeLabel: 'Cofactor Enzimático • UL Suplementario: 350 mg',
        icon: AppIcons.bolt,
        quickTake:
            'Esencial para producción de ATP, síntesis proteica, contracción muscular y calidad del sueño.',
        howItWorks:
            'El magnesio dietético no tiene toxicidad, pero suplementos farmacológicos (óxido, citrato) tienen un Límite Tolerable (UL) de 350 mg/día por su efecto osmótico, que puede provocar diarrea si se excede.',
        formula: 'UL Suplementario = 350 mg/día de magnesio elemental',
        scientificReferences: <String>[
          'Institute of Medicine (US). Dietary Reference Intakes for Magnesium.',
          'Nielsen, F. H. (2010). Magnesium, inflammation, and obesity in humans.',
        ],
        actionableAdvice:
            'Toma suplementos de magnesio (bisglicinato o citrato) con la cena para favorecer la relajación del sistema nervioso.',
      ),
    ),
  );
}

void showFiberScience(BuildContext context) {
  unawaited(
    ScienceOnDemandSheet.show(
      context,
      const ScienceSpec(
        title: 'Fibra Dietética y Microbiota',
        badgeLabel: 'Salud Intestinal y Saciedad • Meta: 25 - 38 g/día',
        icon: Icons.grain_rounded,
        quickTake:
            'La fibra dietética modula la absorción de glucosa, mejora la saciedad y nutre la microbiota con ácidos grasos de cadena corta.',
        howItWorks:
            'La fibra soluble retrasa el vaciamiento gástrico prolongando la saciedad, mientras que la insoluble acelera el tránsito colónico. Las bacterias fermentan la fibra generando butirato y propionato.',
        formula: 'Meta Diaria: 14 g de fibra por cada 1,000 kcal consumidas',
        scientificReferences: <String>[
          'Dahl, W. J. & Stewart, M. L. (2015). Health Implications of Dietary Fiber.',
          'Sonnenburg, E. D. & Sonnenburg, J. L. (2014). Starving our microbial self.',
        ],
        actionableAdvice:
            'Aumenta la fibra de manera progresiva acompañada siempre de abundante agua para una digestión óptima.',
      ),
    ),
  );
}

