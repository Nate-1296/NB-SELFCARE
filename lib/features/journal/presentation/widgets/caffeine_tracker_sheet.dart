import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/caffeine_dao.dart';
import '../../../../core/services/caffeine_pharmacokinetics_service.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/science_on_demand_sheet.dart';
import '../../../../shared/widgets/sheet.dart';

/// Modal interactivo de registro y curva de decaimiento de cafeína.
class CaffeineTrackerSheet extends ConsumerStatefulWidget {
  const CaffeineTrackerSheet({
    super.key,
    required this.dateKey,
  });

  final String dateKey;

  static Future<void> show(BuildContext context, {required String dateKey}) {
    return mostrarHojaMenu<void>(
      context,
      builder: (_) => CaffeineTrackerSheet(dateKey: dateKey),
    );
  }

  @override
  ConsumerState<CaffeineTrackerSheet> createState() =>
      _CaffeineTrackerSheetState();
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

  Future<void> _logQuickDose({
    required String name,
    required double mg,
  }) async {
    unawaited(HapticFeedback.lightImpact());
    await ref.read(caffeineDaoProvider).logCaffeine(
          dateKey: widget.dateKey,
          sourceName: name,
          caffeineMg: mg,
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('+$mg mg de cafeína registrados ($name)'),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _deleteDose(int id, String name) async {
    unawaited(HapticFeedback.selectionClick());
    await ref.read(caffeineDaoProvider).deleteLog(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Eliminado: $name'),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final CaffeineDao caffeineDao = ref.watch(caffeineDaoProvider);
    final CaffeinePharmacokineticsService service =
        ref.watch(caffeinePharmacokineticsServiceProvider);

    final DateTime now = DateTime.now();
    // Hora proyectada de acostarse hoy (23:00)
    final DateTime targetBedtime = DateTime(now.year, now.month, now.day, 23, 0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: StreamBuilder<List<CaffeineLog>>(
        stream: caffeineDao.watchLogsForDate(widget.dateKey),
        builder: (BuildContext context, AsyncSnapshot<List<CaffeineLog>> snapshot) {
          final List<CaffeineLog> logs = snapshot.data ?? const <CaffeineLog>[];
          final CaffeineStatus status = service.evaluateStatus(
            logs: logs,
            targetBedtime: targetBedtime,
            currentTime: now,
          );

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
                        color: c.isFlat ? c.line2 : c.accent.withValues(alpha: 0.15),
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
                            'Cronobiología de la Cafeína',
                            style: TextStyle(
                              fontFamily: ScFonts.display,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: c.text,
                            ),
                          ),
                          Text(
                            'Farmacocinética y protección del sueño profundo N3',
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
                    border: Border.all(
                      color: c.isFlat ? c.line2 : c.line,
                      width: c.isFlat ? 1.4 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(
                            'Nivel activo en sangre:',
                            style: TextStyle(
                              fontFamily: ScFonts.ui,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: c.text,
                            ),
                          ),
                          Text(
                            '${status.currentResidualMg.toStringAsFixed(1)} mg',
                            style: TextStyle(
                              fontFamily: ScFonts.display,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: c.accent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(
                            'Proyección al dormir (23:00):',
                            style: TextStyle(
                              fontFamily: ScFonts.ui,
                              fontSize: 13,
                              color: c.text2,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: status.willDisruptSleep
                                  ? (c.isFlat ? c.line2 : c.warning.withValues(alpha: 0.15))
                                  : (c.isFlat ? c.line2 : c.soft),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${status.bedtimeResidualMg.toStringAsFixed(1)} mg '
                              '(${status.willDisruptSleep ? 'Alerta Sueño' : 'Óptimo <25mg'})',
                              style: TextStyle(
                                fontFamily: ScFonts.ui,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: status.willDisruptSleep
                                    ? (c.isFlat ? c.text : c.warning)
                                    : (c.isFlat ? c.text : c.accent),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(
                            'Hora límite recomendada (Curfew):',
                            style: TextStyle(
                              fontFamily: ScFonts.ui,
                              fontSize: 13,
                              color: c.text2,
                            ),
                          ),
                          Text(
                            '${status.recommendedCutoffTime.hour.toString().padLeft(2, '0')}:${status.recommendedCutoffTime.minute.toString().padLeft(2, '0')}',
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
                  'Registrar Ingesta:',
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
                      label: 'Espresso (65mg)',
                      onTap: () => _logQuickDose(name: 'Espresso', mg: 65),
                    ),
                    _QuickCaffeineChip(
                      label: 'Café Filtro (100mg)',
                      onTap: () => _logQuickDose(name: 'Café Filtro', mg: 100),
                    ),
                    _QuickCaffeineChip(
                      label: 'Doble / Americano (130mg)',
                      onTap: () => _logQuickDose(name: 'Café Americano Doble', mg: 130),
                    ),
                    _QuickCaffeineChip(
                      label: 'Té Verde / Negro (45mg)',
                      onTap: () => _logQuickDose(name: 'Té', mg: 45),
                    ),
                    _QuickCaffeineChip(
                      label: 'Bebida Energética (80mg)',
                      onTap: () => _logQuickDose(name: 'Bebida Energética', mg: 80),
                    ),
                    ActionChip(
                      label: Text(_isCustomMode ? 'Cerrar' : '+ Personalizado'),
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
                          decoration: const InputDecoration(
                            labelText: 'Bebida o suplemento',
                            hintText: 'Ej. Matcha latte',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 90,
                        child: TextField(
                          controller: _customMgCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Mg',
                            suffixText: 'mg',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        icon: const Icon(Icons.check),
                        onPressed: () {
                          final String name = _customNameCtrl.text.trim();
                          final double? mg = double.tryParse(_customMgCtrl.text.trim());
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
                  'Tomas de hoy (${logs.length}):',
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
                      'No hay tomas registradas hoy. Tu sistema está libre de cafeína.',
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 12.5,
                        color: c.text2,
                      ),
                    ),
                  )
                else
                  for (final CaffeineLog log in logs)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: c.bg3,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: c.isFlat ? c.line2 : c.line,
                          width: c.isFlat ? 1.3 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.access_time_rounded, size: 16, color: c.text2),
                          const SizedBox(width: 6),
                          Text(
                            '${log.loggedAt.hour.toString().padLeft(2, '0')}:${log.loggedAt.minute.toString().padLeft(2, '0')}',
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
                            '${log.caffeineMg.toStringAsFixed(0)} mg',
                            style: TextStyle(
                              fontFamily: ScFonts.display,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: c.accent,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline_rounded, size: 18, color: c.text2),
                            onPressed: () => unawaited(_deleteDose(log.id, log.sourceName)),
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
                            halfLifeHours:
                                CaffeinePharmacokineticsService.halfLifeHours,
                            bedtimeCurfewTime:
                                '${status.recommendedCutoffTime.hour.toString().padLeft(2, '0')}:${status.recommendedCutoffTime.minute.toString().padLeft(2, '0')}',
                            residualAtBedtimeMg: status.bedtimeResidualMg,
                          ),
                        ),
                      );
                    },
                    icon: Icon(Icons.science_rounded, size: 16, color: c.accent),
                    label: Text(
                      '¿Por qué importa la cafeína para el sueño profundo?',
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
