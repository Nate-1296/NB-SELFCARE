import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/clock/clock.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/utils/date_time_extensions.dart';
import '../../../../shared/utils/number_formats.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/sheet.dart';
import '../../../pet_gamification/application/reward_service.dart';
import '../../../pet_gamification/domain/reward_policy.dart';
import '../../application/weekly_review.dart';

/// Modal para la ceremonia dominical de reflexión semanal y calibración con Nibi.
class SundayCheckInSheet extends ConsumerStatefulWidget {
  const SundayCheckInSheet({super.key});

  static Future<void> show(BuildContext context) {
    return mostrarHojaMenu<void>(context, builder: (_) => const SundayCheckInSheet());
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
    final DateTime now = ref.read(clockProvider).now();
    final String todayKey = now.dateKey;

    final AsyncValue<WeeklyReview> review = ref.watch(weeklyReviewProvider(todayKey));

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
                    color: c.isFlat ? c.bg3 : c.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.auto_awesome_rounded, color: c.accent, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        context.l10n.todayCheckInDominicalConNibi,
                        style: TextStyle(
                          fontFamily: ScFonts.display,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: c.text,
                        ),
                      ),
                      Text(
                        context.l10n.today60SegundosParaRevisarLa,
                        style: TextStyle(fontFamily: ScFonts.ui, fontSize: 12, color: c.text2),
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
            if (review.value case final WeeklyReview stats)
              Builder(
                builder: (BuildContext context) {
                  final int avgKcal = stats.averageKcal;
                  final int workoutsCount = stats.workoutCount;
                  final double avgSleep = stats.averageSleepHours;
                  final double weightDelta = stats.trendWeightDeltaKg ?? 0;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: c.bg3,
                          borderRadius: BorderRadius.circular(16),
                          border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              context.l10n.todayPulsoDeLosUltimos7,
                              style: TextStyle(
                                fontFamily: ScFonts.ui,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.7,
                                color: c.accent,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: <Widget>[
                                _statCell(
                                  c,
                                  context.l10n.todayIngestaMedia,
                                  context.l10n.todayKcalD(NumberFormats.group(avgKcal)),
                                ),
                                const SizedBox(width: 8),
                                _statCell(
                                  c,
                                  context.l10n.todayEntrenamientos,
                                  context.l10n.todaySesiones((workoutsCount).toString()),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: <Widget>[
                                _statCell(
                                  c,
                                  context.l10n.todaySuenoPromedio,
                                  context.l10n.todayHNoche(NumberFormats.fixed(avgSleep, 1)),
                                ),
                                const SizedBox(width: 8),
                                _statCell(
                                  c,
                                  context.l10n.todayDeltaDePeso,
                                  context.l10n.todayKg(
                                    (weightDelta >= 0 ? '+' : '').toString(),
                                    NumberFormats.fixed(weightDelta, 2),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              )
            else
              const Center(
                child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()),
              ),

            const SizedBox(height: 18),

            // 2. Reflexión Subjetiva (Energía, Hambre, Adherencia)
            Text(
              context.l10n.todayComoTeSentisteEstaSemana,
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
              label: context.l10n.todayNivelDeEnergiaYVitalidad,
              value: _energyRating,
              minLabel: context.l10n.todayFatiga,
              maxLabel: context.l10n.todayOptima,
              onChanged: (val) => setState(() => _energyRating = val),
            ),
            const SizedBox(height: 12),

            _buildRatingRow(
              c: c,
              label: context.l10n.todaySaciedadControlDeApetito,
              value: _satietyRating,
              minLabel: context.l10n.todayHambreAlta,
              maxLabel: context.l10n.todaySaciado,
              onChanged: (val) => setState(() => _satietyRating = val),
            ),
            const SizedBox(height: 12),

            _buildRatingRow(
              c: c,
              label: context.l10n.todayAdherenciaAlPlanNutricional,
              value: _adherenceRating,
              minLabel: context.l10n.todayComplicada,
              maxLabel: context.l10n.todayImpecable,
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
                  const Text('🐾', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          context.l10n.todayConsejoEstrategicoDeNibi,
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
                      final RewardGrant grant = await ref
                          .read(rewardServiceProvider)
                          .grant(RewardAction.sundayCheckIn, dateKey: todayKey);
                      setState(() => _isCompleted = true);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              grant.granted
                                  ? context.l10n.todayCeremoniaDominicalCompletadaMonedas(
                                      grant.coins.toString(),
                                    )
                                  : context.l10n.todayCeremoniaDominicalCompletada,
                            ),
                          ),
                        );
                        await Future<void>.delayed(const Duration(milliseconds: 600));
                        if (context.mounted) Navigator.of(context).pop();
                      }
                    },
              icon: Icon(_isCompleted ? Icons.check_circle_rounded : Icons.star_rounded, size: 20),
              label: Text(
                _isCompleted
                    ? context.l10n.todayCompletadoConExito
                    : context.l10n.todayCerrarSemanaConNibi15,
                style: const TextStyle(
                  fontFamily: ScFonts.display,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
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
          border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(fontFamily: ScFonts.ui, fontSize: 10.5, color: c.text3),
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
        border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Flexible(child: Text(
                label,
                style: TextStyle(
                  fontFamily: ScFonts.ui,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
              )),
              Text(
                context.l10n.today5((value).toString()),
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
              Flexible(child: Text(
                minLabel,
                style: TextStyle(fontFamily: ScFonts.ui, fontSize: 10, color: c.text3),
              )),
              Text(
                maxLabel,
                style: TextStyle(fontFamily: ScFonts.ui, fontSize: 10, color: c.text3),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getNibiAdvice() {
    if (_energyRating <= 2 && _satietyRating <= 2) {
      return context.l10n.todayFatigaAcumuladaDetectadaNibiTe;
    }
    if (_adherenceRating >= 4 && _energyRating >= 4) {
      return context.l10n.todaySemanaBrillanteElBalanceMetabolico;
    }
    if (_adherenceRating <= 2) {
      return context.l10n.todaySemanaDesafianteEnAdherenciaRecuerda;
    }
    return context.l10n.todayBuenRitmoGeneralPriorizaUn;
  }
}
