import 'package:flutter/material.dart';

import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_theme.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/health_card.dart';

/// Tarjeta Hero de Energía y Macronutrientes con anillo calórico y carbohidratos netos.
class EnergyAndMacrosCard extends StatelessWidget {
  const EnergyAndMacrosCard({super.key, 
    required this.totalKcal,
    required this.targetKcal,
    required this.netWorkoutKcal,
    required this.totalP,
    required this.targetP,
    required this.totalC,
    required this.targetC,
    required this.netCarbs,
    required this.totalFiber,
    required this.totalF,
    required this.targetF,
    this.onOpenOracle,
  });

  final double totalKcal;
  final int targetKcal;
  final int netWorkoutKcal;
  final double totalP;
  final double targetP;
  final double totalC;
  final double targetC;
  final double netCarbs;
  final double totalFiber;
  final double totalF;
  final double targetF;
  final VoidCallback? onOpenOracle;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final int consumedInt = totalKcal.round();
    final int remaining = targetKcal - consumedInt;
    final double kcalRatio =
        targetKcal > 0 ? (totalKcal / targetKcal).clamp(0.0, 1.0) : 0.0;
    final int pct = (kcalRatio * 100).round();

    return HealthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 92,
                height: 92,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    SizedBox(
                      width: 92,
                      height: 92,
                      child: CircularProgressIndicator(
                        value: kcalRatio,
                        strokeWidth: 9.5,
                        strokeCap:
                            c.isFlat ? StrokeCap.butt : StrokeCap.round,
                        backgroundColor: c.bg3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          c.isFlat ? c.text : c.calories,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          AppIcons.fuego,
                          size: 17,
                          color: c.isFlat ? c.text : c.calories,
                        ),
                        Text(
                          '$pct%',
                          style: TextStyle(
                            fontFamily: ScFonts.display,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: c.text,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.l10n.comerBalanceEnergetico,
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: c.text2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    RichText(
                      text: TextSpan(
                        text: '$consumedInt',
                        style: TextStyle(
                          fontFamily: ScFonts.display,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: c.text,
                        ),
                        children: <InlineSpan>[
                          TextSpan(
                            text: context.l10n.comerKcal((targetKcal).toString()),
                            style: TextStyle(
                              fontFamily: ScFonts.ui,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: c.text2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: c.bg3,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: c.isFlat ? c.line2 : c.line,
                            ),
                          ),
                          child: Text(
                            remaining >= 0
                                ? context.l10n.comerDisponiblesKcal((remaining).toString()): context.l10n.comerKcalSobreLaMeta(remaining.abs().toString()),
                            softWrap: true,
                            style: TextStyle(
                              fontFamily: ScFonts.ui,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: remaining >= 0
                                  ? (c.isFlat ? c.text : c.accent)
                                  : (c.isFlat ? c.text : c.warning),
                            ),
                          ),
                        ),
                        if (netWorkoutKcal > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: c.bg3,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: c.isFlat ? c.line2 : c.steps,
                              ),
                            ),
                            child: Text(
                              context.l10n.comerKcalEntreno((netWorkoutKcal).toString()),
                              style: TextStyle(
                                fontFamily: ScFonts.ui,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: c.isFlat ? c.text : c.steps,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: c.line),
          ),

          // 3 barras amplias de macronutrientes (cero truncamiento)
          _MacroWideRow(
            label: context.l10n.todayProteina,
            currentG: totalP,
            targetG: targetP,
            badgeText: totalP >= targetP
                ? context.l10n.comerMetaCubierta: context.l10n.comerFaltanG((targetP - totalP).round().toString()),
            barColor: c.isFlat ? c.text : c.protein,
          ),
          const SizedBox(height: 12),
          _MacroWideRow(
            label: context.l10n.todayCarbohidratos,
            currentG: totalC,
            targetG: targetC,
            badgeText:
                context.l10n.comerNetosGFibraG(netCarbs.round().toString(), totalFiber.round().toString()),
            barColor: c.isFlat ? c.text : c.carbs,
          ),
          const SizedBox(height: 12),
          _MacroWideRow(
            label: context.l10n.todayGrasasSaludables,
            currentG: totalF,
            targetG: targetF,
            badgeText: totalF >= targetF
                ? context.l10n.comerMetaCubierta: context.l10n.comerFaltanG((targetF - totalF).round().toString()),
            barColor: c.isFlat ? c.text : c.fat,
          ),
          if (onOpenOracle != null) ...<Widget>[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onOpenOracle,
              icon: Icon(Icons.auto_awesome_rounded, size: 16, color: c.accent),
              label: Text(
                context.l10n.comerQueComerParaCerrarMis,
                style: TextStyle(
                  fontFamily: ScFonts.ui,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                ),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
                side: BorderSide(
                  color: c.isFlat ? c.line2 : c.accent.withValues(alpha: 0.35),
                  width: 1.2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MacroWideRow extends StatelessWidget {
  const _MacroWideRow({
    required this.label,
    required this.currentG,
    required this.targetG,
    required this.badgeText,
    required this.barColor,
  });

  final String label;
  final double currentG;
  final double targetG;
  final String badgeText;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final double ratio =
        targetG > 0 ? (currentG / targetG).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                softWrap: true,
                style: TextStyle(
                  fontFamily: ScFonts.display,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: c.text,
                ),
              ),
            ),
            RichText(
              text: TextSpan(
                text: context.l10n.comerG2(currentG.round().toString()),
                style: TextStyle(
                  fontFamily: ScFonts.display,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: c.text,
                ),
                children: <InlineSpan>[
                  TextSpan(
                    text: context.l10n.comerG3(targetG.round().toString()),
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 12,
                      color: c.text3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        LinearProgressIndicator(
          value: ratio,
          backgroundColor: c.bg3,
          valueColor: AlwaysStoppedAnimation<Color>(barColor),
          borderRadius: BorderRadius.circular(5),
          minHeight: 6.5,
        ),
        const SizedBox(height: 4),
        Text(
          badgeText,
          softWrap: true,
          style: TextStyle(
            fontFamily: ScFonts.ui,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: c.text2,
          ),
        ),
      ],
    );
  }
}
