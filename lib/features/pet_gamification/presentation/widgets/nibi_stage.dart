import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_tokens.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../application/nibi_overview.dart';
import '../../domain/breathing.dart';
import '../../domain/nibi_activity.dart';
import '../nibi/habitat_painter.dart';
import '../nibi/nibi_view.dart';
import 'breathing.dart';
import 'nibi_status.dart';

/// Cuidados que se le pueden dar a Nibi desde su escenario.
enum NibiCare { pet, water, snack, play, breathe }

enum _StageMode { normal, breathingSetup, breathing }

/// Santuario de Nibi: su escenario con monedas, escudos y racha en una
/// esquina, el bocadillo, Nibi y, debajo, los cuidados. "Respirar" convierte
/// el escenario en una sesión de respiración guiada junto a Nibi.
class NibiStage extends StatefulWidget {
  const NibiStage({
    super.key,
    required this.nibiKey,
    required this.overview,
    required this.activity,
    required this.speech,
    required this.semanticsLabel,
    required this.onReaction,
    required this.onCare,
    required this.onBreathingDone,
  });

  final GlobalKey<NibiViewState> nibiKey;
  final NibiOverview overview;
  final NibiActivity activity;
  final String speech;
  final String semanticsLabel;
  final ValueChanged<NibiReaction> onReaction;

  /// Agua, comida o juego (las caricias y la respiración los resuelve el escenario).
  final ValueChanged<NibiCare> onCare;

  /// Sesión de respiración completada.
  final VoidCallback onBreathingDone;

  @override
  State<NibiStage> createState() => _NibiStageState();
}

class _NibiStageState extends State<NibiStage> with TickerProviderStateMixin {
  static const double _height = 400;

  /// Más bajo durante la respiración: escenario y controles caben en pantalla.
  static const double _breathingHeight = 350;
  static const double _breathingNibiSize = 220;
  static const double _nibiSize = 260;
  static const double _nibiBottom = 6;

  late final Ticker _ambientTicker = createTicker(
    (Duration elapsed) => _ambient.value = elapsed.inMicroseconds / Duration.microsecondsPerSecond,
  );
  final ValueNotifier<double> _ambient = ValueNotifier<double>(0);
  late final BreathingClock _clock = BreathingClock(
    vsync: this,
    onPhaseChange: () => unawaited(HapticFeedback.selectionClick()),
    onDone: _breathingFinished,
  );

