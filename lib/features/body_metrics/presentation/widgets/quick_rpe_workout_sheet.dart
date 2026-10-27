import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/health_card.dart';
import '../../../../shared/widgets/sheet.dart';
import '../../application/body_queries.dart';
import '../../application/workout_service.dart';

/// Hoja ultrarrápida (< 5 segundos) para registrar bloques de entrenamiento por RPE y METs.
abstract final class QuickRpeWorkoutSheet {
  static Future<void> show({
    required BuildContext context,
    required WidgetRef ref,
    required UserProfile profile,
  }) async {
    return mostrarHojaMenu<void>(
      context,
      builder: (_) => _QuickRpeWorkoutContent(profile: profile),
    );
  }
}

class _QuickRpeWorkoutContent extends ConsumerStatefulWidget {
  const _QuickRpeWorkoutContent({required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<_QuickRpeWorkoutContent> createState() =>
      _QuickRpeWorkoutContentState();
}

class _QuickRpeWorkoutContentState
    extends ConsumerState<_QuickRpeWorkoutContent> {
  WorkoutCategory _selectedCategory = WorkoutCategory.weights;
  RpeIntensity _selectedRpe = RpeIntensity.moderate;
  int _durationMinutes = 45;

  static const List<int> _presetDurations = <int>[20, 30, 45, 60, 90];

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final latestMeas = ref.watch(latestMeasurementStreamProvider).value;
    final double userWeight =
        latestMeas?.weightKg ?? widget.profile.targetWeightKg;
    final WorkoutEstimate estimate = WorkoutService.estimate(
      category: _selectedCategory,
      intensity: _selectedRpe,
      durationMinutes: _durationMinutes,
      weightKg: userWeight,
    );
    final double met = estimate.met;
    final int netKcal = estimate.netKcal;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: c.soft,
                  borderRadius: BorderRadius.circular(14),
                  border: c.isFlat
                      ? Border.all(color: c.line2, width: 1.5)
                      : null,
                ),
                child: Icon(AppIcons.pesa, color: c.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.bodyEntrenamientoEn5Segundos,
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 18.5,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                      ),
                      softWrap: true,
                    ),
                    Text(
                      context.l10n.bodyGastoNetoRealSinContar,
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 12.5,
                        color: c.text2,
                      ),
                      softWrap: true,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(AppIcons.close),
                tooltip: context.l10n.commonClose,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 1. Selector de Disciplina (Cuadrícula 2x2 para evitar truncamiento horizontal)
          Text(
            context.l10n.body1Disciplina,
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _DisciplineCard(
                  title: context.l10n.bodyPesasFuerza,
                  icon: AppIcons.pesa,
                  metRange: context.l10n.bodyMet3560,
                  isSelected: _selectedCategory == WorkoutCategory.weights,
                  onTap: () {
                    unawaited(HapticFeedback.selectionClick());
                    setState(() => _selectedCategory = WorkoutCategory.weights);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DisciplineCard(
                  title: context.l10n.bodyFuncional,
                  icon: Icons.sports_gymnastics_rounded,
                  metRange: context.l10n.bodyMet3880,
                  isSelected: _selectedCategory == WorkoutCategory.calisthenics,
                  onTap: () {
                    unawaited(HapticFeedback.selectionClick());
                    setState(
                        () => _selectedCategory = WorkoutCategory.calisthenics);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _DisciplineCard(
                  title: context.l10n.workoutCardio,
                  icon: Icons.directions_run_rounded,
                  metRange: context.l10n.bodyMet50105,
                  isSelected: _selectedCategory == WorkoutCategory.cardio,
                  onTap: () {
                    unawaited(HapticFeedback.selectionClick());
                    setState(() => _selectedCategory = WorkoutCategory.cardio);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DisciplineCard(
                  title: context.l10n.workoutSports,
                  icon: Icons.sports_soccer_rounded,
                  metRange: context.l10n.bodyMet4085,
                  isSelected: _selectedCategory == WorkoutCategory.sports,
                  onTap: () {
                    unawaited(HapticFeedback.selectionClick());
                    setState(() => _selectedCategory = WorkoutCategory.sports);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2. Duración Efectiva
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  context.l10n.body2DuracionEfectiva,
                  style: TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: c.soft,
                  borderRadius: BorderRadius.circular(999),
                  border: c.isFlat
                      ? Border.all(color: c.line2, width: 1.2)
                      : null,
                ),
                child: Text(
                  context.l10n.bodyMin((_durationMinutes).toString()),
                  style: TextStyle(
                    fontFamily: ScFonts.display,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: c.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presetDurations.map((mins) {
              final bool isSel = _durationMinutes == mins;
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  unawaited(HapticFeedback.selectionClick());
                  setState(() => _durationMinutes = mins);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSel ? c.accent : c.bg3,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSel && c.isFlat
                          ? c.text
                          : (c.isFlat ? c.line2 : c.line),
                      width: c.isFlat ? 1.5 : 1.0,
                    ),
                  ),
                  child: Text(
                    '${mins}m',
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: isSel ? c.ink : c.text,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          Slider(
            value: _durationMinutes.toDouble(),
            min: 10,
            max: 180,
            divisions: 34,
            label: context.l10n.bodyMin((_durationMinutes).toString()),
            onChanged: (val) =>
                setState(() => _durationMinutes = val.round()),
          ),
          const SizedBox(height: 4),

          // 3. Esfuerzo Percibido (RPE con descripciones fisiológicas)
          Text(
            context.l10n.body3EsfuerzoPercibidoRpe,
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _RpeCard(
                  label: context.l10n.bodyLigero,
                  sublabel: context.l10n.bodyRpe14,
                  cue: context.l10n.bodyConversacionFluida,
                  isSelected: _selectedRpe == RpeIntensity.light,
                  onTap: () {
                    unawaited(HapticFeedback.selectionClick());
                    setState(() => _selectedRpe = RpeIntensity.light);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RpeCard(
                  label: context.l10n.bodyStatusModerate,
                  sublabel: context.l10n.bodyRpe57,
                  cue: context.l10n.bodyFrasesCortas,
                  isSelected: _selectedRpe == RpeIntensity.moderate,
                  onTap: () {
                    unawaited(HapticFeedback.selectionClick());
                    setState(() => _selectedRpe = RpeIntensity.moderate);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RpeCard(
                  label: context.l10n.bodyIntenso,
                  sublabel: context.l10n.bodyRpe810,
                  cue: context.l10n.bodyLimiteMetabolico,
                  isSelected: _selectedRpe == RpeIntensity.intense,
                  onTap: () {
                    unawaited(HapticFeedback.selectionClick());
                    setState(() => _selectedRpe = RpeIntensity.intense);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Resumen de Gasto Neto (Zero Overflow Guarantee)
          HealthCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(14),
            backgroundColor: c.bg3,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.bodyGastoNetoEstimadoDescontandoReposo,
                        style: TextStyle(
                          fontFamily: ScFonts.ui,
                          fontSize: 12,
                          color: c.text2,
                        ),
                        softWrap: true,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        context.l10n.bodyKcalNetas(netKcal.toStringAsFixed(0).toString()),
                        style: TextStyle(
                          fontFamily: ScFonts.display,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: c.accent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: c.bg2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: c.isFlat ? c.line2 : c.line,
                      width: c.isFlat ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'INTENSIDAD',
                        style: TextStyle(
                          fontFamily: ScFonts.ui,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: c.text3,
                        ),
                      ),
                      Text(
                        context.l10n.bodyMet(met.toStringAsFixed(1).toString()),
                        style: TextStyle(
                          fontFamily: ScFonts.display,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: c.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          FilledButton.icon(
            onPressed: () async {
              unawaited(HapticFeedback.mediumImpact());
              final WorkoutLogResult result = await ref.read(workoutServiceProvider).log(
                    category: _selectedCategory,
                    intensity: _selectedRpe,
                    durationMinutes: _durationMinutes,
                  );

              if (context.mounted) {
                final String coins =
                    result.reward.granted ? context.l10n.bodyMonedas(result.reward.coins.toString()): '';
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.l10n.bodyBloqueRegistradoKcalNetas(result.netKcal.toString(), (coins).toString())),
                  ),
                );
              }
            },
            icon: const Icon(AppIcons.check, size: 18),
            label: Text(context.l10n.bodyRegistrarEn5Segundos),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ),
    );
  }
}

class _DisciplineCard extends StatelessWidget {
  const _DisciplineCard({
    required this.title,
    required this.icon,
    required this.metRange,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final String metRange;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? c.soft : c.bg3,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? c.accent
                : (c.isFlat ? c.line2 : c.line),
            width: isSelected || c.isFlat ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? c.accent : c.text2,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? c.text : c.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    metRange,
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 10,
                      color: c.text3,
                    ),
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RpeCard extends StatelessWidget {
  const _RpeCard({
    required this.label,
    required this.sublabel,
    required this.cue,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String sublabel;
  final String cue;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? c.soft : c.bg3,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? c.accent
                : (c.isFlat ? c.line2 : c.line),
            width: isSelected || c.isFlat ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: ScFonts.ui,
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? c.text : c.text,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: TextStyle(
                fontFamily: ScFonts.display,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: isSelected ? c.accent : c.text3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              cue,
              style: TextStyle(
                fontFamily: ScFonts.ui,
                fontSize: 9.5,
                color: c.text3,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
