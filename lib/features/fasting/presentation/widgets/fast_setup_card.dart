import 'package:flutter/material.dart';

import '../../../../core/domain/metabolic_phase.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_tokens.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/chip_pill.dart';
import '../../../../shared/widgets/health_card.dart';
import '../../../../shared/widgets/metric_value.dart';
import '../../../../shared/widgets/progress_ring.dart';

/// Protocolos de ayuno ofrecidos. `custom` deja elegir las horas (12–36).
enum FastProtocol {
  p14(14),
  p16(16),
  p18(18),
  p20(20),
  custom(15);

  const FastProtocol(this.defaultHours);

  final int defaultHours;

  String name(int hours) =>
      this == FastProtocol.custom ? '$hours h' : '$defaultHours:${24 - defaultHours}';

  String description(AppLocalizations l10n) => switch (this) {
    FastProtocol.p14 => l10n.fastProtocol14,
    FastProtocol.p16 => l10n.fastProtocol16,
    FastProtocol.p18 => l10n.fastProtocol18,
    FastProtocol.p20 => l10n.fastProtocol20,
    FastProtocol.custom => l10n.fastProtocolCustom,
  };
}

/// Preparación de un ayuno: protocolo, hora de inicio y botón de empezar.
class FastSetupCard extends StatelessWidget {
  const FastSetupCard({
    super.key,
    required this.protocol,
    required this.targetHours,
    required this.startLabel,
    required this.hasCustomStart,
    required this.onProtocol,
    required this.onCustomHours,
    required this.onStartNow,
    required this.onPickStart,
    required this.onStart,
  });

  final FastProtocol protocol;
  final int targetHours;

  /// Hora de inicio elegida ya formateada, o `null` si empieza ahora.
  final String? startLabel;
  final bool hasCustomStart;
  final ValueChanged<FastProtocol> onProtocol;
  final ValueChanged<int> onCustomHours;
  final VoidCallback onStartNow;
  final VoidCallback onPickStart;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    return Column(
      children: <Widget>[
        HealthCard(
          padding: const EdgeInsets.all(ScSpace.l + 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: ScProgressRing(
                  value: 0,
                  size: 120,
                  stroke: 10,
                  color: c.fasting,
                  ticks: <double>[
                    for (final MetabolicPhase p in MetabolicPhase.values)
                      if (p.startsAtHour > 0 && p.startsAtHour < targetHours)
                        p.startsAtHour / targetHours,
                  ],
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: MetricValue(
                      value: '$targetHours',
                      unit: context.l10n.unitHours,
                      size: 34,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: ScSpace.l),
              Text(
                l10n.fastReady(protocol.name(targetHours)),
                textAlign: TextAlign.center,
                style: context.text.headlineSmall,
              ),
              const SizedBox(height: ScSpace.xs),
              Text(
                startLabel == null ? l10n.fastStartsNow : l10n.fastStartsAt(startLabel!),
                textAlign: TextAlign.center,
                style: context.text.bodySmall,
              ),
              const SizedBox(height: ScSpace.l),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: ScSpace.s,
                runSpacing: ScSpace.s,
                children: <Widget>[
                  ChipPill(label: l10n.fastStartNow, active: !hasCustomStart, onTap: onStartNow),
                  ChipPill(
                    label: l10n.fastPickStart,
                    icon: AppIcons.edit,
                    active: hasCustomStart,
                    onTap: onPickStart,
                  ),
                ],
              ),
              const SizedBox(height: ScSpace.l),
              FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(l10n.fastStartButton(protocol.name(targetHours))),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              ),
            ],
          ),
        ),
        // Protocolos como lista de opciones dentro de una sola tarjeta.
        HealthCard(
          padding: const EdgeInsets.symmetric(vertical: ScSpace.xs),
          child: Column(
            children: <Widget>[
              for (final FastProtocol p in FastProtocol.values) ...<Widget>[
                if (p.index > 0) const Divider(height: 1, indent: ScSpace.l + 40),
                _ProtocolTile(
                  protocol: p,
                  selected: p == protocol,
                  hours: p == FastProtocol.custom && p == protocol ? targetHours : p.defaultHours,
                  onTap: () => onProtocol(p),
                  onCustomHours: onCustomHours,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ProtocolTile extends StatelessWidget {
  const _ProtocolTile({
    required this.protocol,
    required this.selected,
    required this.hours,
    required this.onTap,
    required this.onCustomHours,
  });

  final FastProtocol protocol;
  final bool selected;
  final int hours;
  final VoidCallback onTap;
  final ValueChanged<int> onCustomHours;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final Color tint = c.isFlat ? c.text : c.accent;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: ScMotion.of(context, ScMotion.quick),
          color: selected && !c.isFlat ? c.accent.withValues(alpha: 0.07) : Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: ScSpace.m, horizontal: ScSpace.l),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    color: selected ? tint : c.text3,
                  ),
                  const SizedBox(width: ScSpace.m + 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          protocol == FastProtocol.custom
                              ? l10n.fastProtocolCustomTitle
                              : protocol.name(hours),
                          style: context.type.label.copyWith(fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(protocol.description(l10n), style: context.type.caption),
                      ],
                    ),
                  ),
                  const SizedBox(width: ScSpace.s),
                  Text(
                    l10n.fastHours(hours),
                    style: context.type.metricS.copyWith(
                      fontSize: 15,
                      color: selected ? tint : c.text2,
                    ),
                  ),
                ],
              ),
              if (protocol == FastProtocol.custom && selected)
                Slider(
                  value: hours.toDouble().clamp(12, 36),
                  min: 12,
                  max: 36,
                  divisions: 24,
                  label: l10n.fastHours(hours),
                  onChanged: (double v) => onCustomHours(v.round()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