  _StageMode _mode = _StageMode.normal;
  BreathingPattern _pattern = BreathingPattern.box;
  int _minutes = 1;
  bool _motion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool motion = ScMotion.enabled(context);
    if (motion != _motion) {
      _motion = motion;
      if (motion) {
        unawaited(_ambientTicker.start());
      } else {
        _ambientTicker.stop();
        _ambient.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _ambientTicker.dispose();
    _ambient.dispose();
    _clock.dispose();
    super.dispose();
  }

  void _care(NibiCare care) {
    switch (care) {
      case NibiCare.pet:
        widget.nibiKey.currentState?.pet();
      case NibiCare.breathe:
        unawaited(HapticFeedback.selectionClick());
        setState(() => _mode = _StageMode.breathingSetup);
        _bringIntoView();
      case NibiCare.water:
      case NibiCare.snack:
      case NibiCare.play:
        widget.onCare(care);
    }
  }

  /// El santuario ocupa la pantalla: escenario arriba y controles a la vista.
  void _bringIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        Scrollable.ensureVisible(
          context,
          duration: ScMotion.of(context, ScMotion.standard),
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }

  void _startBreathing() {
    unawaited(HapticFeedback.mediumImpact());
    _clock.start(
      BreathingSession(pattern: _pattern, minutes: _minutes),
      smooth: _motion,
    );
    setState(() => _mode = _StageMode.breathing);
    _bringIntoView();
  }

  void _breathingFinished() {
    unawaited(HapticFeedback.heavyImpact());
    if (mounted) setState(() {});
    widget.onBreathingDone();
  }

  void _closeBreathing() {
    _clock.stop();
    setState(() => _mode = _StageMode.normal);
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final BorderRadius radius = BorderRadius.circular(ScRadius.cardOf(c));
    final Color rule = c.isFlat ? c.line2 : c.line;
    final bool breathing = _mode == _StageMode.breathing;
    final double stageHeight = _mode == _StageMode.normal ? _height : _breathingHeight;
    // Algo más pequeño al respirar: la fase y la cuenta atrás quedan libres arriba.
    final double nibiSize = _mode == _StageMode.normal ? _nibiSize : _breathingNibiSize;
    final bool done = breathing && (_clock.moment?.done ?? false);

    final NibiActivity activity = switch (_mode) {
      _StageMode.normal => widget.activity,
      _StageMode.breathingSetup => NibiActivity.zen,
      _StageMode.breathing => done ? NibiActivity.celebrating : NibiActivity.zen,
    };
    final String speech = switch (_mode) {
      _StageMode.normal => widget.speech,
      _StageMode.breathingSetup => l10n.nibiSayBreatheSetup,
      _StageMode.breathing => done ? l10n.nibiSayBreatheDone : '',
    };

    final Widget panel = switch (_mode) {
      _StageMode.normal => _CareBar(onCare: _care),
      _StageMode.breathingSetup => BreathingSetupPanel(
        pattern: _pattern,
        minutes: _minutes,
        onPattern: (BreathingPattern p) => setState(() => _pattern = p),
        onMinutes: (int m) => setState(() => _minutes = m),
        onStart: _startBreathing,
        onClose: _closeBreathing,
      ),
      _StageMode.breathing => BreathingRunPanel(
        clock: _clock,
        onStop: _closeBreathing,
        onAgain: _startBreathing,
      ),
    };

    return Container(
      decoration: BoxDecoration(
        color: c.bg2,
        borderRadius: radius,
        border: Border.all(color: rule, width: c.isFlat ? 1.5 : 1),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AnimatedContainer(
              duration: ScMotion.of(context, ScMotion.standard),
              curve: ScMotion.ease,
              height: stageHeight,
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints box) {
                  final Offset center = Offset(
                    box.maxWidth / 2,
                    stageHeight - _nibiBottom - nibiSize / 2,
                  );
                  final double ringRadius = math.min(
                    box.maxWidth / 2 - 14,
                    stageHeight - center.dy - 10,
                  );
                  return Stack(
                    children: <Widget>[
                      // En papel el escenario se retira durante la sesión: solo
                      // quedan Nibi y el anillo (menos trazos que refrescar).
                      if (!(breathing && !done && c.isFlat))
                        Positioned.fill(
                          child: RepaintBoundary(
                            child: CustomPaint(
                              painter: HabitatPainter(
                                habitatId: widget.overview.habitatId,
                                colors: c,
                                time: _motion ? _ambient : null,
                              ),
                            ),
                          ),
                        ),
                      // En color, un velo atenúa el escenario para centrar la atención.
                      if (breathing && !done && !c.isFlat)
                        Positioned.fill(child: ColoredBox(color: c.bg.withValues(alpha: 0.55))),
                      if (breathing && !done)
                        Positioned.fill(
                          child: RepaintBoundary(
                            child: CustomPaint(
                              painter: BreathingRingPainter(
                                clock: _clock,
                                center: center,
                                radius: ringRadius,
                                accent: c.isFlat ? c.text : c.accent,
                                track: c.isFlat ? c.text3 : c.text.withValues(alpha: 0.16),
                                surface: c.bg2,
                                ink: c.isFlat,
                              ),
                            ),
                          ),
                        ),
                      if (breathing && !done)
                        Positioned(
                          left: ScSpace.l,
                          right: ScSpace.l,
                          top: ScSpace.m,
                          child: Center(
                            child: _Plate(child: BreathingHeader(clock: _clock)),
                          ),
                        )
                      else
                        Positioned(
                          left: ScSpace.m,
                          right: ScSpace.m,
                          top: ScSpace.m,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              if (_mode == _StageMode.normal) ...<Widget>[
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: NibiStatBadges(overview: widget.overview),
                                ),
                                const SizedBox(height: ScSpace.s),
                              ],
                              if (speech.isNotEmpty) _SpeechBubble(text: speech),
                            ],
                          ),
                        ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: _nibiBottom,
                        child: Center(
                          child: NibiView(
                            key: widget.nibiKey,
                            activity: activity,
                            aura: widget.overview.mood.aura && !breathing,
                            look: widget.overview.look,
                            size: nibiSize,
                            onReaction: widget.onReaction,
                            semanticsLabel: widget.semanticsLabel,
                            guidedBreath: breathing && !done ? _clock.lung : null,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Divider(height: 1, thickness: c.isFlat ? 1.5 : 1, color: rule),
            // Sin animación en papel (AnimatedSize con duración cero falla al
            // recolocarse en el mismo fotograma).
            if (_motion)
              AnimatedSize(duration: ScMotion.quick, alignment: Alignment.topCenter, child: panel)
            else
              panel,
          ],
        ),
      ),
    );
  }
}

/// Fondo legible para el texto que va sobre el escenario.
class _Plate extends StatelessWidget {
  const _Plate({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: ScSpace.xl, vertical: ScSpace.s),
      decoration: BoxDecoration(
        color: c.isFlat ? c.bg2 : c.bg2.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.isFlat ? c.line2 : c.line, width: c.isFlat ? 1.5 : 1),
      ),
      child: child,
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Semantics(
      liveRegion: true,
      child: AnimatedSwitcher(
        duration: ScMotion.of(context, ScMotion.quick),
        child: Container(
          key: ValueKey<String>(text),
          padding: const EdgeInsets.symmetric(horizontal: ScSpace.l, vertical: ScSpace.m),
          decoration: BoxDecoration(
            color: c.isFlat ? c.bg2 : c.bg2.withValues(alpha: 0.94),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
            border: Border.all(color: c.isFlat ? c.line2 : c.line, width: c.isFlat ? 1.5 : 1),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: context.type.body.copyWith(color: c.text),
          ),
        ),
      ),
    );
  }
}

/// Cuidados bajo el escenario, en la misma tarjeta que Nibi.
class _CareBar extends StatelessWidget {
  const _CareBar({required this.onCare});

