import 'package:flutter/material.dart';

import '../../../../../core/hardware/body_scale_driver.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_theme.dart';
import '../../../../../shared/theme/sc_tokens.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/health_card.dart';
import '../../../application/scale_session.dart';

/// Pesaje con la báscula Bluetooth, a mano o con cinta métrica.
class ScaleStationCard extends StatelessWidget {
  const ScaleStationCard({
    super.key,
    required this.session,
    required this.isBound,
    required this.weightOnly,
    required this.onScan,
    required this.onStop,
    required this.onAcceptWeightOnly,
    required this.onManual,
    required this.onTape,
    required this.onConfigure,
  });

  final ScaleSessionState session;
  final bool isBound;

  /// Contraindicación de bioimpedancia: la báscula solo pesa.
  final bool weightOnly;
  final VoidCallback onScan;
  final VoidCallback onStop;
  final VoidCallback onAcceptWeightOnly;
  final VoidCallback onManual;
  final VoidCallback onTape;
  final VoidCallback onConfigure;

  String _status(AppLocalizations l10n) {
    final ScaleMeasurementEvent? live = session.live;
    return switch (session.phase) {
      ScalePhase.searching => l10n.cuerpoScaleSearching,
      ScalePhase.measuring => l10n.cuerpoScaleMeasuring,
      ScalePhase.awaitingImpedance => l10n.cuerpoScaleAwaitingImpedance,
      ScalePhase.error => l10n.cuerpoScaleError,
      ScalePhase.idle when weightOnly => l10n.cuerpoScaleIdleWeightOnly,
      ScalePhase.idle when live != null && session.capture == null => l10n.cuerpoScaleLastReading(
          live.weightKg.toStringAsFixed(1),
        ),
      ScalePhase.idle => isBound ? l10n.cuerpoScaleIdleBound : l10n.cuerpoScaleIdle,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final bool scanning = session.isScanning;
    final ScaleMeasurementEvent? live = scanning ? session.live : null;

    return HealthCard(
      backgroundColor: scanning && !c.isFlat ? c.accent.withValues(alpha: 0.08) : null,
      borderColor: scanning ? (c.isFlat ? c.text : c.accent) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scanning && !c.isFlat ? c.accent : c.bg3,
                  shape: BoxShape.circle,
                  border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
                ),
                child: Icon(AppIcons.bluetooth, size: 22, color: scanning && !c.isFlat ? c.ink : c.text),
              ),
              const SizedBox(width: ScSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(l10n.cuerpoScaleTitle, style: context.text.titleMedium),
                    Semantics(liveRegion: true, child: Text(_status(l10n), style: context.text.bodySmall)),
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.cuerpoScaleSettings,
                onPressed: onConfigure,
                icon: Icon(Icons.tune_rounded, color: c.text2),
              ),
            ],
          ),
          if (live != null) ...<Widget>[
            const SizedBox(height: ScSpace.m),
            _LiveReading(event: live, onAcceptWeightOnly: onAcceptWeightOnly, phase: session.phase),
          ],
          const SizedBox(height: ScSpace.m),
          FilledButton.icon(
            onPressed: scanning ? onStop : onScan,
            icon: Icon(scanning ? Icons.stop_rounded : AppIcons.bluetooth),
            label: Text(scanning ? l10n.cuerpoScaleStop : l10n.cuerpoScaleStart),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          const SizedBox(height: ScSpace.s),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onManual,
                  icon: const Icon(AppIcons.edit, size: 16),
                  label: Text(l10n.cuerpoManualWeighIn),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                ),
              ),
              const SizedBox(width: ScSpace.s),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onTape,
                  icon: const Icon(AppIcons.tape, size: 16),
                  label: Text(l10n.cuerpoTapeButton),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiveReading extends StatelessWidget {
  const _LiveReading({required this.event, required this.onAcceptWeightOnly, required this.phase});

  final ScaleMeasurementEvent event;
  final VoidCallback onAcceptWeightOnly;
  final ScalePhase phase;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Container(
      padding: const EdgeInsets.all(ScSpace.m),
      decoration: BoxDecoration(
        color: c.bg3,
        borderRadius: BorderRadius.circular(ScRadius.tile),
        border: Border.all(color: c.isFlat ? c.text : c.accent, width: c.isFlat ? 1.5 : 1.0),
      ),
      child: Column(
        children: <Widget>[
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: event.weightKg.toStringAsFixed(1),
                  style: TextStyle(
                    fontFamily: ScFonts.display,
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: c.isFlat ? c.text : c.accent,
                  ),
                ),
                TextSpan(
                  text: ' kg',
                  style: TextStyle(fontFamily: ScFonts.display, fontSize: 18, color: c.text2),
                ),
              ],
            ),
          ),
          if (phase == ScalePhase.awaitingImpedance)
            TextButton.icon(
              onPressed: onAcceptWeightOnly,
              icon: const Icon(AppIcons.check, size: 16),
              label: Text(context.l10n.cuerpoSaveWeightOnly),
            ),
        ],
      ),
    );
  }
}
