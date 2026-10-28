import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/sheet.dart';
import 'cuerpo/body_metric_catalog.dart';

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
                  border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
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
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      spec.subtitle,
                      style: TextStyle(fontFamily: ScFonts.ui, fontSize: 12.5, color: c.text2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: c.bg3,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: badgeColor, width: c.isFlat ? 1.5 : 1.1),
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
              border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.bodyValorActual,
                  style: TextStyle(fontFamily: ScFonts.ui, fontSize: 12, color: c.text3),
                ),
                const SizedBox(height: 4),
                Text(
                  spec.valueLabel,
                  style: TextStyle(
                    fontFamily: ScFonts.display,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
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
                      valueColor: AlwaysStoppedAnimation<Color>(c.isFlat ? c.text : badgeColor),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          Text(
            context.l10n.bodyQueRepresenta,
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
            style: TextStyle(fontFamily: ScFonts.ui, fontSize: 13, height: 1.42, color: c.text2),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.bg3,
              borderRadius: BorderRadius.circular(14),
              border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
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
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
            child: Text(context.l10n.commonClose),
          ),
        ],
      ),
    );
  }
}
