import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/services/caffeine_pharmacokinetics_service.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/utils/date_formats.dart';
import '../../../../shared/utils/number_formats.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/science_on_demand_sheet.dart';
import '../../../../shared/widgets/sheet.dart';
import '../../../../shared/widgets/tonal_badge.dart';
import '../../../../shared/widgets/undo_snackbar.dart';
import '../../application/caffeine_queries.dart';

/// Modal interactivo de registro y curva de decaimiento de cafeína.
class CaffeineTrackerSheet extends ConsumerStatefulWidget {
  const CaffeineTrackerSheet({super.key, required this.dateKey});

  final String dateKey;

  static Future<void> show(BuildContext context, {required String dateKey}) {
    return mostrarHojaMenu<void>(context, builder: (_) => CaffeineTrackerSheet(dateKey: dateKey));
  }

  @override
  ConsumerState<CaffeineTrackerSheet> createState() => _CaffeineTrackerSheetState();
}

class _CaffeineTrackerSheetState extends ConsumerState<CaffeineTrackerSheet> {
  final TextEditingController _customNameCtrl = TextEditingController();
  final TextEditingController _customMgCtrl = TextEditingController();
  bool _isCustomMode = false;

  @override
  void dispose() {
    _customNameCtrl.dispose();
    _customMgCtrl.dispose();
    super.dispose();
  }

