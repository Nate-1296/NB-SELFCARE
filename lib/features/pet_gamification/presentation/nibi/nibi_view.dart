import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_tokens.dart';
import '../../domain/nibi_activity.dart';
import '../../domain/pet_catalog.dart';
import 'nibi_painter.dart';
import 'nibi_palette.dart';
import 'nibi_pose.dart';

/// Nibi animado.
///
/// En color corre a la frecuencia de la pantalla con un `Ticker` que solo
/// actualiza un [ValueNotifier]: el pintor se repinta sin reconstruir widgets.
/// Al cambiar de actividad interpola la postura durante 350 ms. En Modo Papel
/// y con "Quitar animaciones" no hay ticker: se pinta una postura fija por
/// actividad y solo se redibuja cuando algo cambia (versión de bajo movimiento).
///
/// Al tocarlo reacciona según dónde: la cabeza (caricia o bocanada), la panza
/// (cosquillas) o alas, cola y patas (vuelta o salto); mantenerlo pulsado le
/// hace ronronear. Cuando está tranquilo tiene sus manías (bostezar, mirar
/// alrededor, estirar las alas, resoplar).
class NibiView extends StatefulWidget {
  const NibiView({
    super.key,
    required this.activity,
    this.aura = false,
    this.look = const NibiLook(),
    this.size = 220,
    this.onReaction,
    this.semanticsLabel,
    this.guidedBreath,
  });

  final NibiActivity activity;
  final bool aura;
  final NibiLook look;
  final double size;

  /// Reacción al toque. Si es `null`, Nibi no se puede tocar ni tiene manías.
  final ValueChanged<NibiReaction>? onReaction;
  final String? semanticsLabel;

  /// Respiración guiada (0 vacío – 1 lleno): Nibi respira al ritmo indicado.
  final ValueListenable<double>? guidedBreath;

  @override
  State<NibiView> createState() => NibiViewState();
}

class NibiViewState extends State<NibiView> with SingleTickerProviderStateMixin {
  static const Duration _transition = Duration(milliseconds: 350);

  /// Actividades en las que Nibi tiene manías propias.
  static const Set<NibiActivity> _quirkyActivities = <NibiActivity>{
    NibiActivity.idle,
    NibiActivity.happy,
    NibiActivity.curious,
  };

  late final Ticker _ticker = createTicker(_onTick);
  late final ValueNotifier<NibiFrame> _frame = ValueNotifier<NibiFrame>(_compose(0));
  final math.Random _random = math.Random();

  double _t = 0;
  bool _animated = false;
  NibiPose? _from;
  double _transitionStart = 0;
  NibiReaction? _reaction;
  double _reactionStart = 0;
  double _nextQuirkAt = 8;
  bool _holding = false;
  Timer? _staticReactionTimer;
  final Map<String, int> _zoneTaps = <String, int>{};

  NibiFrame _compose(double t) {
    final NibiPose target = NibiChoreography.pose(widget.activity, _animated ? t : 0, aura: widget.aura);
    NibiPose pose = target;
    final NibiPose? from = _from;
    if (from != null && _animated) {
      final double k = ((t - _transitionStart) / (_transition.inMilliseconds / 1000)).clamp(0.0, 1.0);
      pose = NibiPose.lerp(from, target, Curves.easeOutCubic.transform(k));
      if (k >= 1) _from = null;
    }
    final ValueListenable<double>? guided = widget.guidedBreath;
    if (guided != null) pose = NibiChoreography.guided(pose, guided.value);

    final NibiReaction? reaction = _reaction;
    double age = 0;
    if (reaction != null) {
      age = _animated ? t - _reactionStart : _staticAge(reaction);
      pose = NibiChoreography.react(pose, reaction, age);
    }
    return NibiFrame(
      activity: widget.activity,
      pose: pose,
      t: _animated ? t : 0,
      reaction: reaction,
      reactionAge: age,
    );
  }

  /// Instante que representa la reacción en Modo Papel.
  static double _staticAge(NibiReaction r) => r == NibiReaction.spin ? r.seconds * 0.12 : r.seconds * 0.45;

  void _onTick(Duration elapsed) {
    _t = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final NibiReaction? reaction = _reaction;
    if (reaction != null && _t - _reactionStart >= reaction.seconds) {
      if (reaction == NibiReaction.purr && _holding) {
        _reactionStart = _t;
      } else {
        _reaction = null;
        _scheduleQuirk();
      }
    } else if (reaction == null && _t >= _nextQuirkAt) {
      if (widget.onReaction != null && widget.guidedBreath == null && _quirkyActivities.contains(widget.activity)) {
        _start(NibiReaction.quirks[_random.nextInt(NibiReaction.quirks.length)]);
      } else {
        _scheduleQuirk();
      }
    }
    _frame.value = _compose(_t);
  }

  void _scheduleQuirk() => _nextQuirkAt = _t + 7 + _random.nextDouble() * 7;

  void _start(NibiReaction reaction) {
    _reaction = reaction;
    if (_animated) {
      _reactionStart = _t;
    } else {
      _frame.value = _compose(0);
      _staticReactionTimer?.cancel();
      _staticReactionTimer = Timer(const Duration(milliseconds: 1500), () {
        _reaction = null;
        if (mounted) _frame.value = _compose(0);
      });
    }
  }

  void _onGuidedBreath() {
    if (!_animated) _frame.value = _compose(0);
  }

