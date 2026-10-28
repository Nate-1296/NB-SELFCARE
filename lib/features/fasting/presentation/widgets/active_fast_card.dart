import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/clock/clock.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/domain/metabolic_phase.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_tokens.dart';
import '../../../../shared/utils/date_formats.dart';
import '../../../../shared/utils/date_time_extensions.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/health_card.dart';
import '../../../../shared/widgets/progress_ring.dart';
import '../../../../shared/widgets/quick_action_button.dart';
import '../../../../shared/widgets/tonal_badge.dart';
import '../metabolic_phase_l10n.dart';

/// "18:30" hoy, "ayer 23:10" o la fecha completa si fue antes.
String fastClockLabel(DateTime time, DateTime now, AppLocalizations l10n) {
  final String clock = DateFormats.time(time, l10n.localeName);
  final int daysAgo = now.calendarDaysSince(time);
  if (daysAgo == 0) return clock;
  if (daysAgo == 1) return l10n.fastYesterdayAt(clock);
  if (daysAgo == -1) return l10n.fastTomorrowAt(clock);
  return '${DateFormats.shortDate(time, l10n.localeName)} $clock';
}

/// Cronómetro del ayuno en curso. Es el único widget que se repinta cada
/// segundo (cada minuto en Modo Papel, para no provocar ghosting).
class ActiveFastCard extends ConsumerStatefulWidget {
  const ActiveFastCard({
    super.key,
    required this.session,
    required this.onAdjustStart,
    required this.onFinish,
  });

  final FastingSession session;
  final VoidCallback onAdjustStart;
  final ValueChanged<double> onFinish;

  @override
  ConsumerState<ActiveFastCard> createState() => _ActiveFastCardState();
}

class _ActiveFastCardState extends ConsumerState<ActiveFastCard> {
  Timer? _ticker;
  bool? _flat;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool flat = context.sc.isFlat;
    if (_flat == flat) return;
    _flat = flat;
    _ticker?.cancel();
    _ticker = Timer.periodic(flat ? const Duration(minutes: 1) : const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final FastingSession s = widget.session;
    final DateTime now = ref.read(clockProvider).now();
    final int secs = now.difference(s.startedAt).inSeconds.clamp(0, 864000);
    final double hours = secs / 3600.0;
    final double progress = s.targetHours > 0 ? (hours / s.targetHours).clamp(0.0, 1.0) : 0.0;
    final MetabolicPhase phase = MetabolicPhase.forHours(hours);
    final Color tone = phase.color(c);
    final String mm = ((secs % 3600) ~/ 60).toString().padLeft(2, '0');
    final String elapsed = c.isFlat
        ? '${secs ~/ 3600} h $mm min'
        : '${secs ~/ 3600}:$mm:${(secs % 60).toString().padLeft(2, '0')}';

    // Marcas de inicio de cada fase que cae dentro de la meta.
    final List<double> phaseTicks = <double>[
      for (final MetabolicPhase p in MetabolicPhase.values)
        if (p.startsAtHour > 0 && p.startsAtHour < s.targetHours) p.startsAtHour / s.targetHours,
    ];

    return HealthCard(
      padding: const EdgeInsets.fromLTRB(ScSpace.l + 4, ScSpace.xl, ScSpace.l + 4, ScSpace.l + 4),
      child: Column(
        children: <Widget>[
          Semantics(
            label: l10n.fastElapsedSemantics(secs ~/ 3600, (secs % 3600) ~/ 60, s.targetHours),
            excludeSemantics: true,
            child: ScProgressRing(
              value: progress,
              size: 236,
              stroke: 16,
              color: tone,
              ticks: phaseTicks,
              animateChanges: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TonalBadge(label: phase.label(l10n), tone: tone),
                  const SizedBox(height: ScSpace.m),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      elapsed,
                      style: context.type.metricXL.copyWith(fontSize: c.isFlat ? 34 : 40),
                    ),
                  ),
                  const SizedBox(height: ScSpace.xs + 2),
                  Text(
                    l10n.fastGoalProgress(s.targetHours, (progress * 100).floor()),
                    style: context.type.caption,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: ScSpace.xl),
          IntrinsicHeight(
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _Cell(
                    label: l10n.fastStart,
                    value: fastClockLabel(s.startedAt, now, l10n),
                    onTap: widget.onAdjustStart,
                    tooltip: l10n.fastAdjustStart,
                  ),
                ),
                VerticalDivider(width: 1, color: c.isFlat ? c.line2 : c.line),
                Expanded(
                  child: _Cell(label: l10n.fastProtocol, value: s.protocolName),
                ),
                VerticalDivider(width: 1, color: c.isFlat ? c.line2 : c.line),
                Expanded(
                  child: _Cell(
                    label: l10n.fastPlannedEnd,
                    value: fastClockLabel(s.plannedEndAt, now, l10n),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ScSpace.l + 4),
          QuickActionButton(
            label: l10n.fastFinish,
            icon: Icons.stop_circle_outlined,
            tone: c.warning,
            onPressed: () => widget.onFinish(hours),
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.value, this.onTap, this.tooltip});

  final String label;
  final String value;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: ScSpace.xs, vertical: ScSpace.xxs),
      child: Column(
        children: <Widget>[
          // Se encoge en pantallas estrechas en lugar de desbordar ("FIN PREVISTO").
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(label.toUpperCase(), style: context.type.overline),
                if (onTap != null) ...<Widget>[
                  const SizedBox(width: ScSpace.xs),
                  Icon(AppIcons.edit, size: 12, color: c.isFlat ? c.text : c.accent),
                ],
              ],
            ),
          ),
          const SizedBox(height: ScSpace.xs + 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: context.type.metricS.copyWith(fontSize: 16),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return Tooltip(
      message: tooltip ?? label,
      child: InkWell(
        borderRadius: BorderRadius.circular(ScRadius.control),
        onTap: onTap,
        child: content,
      ),
    );
  }
}
