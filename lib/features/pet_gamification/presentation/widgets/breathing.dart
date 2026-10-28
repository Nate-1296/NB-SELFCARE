import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_tokens.dart';
import '../../../../shared/widgets/progress_bar.dart';
import '../../domain/breathing.dart';

/// Reloj de una sesión de respiración.
///
/// En color avanza con un `Ticker` (fluido); en Modo Papel, una vez por
/// segundo (la tinta no aguanta animaciones continuas). Expone el instante
/// actual y el nivel de los pulmones para que Nibi respire al mismo ritmo.
class BreathingClock extends ChangeNotifier {
  BreathingClock({required TickerProvider vsync, required this.onPhaseChange, required this.onDone}) : _vsync = vsync; // ignore: prefer_initializing_formals

  final TickerProvider _vsync;
  Ticker? _ticker;
  final VoidCallback onPhaseChange;
  final VoidCallback onDone;
  final Stopwatch _watch = Stopwatch();
  Timer? _timer;
  BreathingSession? _session;
  BreathingMoment? _moment;

  /// Pulmones 0–1 (Nibi y el anillo lo siguen).
  final ValueNotifier<double> lung = ValueNotifier<double>(0);

  BreathingSession? get session => _session;
  BreathingMoment? get moment => _moment;
  bool get running => _session != null && !(_moment?.done ?? true);

  void start(BreathingSession session, {required bool smooth}) {
    stop();
    _session = session;
    _watch
      ..reset()
      ..start();
    _moment = session.at(0);
    lung.value = _moment!.lung;
    if (smooth) {
      unawaited((_ticker ??= _vsync.createTicker((_) => _update())).start());
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _update());
    }
    notifyListeners();
  }

  void _update() {
    final BreathingSession? session = _session;
    if (session == null) return;
    final BreathingMoment next = session.at(_watch.elapsedMicroseconds / Duration.microsecondsPerSecond);
    final BreathingMoment? prev = _moment;
    _moment = next;
    lung.value = next.lung;
    final bool phaseChanged = prev == null || prev.phaseIndex != next.phaseIndex || prev.cycle != next.cycle;
    final bool secondChanged = prev == null || prev.secondsLeftInPhase != next.secondsLeftInPhase;
    if (next.done) {
      _halt();
      notifyListeners();
      onDone();
      return;
    }
    if (phaseChanged) onPhaseChange();
    if (phaseChanged || secondChanged) notifyListeners();
  }

  void _halt() {
    _watch.stop();
    _timer?.cancel();
    _timer = null;
    if (_ticker?.isActive ?? false) _ticker!.stop();
  }

  /// Termina la sesión (sin completar).
  void stop() {
    _halt();
    _session = null;
    _moment = null;
    lung.value = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _halt();
    _ticker?.dispose();
    lung.dispose();
    super.dispose();
  }
}

/// Anillo de respiración alrededor de Nibi: se expande al inhalar, se queda
/// lleno al retener y se encoge al exhalar. Por fuera, el ciclo completo con
/// una marca por fase (como el anillo del ayuno) y un punto que lo recorre.
class BreathingRingPainter extends CustomPainter {
  BreathingRingPainter({
    required this.clock,
    required this.center,
    required this.radius,
    required this.accent,
    required this.track,
    required this.surface,
    required this.ink,
  }) : super(repaint: Listenable.merge(<Listenable>[clock, clock.lung]));

  final BreathingClock clock;
  final Offset center;
  final double radius;
  final Color accent;
  final Color track;

  /// Color del centro del punto (el de la tarjeta).
  final Color surface;
  final bool ink;

  @override
  void paint(Canvas canvas, Size size) {
    final BreathingMoment? m = clock.moment;
    final BreathingSession? session = clock.session;
    if (m == null || session == null) return;
    final double lung = clock.lung.value;
    final double inner = radius * (0.62 + 0.3 * lung);
    if (!ink) {
      canvas.drawCircle(center, inner, Paint()..color = accent.withValues(alpha: 0.1 + 0.08 * lung));
    }
    canvas.drawCircle(
      center,
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ink ? 2 : 2.5
        ..color = ink ? track : accent.withValues(alpha: 0.7),
    );

    // Ciclo: arcos por fase separados por marcas.
    final Rect outer = Rect.fromCircle(center: center, radius: radius);
    final Paint trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = track;
    final Paint donePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = accent;
    const double gap = 0.05;
    double start = -math.pi / 2;
    final int cycle = session.pattern.cycleSeconds;
    for (int i = 0; i < session.pattern.phases.length; i++) {
      final double sweep = session.pattern.phases[i].$2 / cycle * math.pi * 2;
      canvas.drawArc(outer, start + gap, sweep - gap * 2, false, trackPaint);
      final double fill = i < m.phaseIndex ? 1 : (i == m.phaseIndex ? m.phaseProgress : 0);
      if (fill > 0) canvas.drawArc(outer, start + gap, (sweep - gap * 2) * fill, false, donePaint);
      start += sweep;
    }
    // Punto que recorre el ciclo.
    double elapsedInCycle = 0;
    for (int i = 0; i < m.phaseIndex; i++) {
      elapsedInCycle += session.pattern.phases[i].$2;
    }
    elapsedInCycle += session.pattern.phases[m.phaseIndex].$2 * m.phaseProgress;
    final double a = -math.pi / 2 + elapsedInCycle / cycle * math.pi * 2;
    final Offset dot = center + Offset(math.cos(a), math.sin(a)) * radius;
    canvas.drawCircle(dot, 7, Paint()..color = ink ? track : accent);
    canvas.drawCircle(dot, 3, Paint()..color = surface);
  }

