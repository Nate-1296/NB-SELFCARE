import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/services/cross_analytics_engine.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_theme.dart';
import '../../../../../shared/utils/number_formats.dart';
import '../../../../../shared/widgets/health_card.dart';
import '../../../application/profile_queries.dart';

/// Tarjeta de Correlaciones Pearson Offline.
class CrossAnalyticsCard extends ConsumerWidget {
  const CrossAnalyticsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final AsyncValue<List<CrossCorrelationInsight>> async = ref.watch(crossInsightsProvider);

    return Builder(
      builder: (BuildContext context) {
        if (async.isLoading && !async.hasValue) {
          return const HealthCard(
            margin: EdgeInsets.zero,
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final List<CrossCorrelationInsight> insights =
            async.value ?? const <CrossCorrelationInsight>[];

        return HealthCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.hub_rounded, size: 20, color: c.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.perfilCorrelacionesEstadisticasPearsonR,
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: c.text,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    tooltip: context.l10n.perfilRecalcularCorrelaciones,
                    onPressed: () {
                      unawaited(HapticFeedback.selectionClick());
                      ref.invalidate(crossInsightsProvider);
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (insights.isEmpty) ...<Widget>[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.bg3,
                    borderRadius: BorderRadius.circular(14),
                    border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.auto_graph_rounded,
                            size: 16,
                            color: c.isFlat ? c.text : c.accent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              context.l10n.perfilCalibrandoCorrelacionesMultivariables,
                              style: TextStyle(
                                fontFamily: ScFonts.ui,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: c.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.l10n.perfilElMotorOfflineRequiereAl,
                        style: TextStyle(
                          fontFamily: ScFonts.ui,
                          fontSize: 11.5,
                          height: 1.35,
                          color: c.text2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          Icon(Icons.lock_outline_rounded, size: 13, color: c.text3),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              context.l10n.perfil100OfflineCeroTelemetriaComputacion,
                              style: TextStyle(
                                fontFamily: ScFonts.ui,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: c.text3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...<Widget>[
                Text(
                  context.l10n.perfilDescubrimientosMatematicosCruzandoTusMetricas,
                  style: TextStyle(fontFamily: ScFonts.ui, fontSize: 12, color: c.text2),
                ),
                const SizedBox(height: 10),
                for (final CrossCorrelationInsight ins in insights)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.bg3,
                        borderRadius: BorderRadius.circular(14),
                        border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: c.isFlat ? c.line2 : c.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              context.l10n.perfilR(NumberFormats.fixed(ins.correlationR, 2)),
                              style: TextStyle(
                                fontFamily: ScFonts.display,
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: c.isFlat ? c.text : c.accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  ins.title,
                                  style: TextStyle(
                                    fontFamily: ScFonts.ui,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: c.text,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  ins.description,
                                  style: TextStyle(
                                    fontFamily: ScFonts.ui,
                                    fontSize: 11.5,
                                    color: c.text2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}