  final ValueChanged<NibiCare> onCare;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final List<(NibiCare, IconData, String, Color)> cares = <(NibiCare, IconData, String, Color)>[
      (NibiCare.pet, Icons.favorite_rounded, l10n.nibiCarePet, c.fat),
      (NibiCare.water, AppIcons.water, l10n.nibiCareWater, c.water),
      (NibiCare.snack, Icons.apple_rounded, l10n.nibiCareSnack, c.calories),
      (NibiCare.play, Icons.sports_baseball_rounded, l10n.nibiCarePlay, c.warning),
      (NibiCare.breathe, Icons.self_improvement_rounded, l10n.nibiCareBreathe, c.fasting),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ScSpace.xs, vertical: ScSpace.s),
      child: Row(
        children: <Widget>[
          for (final (NibiCare care, IconData icon, String label, Color tone) in cares)
            Expanded(
              child: _CareButton(icon: icon, label: label, tone: tone, onTap: () => onCare(care)),
            ),
        ],
      ),
    );
  }
}

class _CareButton extends StatelessWidget {
  const _CareButton({
    required this.icon,
    required this.label,
    required this.tone,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ScRadius.tileOf(c)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: ScSpace.s, horizontal: 2),
          child: Column(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.isFlat ? c.bg2 : tone.withValues(alpha: 0.16),
                  border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
                ),
                child: Icon(icon, size: 22, color: c.isFlat ? c.text : tone),
              ),
              const SizedBox(height: ScSpace.xs),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: context.type.caption.copyWith(color: c.text, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
