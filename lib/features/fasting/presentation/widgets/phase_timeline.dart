import 'package:flutter/material.dart';

import '../../../../core/domain/metabolic_phase.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
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
    final MetabolicPhase? current = elapsedHours == null ? null : MetabolicPhase.forHours(elapsedHours!);
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
                  color: (isCompleted || isActive) ? resolvedColor : c.bg3,
                  border: Border.all(
                    color: isActive ? resolvedColor : c.line2,
                    width: isActive ? 2.4 : 1.2,
                  ),
                ),
                child: Center(
                  child: isCompleted
                      ? Icon(Icons.check, size: 13, color: c.ink)
                      : (isActive
                          ? Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: c.ink,
                              ),
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
                        : c.line,
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
                          style: TextStyle(
                            fontFamily: ScFonts.display,
                            fontSize: 14,
                            fontWeight:
                                isActive ? FontWeight.w800 : FontWeight.w700,
                            color: isActive ? resolvedColor : c.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        hoursLabel,
                        style: TextStyle(
                          fontFamily: ScFonts.ui,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: c.text3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    softWrap: true,
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 12,
                      color: c.text2,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
