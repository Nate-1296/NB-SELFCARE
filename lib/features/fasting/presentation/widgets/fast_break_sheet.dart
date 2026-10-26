import 'package:flutter/material.dart';
import '../../../../core/services/fasting_dosage_advisor.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/sheet.dart';

/// Modal informativo para romper el ayuno de forma segura y progresiva.
class FastBreakSheet extends StatelessWidget {
  const FastBreakSheet({
    super.key,
    required this.actualHours,
  });

  final double actualHours;

  static Future<void> show(BuildContext context, {required double actualHours}) {
    return mostrarHojaMenu<void>(
      context,
      builder: (_) => FastBreakSheet(actualHours: actualHours),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final List<FastBreakStage> stages =
        FastingDosageAdvisor.getRefeedingGuidance(actualHours);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: c.isFlat ? c.line2 : c.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.soup_kitchen_rounded,
                    color: c.accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Ruptura Segura de Ayuno',
                        style: TextStyle(
                          fontFamily: ScFonts.display,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: c.text,
                        ),
                      ),
                      Text(
                        'Completaste ${actualHours.toStringAsFixed(1)} horas de ayuno metabólico',
                        style: TextStyle(
                          fontFamily: ScFonts.ui,
                          fontSize: 12,
                          color: c.text2,
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
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.bg3,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: c.isFlat ? c.line2 : c.line,
                  width: c.isFlat ? 1.4 : 1.0,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.info_outline_rounded, color: c.accent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tras un reposo digestivo prolongado, tu microbiota y enzimas estomacales necesitan una activación gradual para evitar picos abruptos de glucosa o pesadez.',
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 12.5,
                        color: c.text,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Etapas de realimentación
            for (final FastBreakStage stage in stages) ...<Widget>[
              _StageCard(stage: stage),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Entendido, ¡a disfrutar con salud!'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({required this.stage});

  final FastBreakStage stage;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.bg3,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: c.isFlat ? c.line2 : c.line,
          width: c.isFlat ? 1.3 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.isFlat ? c.text : c.accent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${stage.phaseNumber}',
                  style: TextStyle(
                    fontFamily: ScFonts.display,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: c.isFlat ? c.bg : Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  stage.title,
                  style: TextStyle(
                    fontFamily: ScFonts.display,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: c.text,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.isFlat ? c.line2 : c.soft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  stage.timing,
                  style: TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: c.isFlat ? c.text : c.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            stage.description,
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 12,
              color: c.text2,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),

          // Alimentos recomendados
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.check_circle_rounded, color: c.protein, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  stage.recommendedFoods.join(' · '),
                  style: TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Qué evitar
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.cancel_rounded, color: c.warning, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  stage.foodsToAvoid.join(' · '),
                  style: TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: 11.5,
                    color: c.text2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