  Future<void> _logQuickDose({required String name, required double mg}) async {
    unawaited(HapticFeedback.lightImpact());
    await ref.read(caffeineServiceProvider).log(dateKey: widget.dateKey, sourceName: name, mg: mg);

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.journalMgDeCafeinaRegistrados((mg).toString(), (name).toString()),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _deleteDose(CaffeineLog log) async {
    unawaited(HapticFeedback.selectionClick());
    final CaffeineService service = ref.read(caffeineServiceProvider);
    await service.delete(log.id);
    if (!mounted) return;
    showUndoSnackBar(
      context,
      message: context.l10n.caffeineDeleted(log.sourceName),
      onUndo: () => unawaited(service.restore(log)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final CaffeineDay? day = ref.watch(caffeineDayProvider(widget.dateKey)).value;
    if (day == null) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final List<CaffeineLog> logs = day.logs;
    final CaffeineStatus status = day.status;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Builder(
        builder: (BuildContext context) {
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Encabezado
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: c.isFlat ? c.bg3 : c.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.coffee_rounded, color: c.accent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            context.l10n.journalCronobiologiaDeLaCafeina,
                            style: TextStyle(
                              fontFamily: ScFonts.display,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: c.text,
                            ),
                          ),
                          Text(
                            context.l10n.journalFarmacocineticaYProteccionDelSueno,
                            style: TextStyle(fontFamily: ScFonts.ui, fontSize: 12, color: c.text2),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(AppIcons.close, color: c.text2),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Tarjeta de Estado Farmacocinético
                Container(
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
                          Flexible(child: Text(
                            context.l10n.journalNivelActivoEnSangre,
                            style: TextStyle(
                              fontFamily: ScFonts.ui,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: c.text,
                            ),
                          )),
                          Text(
                            context.l10n.journalMg(
                              NumberFormats.fixed(status.currentResidualMg, 1),
                            ),
                            style: TextStyle(
                              fontFamily: ScFonts.display,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: c.accent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              context.l10n.journalProyeccionAlDormir2300,
                              style: TextStyle(fontFamily: ScFonts.ui, fontSize: 13, color: c.text2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: TonalBadge(
                              label: context.l10n.journalBedtimeResidual(
                                NumberFormats.fixed(status.bedtimeResidualMg, 0),
                                status.willDisruptSleep
                                    ? context.l10n.journalAlertaSueno
                                    : context.l10n.journalSleepSafe,
                              ),
                              tone: status.willDisruptSleep ? c.warning : c.accent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              context.l10n.journalHoraLimiteRecomendadaCurfew,
                              style: TextStyle(fontFamily: ScFonts.ui, fontSize: 13, color: c.text2),
                            ),
                          ),
                          Text(
                            DateFormats.time(status.recommendedCutoffTime, context.l10n.localeName),
                            style: TextStyle(
                              fontFamily: ScFonts.display,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: status.isCurfewPassed
                                  ? (c.isFlat ? c.text : c.warning)
                                  : (c.isFlat ? c.text : c.text),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Registro Rápido
                Text(
                  context.l10n.journalRegistrarIngesta,
                  style: TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _QuickCaffeineChip(
                      label: context.l10n.journalEspresso65mg,
                      onTap: () => _logQuickDose(name: context.l10n.journalEspresso, mg: 65),
                    ),
                    _QuickCaffeineChip(
                      label: context.l10n.journalCafeFiltro100mg,
                      onTap: () => _logQuickDose(name: context.l10n.journalCafeFiltro, mg: 100),
                    ),
                    _QuickCaffeineChip(
                      label: context.l10n.journalDobleAmericano130mg,
                      onTap: () =>
                          _logQuickDose(name: context.l10n.journalCafeAmericanoDoble, mg: 130),
                    ),
                    _QuickCaffeineChip(
                      label: context.l10n.journalTeVerdeNegro45mg,
                      onTap: () => _logQuickDose(name: context.l10n.journalTe, mg: 45),
                    ),
                    _QuickCaffeineChip(
                      label: context.l10n.journalBebidaEnergetica80mg,
                      onTap: () =>
                          _logQuickDose(name: context.l10n.journalBebidaEnergetica, mg: 80),
                    ),
                    ActionChip(
                      label: Text(
                        _isCustomMode
                            ? context.l10n.commonClose
                            : context.l10n.journalPersonalizado,
                      ),
                      onPressed: () {
                        setState(() => _isCustomMode = !_isCustomMode);
                      },
                    ),
                  ],
                ),

                if (_isCustomMode) ...<Widget>[
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _customNameCtrl,
                          decoration: InputDecoration(
                            labelText: context.l10n.journalBebidaOSuplemento,
                            hintText: context.l10n.journalEjMatchaLatte,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 90,
                        child: TextField(
                          controller: _customMgCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: context.l10n.journalMg3,
                            suffixText: 'mg',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        icon: const Icon(Icons.check),
                        onPressed: () {
                          final String name = _customNameCtrl.text.trim();
                          final double? mg = double.tryParse(_customMgCtrl.text.trim().replaceAll(',', '.'));
                          if (name.isNotEmpty && mg != null && mg > 0) {
                            unawaited(_logQuickDose(name: name, mg: mg));
                            _customNameCtrl.clear();
                            _customMgCtrl.clear();
                            setState(() => _isCustomMode = false);
                          }
                        },
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),

                // Lista de tomas de hoy
                Text(
                  context.l10n.journalTomasDeHoy(logs.length.toString()),
                  style: TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 8),
                if (logs.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    alignment: Alignment.center,
                    child: Text(
                      context.l10n.journalNoHayTomasRegistradasHoy,
                      style: TextStyle(fontFamily: ScFonts.ui, fontSize: 12.5, color: c.text2),
                    ),
                  )
                else
                  for (final CaffeineLog log in logs)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: c.bg3,
                        borderRadius: BorderRadius.circular(12),
                        border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.access_time_rounded, size: 16, color: c.text2),
                          const SizedBox(width: 6),
                          Text(
                            DateFormats.time(log.loggedAt, context.l10n.localeName),
                            style: TextStyle(
                              fontFamily: ScFonts.ui,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: c.text2,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              log.sourceName,
                              style: TextStyle(
                                fontFamily: ScFonts.ui,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: c.text,
                              ),
                            ),
                          ),
                          Text(
                            context.l10n.journalMg4(NumberFormats.fixed(log.caffeineMg, 0)),
                            style: TextStyle(
                              fontFamily: ScFonts.display,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: c.accent,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline_rounded, size: 18, color: c.text2),
                            onPressed: () => unawaited(_deleteDose(log)),
                          ),
                        ],
                      ),
                    ),

                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      unawaited(
                        ScienceOnDemandSheet.show(
                          context,
                          ScienceSpec.caffeineDecay(
                            halfLifeHours: CaffeinePharmacokineticsService.halfLifeHours,
                            bedtimeCurfewTime: DateFormats.time(
                              status.recommendedCutoffTime,
                              context.l10n.localeName,
                            ),
                            residualAtBedtimeMg: status.bedtimeResidualMg,
                          ),
                        ),
                      );
                    },
                    icon: Icon(Icons.science_rounded, size: 16, color: c.accent),
                    label: Text(
                      context.l10n.journalPorQueImportaLaCafeina,
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: c.accent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _QuickCaffeineChip extends StatelessWidget {
  const _QuickCaffeineChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.add, size: 16),
      label: Text(label),
      onPressed: onTap,
    );
  }
}
