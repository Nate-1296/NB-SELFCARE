import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/body_measurements_dao.dart';
import '../../../../core/database/daos/food_dao.dart';
import '../../../../core/database/daos/health_sync_dao.dart';
import '../../../../core/database/daos/pet_dao.dart';
import '../../../../core/database/daos/user_profile_dao.dart';
import '../../../../core/database/daos/workout_dao.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/utils/date_time_extensions.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/sheet.dart';

/// Modal para la ceremonia dominical de reflexión semanal y calibración con Nibi.
class SundayCheckInSheet extends ConsumerStatefulWidget {
  const SundayCheckInSheet({super.key});

  static Future<void> show(BuildContext context) {
    return mostrarHojaMenu<void>(
      context,
      builder: (_) => const SundayCheckInSheet(),
    );
  }

  @override
  ConsumerState<SundayCheckInSheet> createState() => _SundayCheckInSheetState();
}

class _SundayCheckInSheetState extends ConsumerState<SundayCheckInSheet> {
  int _energyRating = 4; // 1 a 5
  int _satietyRating = 3; // 1 a 5
  int _adherenceRating = 4; // 1 a 5
  bool _isCompleted = false;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final UserProfile? profile = ref.watch(userProfileStreamProvider).value;
    final DateTime now = DateTime.now();
    final String todayKey = now.dateKey;