  @override
  void initState() {
    super.initState();
    widget.guidedBreath?.addListener(_onGuidedBreath);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool animate = ScMotion.enabled(context);
    if (animate != _animated) {
      _animated = animate;
      if (animate) {
        unawaited(_ticker.start());
      } else {
        _ticker.stop();
        _t = 0;
      }
      _reaction = null;
      _nextQuirkAt = 8;
      _frame.value = _compose(_t);
    }
  }

  @override
  void didUpdateWidget(NibiView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.guidedBreath != widget.guidedBreath) {
      oldWidget.guidedBreath?.removeListener(_onGuidedBreath);
      widget.guidedBreath?.addListener(_onGuidedBreath);
    }
    if (oldWidget.activity != widget.activity ||
        oldWidget.aura != widget.aura ||
        oldWidget.guidedBreath != widget.guidedBreath) {
      _from = _frame.value.pose;
      _transitionStart = _t;
      // Una manía se interrumpe al cambiar de actividad.
      if (_reaction != null && NibiReaction.quirks.contains(_reaction)) _reaction = null;
      _frame.value = _compose(_t);
    }
  }

  /// Reacción al toque en [local] (coordenadas del widget). Sin posición (botón
  /// "Acariciar" o lector de pantalla) va alternando todas las reacciones.
  void pet([Offset? local]) {
    final NibiReaction reaction = _reactionAt(local);
    unawaited(HapticFeedback.lightImpact());
    _start(reaction);
    widget.onReaction?.call(reaction);
  }

  NibiReaction _reactionAt(Offset? local) {
    final String zone;
    final List<NibiReaction> options;
    // A unidades del lienzo de 200 × 200.
    final double u = (local?.dx ?? 0) / widget.size * 200;
    final double v = (local?.dy ?? 0) / widget.size * 200;
    if (local == null) {
      zone = 'any';
      options = const <NibiReaction>[
        NibiReaction.pat,
        NibiReaction.giggle,
        NibiReaction.spin,
        NibiReaction.puff,
        NibiReaction.hop,
      ];
    } else if (v < 118) {
      zone = 'head';
      options = const <NibiReaction>[NibiReaction.pat, NibiReaction.puff, NibiReaction.pat, NibiReaction.spin];
    } else if ((u - 100).abs() < 34) {
      zone = 'belly';
      options = const <NibiReaction>[NibiReaction.giggle, NibiReaction.giggle, NibiReaction.hop];
    } else {
      zone = 'side';
      options = const <NibiReaction>[NibiReaction.spin, NibiReaction.hop];
    }
    final int n = _zoneTaps[zone] ?? 0;
    _zoneTaps[zone] = n + 1;
    return options[n % options.length];
  }

  void _purrStart() {
    _holding = true;
    unawaited(HapticFeedback.mediumImpact());
    _start(NibiReaction.purr);
    widget.onReaction?.call(NibiReaction.purr);
  }

  void _purrEnd() => _holding = false;

  @override
  void dispose() {
    widget.guidedBreath?.removeListener(_onGuidedBreath);
    _staticReactionTimer?.cancel();
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final Widget canvas = RepaintBoundary(
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: NibiPainter(
          frame: _frame,
          palette: NibiPalette.of(c, colorId: widget.look.colorId),
          look: widget.look,
        ),
      ),
    );
    final bool interactive = widget.onReaction != null;
    return Semantics(
      label: widget.semanticsLabel,
      button: interactive,
      image: !interactive,
      excludeSemantics: true,
      onTap: interactive ? pet : null,
      child: interactive
          ? GestureDetector(
              onTapUp: (TapUpDetails d) => pet(d.localPosition),
              onLongPressStart: (_) => _purrStart(),
              onLongPressEnd: (_) => _purrEnd(),
              onLongPressCancel: _purrEnd,
              child: canvas,
            )
          : canvas,
    );
  }
}

/// Retrato estático de Nibi (solo la cabeza) para avatares: una sola imagen
/// vectorial, nítida a cualquier tamaño y sin animación (no gasta batería en
/// listas ni en Hoy).
class NibiAvatar extends StatelessWidget {
  // Un fotograma fijo por actividad, compartido por todos los avatares.
  static final Map<NibiActivity, ValueNotifier<NibiFrame>> _staticFrames = <NibiActivity, ValueNotifier<NibiFrame>>{};

  const NibiAvatar({super.key, this.size = 48, this.look = const NibiLook(), this.activity = NibiActivity.happy});

  final double size;
  final NibiLook look;
  final NibiActivity activity;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.isFlat ? c.bg2 : Color.lerp(NibiSkin.of(look.colorId).muzzle, const Color(0xFFFFFFFF), 0.7),
        border: Border.all(color: c.isFlat ? c.line2 : c.accent.withValues(alpha: 0.6), width: c.isFlat ? 1.5 : 2),
      ),
      child: ClipOval(
        child: CustomPaint(
          size: Size.square(size),
          painter: NibiPainter(
            frame: _staticFrames[activity] ??= ValueNotifier<NibiFrame>(
              NibiFrame(activity: activity, pose: NibiChoreography.pose(activity, 0)),
            ),
            palette: NibiPalette.of(c, colorId: look.colorId),
            look: look,
            framing: NibiFraming.head,
          ),
        ),
      ),
    );
  }
}

/// Fotograma fijo de una actividad (capturas, pruebas, vistas sin animación).
NibiFrame nibiStaticFrame(NibiActivity activity, {double t = 0, bool aura = false}) =>
    NibiFrame(activity: activity, pose: NibiChoreography.pose(activity, t, aura: aura), t: t);
