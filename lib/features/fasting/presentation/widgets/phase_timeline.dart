import 'package:flutter/material.dart';

import '../../../../core/domain/metabolic_phase.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_tokens.dart';
import '../../../../shared/widgets/health_card.dart';
import '../metabolic_phase_l10n.dart';

/// Línea de tiempo de las fases del ayuno (docs/09 §1), marcando la actual.
class PhaseTimeline extends StatelessWidget {
  const PhaseTimeline({super.key, required this.elapsedHours});

  /// Horas de ayuno en curso, o `null` si no hay ninguno.
  final double? elapsedHours;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final MetabolicPhase? current = elapsedHours == null
        ? null
        : MetabolicPhase.forHours(elapsedHours!);
    const List<MetabolicPhase> phases = MetabolicPhase.values;
    return HealthCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: <Widget>[
          for (final MetabolicPhase phase in phases)
            _PhaseTimelineStep(
              hoursLabel: phase.nextStartsAtHour == null
                  ? l10n.fastPhaseFrom(phase.startsAtHour)
                  : l10n.fastPhaseRange(phase.startsAtHour, phase.nextStartsAtHour!),
              title: phase.label(l10n),
              subtitle: phase.description(l10n),
              isActive: current == phase,
              isCompleted: current != null && current.index > phase.index,
              color: phase.color(c),
              isLast: phase == phases.last,
            ),
        ],
      ),
    );
  }
}

class _PhaseTimelineStep extends StatelessWidget {
  const _PhaseTimelineStep({
    required this.hoursLabel,
    required this.title,
    required this.subtitle,
    required this.isActive,
    required this.isCompleted,
    required this.color,
    this.isLast = false,
  });

  final String hoursLabel;
  final String title;
  final String subtitle;
  final bool isActive;
  final bool isCompleted;
  final Color color;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final Color resolvedColor = c.isFlat ? c.text : color;
    final Color onNode = resolvedColor.computeLuminance() > 0.45
        ? const Color(0xFF0A0C10)
        : Colors.white;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Column(
            children: <Widget>[
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isCompleted || isActive) ? resolvedColor : (c.isFlat ? c.bg2 : c.bg3),
                  border: c.isFlat || isActive
                      ? Border.all(color: resolvedColor, width: 1.5)
                      : null,
                  boxShadow: isActive && !c.isFlat
                      ? <BoxShadow>[
                          BoxShadow(color: resolvedColor.withValues(alpha: 0.45), blurRadius: 10),
                        ]
                      : null,
                ),
                child: Center(
                  child: isCompleted
                      ? Icon(Icons.check_rounded, size: 14, color: onNode)
                      : (isActive
                            ? Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: onNode),
                              )
                            : null),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCompleted
                        ? resolvedColor.withValues(alpha: 0.65)
                        : (c.isFlat ? c.line2 : c.line),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 2 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          title,
                          softWrap: true,
                          style: context.type.label.copyWith(
                            fontSize: 14.5,
                            color: isActive ? resolvedColor : (isCompleted ? c.text2 : c.text),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        hoursLabel,
                        style: context.type.metricS.copyWith(fontSize: 12.5, color: c.text3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle, softWrap: true, style: context.type.caption),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
