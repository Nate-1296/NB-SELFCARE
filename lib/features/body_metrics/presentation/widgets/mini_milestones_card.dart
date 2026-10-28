import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/theme/sc_tokens.dart';
import '../../../../shared/utils/number_formats.dart';
import '../../../../shared/widgets/card_header.dart';
import '../../../../shared/widgets/health_card.dart';
import '../../../../shared/widgets/metric_value.dart';
import '../../../../shared/widgets/progress_bar.dart';
import '../../../../shared/widgets/quick_action_button.dart';
import '../../../../shared/widgets/tonal_badge.dart';
import '../../application/body_queries.dart';
import '../../application/milestone_service.dart';

/// Tarjeta de subdivisión psicológica de metas en mini-hitos de 1.5 kg (estilo Happy Scale).
class MiniMilestonesCard extends ConsumerStatefulWidget {
  const MiniMilestonesCard({
    super.key,
    required this.currentWeightKg,
    required this.targetWeightKg,
    required this.weeklyGoalRateKg,
  });

  final double currentWeightKg;
  final double targetWeightKg;
  final double weeklyGoalRateKg;

  @override
  ConsumerState<MiniMilestonesCard> createState() => _MiniMilestonesCardState();
}

class _MiniMilestonesCardState extends ConsumerState<MiniMilestonesCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final List<MilestoneGoal> milestones =
        ref.watch(milestonesProvider).value ?? const <MilestoneGoal>[];

    return Builder(
      builder: (BuildContext context) {
        // Si no existen hitos generados aún, mostramos botón generador
        if (milestones.isEmpty) {
          return HealthCard(
            child: CardHeader(
              icon: Icons.flag_rounded,
              tone: c.accent,
              title: context.l10n.bodyMiniHitosPsicologicos,
              subtitle: context.l10n.bodyDescomponTuMetaEnTramos,
              trailing: QuickActionButton(
                label: context.l10n.bodyGenerar,
                tone: c.accent,
                expand: false,
                onPressed: () async {
                  unawaited(HapticFeedback.lightImpact());
                  await ref
                      .read(milestoneServiceProvider)
                      .regenerate(
                        currentWeightKg: widget.currentWeightKg,
                        targetWeightKg: widget.targetWeightKg,
                      );
                },
              ),
            ),
          );
        }

        // Hito activo (primer hito aún no completado)
        final MilestoneGoal? activeMilestone = milestones
            .where((MilestoneGoal m) => !m.isCompleted)
            .firstOrNull;

        final int completedCount = milestones.where((MilestoneGoal m) => m.isCompleted).length;
        final int totalCount = milestones.length;

        // Progreso hacia el hito activo
        double milestoneProgress = 0.0;
        double remainingKgToActive = 0.0;
        String projectedTimeLabel = '';

        if (activeMilestone != null) {
          final double milestoneTarget = activeMilestone.targetWeightKg;
          final double previousTarget = activeMilestone.milestoneOrder > 1
              ? milestones[activeMilestone.milestoneOrder - 2].targetWeightKg
              : widget.currentWeightKg;

          final double span = (previousTarget - milestoneTarget).abs();
          final double currentProgress = (previousTarget - widget.currentWeightKg).abs();

          milestoneProgress = span > 0 ? (currentProgress / span).clamp(0.0, 1.0) : 1.0;
          remainingKgToActive = (widget.currentWeightKg - milestoneTarget).abs();

          final double effectiveWeeklyRate = widget.weeklyGoalRateKg.abs() > 0.05
              ? widget.weeklyGoalRateKg.abs()
              : 0.35; // Tasa por defecto
          final double weeksRemaining = remainingKgToActive / effectiveWeeklyRate;
          final int daysRemaining = (weeksRemaining * 7).round();

          if (daysRemaining <= 1) {
            projectedTimeLabel = context.l10n.bodyATiroDePiedra;
          } else if (daysRemaining < 30) {
            projectedTimeLabel = context.l10n.bodyDiasRestantes((daysRemaining).toString());
          } else {
            final int weeks = (daysRemaining / 7).round();
            projectedTimeLabel = context.l10n.bodySemanasRestantes((weeks).toString());
          }
        }

        final String locale = context.l10n.localeName;
        return HealthCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.flag_rounded, color: c.isFlat ? c.text : c.accent, size: 20),
                  const SizedBox(width: ScSpace.s + 2),
                  Expanded(
                    child: Text(
                      context.l10n.bodyMiniHitoDe(completedCount.toString(), totalCount.toString()),
                      style: context.text.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    tooltip: context.l10n.bodyRecalibrarTramosDe15,
                    onPressed: () async {
                      unawaited(HapticFeedback.lightImpact());
                      await ref
                          .read(milestoneServiceProvider)
                          .regenerate(
                            currentWeightKg: widget.currentWeightKg,
                            targetWeightKg: widget.targetWeightKg,
                          );
                    },
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).expandedIconTapHint,
                    icon: AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: ScMotion.of(context, ScMotion.standard),
                      child: const Icon(Icons.expand_more_rounded, size: 22),
                    ),
                    onPressed: () => setState(() => _isExpanded = !_isExpanded),
                  ),
                ],
              ),
              const SizedBox(height: ScSpace.s),

              // Pista de tramos: uno por hito; el actual se rellena según el avance.
              Row(
                children: <Widget>[
                  for (int i = 0; i < milestones.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(width: 4),
                    Expanded(
                      child: ScProgressBar(
                        value: milestones[i].isCompleted
                            ? 1
                            : (milestones[i].id == activeMilestone?.id ? milestoneProgress : 0),
                        color: c.accent,
                        height: 8,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: ScSpace.m + 2),

              if (activeMilestone != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            context.l10n.bodyNextStop.toUpperCase(),
                            style: context.type.overline,
                          ),
                          const SizedBox(height: ScSpace.xs),
                          MetricValue(
                            value: NumberFormats.oneDecimal(activeMilestone.targetWeightKg, locale),
                            unit: context.l10n.unitKg,
                            size: 26,
                            color: c.isFlat ? null : c.accent,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          context.l10n.bodyFaltanKg(
                            NumberFormats.oneDecimal(remainingKgToActive, locale),
                          ),
                          style: context.type.label,
                        ),
                        const SizedBox(height: 2),
                        Text(projectedTimeLabel, style: context.type.caption),
                      ],
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: <Widget>[
                    const Text('🏆', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.l10n.bodyFelicitacionesHasCompletadoTodosLos,
                        style: context.type.label,
                      ),
                    ),
                  ],
                ),
              ],

              // Desglose expandible de todos los tramos
              if (_isExpanded) ...[
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 10),
                ...milestones.map((MilestoneGoal m) {
                  final bool isCurrent = activeMilestone?.id == m.id;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          m.isCompleted
                              ? Icons.check_circle_rounded
                              : (isCurrent
                                    ? Icons.play_circle_filled_rounded
                                    : Icons.radio_button_unchecked_rounded),
                          size: 18,
                          color: m.isCompleted ? c.accent : (isCurrent ? c.accent : c.text3),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            context.l10n.bodyHitoKg(
                              m.milestoneOrder.toString(),
                              NumberFormats.fixed(m.targetWeightKg, 1),
                            ),
                            style: TextStyle(
                              fontFamily: ScFonts.ui,
                              fontSize: 12.5,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                              color: m.isCompleted ? c.text3 : (isCurrent ? c.text : c.text2),
                              decoration: m.isCompleted ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                        if (m.isCompleted)
                          Text(
                            context.l10n.bodyLogrado25,
                            style: TextStyle(
                              fontFamily: ScFonts.ui,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: c.accent,
                            ),
                          )
                        else if (isCurrent)
                          Flexible(child: TonalBadge(label: context.l10n.bodyEnCurso)),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        );
      },
    );
  }
}
