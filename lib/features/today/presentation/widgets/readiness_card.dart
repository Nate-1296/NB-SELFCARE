import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/services/readiness_engine.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_tokens.dart';
import '../../../../shared/utils/date_formats.dart';
import '../../../../shared/utils/number_formats.dart';
import '../../../../shared/widgets/card_header.dart';
import '../../../../shared/widgets/health_card.dart';
import '../../../../shared/widgets/progress_bar.dart';
import '../../../../shared/widgets/progress_ring.dart';
import '../../../../shared/widgets/quick_action_button.dart';
import '../../../journal/application/caffeine_queries.dart';
import '../../../journal/presentation/widgets/caffeine_tracker_sheet.dart';
import '../../application/readiness_queries.dart';

/// Disposición del día (sueño, FC en reposo y carga reciente) y franja de cafeína.
///
/// Solo muestra una puntuación cuando hay sueño registrado para esa noche.
class ReadinessCard extends ConsumerWidget {
  const ReadinessCard({super.key, required this.dateKey, required this.onLogSleep});

  final String dateKey;
  final VoidCallback onLogSleep;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DailyReadinessResult? readiness = ref.watch(readinessProvider(dateKey)).value;
    return HealthCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (readiness == null)
            _NoSleepYet(onLogSleep: onLogSleep)
          else
            _ReadinessSummary(readiness),
          const SizedBox(height: ScSpace.l),
          _CaffeineStrip(dateKey: dateKey),
        ],
      ),
    );
  }
}

extension ReadinessCategoryL10n on ReadinessCategory {
  String label(AppLocalizations l10n) => switch (this) {
    ReadinessCategory.optimal => l10n.readinessOptimal,
    ReadinessCategory.favorable => l10n.readinessFavorable,
    ReadinessCategory.recoveryNeeded => l10n.readinessRecovery,
  };

  String advice(AppLocalizations l10n) => switch (this) {
    ReadinessCategory.optimal => l10n.readinessAdviceOptimal,
    ReadinessCategory.favorable => l10n.readinessAdviceFavorable,
    ReadinessCategory.recoveryNeeded => l10n.readinessAdviceRecovery,
  };
}

class _ReadinessSummary extends StatelessWidget {
  const _ReadinessSummary(this.readiness);

  final DailyReadinessResult readiness;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final Color tone = switch (readiness.category) {
      ReadinessCategory.optimal => c.success,
      ReadinessCategory.favorable => c.accent,
      ReadinessCategory.recoveryNeeded => c.warning,
    };
    return Semantics(
      container: true,
      label: l10n.readinessSemantics(readiness.totalScore, readiness.category.label(l10n)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              ExcludeSemantics(
                child: ScProgressRing(
                  value: readiness.totalScore / 100,
                  size: 84,
                  stroke: 8,
                  color: tone,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('${readiness.totalScore}', style: context.type.metricM),
                  ),
                ),
              ),
              const SizedBox(width: ScSpace.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(l10n.todayDisposicionEnergia.toUpperCase(), style: context.type.overline),
                    const SizedBox(height: ScSpace.xs),
                    Text(
                      readiness.category.label(l10n),
                      style: context.text.headlineSmall?.copyWith(color: c.isFlat ? c.text : tone),
                    ),
                    const SizedBox(height: ScSpace.xs),
                    Text(
                      readiness.category.advice(l10n),
                      style: context.type.caption.copyWith(color: c.text),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: ScSpace.l),
          ExcludeSemantics(
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _SubScore(
                    label: l10n.readinessSleepLabel,
                    value: readiness.sleepSubScore,
                    max: 40,
                    tone: c.fasting,
                  ),
                ),
                const SizedBox(width: ScSpace.m),
                Expanded(
                  child: _SubScore(
                    label: l10n.readinessPulseLabel,
                    value: readiness.rhrSubScore,
                    max: 35,
                    tone: c.calories,
                  ),
                ),
                const SizedBox(width: ScSpace.m),
                Expanded(
                  child: _SubScore(
                    label: l10n.readinessLoadLabel,
                    value: readiness.strainSubScore,
                    max: 25,
                    tone: c.steps,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Componente de la puntuación (sueño, pulso, carga) con su barra.
class _SubScore extends StatelessWidget {
  const _SubScore({
    required this.label,
    required this.value,
    required this.max,
    required this.tone,
  });

  final String label;
  final double value;
  final double max;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.type.caption,
              ),
            ),
            Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: '${value.round()}',
                    style: context.type.metricS.copyWith(fontSize: 13.5),
                  ),
                  TextSpan(
                    text: '/${max.round()}',
                    style: context.type.caption.copyWith(fontSize: 11, color: c.text3),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ScProgressBar(value: value / max, color: tone, height: 4),
      ],
    );
  }
}

class _NoSleepYet extends StatelessWidget {
  const _NoSleepYet({required this.onLogSleep});

  final VoidCallback onLogSleep;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        CardHeader(
          title: l10n.todayDisposicionEnergia,
          subtitle: l10n.readinessNoSleep,
          icon: Icons.bedtime_outlined,
          tone: c.fasting,
        ),
        const SizedBox(height: ScSpace.m),
        QuickActionButton(
          label: l10n.readinessLogSleep,
          icon: Icons.bedtime_outlined,
          tone: c.fasting,
          onPressed: onLogSleep,
        ),
      ],
    );
  }
}

class _CaffeineStrip extends ConsumerWidget {
  const _CaffeineStrip({required this.dateKey});

  final String dateKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final CaffeineDay? day = ref.watch(caffeineDayProvider(dateKey)).value;
    if (day == null) return const SizedBox.shrink();

    final String cutoff = DateFormats.time(day.status.recommendedCutoffTime, l10n.localeName);
    final String text = day.logs.isEmpty
        ? l10n.caffeineNoneToday(cutoff)
        : l10n.todayCafeinaActivaMgAlDormir(
            NumberFormats.fixed(day.status.currentResidualMg, 0),
            NumberFormats.fixed(day.status.bedtimeResidualMg, 0),
          );

    return Column(
      children: <Widget>[
        Divider(height: 1, color: c.isFlat ? c.line2 : c.line),
        InkWell(
          borderRadius: BorderRadius.circular(ScRadius.controlOf(c)),
          onTap: () {
            unawaited(HapticFeedback.selectionClick());
            unawaited(CaffeineTrackerSheet.show(context, dateKey: dateKey));
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.only(top: ScSpace.m - 2),
              child: Row(
                children: <Widget>[
                  Icon(Icons.coffee_rounded, size: 18, color: c.isFlat ? c.text : c.carbs),
                  const SizedBox(width: ScSpace.s + 2),
                  Expanded(
                    child: Text(text, style: context.type.caption.copyWith(color: c.text)),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 20, color: c.text3),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
