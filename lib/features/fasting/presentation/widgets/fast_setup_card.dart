import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/theme/sc_tokens.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/chip_pill.dart';
import '../../../../shared/widgets/health_card.dart';

/// Protocolos de ayuno ofrecidos. `custom` deja elegir las horas (12–36).
enum FastProtocol {
  p14(14),
  p16(16),
  p18(18),
  p20(20),
  custom(15);

  const FastProtocol(this.defaultHours);

  final int defaultHours;

  String name(int hours) => this == FastProtocol.custom ? '$hours h' : '$defaultHours:${24 - defaultHours}';

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
              Icon(AppIcons.ayuno, size: 32, color: c.isFlat ? c.text : c.fasting),
              const SizedBox(height: ScSpace.s),
              Text(
                l10n.fastReady(protocol.name(targetHours)),
                textAlign: TextAlign.center,
                style: context.text.titleLarge,
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
                  ChipPill(label: l10n.fastPickStart, icon: AppIcons.edit, active: hasCustomStart, onTap: onPickStart),
                ],
              ),
              const SizedBox(height: ScSpace.l),
              FilledButton(
                onPressed: onStart,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: ScSpace.l),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ScRadius.tile)),
                ),
                child: Text(
                  l10n.fastStartButton(protocol.name(targetHours)),
                  style: const TextStyle(fontFamily: ScFonts.display, fontWeight: FontWeight.w800, fontSize: 15.5),
                ),
              ),
            ],
          ),
        ),
        for (final FastProtocol p in FastProtocol.values)
          _ProtocolTile(
            protocol: p,
            selected: p == protocol,
            hours: p == FastProtocol.custom && p == protocol ? targetHours : p.defaultHours,
            onTap: () => onProtocol(p),
            onCustomHours: onCustomHours,
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
      child: HealthCard(
        padding: const EdgeInsets.symmetric(vertical: ScSpace.m + 2, horizontal: ScSpace.l),
        borderColor: selected ? tint : null,
        onTap: onTap,
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: selected ? tint : c.text3,
                ),
                const SizedBox(width: ScSpace.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        protocol == FastProtocol.custom ? l10n.fastProtocolCustomTitle : protocol.name(hours),
                        style: context.text.titleMedium,
                      ),
                      Text(protocol.description(l10n), style: context.text.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: ScSpace.s),
                Text(
                  l10n.fastHours(hours),
                  style: TextStyle(fontFamily: ScFonts.display, fontSize: 13.5, fontWeight: FontWeight.w800, color: tint),
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
    );
  }
}
