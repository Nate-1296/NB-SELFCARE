import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/sheet.dart';
import '../../../../shared/widgets/undo_snackbar.dart';
import '../../application/digestive_service.dart';

/// Modal para seguimiento de salud digestiva y Escala de Bristol (Tipos 1 a 7).
class DigestiveTrackerSheet extends ConsumerStatefulWidget {
  const DigestiveTrackerSheet({
    super.key,
    required this.dateKey,
  });

  final String dateKey;

  static Future<void> show(BuildContext context, {required String dateKey}) {
    return mostrarHojaMenu<void>(
      context,
      builder: (_) => DigestiveTrackerSheet(dateKey: dateKey),
    );
  }

  @override
  ConsumerState<DigestiveTrackerSheet> createState() =>
      _DigestiveTrackerSheetState();
}

class _DigestiveTrackerSheetState extends ConsumerState<DigestiveTrackerSheet> {
  int _selectedBristol = 4;
  int _discomfortLevel = 1;
  final Set<String> _selectedSymptoms = <String>{};
  final TextEditingController _notesCtrl = TextEditingController();

  List<({int type, String name, String subtitle, bool isOptimal})> _bristolTypes(AppLocalizations l10n) =>
      <({int type, String name, String subtitle, bool isOptimal})>[
    (
      type: 1,
      name: l10n.journalTipo1TerronesDuros,
      subtitle: l10n.journalTrozosDurosSeparadosDificilesDe,
      isOptimal: false,
    ),
    (
      type: 2,
      name: l10n.journalTipo2SalchichaGrumosa,
      subtitle: l10n.journalConFormaDeSalchichaPero,
      isOptimal: false,
    ),
    (
      type: 3,
      name: l10n.journalTipo3SalchichaConGrietas,
      subtitle: l10n.journalFormaCilindricaConGrietasEn,
      isOptimal: true,
    ),
    (
      type: 4,
      name: l10n.journalTipo4SuaveYLisa,
      subtitle: l10n.journalComoUnaSerpienteOSalchicha,
      isOptimal: true,
    ),
    (
      type: 5,
      name: l10n.journalTipo5TrozosPastososSuaves,
      subtitle: l10n.journalTrozosDeBordesDefinidosQue,
      isOptimal: false,
    ),
    (
      type: 6,
      name: l10n.journalTipo6FragmentosEsponjosos,
      subtitle: l10n.journalBlandosConBordesIrregularesTextura,
      isOptimal: false,
    ),
    (
      type: 7,
      name: l10n.journalTipo7AcuosaLiquida,
      subtitle: l10n.journalSinTrozosSolidosEnteramenteLiquida,
      isOptimal: false,
    ),
  ];

  /// Síntomas guardados como códigos estables; la etiqueta se traduce al mostrar.
  static const List<String> _symptomCodes = <String>['bloating', 'gas', 'reflux', 'cramps', 'heaviness'];

  static String symptomLabel(AppLocalizations l10n, String code) => switch (code) {
        'bloating' => l10n.journalHinchazonDistension,
        'gas' => l10n.journalGasesFrecuentes,
        'reflux' => l10n.journalReflujoOAcidez,
        'cramps' => l10n.journalDolorOColicos,
        'heaviness' => l10n.journalPesadezGastrica,
        _ => code,
      };

