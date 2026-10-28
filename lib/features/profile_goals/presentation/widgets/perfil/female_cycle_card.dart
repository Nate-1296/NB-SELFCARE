import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/clock/clock.dart';
import '../../../../../core/database/app_database.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_theme.dart';
import '../../../../../shared/widgets/card_header.dart';
import '../../../../../shared/widgets/health_card.dart';
import '../../../../../shared/widgets/science_on_demand_sheet.dart';
import '../../../../body_metrics/application/body_queries.dart';
import '../../../../body_metrics/application/cycle_service.dart';

/// Tarjeta de Salud Femenina y Seguimiento Hormonal (oculta 100% para hombres).
class FemaleCycleCard extends ConsumerWidget {
  const FemaleCycleCard({super.key, required this.profile});

  final UserProfile profile;

  void _showCycleScience(BuildContext context) {
    unawaited(
      ScienceOnDemandSheet.show(
        context,
        ScienceSpec(
          title: context.l10n.perfilCicloHormonalYGastoCalorico,
          badgeLabel: context.l10n.perfilProgesteronaFaseLuteaYRetencion,
          icon: Icons.female_rounded,
          quickTake: context.l10n.perfilDuranteLaFaseLuteaEntre,
          howItWorks: context.l10n.perfilEnLaFaseLuteaEl,
          formula: context.l10n.perfilGastoLuteoBmr100300,
          scientificReferences: <String>[
            context.l10n.perfilWebbP198624Hour,
            context.l10n.perfilBarrSIEtAl,
          ],
          actionableAdvice: context.l10n.perfilSiTuPesoSubeDurante,
        ),
      ),
    );
  }

  Future<void> _logNewPeriod(BuildContext context, WidgetRef ref) async {
    final DateTime now = ref.read(clockProvider).now();
    final DateTime? picked = await showDatePicker(
      context: context,
      confirmText: context.l10n.commonAccept,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 60)),
      lastDate: now,
      helpText: context.l10n.perfilSeleccionaLaFechaDeInicio,
    );
    if (picked != null) {
      await ref.read(cycleServiceProvider).logPeriodStart(picked);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.perfilInicioDeCicloRegistradoCon)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final AsyncValue<FemaleCycleLog?> cycleAsync = ref.watch(latestFemaleCycleStreamProvider);

    return HealthCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CardHeader(
            icon: Icons.female_rounded,
            tone: c.fat,
            title: context.l10n.perfilSaludFemeninaYCiclo,
            trailing: IconButton(
              icon: Icon(Icons.info_outline_rounded, size: 20, color: c.text2),
              tooltip: context.l10n.perfilCienciaDelCicloHormonal,
              onPressed: () => _showCycleScience(context),
            ),
          ),
          const SizedBox(height: 10),
          cycleAsync.when(
            data: (FemaleCycleLog? latest) {
              if (latest == null) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.bg3,
                    borderRadius: BorderRadius.circular(14),
                    border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        context.l10n.perfilRegistraElInicioDeTu,
                        style: TextStyle(
                          fontFamily: ScFonts.ui,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: c.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.l10n.perfilPermiteCalibrarElGastoMetabolico,
                        style: TextStyle(fontFamily: ScFonts.ui, fontSize: 11.5, color: c.text2),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          side: BorderSide(color: c.isFlat ? c.line2 : c.accent),
                        ),
                        onPressed: () => _logNewPeriod(context, ref),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: Text(context.l10n.perfilRegistrarInicioDePeriodo),
                      ),
                    ],
                  ),
                );
              }

              final DateTime today = ref.read(clockProvider).now();
              final int diffDays = today.difference(latest.cycleStartDate).inDays;
              final int cycleLength = latest.cycleLengthDays > 0 ? latest.cycleLengthDays : 28;
              final int currentCycleDay = (diffDays % cycleLength) + 1;

              String phaseName;
              String phaseDesc;
              bool isLuteal = false;

              if (currentCycleDay <= 5) {
                phaseName = context.l10n.perfilFaseMenstrual;
                phaseDesc = context.l10n.perfilDiasDeRenovacionPriorizaDescanso;
              } else if (currentCycleDay <= 13) {
                phaseName = context.l10n.perfilFaseFolicular;
                phaseDesc = context.l10n.perfilSensibilidadALaInsulinaOptima;
              } else if (currentCycleDay <= 16) {
                phaseName = context.l10n.perfilFaseDeOvulacion;
                phaseDesc = context.l10n.perfilPicoDeEstrogenosFuerzaY;
              } else {
                phaseName = context.l10n.perfilFaseLuteaPremenstrual;
                phaseDesc = context.l10n.perfilAumentoDeProgesteronaGastoBasal;
                isLuteal = true;
              }

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: c.isFlat
                                ? c.line2
                                : (isLuteal ? c.accent.withValues(alpha: 0.18) : c.soft),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            context.l10n.perfilDiaDe(
                              (phaseName).toString(),
                              (currentCycleDay).toString(),
                              (cycleLength).toString(),
                            ),
                            style: TextStyle(
                              fontFamily: ScFonts.display,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: c.isFlat ? c.text : c.accent,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _logNewPeriod(context, ref),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: Text(
                            context.l10n.perfilNuevoCiclo,
                            style: const TextStyle(fontSize: 11.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      phaseDesc,
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 12,
                        color: c.text2,
                        height: 1.3,
                      ),
                    ),
                    if (isLuteal) ...<Widget>[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: c.isFlat ? c.bg2 : c.accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: c.isFlat ? c.line2 : c.accent.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(Icons.local_fire_department_rounded, size: 16, color: c.calories),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                context.l10n.perfilAjusteMetabolicoActivo150Kcal,
                                style: TextStyle(
                                  fontFamily: ScFonts.ui,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: c.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
            loading: () => const Center(
              child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()),
            ),
            error: (Object e, _) => Text(
              context.l10n.perfilNoSePudoCargarEl((e).toString()),
              style: TextStyle(color: c.text3, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
