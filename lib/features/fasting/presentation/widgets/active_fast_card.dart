import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/clock/clock.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/domain/metabolic_phase.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/theme/sc_tokens.dart';
import '../../../../shared/utils/date_formats.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/health_card.dart';
import '../../../../shared/widgets/tonal_badge.dart';
import '../metabolic_phase_l10n.dart';

/// "18:30" hoy, "ayer 23:10" o la fecha completa si fue antes.
String fastClockLabel(DateTime time, DateTime now, AppLocalizations l10n) {
  final String clock = DateFormats.time(time, l10n.localeName);
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime day = DateTime(time.year, time.month, time.day);
  final int daysAgo = today.difference(day).inDays;
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

    return HealthCard(
      padding: const EdgeInsets.symmetric(vertical: ScSpace.xl, horizontal: ScSpace.l + 4),
      child: Column(
        children: <Widget>[
          TonalBadge(label: phase.label(l10n), tone: tone),
          const SizedBox(height: ScSpace.l),
          Semantics(
            label: l10n.fastElapsedSemantics(secs ~/ 3600, (secs % 3600) ~/ 60, s.targetHours),
            excludeSemantics: true,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                SizedBox(
                  width: 204,
                  height: 204,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 14,
                    strokeCap: c.isFlat ? StrokeCap.butt : StrokeCap.round,
                    backgroundColor: c.bg3,
                    valueColor: AlwaysStoppedAnimation<Color>(tone),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(AppIcons.ayunoFilled, size: 28, color: tone),
                    const SizedBox(height: ScSpace.xs),
                    Text(
                      elapsed,
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      l10n.fastGoalProgress(s.targetHours, (progress * 100).floor()),
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: ScSpace.xl),
          Container(
            padding: const EdgeInsets.symmetric(vertical: ScSpace.m, horizontal: ScSpace.s),
            decoration: BoxDecoration(
              color: c.bg3,
              borderRadius: BorderRadius.circular(ScRadius.tile),
              border: Border.all(color: c.isFlat ? c.line2 : c.line, width: c.isFlat ? 1.5 : 1),
            ),
            child: IntrinsicHeight(
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
                  VerticalDivider(width: 1, color: c.line),
                  Expanded(child: _Cell(label: l10n.fastProtocol, value: s.protocolName)),
                  VerticalDivider(width: 1, color: c.line),
                  Expanded(
                    child: _Cell(label: l10n.fastPlannedEnd, value: fastClockLabel(s.plannedEndAt, now, l10n)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: ScSpace.l + 2),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: ScSpace.l),
                side: BorderSide(color: c.isFlat ? c.line2 : c.warning, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ScRadius.tile)),
              ),
              onPressed: () => widget.onFinish(hours),
              child: Text(
                l10n.fastFinish,
                style: const TextStyle(fontFamily: ScFonts.display, fontWeight: FontWeight.w800, fontSize: 15.5),
              ),
            ),
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(label, style: TextStyle(fontFamily: ScFonts.ui, fontSize: 11.5, color: c.text3)),
              if (onTap != null) ...<Widget>[
                const SizedBox(width: ScSpace.xs),
                Icon(AppIcons.edit, size: 12, color: c.isFlat ? c.text : c.accent),
              ],
            ],
          ),
          const SizedBox(height: ScSpace.xxs),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: ScFonts.display, fontSize: 14, fontWeight: FontWeight.w800, color: c.text),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return Tooltip(
      message: tooltip ?? label,
      child: InkWell(borderRadius: BorderRadius.circular(ScRadius.control), onTap: onTap, child: content),
    );
  }
}