  static List<String> _decodeSymptoms(String raw) {
    try {
      final Object? decoded = jsonDecode(raw);
      return decoded is List<dynamic> ? decoded.whereType<String>().toList() : const <String>[];
    } on FormatException {
      return const <String>[];
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveDigestiveEvent() async {
    unawaited(HapticFeedback.lightImpact());
    await ref.read(digestiveServiceProvider).log(
          dateKey: widget.dateKey,
          bristolType: _selectedBristol,
          discomfortLevel: _discomfortLevel,
          symptoms: _selectedSymptoms.toList(),
          notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(context.l10n.journalEventoDigestivoTipoRegistrado((_selectedBristol).toString())),
          duration: const Duration(seconds: 2),
        ),
      );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final List<DigestiveLog> todayLogs =
        ref.watch(digestiveLogsProvider(widget.dateKey)).value ?? const <DigestiveLog>[];

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
                        color: c.isFlat
                            ? c.line2
                            : c.carbs.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.health_and_safety_rounded,
                        color: c.carbs,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            context.l10n.journalSaludDigestivaEscalaDeBristol,
                            style: TextStyle(
                              fontFamily: ScFonts.display,
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: c.text,
                            ),
                          ),
                          Text(
                            context.l10n.journalTransitoIntestinalYCorrelacionCon,
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

                // Selector de Tipo de Bristol (1 a 7)
                Text(
                  context.l10n.journalTipoEnLaEscalaDe,
                  style: TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 8),

                for (final item in _bristolTypes(context.l10n))
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      unawaited(HapticFeedback.selectionClick());
                      setState(() => _selectedBristol = item.type);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: _selectedBristol == item.type
                            ? (c.isFlat ? c.line2 : c.soft)
                            : c.bg3,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedBristol == item.type
                              ? (c.isFlat ? c.text : c.accent)
                              : (c.isFlat ? c.line2 : c.line),
                          width: _selectedBristol == item.type ? 1.6 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _selectedBristol == item.type
                                    ? (c.isFlat ? c.text : c.accent)
                                    : c.text2,
                                width: 2,
                              ),
                              color: _selectedBristol == item.type
                                  ? (c.isFlat ? c.text : c.accent)
                                  : Colors.transparent,
                            ),
                            child: _selectedBristol == item.type
                                ? Center(
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: c.isFlat ? c.bg : Colors.white,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Text(
                                      item.name,
                                      style: TextStyle(
                                        fontFamily: ScFonts.ui,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: c.text,
                                      ),
                                    ),
                                    if (item.isOptimal) ...<Widget>[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: c.isFlat
                                              ? c.line2
                                              : c.protein
                                                  .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          context.l10n.bodyStatusOptimal,
                                          style: TextStyle(
                                            fontFamily: ScFonts.ui,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: c.isFlat
                                                ? c.text
                                                : c.protein,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  item.subtitle,
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
                    ),
                  ),

                const SizedBox(height: 12),

                // Nivel de Molestia / Hinchazón (1 a 5)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      context.l10n.journalNivelDeMolestiaHinchazon,
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                    ),
                    Text(
                      _discomfortLevel == 1
                          ? context.l10n.journal1CeroMolestia: (_discomfortLevel <= 3
                              ? context.l10n.journalLeveModerada((_discomfortLevel).toString()): context.l10n.journalMolestiaMarcada((_discomfortLevel).toString())),
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.accent,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _discomfortLevel.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  onChanged: (double val) {
                    setState(() => _discomfortLevel = val.round());
                  },
                ),

                const SizedBox(height: 8),

                // Síntomas acompañantes
                Text(
                  context.l10n.journalSintomasAdicionales,
                  style: TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _symptomCodes.map((String symptom) {
                    final bool isSelected =
                        _selectedSymptoms.contains(symptom);
                    return FilterChip(
                      selected: isSelected,
                      label: Text(symptomLabel(context.l10n, symptom)),
                      onSelected: (bool sel) {
                        unawaited(HapticFeedback.selectionClick());
                        setState(() {
                          if (sel) {
                            _selectedSymptoms.add(symptom);
                          } else {
                            _selectedSymptoms.remove(symptom);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 12),

                // Botón Guardar
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saveDigestiveEvent,
                    child: Text(context.l10n.journalGuardarRegistroDigestivo),
                  ),
                ),

                if (todayLogs.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.journalRegistrosDeHoy(todayLogs.length.toString()),
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final DigestiveLog log in todayLogs)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: c.bg3,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: <Widget>[
                          Text(
                            context.l10n.journalTipo(log.bristolType.toString()),
                            style: TextStyle(
                              fontFamily: ScFonts.display,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: c.text,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              <String>[
                                context.l10n.journalDiscomfortLine(log.discomfortLevel),
                                ..._decodeSymptoms(log.symptomsJson).map((String code) => symptomLabel(context.l10n, code)),
                              ].join(' · '),
                              style: TextStyle(
                                fontFamily: ScFonts.ui,
                                fontSize: 11.5,
                                color: c.text2,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              size: 16,
                              color: c.text2,
                            ),
                            tooltip: context.l10n.commonDelete,
                            onPressed: () async {
                              final DigestiveService service = ref.read(digestiveServiceProvider);
                              await service.delete(log);
                              if (!context.mounted) return;
                              showUndoSnackBar(
                                context,
                                message: context.l10n.digestiveDeleted,
                                onUndo: () => unawaited(service.restore(log)),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
