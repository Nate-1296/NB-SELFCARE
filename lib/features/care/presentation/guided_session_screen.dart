import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/platform/device_gateway.dart';
import '../../../shared/theme/sc_colors.dart';
import '../../../shared/theme/sc_tokens.dart';
import '../../../shared/widgets/progress_bar.dart';
import '../../pet_gamification/application/reward_service.dart';
import '../domain/guided_sequence.dart';

/// Reloj de una sesión guiada con pausa. En color avanza con un `Ticker`; en
/// papel consulta cuatro veces por segundo y solo avisa cuando cambia el paso o
/// el segundo (la tinta no aguanta animaciones continuas).
class GuidedClock<T> extends ChangeNotifier {
  GuidedClock({required this.sequence, required this._vsync, required this.smooth});

  final GuidedSequence<T> sequence;
  final bool smooth;
  final TickerProvider _vsync;
  final Stopwatch _watch = Stopwatch();
  Ticker? _ticker;
  Timer? _timer;
  late GuidedMoment<T> _moment = sequence.at(0);

  /// Se llama al cambiar de paso (vibración) y al terminar.
  void Function(GuidedMoment<T> moment)? onStep;
  VoidCallback? onDone;

  GuidedMoment<T> get moment => _moment;
  bool get running => _watch.isRunning;
  int get elapsedSeconds => _watch.elapsed.inSeconds;

  void start() {
    _watch.start();
    if (smooth) {
      final Ticker ticker = _ticker ??= _vsync.createTicker((_) => _update());
      if (!ticker.isActive) unawaited(ticker.start());
    } else {
      _timer ??= Timer.periodic(const Duration(milliseconds: 250), (_) => _update());
    }
    notifyListeners();
  }

  void pause() {
    _watch.stop();
    notifyListeners();
  }

  void _update() {
    if (!_watch.isRunning) return;
    final GuidedMoment<T> next = sequence.at(
      _watch.elapsedMicroseconds / Duration.microsecondsPerSecond,
    );
    final GuidedMoment<T> prev = _moment;
    _moment = next;
    if (next.done) {
      _halt();
      notifyListeners();
      onDone?.call();
      return;
    }
    if (next.index != prev.index) onStep?.call(next);
    if (smooth || next.index != prev.index || next.secondsLeftInStep != prev.secondsLeftInStep) {
      notifyListeners();
    }
  }

  void _halt() {
    _watch.stop();
    _timer?.cancel();
    _timer = null;
    if (_ticker?.isActive ?? false) _ticker!.stop();
  }

  @override
  void dispose() {
    _halt();
    _ticker?.dispose();
    super.dispose();
  }
}

/// Pantalla de una sesión guiada (suelo pélvico, pausa activa, descanso visual).
class GuidedSessionScreen<T> extends ConsumerStatefulWidget {
  const GuidedSessionScreen({
    super.key,
    required this.title,
    required this.sequence,
    required this.cueLabel,
    required this.visual,
    required this.onComplete,
    this.hint,
    this.vibrationPattern,
  });

  final String title;
  final GuidedSequence<T> sequence;
  final String Function(AppLocalizations l10n, T cue) cueLabel;

  /// Lo que se dibuja en el centro según el instante.
  final Widget Function(BuildContext context, GuidedMoment<T> moment) visual;

  /// Guarda la sesión y devuelve las monedas (se llama al terminar).
  final Future<RewardGrant> Function(int seconds) onComplete;
  final String? hint;

  /// Patrón de vibración al empezar cada paso (`null` = sin vibración).
  final List<int>? Function(T cue)? vibrationPattern;

  static Future<void> open<T>(BuildContext context, GuidedSessionScreen<T> screen) {
    final bool animate = ScMotion.enabled(context);
    // Un aviso pendiente de la pestaña no debe tapar los botones de la sesión.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    return Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: animate ? ScMotion.standard : Duration.zero,
        reverseTransitionDuration: animate ? ScMotion.quick : Duration.zero,
        pageBuilder: (_, _, _) => screen,
        transitionsBuilder: (_, Animation<double> animation, _, Widget child) =>
            animate ? FadeTransition(opacity: animation, child: child) : child,
      ),
    );
  }

  @override
  ConsumerState<GuidedSessionScreen<T>> createState() => _GuidedSessionScreenState<T>();
}

