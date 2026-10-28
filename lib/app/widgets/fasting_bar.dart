import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/clock/clock.dart';
import '../../core/database/app_database.dart';
import '../../core/domain/metabolic_phase.dart';
import '../../core/l10n/l10n.dart';
import '../../features/fasting/application/fasting_queries.dart';
import '../../features/fasting/presentation/metabolic_phase_l10n.dart';
import '../../shared/theme/sc_colors.dart';
import '../../shared/theme/sc_tokens.dart';
import '../../shared/widgets/app_icons.dart';
import '../../shared/widgets/progress_ring.dart';

/// Barra flotante persistente del temporizador de ayuno intermitente.
///
/// Permanece anclada sobre la barra de navegación inferior mientras exista una
/// sesión en curso, actualizando el tiempo transcurrido en vivo con cadencia
/// adaptada al hardware (cero ghosting en NXTPAPER E-Ink).
class FastingBar extends ConsumerStatefulWidget {
  const FastingBar({super.key});

  @override
  ConsumerState<FastingBar> createState() => _FastingBarState();
}

class _FastingBarState extends ConsumerState<FastingBar> {
  Timer? _tickTimer;
  bool? _lastFlatMode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool isFlat = context.sc.isFlat;
    if (_lastFlatMode != isFlat) {
      _lastFlatMode = isFlat;
      _restartTicker(isFlat);
    }
  }

  void _restartTicker(bool isFlat) {
    _tickTimer?.cancel();
    final Duration period = isFlat ? const Duration(seconds: 60) : const Duration(seconds: 15);
    _tickTimer = Timer.periodic(period, (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<FastingSession?> sessionAsync = ref.watch(activeFastingSessionStreamProvider);
    final FastingSession? session = sessionAsync.value;
    if (session == null) {
      return const SizedBox.shrink();
    }

    final ScColors c = context.sc;
    final DateTime now = ref.read(clockProvider).now();
    final int totalSeconds = now.difference(session.startedAt).inSeconds.clamp(0, 864000);
    final double elapsedHours = totalSeconds / 3600.0;
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;

    final double progress = session.targetHours > 0
        ? (elapsedHours / session.targetHours).clamp(0.0, 1.0)
        : 0.0;

    final Color tone = c.isFlat ? c.text : c.fasting;
    return Padding(
      padding: const EdgeInsets.fromLTRB(ScSpace.gutter, 0, ScSpace.gutter, ScSpace.s),
      child: RepaintBoundary(
        child: Material(
          color: c.bg2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ScRadius.tileOf(c)),
            side: BorderSide(color: c.isFlat ? c.line2 : c.line, width: c.isFlat ? 1.5 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push('/ayuno'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                ScSpace.m,
                ScSpace.s + 2,
                ScSpace.s,
                ScSpace.s + 2,
              ),
              child: Row(
                children: <Widget>[
                  ScProgressRing(
                    value: progress,
                    size: 38,
                    stroke: 4,
                    color: tone,
                    child: Icon(AppIcons.fasting, size: 15, color: tone),
                  ),
                  const SizedBox(width: ScSpace.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          context.l10n.fastBarTitle(
                            session.protocolName,
                            hours,
                            minutes.toString().padLeft(2, '0'),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.type.label.copyWith(
                            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          MetabolicPhase.forHours(elapsedHours).label(context.l10n),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.type.caption.copyWith(
                            color: c.isFlat ? c.text2 : c.fasting,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${(progress * 100).toInt()} %',
                    style: context.type.metricS.copyWith(fontSize: 15, color: c.text2),
                  ),
                  Icon(AppIcons.chevronRight, size: 20, color: c.text3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