  @override
  bool shouldRepaint(BreathingRingPainter old) =>
      old.clock != clock || old.center != center || old.radius != radius || old.accent != accent || old.ink != ink;
}

extension BreathingL10n on BreathingPattern {
  String title(AppLocalizations l10n) => switch (id) {
        'box' => l10n.breathPatternBox,
        'triangle' => l10n.breathPatternTriangle,
        'relax' => l10n.breathPatternRelax,
        _ => l10n.breathPatternCoherence,
      };

  String purpose(AppLocalizations l10n) => switch (id) {
        'box' => l10n.breathPatternBoxHint,
        'triangle' => l10n.breathPatternTriangleHint,
        'relax' => l10n.breathPatternRelaxHint,
        _ => l10n.breathPatternCoherenceHint,
      };
}

extension BreathPhaseL10n on BreathPhase {
  String label(AppLocalizations l10n) => switch (this) {
        BreathPhase.inhale => l10n.breathInhale,
        BreathPhase.holdIn => l10n.breathHoldIn,
        BreathPhase.exhale => l10n.breathExhale,
        BreathPhase.holdOut => l10n.breathHoldOut,
      };
}

/// Encabezado del escenario durante la sesión: fase y cuenta atrás.
class BreathingHeader extends StatelessWidget {
  const BreathingHeader({super.key, required this.clock});

  final BreathingClock clock;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    return ListenableBuilder(
      listenable: clock,
      builder: (BuildContext context, _) {
        final BreathingMoment? m = clock.moment;
        if (m == null) return const SizedBox.shrink();
        final String phase = m.done ? l10n.breathDone : m.phase.label(l10n);
        return Semantics(
          liveRegion: true,
          label: m.done ? phase : '$phase, ${m.secondsLeftInPhase}',
          excludeSemantics: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(phase, style: context.text.headlineSmall?.copyWith(color: c.text, fontWeight: FontWeight.w700)),
              if (!m.done)
                Text(
                  '${m.secondsLeftInPhase}',
                  style: context.type.metricXL.copyWith(color: c.isFlat ? c.text : c.accent),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Elección de ritmo y duración antes de empezar.
class BreathingSetupPanel extends StatelessWidget {
  const BreathingSetupPanel({
    super.key,
    required this.pattern,
    required this.minutes,
    required this.onPattern,
    required this.onMinutes,
    required this.onStart,
    required this.onClose,
  });

  final BreathingPattern pattern;
  final int minutes;
  final ValueChanged<BreathingPattern> onPattern;
  final ValueChanged<int> onMinutes;
  final VoidCallback onStart;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(ScSpace.m, ScSpace.m, ScSpace.m, ScSpace.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Ritmos en una sola fila desplazable: el panel cabe bajo el escenario.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (final BreathingPattern p in BreathingPattern.all) ...<Widget>[
                  if (p != BreathingPattern.all.first) const SizedBox(width: ScSpace.s),
                  ChoiceChip(
                    label: Text('${p.title(l10n)} · ${p.rhythm}'),
                    selected: p.id == pattern.id,
                    onSelected: (_) => onPattern(p),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: ScSpace.xs),
          Text(pattern.purpose(l10n), style: context.type.caption.copyWith(color: c.text2)),
          const SizedBox(height: ScSpace.m),
          SegmentedButton<int>(
            segments: <ButtonSegment<int>>[
              for (final int m in BreathingSession.minuteOptions)
                ButtonSegment<int>(value: m, label: Text(l10n.breathMinutes('$m'))),
            ],
            selected: <int>{minutes},
            showSelectedIcon: false,
            onSelectionChanged: (Set<int> s) => onMinutes(s.first),
          ),
          const SizedBox(height: ScSpace.m),
          Row(
            children: <Widget>[
              TextButton(onPressed: onClose, child: Text(l10n.commonClose)),
              const SizedBox(width: ScSpace.s),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.self_improvement_rounded),
                  label: Text(l10n.breathStart),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Progreso de la sesión en curso o terminada.
class BreathingRunPanel extends StatelessWidget {
  const BreathingRunPanel({super.key, required this.clock, required this.onStop, required this.onAgain});

  final BreathingClock clock;
  final VoidCallback onStop;
  final VoidCallback onAgain;

  static String _clock(int seconds) => '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    return ListenableBuilder(
      listenable: clock,
      builder: (BuildContext context, _) {
        final BreathingMoment? m = clock.moment;
        final BreathingSession? session = clock.session;
        if (m == null || session == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.all(ScSpace.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      m.done
                          ? l10n.breathSummary('${session.cycles}', _clock(session.totalSeconds))
                          : l10n.breathCycleOf('${m.cycle}', '${m.cycles}'),
                      style: context.type.label.copyWith(color: c.text),
                    ),
                  ),
                  if (!m.done) Text(_clock(m.remainingSeconds), style: context.type.metricS.copyWith(color: c.text)),
                ],
              ),
              const SizedBox(height: ScSpace.s),
              ScProgressBar(value: m.progress, color: c.accent, height: 6),
              const SizedBox(height: ScSpace.m),
              if (m.done)
                Row(
                  children: <Widget>[
                    TextButton(onPressed: onStop, child: Text(l10n.commonClose)),
                    const SizedBox(width: ScSpace.s),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: onAgain,
                        icon: const Icon(Icons.replay_rounded),
                        label: Text(l10n.breathAgain),
                      ),
                    ),
                  ],
                )
              else
                OutlinedButton.icon(
                  onPressed: () {
                    unawaited(HapticFeedback.selectionClick());
                    onStop();
                  },
                  icon: const Icon(Icons.stop_rounded),
                  label: Text(l10n.breathStop),
                ),
            ],
          ),
        );
      },
    );
  }
}
