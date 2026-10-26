import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/caffeine_dao.dart';
import '../../../../core/database/daos/user_profile_dao.dart';
import '../../../../core/services/caffeine_pharmacokinetics_service.dart';
import '../../../../core/services/readiness_engine.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/widgets/health_card.dart';
import '../../../journal/presentation/widgets/caffeine_tracker_sheet.dart';

/// Tarjeta de Recuperación y Disposición Diaria (Readiness Score) en Hoy.
class ReadinessCard extends ConsumerWidget {
  const ReadinessCard({
    super.key,
    required this.dateKey,
  });

  final String dateKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final ReadinessEngine engine = ref.watch(readinessEngineProvider);
    final UserProfile? profile = ref.watch(userProfileStreamProvider).value;
    final CaffeineDao caffeineDao = ref.watch(caffeineDaoProvider);
    final CaffeinePharmacokineticsService caffeineService =
        ref.watch(caffeinePharmacokineticsServiceProvider);

    final double actualSleepHours = profile?.dailySleepGoalHours ?? 7.5;
    final double targetSleepHours = profile?.dailySleepGoalHours ?? 8.0;

    // Calcular readiness score
    final DailyReadinessResult readiness = engine.compute(
      actualSleepHours: actualSleepHours,
      targetSleepHours: targetSleepHours,
      currentRhrBpm: 60,
      baselineRhrBpm: 60,
      recent3DayWorkoutHours: 1.5,
      averageRecentRpe: 7.0,
    );

    final DateTime now = DateTime.now();
    final DateTime targetBedtime = DateTime(now.year, now.month, now.day, 23, 0);

    return HealthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Fila superior: Título e Indicador de Score
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.isFlat ? c.line2 : c.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
                ),
                child: Center(
                  child: Text(
                    '${readiness.totalScore}',
                    style: TextStyle(
                      fontFamily: ScFonts.display,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: c.accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          'Disposición & Energía',
                          style: TextStyle(
                            fontFamily: ScFonts.display,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: c.text,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: c.isFlat ? c.line2 : c.soft,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            readiness.categoryLabel.toUpperCase(),
                            style: TextStyle(
                              fontFamily: ScFonts.display,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: c.accent,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Sueño (${readiness.sleepSubScore.round()}p) · FC Reposo (${readiness.rhrSubScore.round()}p) · Carga (${readiness.strainSubScore.round()}p)',
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 11,
                        color: c.text2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Consejo de acción adaptativa
          Text(
            readiness.actionableAdvice,
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 12.5,
              color: c.text,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),

          // Franja de Cronobiología de Cafeína
          StreamBuilder<List<CaffeineLog>>(
            stream: caffeineDao.watchLogsForDate(dateKey),
            builder: (BuildContext context, AsyncSnapshot<List<CaffeineLog>> snap) {
              final List<CaffeineLog> cLogs = snap.data ?? const <CaffeineLog>[];
              final CaffeineStatus cStatus = caffeineService.evaluateStatus(
                logs: cLogs,
                targetBedtime: targetBedtime,
                currentTime: now,
              );

              return Material(
                color: c.bg3,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    unawaited(HapticFeedback.selectionClick());
                    unawaited(CaffeineTrackerSheet.show(context, dateKey: dateKey));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: c.isFlat ? c.line2 : c.line,
                        width: c.isFlat ? 1.3 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.coffee_rounded, size: 18, color: c.accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            cLogs.isEmpty
                                ? 'Sin cafeína hoy · Límite para dormir: ${cStatus.recommendedCutoffTime.hour.toString().padLeft(2, '0')}:${cStatus.recommendedCutoffTime.minute.toString().padLeft(2, '0')}'
                                : 'Cafeína activa: ${cStatus.currentResidualMg.toStringAsFixed(0)} mg · Al dormir: ${cStatus.bedtimeResidualMg.toStringAsFixed(0)} mg',
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
            },
          ),
        ],
      ),
    );
  }
}

