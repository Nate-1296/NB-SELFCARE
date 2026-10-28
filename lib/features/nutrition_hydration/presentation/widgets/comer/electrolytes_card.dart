import 'package:flutter/material.dart';

import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_tokens.dart';
import '../../../../../shared/utils/number_formats.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/card_header.dart';
import '../../../../../shared/widgets/health_card.dart';
import '../../../../../shared/widgets/pressable.dart';
import '../../../../../shared/widgets/progress_bar.dart';
import '../../../../../shared/widgets/tonal_badge.dart';
import 'nutrient_science.dart';

/// Tarjeta Bento 2×2 para el Triángulo de Electrolitos y Fibra con límites UL y pedagogía.
class ElectrolytesCard extends StatelessWidget {
  const ElectrolytesCard({
    super.key,
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
          CardHeader(
            title: context.l10n.comerElectrolitosYFibra,
            icon: AppIcons.bolt,
            tone: c.water,
            trailing: ulSodium
                ? TonalBadge(label: context.l10n.comerUlSodio2300mg, tone: c.danger)
                : (highSodium
                      ? TonalBadge(label: context.l10n.comerSodioElevado, tone: c.warning)
                      : null),
          ),
          const SizedBox(height: ScSpace.l),
          Row(
            children: <Widget>[
              Expanded(
                child: _MicroCell(
                  title: context.l10n.comerSodioNa,
                  currentText: context.l10n.comerMg(NumberFormats.group(sodiumMg)),
                  targetText: context.l10n.comerMetaMg(NumberFormats.group(targetSodiumMg)),
                  ratio: (sodiumMg / targetSodiumMg).clamp(0.0, 1.0),
                  color: c.isFlat
                      ? c.text
                      : (ulSodium ? c.fasting : (highSodium ? c.warning : c.water)),
                  badgeLabel: ulSodium ? context.l10n.comerTechoUl : null,
                  onTap: () => showSodiumScience(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MicroCell(
                  title: context.l10n.comerPotasioK,
                  currentText: context.l10n.comerMg2(NumberFormats.group(potassiumMg)),
                  targetText: context.l10n.comerMetaMg2(NumberFormats.group(targetPotassiumMg)),
                  ratio: (potassiumMg / targetPotassiumMg).clamp(0.0, 1.0),
                  color: c.isFlat ? c.text : (ulPotassium ? c.warning : c.steps),
                  badgeLabel: ulPotassium ? context.l10n.comerTechoSupl : null,
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
                  currentText: context.l10n.comerMg3(NumberFormats.group(magnesiumMg)),
                  targetText: context.l10n.comerMetaMg3(NumberFormats.group(targetMagnesiumMg)),
                  ratio: (magnesiumMg / targetMagnesiumMg).clamp(0.0, 1.0),
                  color: c.isFlat ? c.text : (ulMagnesium ? c.warning : c.fasting),
                  badgeLabel: ulMagnesium ? context.l10n.comerTechoSupl : null,
                  onTap: () => showMagnesiumScience(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MicroCell(
                  title: context.l10n.comerFibraDietetica,
                  currentText: context.l10n.comerG(NumberFormats.group(fiberG)),
                  targetText: context.l10n.comerMetaG(NumberFormats.group(targetFiberG)),
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
      padding: const EdgeInsets.fromLTRB(ScSpace.m + 2, ScSpace.m, ScSpace.m, ScSpace.m + 2),
      decoration: BoxDecoration(
        color: c.isFlat ? c.bg2 : c.bg3,
        borderRadius: BorderRadius.circular(ScRadius.tileOf(c)),
        border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.caption.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (badgeLabel != null)
                Flexible(child: TonalBadge(label: badgeLabel!, tone: c.danger))
              else if (onTap != null)
                Icon(Icons.info_outline_rounded, size: 15, color: c.text3),
            ],
          ),
          const SizedBox(height: ScSpace.s - 2),
          Text(currentText, maxLines: 1, style: context.type.metricS),
          const SizedBox(height: 3),
          Text(
            targetText,
            maxLines: 1,
            style: context.type.caption.copyWith(fontSize: 11.5, color: c.text3),
          ),
          const SizedBox(height: ScSpace.s),
          ScProgressBar(value: ratio, color: color, height: 5),
        ],
      ),
    );

    if (onTap != null) {
      return Pressable(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(ScRadius.tileOf(c)),
            onTap: onTap,
            child: cellContent,
          ),
        ),
      );
    }

    return cellContent;
  }
}
