import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/services/readiness_engine.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/theme/sc_tokens.dart';
import '../../../../shared/utils/date_formats.dart';
import '../../../../shared/widgets/health_card.dart';
import '../../../../shared/widgets/tonal_badge.dart';
import '../../../journal/application/caffeine_queries.dart';
import '../../../journal/presentation/widgets/caffeine_tracker_sheet.dart';
import '../../application/readiness_queries.dart';

/// Disposición del día (sueño, FC en reposo y carga reciente) y franja de cafeína.
///
/// Solo muestra una puntuación cuando hay sueño registrado para esa noche.
class ReadinessCard extends ConsumerWidget {
  const ReadinessCard({
    super.key,
    required this.dateKey,
    required this.onLogSleep,
  });

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
          if (readiness == null) _NoSleepYet(onLogSleep: onLogSleep) else _ReadinessSummary(readiness),
          const SizedBox(height: ScSpace.m),
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
    return Semantics(
      container: true,
      label: l10n.readinessSemantics(readiness.totalScore, readiness.category.label(l10n)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              ExcludeSemantics(child: _ScoreBox(score: readiness.totalScore)),
              const SizedBox(width: ScSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: ScSpace.s,
                      runSpacing: ScSpace.xxs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(l10n.todayDisposicionEnergia, style: context.text.titleMedium),
                        TonalBadge(label: readiness.category.label(l10n)),
                      ],
                    ),
                    const SizedBox(height: ScSpace.xxs),
                    Text(
                      l10n.todaySuenoPFcReposoP(
                        readiness.sleepSubScore.round().toString(),
                        readiness.rhrSubScore.round().toString(),
                        readiness.strainSubScore.round().toString(),
                      ),
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: ScSpace.s + 2),
          Text(
            readiness.category.advice(l10n),
            style: TextStyle(fontFamily: ScFonts.ui, fontSize: 12.5, color: c.text, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _ScoreBox extends StatelessWidget {
  const _ScoreBox({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.isFlat ? c.bg3 : c.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(ScRadius.control),
        border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
      ),
      child: Text(
        '$score',
        style: TextStyle(
          fontFamily: ScFonts.display,
          fontSize: 19,
          fontWeight: FontWeight.w900,
          color: c.isFlat ? c.text : c.accent,
        ),
      ),
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
    return Row(
      children: <Widget>[
        Icon(Icons.bedtime_outlined, size: 22, color: c.isFlat ? c.text : c.fasting),
        const SizedBox(width: ScSpace.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l10n.todayDisposicionEnergia, style: context.text.titleMedium),
              Text(l10n.readinessNoSleep, style: context.text.bodySmall),
            ],
          ),
        ),
        const SizedBox(width: ScSpace.s),
        TextButton(onPressed: onLogSleep, child: Text(l10n.readinessLogSleep)),
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
            day.status.currentResidualMg.toStringAsFixed(0),
            day.status.bedtimeResidualMg.toStringAsFixed(0),
          );

    return Material(
      color: c.bg3,
      borderRadius: BorderRadius.circular(ScRadius.control),
      child: InkWell(
        borderRadius: BorderRadius.circular(ScRadius.control),
        onTap: () {
          unawaited(HapticFeedback.selectionClick());
          unawaited(CaffeineTrackerSheet.show(context, dateKey: dateKey));
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: ScSpace.m, vertical: ScSpace.s + 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ScRadius.control),
            border: Border.all(color: c.isFlat ? c.line2 : c.line, width: c.isFlat ? 1.5 : 1.0),
          ),
          child: Row(
            children: <Widget>[
              Icon(Icons.coffee_rounded, size: 18, color: c.isFlat ? c.text : c.accent),
              const SizedBox(width: ScSpace.s),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: c.text2),
            ],
          ),
        ),
      ),
    );
  }
}
