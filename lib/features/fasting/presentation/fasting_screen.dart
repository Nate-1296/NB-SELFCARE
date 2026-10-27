import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/clock/clock.dart';
import '../../../core/database/app_database.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/services/fasting_dosage_advisor.dart';
import '../../../shared/theme/sc_colors.dart';
import '../../../shared/theme/sc_tokens.dart';
import '../../../shared/widgets/section_head.dart';
import '../../../shared/widgets/top_bar.dart';
import '../../../shared/widgets/undo_snackbar.dart';
import '../../protocol/application/protocol_service.dart';
import '../../protocol/domain/weekly_protocol.dart';
import '../application/fasting_queries.dart';
import '../application/fasting_service.dart';
import 'widgets/active_fast_card.dart';
import 'widgets/fast_break_sheet.dart';
import 'widgets/fast_history.dart';
import 'widgets/fast_setup_card.dart';
import 'widgets/phase_timeline.dart';

/// Ayuno intermitente: cronómetro, protocolos, fases e historial.
class FastingScreen extends ConsumerStatefulWidget {
  const FastingScreen({super.key});

  @override
  ConsumerState<FastingScreen> createState() => _FastingScreenState();
}

class _FastingScreenState extends ConsumerState<FastingScreen> {
  FastProtocol _protocol = FastProtocol.p16;
  int _targetHours = FastProtocol.p16.defaultHours;
  DateTime? _customStart;

  /// Hasta que el usuario elige, se propone el ayuno previsto hoy en "Mi protocolo".
  bool _protocolTouched = false;

  FastingService get _service => ref.read(fastingServiceProvider);

  void _selectProtocol(FastProtocol protocol) {
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _protocolTouched = true;
      _protocol = protocol;
      _targetHours = protocol.defaultHours;
    });
  }

  /// Aplica las horas planeadas para hoy si el usuario aún no eligió otra cosa.
  void _syncWithPlan(WeeklyProtocol? plan, DateTime now) {
    if (_protocolTouched || plan == null) return;
    final int? hours = plan.fastingHoursFor(now);
    if (hours == null) return;
    _targetHours = hours;
    _protocol = FastProtocol.values.firstWhere(
      (FastProtocol p) => p != FastProtocol.custom && p.defaultHours == hours,
      orElse: () => FastProtocol.custom,
    );
  }

  /// Elige una fecha y hora pasadas (hasta 7 días); nunca en el futuro.
  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final DateTime now = ref.read(clockProvider).now();
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: now.subtract(const Duration(days: 7)),
      lastDate: now,
    );
    if (date == null || !mounted) return null;
    final TimeOfDay? time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null || !mounted) return null;
    final DateTime picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    return picked.isAfter(now) ? now : picked;
  }

  Future<void> _adjustStart(FastingSession session) async {
    final DateTime? updated = await _pickDateTime(session.startedAt);
    if (updated != null) await _service.adjustStart(sessionId: session.id, newStartedAt: updated);
  }

  Future<void> _start() async {
    unawaited(HapticFeedback.heavyImpact());
    final FastingSafetyVerdict verdict = await _service.checkSafety(_targetHours);
    if (!verdict.isSafe) {
      if (!mounted) return;
      final AppLocalizations l10n = context.l10n;
      final int? alternative = verdict.recommendedAlternativeHours;
      final bool? proceed = await showDialog<bool>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          title: Text(verdict.warningTitle ?? l10n.fastSafetyTitle),
          content: Text(verdict.warningBody ?? ''),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l10n.commonCancel)),
            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l10n.fastSafetyContinue)),
            if (alternative != null)
              FilledButton(
                onPressed: () {
                  setState(() {
                    _protocolTouched = true;
                    _protocol = FastProtocol.custom;
                    _targetHours = alternative;
                  });
                  Navigator.of(ctx).pop(true);
                },
                child: Text(l10n.fastSafetyAdjust(alternative)),
              ),
          ],
        ),
      );
      if (proceed != true) return;
    }
    await _service.start(
      protocolName: _protocol.name(_targetHours),
      targetHours: _targetHours,
      startedAt: _customStart,
    );
    if (mounted) setState(() => _customStart = null);
  }

  Future<void> _finish(FastingSession session, double hours) async {
    unawaited(HapticFeedback.heavyImpact());
    final AppLocalizations l10n = context.l10n;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(l10n.fastFinishTitle),
        content: Text(
          hours >= 14 ? l10n.fastFinishBodyReward(hours.toStringAsFixed(1)) : l10n.fastFinishBody(hours.toStringAsFixed(1)),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l10n.fastKeepGoing)),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l10n.fastFinish)),
        ],
      ),
    );
    if (confirm != true) return;
    final FastFinishResult? result = await _service.finish(session.id);
    if (!mounted || result == null) return;
    if (result.coins > 0) {
      showUndoSnackBar(context, message: l10n.fastFinishedCoins(result.hours.toStringAsFixed(1), result.coins));
    }
    if (result.suggestsRefeedingGuide) {
      unawaited(FastBreakSheet.show(context, actualHours: result.hours));
    }
  }

  Future<void> _delete(FastingSession session) async {
    await _service.delete(session.id);
    if (!mounted) return;
    showUndoSnackBar(
      context,
      message: context.l10n.fastDeleted,
      onUndo: () => unawaited(_service.restore(session)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<FastingSession?> active = ref.watch(activeFastingSessionStreamProvider);
    final FastingSession? session = active.value;
    final DateTime now = ref.read(clockProvider).now();
    _syncWithPlan(ref.watch(activeProtocolProvider).value, now);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            TopBar(
              title: l10n.fastTitle,
              subtitle: l10n.fastSubtitle,
              subtitleBelowTitle: true,
              uppercaseSubtitle: false,
              leading: BackButton(
                color: c.text,
                onPressed: () => context.canPop() ? context.pop() : context.go('/comer'),
              ),
            ),
            Expanded(
              child: active.isLoading && session == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.only(bottom: ScSpace.xxl * 3),
                      children: <Widget>[
                        if (session != null)
                          ActiveFastCard(
                            session: session,
                            onAdjustStart: () => _adjustStart(session),
                            onFinish: (double hours) => _finish(session, hours),
                          )
                        else
                          FastSetupCard(
                            protocol: _protocol,
                            targetHours: _targetHours,
                            hasCustomStart: _customStart != null,
                            startLabel: _customStart == null ? null : fastClockLabel(_customStart!, now, l10n),
                            onProtocol: _selectProtocol,
                            onCustomHours: (int h) => setState(() {
                              _protocolTouched = true;
                              _targetHours = h;
                            }),
                            onStartNow: () => setState(() => _customStart = null),
                            onPickStart: () async {
                              final DateTime? picked = await _pickDateTime(_customStart ?? now);
                              if (picked != null && mounted) setState(() => _customStart = picked);
                            },
                            onStart: _start,
                          ),
                        SectionHead(title: l10n.fastPhasesTitle, subtitle: l10n.fastPhasesSubtitle),
                        PhaseTimeline(
                          elapsedHours: session == null ? null : now.difference(session.startedAt).inMinutes / 60.0,
                        ),
                        FastHistory(onDelete: _delete),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
