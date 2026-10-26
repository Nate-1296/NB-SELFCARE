import 'package:flutter/material.dart';

import '../theme/sc_colors.dart';
import '../theme/sc_theme.dart';
import 'app_icons.dart';
import 'sheet.dart';

/// Especificación de contenido para una tarjeta o concepto científico en la aplicación.
class ScienceSpec {
  const ScienceSpec({
    required this.title,
    required this.badgeLabel,
    this.icon = AppIcons.hoy,
    required this.quickTake,
    required this.howItWorks,
    this.formula,
    this.scientificReferences = const <String>[],
    required this.actionableAdvice,
  });

  final String title;
  final String badgeLabel;
  final IconData icon;
  final String quickTake;
  final String howItWorks;
  final String? formula;
  final List<String> scientificReferences;
  final String actionableAdvice;

  factory ScienceSpec.caffeineDecay({
    required double halfLifeHours,
    required String bedtimeCurfewTime,
    required double residualAtBedtimeMg,
  }) {
    return ScienceSpec(
      title: 'Decaimiento de la Cafeína',
      badgeLabel: 'Cronobiología & Sueño N3',
      icon: Icons.coffee_rounded,
      quickTake:
          'La cafeína tiene una semivida promedio de $halfLifeHours horas. Incluso cuando ya no sientes el estímulo activo, las moléculas residuales bloquean los receptores de adenosina y reducen el sueño profundo reparador.',
      howItWorks:
          'La adenosina es el neurotransmisor que acumula la presión homeostática de sueño. La cafeína actúa como antagonista competitivo en los receptores A1 y A2A. Si al acostarte tienes más de 25 mg activos, la arquitectura del sueño N3 de ondas lentas se fragmenta.',
      formula: 'C(t) = C₀ · (0.5)^(Δt / $halfLifeHours)',
      scientificReferences: const <String>[
        'Drake et al. (2013). Caffeine effects on sleep taken 0, 3, or 6 hours before going to bed. J Clin Sleep Med.',
        'EFSA NDA Panel (2015). Scientific Opinion on the safety of caffeine. EFSA Journal.',
      ],
      actionableAdvice:
          'Tu hora de corte aconsejada para café o pre-entreno es $bedtimeCurfewTime. Mantener el nivel residual bajo 25 mg al dormir (hoy proyectado en ${residualAtBedtimeMg.toStringAsFixed(1)} mg) restaura tu recuperación física y mental.',
    );
  }

  factory ScienceSpec.novaClassification() {
    return const ScienceSpec(
      title: 'Sistema de Clasificación NOVA',
      badgeLabel: 'Procesamiento Alimentario',
      icon: Icons.eco_rounded,
      quickTake:
          'El sistema NOVA clasifica los alimentos no por sus nutrientes aislados, sino por la intensidad y el propósito de su procesamiento industrial (Grupos 1 al 4).',
      howItWorks:
          '• Grupo 1: Alimentos sin procesar o mínimamente procesados (frutas, verduras, huevos, carnes frescas, legumbres).\n• Grupo 2: Ingredientes culinarios procesados (aceite de oliva, mantequilla, sal, especias).\n• Grupo 3: Alimentos procesados (conservas simples, quesos madurados, panadería artesanal).\n• Grupo 4: Productos ultraprocesados (formulaciones industriales con emulsionantes, colorantes, saborizantes y harinas refinadas).',
      scientificReferences: <String>[
        'Monteiro CA et al. (2019). Ultra-processed foods: what they are and how to identify them. Public Health Nutr.',
        'FAO / OMS (2019). Ultra-processed foods, diet quality, and health using the NOVA classification system.',
      ],
      actionableAdvice:
          'Apunta a que más del 70–80% de tus calorías provengan de los Grupos 1 al 3. La clave no es la perfección extrema, sino construir una base sólida de comida real con mínima manipulación industrial.',
    );
  }
}

/// Hoja modal pedagógica reutilizable para el principio "Action-First, Science-on-Demand".
/// Permite que la interfaz principal se mantenga limpia de fórmulas complejas, ofreciendo
/// la explicación científica profunda a demanda con solo un toque del usuario.
class ScienceOnDemandSheet extends StatelessWidget {
  const ScienceOnDemandSheet({
    super.key,
    required this.spec,
  });

  final ScienceSpec spec;

  /// Presenta la hoja pedagógica con el diseño responsivo del sistema.
  static Future<void> show(BuildContext context, ScienceSpec spec) {
    return mostrarHojaMenu<void>(
      context,
      builder: (_) => ScienceOnDemandSheet(spec: spec),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Encabezado con Icono y Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
                ),
                child: Icon(spec.icon, color: c.accent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: c.soft,
                        borderRadius: BorderRadius.circular(6),
                        border: c.isFlat ? Border.all(color: c.line2) : null,
                      ),
                      child: Text(
                        spec.badgeLabel.toUpperCase(),
                        style: TextStyle(
                          fontFamily: ScFonts.display,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: c.accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      spec.title,
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(AppIcons.close, color: c.text2),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // En Resumen (Takeaway ejecutivo)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.soft,
              borderRadius: BorderRadius.circular(12),
              border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : Border.all(color: c.line),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(AppIcons.check, color: c.accent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    spec.quickTake,
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ¿Cómo funciona en tu cuerpo? (Fisiología)
          Text(
            '¿Cómo funciona en tu cuerpo?',
            style: TextStyle(
              fontFamily: ScFonts.display,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: c.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            spec.howItWorks,
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 13,
              color: c.text2,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),

          // Fórmula Matemática (Opcional)
          if (spec.formula != null) ...[
            Text(
              'La Matemática Aplicada',
              style: TextStyle(
                fontFamily: ScFonts.display,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: c.text,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: c.bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.isFlat ? c.line2 : c.line),
              ),
              child: Text(
                spec.formula!,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: c.accent,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Qué debes hacer tú (Acción clara)
          Text(
            'Tu acción recomendada',
            style: TextStyle(
              fontFamily: ScFonts.display,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: c.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            spec.actionableAdvice,
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 13,
              color: c.text,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // Referencias Científicas (Opcional)
          if (spec.scientificReferences.isNotEmpty) ...[
            Text(
              'Evidencia y Literatura',
              style: TextStyle(
                fontFamily: ScFonts.display,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: c.text3,
              ),
            ),
            const SizedBox(height: 4),
            for (final ref in spec.scientificReferences)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '• $ref',
                  style: TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: 11,
                    color: c.text3,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            const SizedBox(height: 16),
          ],

          // Botón Entendido
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
