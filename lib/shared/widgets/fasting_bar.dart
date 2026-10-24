import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/fasting_dao.dart';
import '../theme/sc_colors.dart';
import '../theme/sc_theme.dart';
import 'app_icons.dart';

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
    final Duration period =
        isFlat ? const Duration(seconds: 60) : const Duration(seconds: 15);
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

  String _getMetabolicStageSnippet(double hours) {
    if (hours < 4.0) return 'Fase anabólica';
    if (hours < 12.0) return 'Glucogenólisis';
    if (hours < 18.0) return 'Lipólisis y cetosis ✨';
    if (hours < 24.0) return 'Cetosis activa';
    return 'Autofagia profunda 🧬';
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<FastingSession?> sessionAsync =
        ref.watch(activeFastingSessionStreamProvider);
    final FastingSession? session = sessionAsync.value;
    if (session == null) {
      return const SizedBox.shrink();
    }

    final ScColors c = context.sc;
    final DateTime now = DateTime.now();
    final int totalSeconds =
        now.difference(session.startedAt).inSeconds.clamp(0, 864000);
    final double elapsedHours = totalSeconds / 3600.0;
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;

    final double progress = session.targetHours > 0
        ? (elapsedHours / session.targetHours).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: c.bg2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: c.isFlat ? c.line2 : c.fasting.withValues(alpha: 0.4),
            width: c.isFlat ? 1.5 : 1.2,
          ),
        ),
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/ayuno'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c.isFlat
                            ? Colors.transparent
                            : c.fasting.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: c.isFlat
                            ? Border.all(color: c.line2, width: 1.5)
                            : null,
                      ),
                      child: Icon(
                        AppIcons.fasting,
                        size: 20,
                        color: c.isFlat ? c.text : c.fasting,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Ayuno ${session.protocolName} · ${hours}h ${minutes.toString().padLeft(2, '0')}m',
                                style: TextStyle(
                                  fontFamily: ScFonts.display,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: c.text,
                                ),
                              ),
                              Text(
                                '${(progress * 100).toInt()}%',
                                style: TextStyle(
                                  fontFamily: ScFonts.display,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: c.isFlat ? c.text : c.fasting,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _getMetabolicStageSnippet(elapsedHours),
                            style: TextStyle(
                              fontFamily: ScFonts.ui,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: c.text2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(AppIcons.chevronRight, size: 18, color: c.text3),
                  ],
                ),
              ),
              LinearProgressIndicator(
                value: progress,
                minHeight: 3.5,
                backgroundColor: c.bg3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  c.isFlat ? c.text : c.fasting,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
