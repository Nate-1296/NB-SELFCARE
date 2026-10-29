import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../shared/theme/sc_colors.dart';
import '../../../shared/theme/sc_tokens.dart';
import '../application/care_queries.dart';
import '../application/care_session_service.dart';
import '../domain/active_break_catalog.dart';
import '../domain/guided_sequence.dart';
import '../domain/pelvic_floor_program.dart';
import 'care_l10n.dart';
import 'guided_session_screen.dart';
import 'widgets/stick_figure_painter.dart';

/// Abre las sesiones guiadas de Cuidado.
abstract final class CareSessions {
  static Future<void> pelvicFloor(
    BuildContext context,
    WidgetRef ref, {
    required PelvicVariant variant,
    required int level,
  }) {
    final AppLocalizations l10n = context.l10n;
    final GuidedSequence<PelvicCue> sequence = PelvicFloorProgram.session(
      variant: variant,
      level: level,
    );
    return GuidedSessionScreen.open<PelvicCue>(
      context,
      GuidedSessionScreen<PelvicCue>(
        title: variant == PelvicVariant.relaxOnly
            ? l10n.carePelvicRelax
            : l10n.carePelvicLevel('$level'),
        sequence: sequence,
        hint: l10n.carePelvicHint,
        cueLabel: (AppLocalizations l, PelvicCue cue) => cue.label(l),
        // Un pulso largo al apretar y dos cortos al soltar: se sigue con los ojos cerrados.
        vibrationPattern: (PelvicCue cue) => switch (cue) {
          PelvicCue.squeeze => const <int>[0, 220],
          PelvicCue.quickSqueeze => const <int>[0, 90],
          PelvicCue.release || PelvicCue.lengthenInhale => const <int>[0, 50, 90, 50],
          _ => null,
        },
        visual: (BuildContext context, GuidedMoment<PelvicCue> m) => _PelvicPulse(moment: m),
        onComplete: (int seconds) => ref
            .read(careSessionServiceProvider)
            .complete(
              kind: CareSessionKind.pelvicFloor,
              variant: PelvicProgress.variantFor(variant, level),
              durationSeconds: seconds,
            ),
      ),
    );
  }

  static Future<void> activeBreak(BuildContext context, WidgetRef ref, ActiveBreakRoutine routine) {
    final AppLocalizations l10n = context.l10n;
    return GuidedSessionScreen.open<BreakMove>(
      context,
      GuidedSessionScreen<BreakMove>(
        title: CareText.routine(l10n, routine.id),
        sequence: routine.sequence(),
        cueLabel: (AppLocalizations l, BreakMove move) => CareText.move(l, move.key),
        vibrationPattern: (BreakMove _) => const <int>[0, 120],
        visual: (BuildContext context, GuidedMoment<BreakMove> m) => _Figure(pose: m.step.cue.pose),
        onComplete: (int seconds) => ref
            .read(careSessionServiceProvider)
            .complete(
              kind: CareSessionKind.activeBreak,
              variant: routine.id,
              durationSeconds: seconds,
            ),
      ),
    );
  }
}

/// Círculo que crece al apretar y se encoge al soltar. En papel, tamaño fijo
/// por indicación (sin animación).
class _PelvicPulse extends StatelessWidget {
  const _PelvicPulse({required this.moment});

  final GuidedMoment<PelvicCue> moment;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final bool smooth = ScMotion.enabled(context);
    final double p = smooth ? Curves.easeInOut.transform(moment.stepProgress) : 1;
    final double level = switch (moment.step.cue) {
      PelvicCue.squeeze || PelvicCue.quickSqueeze => 0.55 + 0.45 * p,
      PelvicCue.release || PelvicCue.quickRelease => 1 - 0.45 * p,
      PelvicCue.lengthenInhale => 0.55 + 0.3 * p,
      PelvicCue.lengthenExhale => 0.85 - 0.3 * p,
      PelvicCue.rest => 0.55,
    };
    final bool effort = PelvicFloorProgram.isEffort(moment.step.cue);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double size = math.min(constraints.maxWidth, constraints.maxHeight) * 0.8;
        return SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Container(
              width: size * level,
              height: size * level,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.isFlat
                    ? (effort ? c.text : c.bg3)
                    : c.accent.withValues(alpha: effort ? 0.35 : 0.14),
                border: Border.all(
                  color: c.isFlat ? c.text : c.accent,
                  width: c.isFlat ? 1.5 : 2.5,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.pose});

  final StickPose pose;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return AspectRatio(
      aspectRatio: 0.8,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: StickFigurePainter(
            pose: pose,
            ink: c.text,
            accent: c.isFlat ? c.text : c.accent,
            floor: c.isFlat ? c.line2 : c.line,
          ),
        ),
      ),
    );
  }
}
