import 'package:flutter/material.dart';

import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_theme.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/health_card.dart';
import 'nutrient_science.dart';

/// Tarjeta Bento 2×2 para el Triángulo de Electrolitos y Fibra con límites UL y pedagogía.
class ElectrolytesCard extends StatelessWidget {
  const ElectrolytesCard({super.key, 
    required this.sodiumMg,
    required this.targetSodiumMg,
    required this.potassiumMg,
    required this.targetPotassiumMg,
    required this.magnesiumMg,
    required this.targetMagnesiumMg,
    required this.fiberG,
    required this.targetFiberG,
  });

  final double sodiumMg;
  final double targetSodiumMg;
  final double potassiumMg;
  final double targetPotassiumMg;
  final double magnesiumMg;
  final double targetMagnesiumMg;
  final double fiberG;
  final double targetFiberG;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final bool highSodium = sodiumMg > targetSodiumMg * 1.15;
    final bool ulSodium = sodiumMg > 2300;
    final bool ulPotassium = potassiumMg > 4700;
    final bool ulMagnesium = magnesiumMg > 350;

    return HealthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(AppIcons.bolt, size: 19, color: c.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.comerElectrolitosYFibra,
                  softWrap: true,
                  style: TextStyle(
                    fontFamily: ScFonts.display,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: c.text,
                  ),
                ),
              ),
              if (ulSodium)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.bg3,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: c.isFlat ? c.line2 : c.fasting,
                    ),
                  ),
                  child: Text(
                    context.l10n.comerUlSodio2300mg,
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: c.isFlat ? c.text : c.fasting,
                    ),
                  ),
                )
              else if (highSodium)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.bg3,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: c.isFlat ? c.line2 : c.warning,
                    ),
                  ),
                  child: Text(
                    context.l10n.comerSodioElevado,
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: c.isFlat ? c.text : c.warning,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _MicroCell(
                  title: context.l10n.comerSodioNa,
                  currentText: context.l10n.comerMg(sodiumMg.round().toString()),
                  targetText: context.l10n.comerMetaMg(targetSodiumMg.round().toString()),
                  ratio: (sodiumMg / targetSodiumMg).clamp(0.0, 1.0),
                  color: c.isFlat
                      ? c.text
                      : (ulSodium
                          ? c.fasting
                          : (highSodium ? c.warning : c.water)),
                  badgeLabel: ulSodium ? context.l10n.comerTechoUl: null,
                  onTap: () => showSodiumScience(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MicroCell(
                  title: context.l10n.comerPotasioK,
                  currentText: context.l10n.comerMg2(potassiumMg.round().toString()),
                  targetText: context.l10n.comerMetaMg2(targetPotassiumMg.round().toString()),
                  ratio: (potassiumMg / targetPotassiumMg).clamp(0.0, 1.0),
                  color: c.isFlat
                      ? c.text
                      : (ulPotassium ? c.warning : c.steps),
                  badgeLabel: ulPotassium ? context.l10n.comerTechoSupl: null,
                  onTap: () => showPotassiumScience(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _MicroCell(
                  title: context.l10n.comerMagnesioMg,
                  currentText: context.l10n.comerMg3(magnesiumMg.round().toString()),
                  targetText: context.l10n.comerMetaMg3(targetMagnesiumMg.round().toString()),
                  ratio: (magnesiumMg / targetMagnesiumMg).clamp(0.0, 1.0),
                  color: c.isFlat
                      ? c.text
                      : (ulMagnesium ? c.warning : c.fasting),
                  badgeLabel: ulMagnesium ? context.l10n.comerTechoSupl: null,
                  onTap: () => showMagnesiumScience(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MicroCell(
                  title: context.l10n.comerFibraDietetica,
                  currentText: context.l10n.comerG(fiberG.round().toString()),
                  targetText: context.l10n.comerMetaG(targetFiberG.round().toString()),
                  ratio: (fiberG / targetFiberG).clamp(0.0, 1.0),
                  color: c.isFlat ? c.text : c.accent,
                  onTap: () => showFiberScience(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MicroCell extends StatelessWidget {
  const _MicroCell({
    required this.title,
    required this.currentText,
    required this.targetText,
    required this.ratio,
    required this.color,
    this.badgeLabel,
    this.onTap,
  });

  final String title;
  final String currentText;
  final String targetText;
  final double ratio;
  final Color color;
  final String? badgeLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final Widget cellContent = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.bg3,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: c.isFlat ? c.line2 : c.line,
          width: c.isFlat ? 1.3 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  softWrap: true,
                  style: TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: c.text2,
                  ),
                ),
              ),
              if (badgeLabel != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: c.fasting.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeLabel!,
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: c.isFlat ? c.text : c.fasting,
                    ),
                  ),
                )
              else if (onTap != null)
                Icon(
                  Icons.info_outline_rounded,
                  size: 13,
                  color: c.text3,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            currentText,
            softWrap: true,
            style: TextStyle(
              fontFamily: ScFonts.display,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: c.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            targetText,
            softWrap: true,
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 11,
              color: c.text3,
            ),
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: ratio,
            backgroundColor: c.bg2,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            borderRadius: BorderRadius.circular(4),
            minHeight: 5,
          ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: cellContent,
        ),
      );
    }

    return cellContent;
  }
}
