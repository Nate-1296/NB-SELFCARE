import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/platform/health_connect_gateway.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/chip_pill.dart';
import '../../../../shared/widgets/sheet.dart';
import '../../../profile_goals/application/profile_queries.dart';
import '../../application/daily_activity_service.dart';
import '../../application/health_sync_service.dart';

/// Hoja rápida (< 5s) para ajustar Pasos NEAT, Horas de Sueño y sincronizar Health Connect.
class HoyStepsSleepSheet extends ConsumerStatefulWidget {
  const HoyStepsSleepSheet({
    super.key,
    required this.dateKey,
    required this.profile,
    this.currentSummary,
  });

  final String dateKey;
  final UserProfile profile;
  final DailySummary? currentSummary;

  static Future<void> show({
    required BuildContext context,
    required String dateKey,
    required UserProfile profile,
    DailySummary? currentSummary,
  }) {
    return mostrarHojaMenu<void>(
      context,
      builder: (_) => HoyStepsSleepSheet(
        dateKey: dateKey,
        profile: profile,
        currentSummary: currentSummary,
      ),
    );
  }

  @override
  ConsumerState<HoyStepsSleepSheet> createState() => _HoyStepsSleepSheetState();
}

class _HoyStepsSleepSheetState extends ConsumerState<HoyStepsSleepSheet> {
  late int _steps;
  late double _sleepHours;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _steps = widget.currentSummary?.stepsCount ?? 0;
    final int currentMin = widget.currentSummary?.sleepDurationMinutes ?? 0;
    _sleepHours = currentMin > 0 ? (currentMin / 60.0).clamp(3.0, 12.0) : 7.5;
  }

  Future<void> _syncFromHealthConnect() async {
    setState(() => _isSyncing = true);
    final HealthConnectGateway gateway = ref.read(healthConnectGatewayProvider);
    if (!await gateway.hasPermissions()) {
      await gateway.requestPermissions();
    }
    final HealthSyncResult result =
        await ref.read(healthSyncServiceProvider).syncDay(widget.dateKey);
    final DailyActivitySnapshot? data = result.snapshot;

    if (!mounted) return;
    setState(() {
      _isSyncing = false;
      if (data?.steps != null) _steps = data!.steps!;
      final int? sleep = data?.sleepMinutes;
      if (sleep != null && sleep > 0) _sleepHours = (sleep / 60.0).clamp(3.0, 12.0);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(switch (result.outcome) {
          HealthSyncOutcome.synced => context.l10n.todayDatosSincronizadosDesdeHealthConnect,
          HealthSyncOutcome.noData =>
            context.l10n.todayHealthConnectNoTieneRegistros,
          HealthSyncOutcome.notConnected =>
            context.l10n.todayConectaHealthConnectEnAjustes,
        }),
      ),
    );
  }

  Future<void> _save() async {
    unawaited(HapticFeedback.lightImpact());
    final int coins = await ref.read(dailyActivityServiceProvider).saveManualEntry(
          dateKey: widget.dateKey,
          steps: _steps,
          sleepMinutes: (_sleepHours * 60).round(),
        );

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            coins > 0
                ? context.l10n.todayActivitySavedCoins(_steps, _sleepHours.toStringAsFixed(1), coins)
                : context.l10n.todayActivitySaved(_steps, _sleepHours.toStringAsFixed(1)),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final double sleepGoalHours =
        ref.watch(userProfileStreamProvider).value?.dailySleepGoalHours ?? 7.5;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                context.l10n.todayPasosNeatYSueno,
                style: TextStyle(
                  fontFamily: ScFonts.display,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: c.text,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _isSyncing ? null : _syncFromHealthConnect,
                icon: Icon(AppIcons.refresh, size: 16, color: c.accent),
                label:
                    Text(_isSyncing ? context.l10n.todaySincronizando: context.l10n.todayHealthConnect),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                context.l10n.todayPasosDelDia,
                style: TextStyle(fontWeight: FontWeight.w700, color: c.text),
              ),
              Text(
                context.l10n.todayTexto2((_steps).toString(), widget.profile.dailyStepsGoal.toString()),
                style: TextStyle(
                  fontFamily: ScFonts.display,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: c.steps,
                ),
              ),
            ],
          ),
          Slider(
            value: _steps.clamp(0, 25000).toDouble(),
            min: 0,
            max: 25000,
            divisions: 50,
            activeColor: c.steps,
            onChanged: (double v) => setState(() => _steps = v.round()),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              ChipPill(
                label: context.l10n.today1000Pasos,
                onTap: () =>
                    setState(() => _steps = (_steps + 1000).clamp(0, 50000)),
              ),
              ChipPill(
                label: context.l10n.today2500Pasos,
                onTap: () =>
                    setState(() => _steps = (_steps + 2500).clamp(0, 50000)),
              ),
              ChipPill(
                label: context.l10n.todayMeta(widget.profile.dailyStepsGoal.toString()),
                onTap: () =>
                    setState(() => _steps = widget.profile.dailyStepsGoal),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                context.l10n.todayHorasDeSuenoAnoche,
                style: TextStyle(fontWeight: FontWeight.w700, color: c.text),
              ),
              Text(
                context.l10n.todayH(_sleepHours.toStringAsFixed(1).toString()),
                style: TextStyle(
                  fontFamily: ScFonts.display,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: c.fasting,
                ),
              ),
            ],
          ),
          Slider(
            value: _sleepHours,
            min: 3.0,
            max: 12.0,
            divisions: 18,
            activeColor: c.fasting,
            onChanged: (double v) => setState(() => _sleepHours = v),
          ),
          Text(
            _sleepHours >= sleepGoalHours
                ? context.l10n.todayCumplesTuMetaDeH(sleepGoalHours.toStringAsFixed(1).toString()): context.l10n.todayConHDeSuenoTus(sleepGoalHours.toStringAsFixed(1).toString()),
            style: TextStyle(fontSize: 11.5, color: c.text2),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(context.l10n.todayGuardarResumenDiario),
            ),
          ),
        ],
      ),
    );
  }
}
