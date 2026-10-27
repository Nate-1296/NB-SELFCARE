import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/science_on_demand_sheet.dart';

// Fichas divulgativas de "Ciencia a demanda" del perfil (contenido editorial).

void showTdeeScience(BuildContext context) {
  unawaited(
    ScienceOnDemandSheet.show(
      context,
      const ScienceSpec(
        title: 'Gasto Energético Diario (TDEE)',
        badgeLabel: 'Metabolismo Basal + Actividad',
        icon: AppIcons.fuego,
        quickTake:
            'Tu TDEE es la energía real gastada por tu organismo en 24 horas sumando metabolismo basal, digestión y movimiento.',
        howItWorks:
            'A diferencia de las fórmulas estándar estáticas que asumen factores teóricos fijos, NB Selfcare utiliza un filtro de suavizado exponencial (EMA) de 14 días cruzando tu ingesta calórica diaria con la oscilación real del peso filtrado para calcular con exactitud tu gasto metabólico verdadero.',
        formula:
            'TDEE = Ingesta Diaria (kcal) - [Δ Peso Filtrado (kg) × 7700 kcal / Días]',
        scientificReferences: <String>[
          'Hall, K. D. et al. (2011). Quantification of the effect of energy imbalance on bodyweight. The Lancet.',
          'Mifflin, M. D. et al. (1990). A new predictive equation for resting energy expenditure.',
        ],
        actionableAdvice:
            'Registra tus comidas y pésate con frecuencia. Cuantos más días consecutivos con registros existan, mayor precisión matemática tendrá la calibración.',
      ),
    ),
  );
}

void showWeightTrendScience(BuildContext context) {
  unawaited(
    ScienceOnDemandSheet.show(
      context,
      const ScienceSpec(
        title: 'Tendencia de Peso y Fluctuaciones',
        badgeLabel: 'Masa Grasa vs Agua Transitoria',
        icon: AppIcons.cuerpo,
        quickTake:
            'Las subidas o bajadas bruscas de peso de un día para otro casi nunca son grasa corporal, sino variaciones de agua, glucógeno y contenido digestivo.',
        howItWorks:
            'Almacenar 1 gramo de glucógeno retiene entre 3 y 4 gramos de agua intracelular. Una comida con más carbohidratos o sodio, un entrenamiento muscular intenso, la ingesta de creatina o la fase lútea pueden alterar el peso en 1 a 2.5 kg de pura agua transitoria.',
        formula: '1g Glucógeno = +3.5g H₂O retención celular',
        scientificReferences: <String>[
          'Fernández-Elías, V. E. et al. (2015). Relationship between muscle water and glycogen recovery.',
          'Davy, K. P. & Hall, J. E. (2004). Weight gain and hormonal fluid retention.',
        ],
        actionableAdvice:
            'No te alarmes por picos puntuales. Observa siempre la media móvil semanal suavizada (EMA) y el porcentaje de grasa medido por impedancia.',
      ),
    ),
  );
}

