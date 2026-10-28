import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/hardware/body_scale_driver.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_tokens.dart';
import '../../../../../shared/utils/number_formats.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/health_card.dart';
import '../../../../../shared/widgets/metric_value.dart';
import '../../../../pet_gamification/application/nibi_overview.dart';
import '../../../../pet_gamification/domain/nibi_activity.dart';
import '../../../../pet_gamification/presentation/nibi/nibi_view.dart';
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
      ScalePhase.notFound => l10n.cuerpoScaleNotFound,
      ScalePhase.idle when weightOnly => l10n.cuerpoScaleIdleWeightOnly,
      ScalePhase.idle when live != null && session.capture == null => l10n.cuerpoScaleLastReading(
        NumberFormats.fixed(live.weightKg, 1),
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
      backgroundColor: scanning && !c.isFlat
          ? Color.alphaBlend(c.accent.withValues(alpha: 0.07), c.bg2)
          : null,
      borderColor: scanning ? (c.isFlat ? c.text : c.accent) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              _ScaleBeacon(active: scanning),
              const SizedBox(width: ScSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(l10n.cuerpoScaleTitle, style: context.text.titleLarge),
                    Semantics(
                      liveRegion: true,
                      child: Text(_status(l10n), style: context.type.caption),
                    ),
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
          const SizedBox(height: ScSpace.l),
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
        color: c.isFlat ? c.bg2 : c.bg3,
        borderRadius: BorderRadius.circular(ScRadius.tileOf(c)),
        border: c.isFlat ? Border.all(color: c.text, width: 1.5) : null,
      ),
      child: Column(
        children: <Widget>[
          // Nibi se sube a su mini báscula mientras se pesa contigo.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // Nibi se sube a su báscula con lo que lleva puesto.
              Consumer(
                builder: (BuildContext context, WidgetRef ref, _) =>
                    NibiView(activity: NibiActivity.weighing, size: 84, look: ref.watch(nibiLookProvider)),
              ),
              const SizedBox(width: ScSpace.s),
              Flexible(
                child: AnimatedMetricValue(
                  value: event.weightKg,
                  format: (double v) => NumberFormats.oneDecimal(v, context.l10n.localeName),
                  unit: context.l10n.unitKg,
                  size: 44,
                  color: c.isFlat ? c.text : c.accent,
                ),
              ),
            ],
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

/// Icono de la báscula; mientras busca, emite ondas suaves (solo en color).
class _ScaleBeacon extends StatefulWidget {
  const _ScaleBeacon({required this.active});

  final bool active;

  @override
  State<_ScaleBeacon> createState() => _ScaleBeaconState();
}

class _ScaleBeaconState extends State<_ScaleBeacon> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_ScaleBeacon oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final bool animate = widget.active && ScMotion.enabled(context);
    if (animate && !_pulse.isAnimating) {
      unawaited(_pulse.repeat());
    } else if (!animate && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final bool on = widget.active;
    return SizedBox.square(
      dimension: 48,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (BuildContext context, Widget? child) {
            final double t = _pulse.value;
            return Stack(
              alignment: Alignment.center,
              children: <Widget>[
                if (on && !c.isFlat)
                  Container(
                    width: 30 + 18 * t,
                    height: 30 + 18 * t,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.accent.withValues(alpha: 0.35 * (1 - t)),
                    ),
                  ),
                child!,
              ],
            );
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: on ? (c.isFlat ? c.text : c.accent) : (c.isFlat ? c.bg2 : c.bg3),
              shape: BoxShape.circle,
              border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
            ),
            child: Icon(
              AppIcons.bluetooth,
              size: 20,
              color: on ? (c.isFlat ? c.bg : c.ink) : c.text,
            ),
          ),
        ),
      ),
    );
  }
}
