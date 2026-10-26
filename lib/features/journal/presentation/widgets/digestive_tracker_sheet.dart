import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/digestive_dao.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/sheet.dart';

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

  static const List<({int type, String name, String subtitle, bool isOptimal})>
      _bristolTypes = <({int type, String name, String subtitle, bool isOptimal})>[
    (
      type: 1,
      name: 'Tipo 1: Terrones duros',
      subtitle: 'Trozos duros separados, difíciles de expulsar (estreñimiento severo)',
      isOptimal: false,
    ),
    (
      type: 2,
      name: 'Tipo 2: Salchicha grumosa',
      subtitle: 'Con forma de salchicha pero unida con protuberancias (estreñimiento leve)',
      isOptimal: false,
    ),
    (
      type: 3,
      name: 'Tipo 3: Salchicha con grietas',
      subtitle: 'Forma cilíndrica con grietas en la superficie (normal)',
      isOptimal: true,
    ),
    (
      type: 4,
      name: 'Tipo 4: Suave y lisa',
      subtitle: 'Como una serpiente o salchicha, suave y tersa (óptimo fisiológico)',
      isOptimal: true,
    ),
    (
      type: 5,
      name: 'Tipo 5: Trozos pastosos suaves',
      subtitle: 'Trozos de bordes definidos que se expulsan fácil (falta leve de fibra)',
      isOptimal: false,
    ),
    (
      type: 6,
      name: 'Tipo 6: Fragmentos esponjosos',
      subtitle: 'Blandos con bordes irregulares, textura pastosa (tránsito rápido / inflamación)',
      isOptimal: false,
    ),
    (
      type: 7,
      name: 'Tipo 7: Acuosa / Líquida',
      subtitle: 'Sin trozos sólidos, enteramente líquida (diarrea / gastroenteritis)',
      isOptimal: false,
    ),
  ];

  static const List<String> _availableSymptoms = <String>[
    'Hinchazón / Distensión',
    'Gases frecuentes',
    'Reflujo o acidez',
    'Dolor o cólicos',
    'Pesadez gástrica',
  ];

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveDigestiveEvent() async {
    unawaited(HapticFeedback.lightImpact());
    final List<String> symptomsList = _selectedSymptoms.toList();
    final String symptomsJson =
        '["${symptomsList.join('","')}"]';

    await ref.read(digestiveDaoProvider).logDigestiveEvent(
          dateKey: widget.dateKey,
          bristolType: _selectedBristol,
          discomfortLevel: _discomfortLevel,
          symptomsJson: symptomsList.isEmpty ? '[]' : symptomsJson,
          notes: _notesCtrl.text.trim().isNotEmpty
              ? _notesCtrl.text.trim()
              : null,
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Evento digestivo Tipo $_selectedBristol registrado'),
          duration: const Duration(seconds: 2),
        ),
      );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final DigestiveDao dao = ref.watch(digestiveDaoProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: StreamBuilder<List<DigestiveLog>>(
        stream: dao.watchLogsForDate(widget.dateKey),
        builder: (
          BuildContext context,
          AsyncSnapshot<List<DigestiveLog>> snapshot,
        ) {
          final List<DigestiveLog> todayLogs =
              snapshot.data ?? const <DigestiveLog>[];

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
                            'Salud Digestiva & Escala de Bristol',
                            style: TextStyle(
                              fontFamily: ScFonts.display,
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: c.text,
                            ),
                          ),
                          Text(
                            'Tránsito intestinal y correlación con fibra y alimentos',
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
                  'Tipo en la Escala de Bristol:',
                  style: TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 8),

                for (final item in _bristolTypes)
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
                                          'Óptimo',
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
                      'Nivel de molestia / Hinchazón:',
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                    ),
                    Text(
                      _discomfortLevel == 1
                          ? '1 - Cero molestia'
                          : (_discomfortLevel <= 3
                              ? '$_discomfortLevel - Leve/Moderada'
                              : '$_discomfortLevel - Molestia marcada'),
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
                  'Síntomas adicionales:',
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
                  children: _availableSymptoms.map((String symptom) {
                    final bool isSelected =
                        _selectedSymptoms.contains(symptom);
                    return FilterChip(
                      selected: isSelected,
                      label: Text(symptom),
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
                    child: const Text('Guardar Registro Digestivo'),
                  ),
                ),

                if (todayLogs.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  Text(
                    'Registros de hoy (${todayLogs.length}):',
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
                            'Tipo ${log.bristolType}',
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
                              'Molestia: ${log.discomfortLevel}/5 ${log.symptomsJson != "[]" ? "· ${log.symptomsJson}" : ""}',
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
                            onPressed: () {
                              unawaited(dao.deleteLog(log.id));
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
