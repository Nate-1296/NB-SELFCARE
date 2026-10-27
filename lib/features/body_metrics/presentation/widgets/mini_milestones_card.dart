import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/widgets/health_card.dart';
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
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: c.isFlat ? c.bg3 : c.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.flag_rounded, color: c.accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        context.l10n.bodyMiniHitosPsicologicos,
                        style: TextStyle(
                          fontFamily: ScFonts.display,
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: c.text,
                        ),
                      ),
                      Text(
                        context.l10n.bodyDescomponTuMetaEnTramos,
                        style: TextStyle(
                          fontFamily: ScFonts.ui,
                          fontSize: 11.5,
                          color: c.text2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () async {
                    unawaited(HapticFeedback.lightImpact());
                    await ref.read(milestoneServiceProvider).regenerate(
                      currentWeightKg: widget.currentWeightKg,
                      targetWeightKg: widget.targetWeightKg,
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: c.isFlat ? c.bg3 : c.accent,
                    foregroundColor: c.isFlat ? c.text : c.ink,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: Text(context.l10n.bodyGenerar, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
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

        return HealthCard(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Cabecera con selector expandible y orden de hito
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(Icons.flag_circle_rounded, color: c.accent, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        context.l10n.bodyMiniHitoDe((completedCount).toString(), (totalCount).toString()),
                        style: TextStyle(
                          fontFamily: ScFonts.display,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: c.text,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        tooltip: context.l10n.bodyRecalibrarTramosDe15,
                        onPressed: () async {
                          unawaited(HapticFeedback.lightImpact());
                          await ref.read(milestoneServiceProvider).regenerate(
                            currentWeightKg: widget.currentWeightKg,
                            targetWeightKg: widget.targetWeightKg,
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          _isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _isExpanded = !_isExpanded),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),

              if (activeMilestone != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      context.l10n.bodyObjetivoInmediatoKg(activeMilestone.targetWeightKg.toStringAsFixed(1).toString()),
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: c.accent,
                      ),
                    ),
                    Text(
                      context.l10n.bodyFaltanKg(remainingKgToActive.toStringAsFixed(1).toString()),
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.text2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Barra de progreso hacia el hito activo
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: milestoneProgress,
                    minHeight: 10,
                    backgroundColor: c.bg3,
                    valueColor: AlwaysStoppedAnimation<Color>(c.accent),
                  ),
                ),
                const SizedBox(height: 6),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      context.l10n.bodyCompletado((milestoneProgress * 100).toStringAsFixed(0).toString()),
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 11,
                        color: c.text3,
                      ),
                    ),
                    Text(
                      projectedTimeLabel,
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: c.text2,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.bg3,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Text('🏆', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.l10n.bodyFelicitacionesHasCompletadoTodosLos,
                          style: TextStyle(
                            fontFamily: ScFonts.display,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: c.text,
                          ),
                        ),
                      ),
                    ],
                  ),
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
                              : (isCurrent ? Icons.play_circle_filled_rounded : Icons.radio_button_unchecked_rounded),
                          size: 18,
                          color: m.isCompleted
                              ? c.accent
                              : (isCurrent ? c.accent : c.text3),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            context.l10n.bodyHitoKg(m.milestoneOrder.toString(), m.targetWeightKg.toStringAsFixed(1).toString()),
                            style: TextStyle(
                              fontFamily: ScFonts.ui,
                              fontSize: 12.5,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                              color: m.isCompleted
                                  ? c.text3
                                  : (isCurrent ? c.text : c.text2),
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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: c.isFlat ? c.bg3 : c.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              context.l10n.bodyEnCurso,
                              style: TextStyle(
                                fontFamily: ScFonts.ui,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: c.accent,
                              ),
                            ),
                          ),
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