class _GuidedSessionScreenState<T> extends ConsumerState<GuidedSessionScreen<T>>
    with TickerProviderStateMixin {
  GuidedClock<T>? _clock;
  bool _vibrate = true;
  RewardGrant? _grant;
  bool _finished = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_clock != null) return;
    final GuidedClock<T> clock =
        GuidedClock<T>(sequence: widget.sequence, vsync: this, smooth: ScMotion.enabled(context))
          ..onStep = _onStep
          ..onDone = _onDone;
    _clock = clock;
    clock.start();
    _onStep(clock.moment);
  }

  @override
  void dispose() {
    _clock?.dispose();
    super.dispose();
  }

  void _onStep(GuidedMoment<T> m) {
    if (!_vibrate) return;
    final List<int>? pattern = widget.vibrationPattern?.call(m.step.cue);
    if (pattern != null) unawaited(ref.read(deviceGatewayProvider).vibrate(pattern));
  }

  Future<void> _onDone() async {
    if (_finished) return;
    _finished = true;
    unawaited(HapticFeedback.mediumImpact());
    final RewardGrant grant = await widget.onComplete(widget.sequence.totalSeconds);
    if (mounted) setState(() => _grant = grant);
  }

  static String _clockText(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final GuidedClock<T> clock = _clock!;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: clock,
          builder: (BuildContext context, _) {
            final GuidedMoment<T> m = clock.moment;
            final int total = widget.sequence.steps.length;
            final GuidedStep<T>? next = m.index + 1 < total
                ? widget.sequence.steps[m.index + 1]
                : null;
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                ScSpace.gutter,
                ScSpace.s,
                ScSpace.gutter,
                ScSpace.l,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      IconButton(
                        tooltip: l10n.commonClose,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close_rounded, color: c.text),
                      ),
                      Expanded(
                        child: Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          style: context.text.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.careVibration,
                        isSelected: _vibrate,
                        onPressed: () => setState(() => _vibrate = !_vibrate),
                        icon: Icon(Icons.vibration_rounded, color: c.text3),
                        selectedIcon: Icon(
                          Icons.vibration_rounded,
                          color: c.isFlat ? c.text : c.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: ScSpace.s),
                  ScProgressBar(value: m.progress, height: 6),
                  const SizedBox(height: ScSpace.xs),
                  Row(
                    children: <Widget>[
                      Text(
                        l10n.careSessionStepOf('${m.index + 1}', '$total'),
                        style: context.type.caption,
                      ),
                      const Spacer(),
                      Text(
                        l10n.careSessionRemaining(_clockText(m.remainingSeconds)),
                        style: context.type.caption,
                      ),
                    ],
                  ),
                  Expanded(
                    child: _finished
                        ? _DonePanel(grant: _grant, onClose: () => Navigator.of(context).pop())
                        : Column(
                            children: <Widget>[
                              Expanded(child: Center(child: widget.visual(context, m))),
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  widget.cueLabel(l10n, m.step.cue),
                                  textAlign: TextAlign.center,
                                  style: context.text.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: ScSpace.xs),
                              Text(
                                '${m.secondsLeftInStep}',
                                style: context.type.metricXL.copyWith(
                                  color: c.isFlat ? c.text : c.accent,
                                ),
                              ),
                              if (next != null)
                                Text(
                                  l10n.careBreakNext(widget.cueLabel(l10n, next.cue)),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.type.caption,
                                ),
                              if (widget.hint != null) ...<Widget>[
                                const SizedBox(height: ScSpace.m),
                                Text(
                                  widget.hint!,
                                  textAlign: TextAlign.center,
                                  style: context.type.caption.copyWith(color: c.text2),
                                ),
                              ],
                            ],
                          ),
                  ),
                  if (!_finished) const SizedBox(height: ScSpace.m),
                  if (!_finished)
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(l10n.careSessionStop),
                          ),
                        ),
                        const SizedBox(width: ScSpace.m),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              unawaited(HapticFeedback.selectionClick());
                              clock.running ? clock.pause() : clock.start();
                            },
                            icon: Icon(
                              clock.running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            ),
                            label: Text(
                              clock.running ? l10n.careSessionPause : l10n.careSessionResume,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DonePanel extends StatelessWidget {
  const _DonePanel({required this.grant, required this.onClose});

  final RewardGrant? grant;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final RewardGrant? g = grant;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(Icons.check_circle_rounded, size: 72, color: c.isFlat ? c.text : c.success),
        const SizedBox(height: ScSpace.m),
        Text(l10n.careSessionDone, style: context.text.headlineSmall),
        if (g != null && g.granted) ...<Widget>[
          const SizedBox(height: ScSpace.xs),
          Text(
            l10n.careSessionDoneCoins('${g.coins}'),
            style: context.type.label.copyWith(color: c.text2),
          ),
        ],
        const SizedBox(height: ScSpace.xl),
        FilledButton(onPressed: onClose, child: Text(l10n.commonClose)),
      ],
    );
  }
}