    final FoodDao foodDao = ref.watch(foodDaoProvider);
    final WorkoutDao workoutDao = ref.watch(workoutDaoProvider);
    final HealthSyncDao healthDao = ref.watch(healthSyncDaoProvider);
    final BodyMeasurementsDao bodyDao = ref.watch(bodyMeasurementsDaoProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Encabezado Ceremonial
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: c.isFlat ? c.line2 : c.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: c.accent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Check-In Dominical con Nibi',
                        style: TextStyle(
                          fontFamily: ScFonts.display,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: c.text,
                        ),
                      ),
                      Text(
                        '60 segundos para revisar la semana y sincronizar',
                        style: TextStyle(
                          fontFamily: ScFonts.ui,
                          fontSize: 12,
                          color: c.text2,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(AppIcons.close, color: c.text3),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 1. Resumen Fisiológico de los últimos 7 días
            FutureBuilder<Map<String, dynamic>>(
              future: _computeWeeklyStats(foodDao, workoutDao, healthDao, bodyDao, profile),
              builder: (BuildContext context, AsyncSnapshot<Map<String, dynamic>> snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final Map<String, dynamic> stats = snap.data ?? <String, dynamic>{};
                final int avgKcal = (stats['avgKcal'] as num?)?.toInt() ?? 0;
                final int workoutsCount = (stats['workoutsCount'] as num?)?.toInt() ?? 0;
                final double avgSleep = (stats['avgSleep'] as num?)?.toDouble() ?? 0.0;
                final double weightDelta = (stats['weightDelta'] as num?)?.toDouble() ?? 0.0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: c.bg3,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: c.isFlat ? c.line2 : c.line,
                          width: c.isFlat ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'PULSO DE LOS ÚLTIMOS 7 DÍAS',
                            style: TextStyle(
                              fontFamily: ScFonts.ui,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.7,
                              color: c.accent,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: <Widget>[
                              _statCell(c, 'Ingesta media', '$avgKcal kcal/d'),
                              const SizedBox(width: 8),
                              _statCell(c, 'Entrenamientos', '$workoutsCount sesiones'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: <Widget>[
                              _statCell(c, 'Sueño promedio', '${avgSleep.toStringAsFixed(1)} h/noche'),
                              const SizedBox(width: 8),
                              _statCell(
                                c,
                                'Delta de peso',
                                '${weightDelta >= 0 ? "+" : ""}${weightDelta.toStringAsFixed(2)} kg',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 18),

            // 2. Reflexión Subjetiva (Energía, Hambre, Adherencia)
            Text(
              '¿Cómo te sentiste esta semana?',
              style: TextStyle(
                fontFamily: ScFonts.display,
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: c.text,
              ),
            ),
            const SizedBox(height: 10),

            _buildRatingRow(
              c: c,
              label: 'Nivel de energía y vitalidad',
              value: _energyRating,
              minLabel: 'Fatiga',
              maxLabel: 'Óptima',
              onChanged: (val) => setState(() => _energyRating = val),
            ),
            const SizedBox(height: 12),

            _buildRatingRow(
              c: c,
              label: 'Saciedad / Control de apetito',
              value: _satietyRating,
              minLabel: 'Hambre alta',
              maxLabel: 'Saciado',
              onChanged: (val) => setState(() => _satietyRating = val),
            ),
            const SizedBox(height: 12),

            _buildRatingRow(
              c: c,
              label: 'Adherencia al plan nutricional',
              value: _adherenceRating,
              minLabel: 'Complicada',
              maxLabel: 'Impecable',
              onChanged: (val) => setState(() => _adherenceRating = val),
            ),

            const SizedBox(height: 18),

            // 3. Recomendación Adaptativa de Nibi
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.isFlat ? c.bg : (c.isFlat ? c.bg3 : c.soft),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: c.isFlat ? c.line2 : c.accent.withValues(alpha: 0.3),
                  width: c.isFlat ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    '🐾',
                    style: TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Consejo Estratégico de Nibi',
                          style: TextStyle(
                            fontFamily: ScFonts.display,
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: c.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getNibiAdvice(),
                          style: TextStyle(
                            fontFamily: ScFonts.ui,
                            fontSize: 12,
                            height: 1.35,
                            color: c.text2,
                          ),
                          softWrap: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // 4. Botón de Confirmación y Recompensa (+15 monedas)
            FilledButton.icon(
              onPressed: _isCompleted
                  ? null
                  : () async {
                      unawaited(HapticFeedback.mediumImpact());
                      await ref.read(petDaoProvider).grantDailyReward(
                            dateKey: todayKey,
                            actionType: 'sunday_checkin',
                            baseAmount: 15,
                          );
                      setState(() => _isCompleted = true);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('¡Ceremonia dominical completada! 🎉 +15 monedas Nibi sumadas'),
                          ),
                        );
                        await Future<void>.delayed(const Duration(milliseconds: 600));
                        if (context.mounted) Navigator.of(context).pop();
                      }
                    },
              icon: Icon(_isCompleted ? Icons.check_circle_rounded : Icons.star_rounded, size: 20),
              label: Text(
                _isCompleted ? '¡Completado con Éxito!' : 'Cerrar Semana con Nibi (+15 Monedas)',
                style: const TextStyle(
                  fontFamily: ScFonts.display,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: c.isFlat ? c.bg3 : c.accent,
                foregroundColor: c.isFlat ? c.text : c.ink,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: c.isFlat ? c.line2 : Colors.transparent,
                    width: c.isFlat ? 1.5 : 0.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCell(ScColors c, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: c.isFlat ? c.line2 : c.line,
            width: c.isFlat ? 1.2 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                fontFamily: ScFonts.ui,
                fontSize: 10.5,
                color: c.text3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontFamily: ScFonts.display,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: c.text,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingRow({
    required ScColors c,
    required String label,
    required int value,
    required String minLabel,
    required String maxLabel,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.bg3,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: c.isFlat ? c.line2 : c.line,
          width: c.isFlat ? 1.3 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  fontFamily: ScFonts.ui,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
              ),
              Text(
                '$value / 5',
                style: TextStyle(
                  fontFamily: ScFonts.display,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: c.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (int i) {
              final int starVal = i + 1;
              final bool isSelected = starVal <= value;
              return InkWell(
                onTap: () {
                  unawaited(HapticFeedback.selectionClick());
                  onChanged(starVal);
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    isSelected ? Icons.circle_rounded : Icons.radio_button_unchecked_rounded,
                    size: 20,
                    color: isSelected ? c.accent : c.text3,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(minLabel, style: TextStyle(fontFamily: ScFonts.ui, fontSize: 10, color: c.text3)),
              Text(maxLabel, style: TextStyle(fontFamily: ScFonts.ui, fontSize: 10, color: c.text3)),
            ],
          ),
        ],
      ),
    );
  }

  String _getNibiAdvice() {
    if (_energyRating <= 2 && _satietyRating <= 2) {
      return 'Fatiga acumulada detectada. Nibi te sugiere planear 1 o 2 días de mantenimiento calórico (Diet Break o Refeed) para reponer reservas de glucógeno y normalizar la leptina sin comprometer tu progreso.';
    }
    if (_adherenceRating >= 4 && _energyRating >= 4) {
      return '¡Semana brillante! El balance metabólico es excelente y tu adherencia es sólida. Mantén este mismo ritmo la próxima semana sin modificar tus variables.';
    }
    if (_adherenceRating <= 2) {
      return 'Semana desafiante en adherencia. Recuerda que la constancia vence a la perfección: utiliza el Calorie Cycling o flexibiliza la ventana de comidas para adaptarlo a tus compromisos reales.';
    }
    return 'Buen ritmo general. Prioriza un descanso profundo esta noche y una buena hidratación para empezar la semana con alta disponibilidad neuromotora.';
  }

  Future<Map<String, dynamic>> _computeWeeklyStats(
    FoodDao foodDao,
    WorkoutDao workoutDao,
    HealthSyncDao healthDao,
    BodyMeasurementsDao bodyDao,
    UserProfile? profile,
  ) async {
    final DateTime now = DateTime.now();
    double totalKcal = 0;
    int daysWithFood = 0;
    int totalWorkouts = 0;
    double totalSleepHours = 0;
    int daysWithSleep = 0;

    for (int i = 0; i < 7; i++) {
      final DateTime day = now.subtract(Duration(days: i));
      final String key = day.dateKey;

      final List<FoodLog> foods = await foodDao.getLogsForDate(key);
      if (foods.isNotEmpty) {
        final double kcal = foods.fold<double>(0, (double sum, FoodLog f) => sum + f.totalKcal);
        totalKcal += kcal;
        daysWithFood++;
      }

      final List<WorkoutBlock> workouts = await workoutDao.getWorkoutsForDate(key);
      totalWorkouts += workouts.length;

      final DailySummary? summary = await healthDao.getSummaryForDate(key);
      if (summary != null && summary.sleepDurationMinutes > 0) {
        totalSleepHours += summary.sleepDurationMinutes / 60.0;
        daysWithSleep++;
      }
    }

    final List<BodyMeasurement> recent = await bodyDao.getRecentMeasurements(limit: 7);
    double weightDelta = 0.0;
    if (recent.length >= 2) {
      weightDelta = recent.first.trendWeightKg - recent.last.trendWeightKg;
    }

    return <String, dynamic>{
      'avgKcal': daysWithFood > 0 ? (totalKcal / daysWithFood).round() : 0,
      'workoutsCount': totalWorkouts,
      'avgSleep': daysWithSleep > 0 ? totalSleepHours / daysWithSleep : 0.0,
      'weightDelta': weightDelta,
    };
  }
}
