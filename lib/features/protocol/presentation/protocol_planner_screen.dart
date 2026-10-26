import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/protocol_dao.dart';
import '../../../core/database/daos/supplement_dao.dart';
import '../../../core/database/daos/user_profile_dao.dart';
import '../../../shared/theme/sc_colors.dart';
import '../../../shared/theme/sc_theme.dart';
import '../../../shared/utils/date_time_extensions.dart';
import '../../../shared/widgets/app_icons.dart';
import '../../../shared/widgets/health_card.dart';
import '../../../shared/widgets/top_bar.dart';
import '../../nutrition_hydration/presentation/widgets/diet_archetype_sheets.dart';
import '../../profile_goals/presentation/widgets/supplement_tracker_sheet.dart';

/// Pantalla "Mi Protocolo": Tablero integral de planificación proactiva.
///
/// Unifica en un único centro de mando:
/// 1. Estrategia Nutricional & Arquetipo (Mediterránea, Keto, etc. y Calorie Cycling)
/// 2. Ventana de Ayuno Semanal (Días y horario preferido)
/// 3. Pauta de Suplementación & Medicación
/// 4. Rutina de Entrenamiento (Días, RPE y horario)
/// 5. Diagnóstico de Coherencia de la IA Local.
class ProtocolPlannerScreen extends ConsumerStatefulWidget {
  const ProtocolPlannerScreen({super.key});

  @override
  ConsumerState<ProtocolPlannerScreen> createState() =>
      _ProtocolPlannerScreenState();
}

class _ProtocolPlannerScreenState
    extends ConsumerState<ProtocolPlannerScreen> {
  final Set<int> _plannedWorkoutDays = <int>{1, 3, 5}; // Lunes, Miércoles, Viernes
  final Set<int> _plannedFastingDays = <int>{1, 2, 3, 4, 5}; // Lunes a Viernes
  String _fastingProtocol = '16:8';
  String _workoutTimeOfDay = 'mañana'; // mañana, tarde, noche

  static const List<String> _dayInitials = <String>[
    'L',
    'M',
    'X',
    'J',
    'V',
    'S',
    'D',
  ];

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final ProtocolDao protocolDao = ref.watch(protocolDaoProvider);
    final SupplementDao supplementDao = ref.watch(supplementDaoProvider);
    final UserProfile? profile = ref.watch(userProfileStreamProvider).value;

    final String archetype = profile?.activeDietArchetype ?? 'mediterranean';
    final String dietPhase = profile?.activeDietPhase ?? 'deficit';

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 36),
          children: <Widget>[
            TopBar(
              title: 'Mi Protocolo',
              subtitle: 'Planificador Semanal Proactivo',
              large: true,
              subtitleBelowTitle: true,
              pageIcon: Icons.calendar_month_rounded,
              onProfile: () => context.go('/perfil'),
            ),

            // 1. Diagnóstico de Coherencia IA Local
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: _ProtocolAiDiagnosticsCard(
                plannedWorkoutDays: _plannedWorkoutDays.length,
                plannedFastingDays: _plannedFastingDays.length,
                dietPhase: dietPhase,
                archetype: archetype,
              ),
            ),

            // 2. Bloque: Dieta & Arquetipo
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: HealthCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(Icons.restaurant_menu_rounded, color: c.accent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '1. Estrategia Nutricional',
                            style: TextStyle(
                              fontFamily: ScFonts.display,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: c.text,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            unawaited(HapticFeedback.selectionClick());
                            unawaited(DietArchetypePickerSheet.show(context));
                          },
                          child: const Text('Modificar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Arquetipo: ${archetype.toUpperCase()} · Fase: ${dietPhase == "deficit" ? "Déficit Calórico" : "Mantenimiento"}',
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'El plan calcula automáticamente tus porciones y macros en cada comida para que no pienses en qué comer.',
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 12,
                        color: c.text2,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Bloque: Ventana de Ayuno Semanal
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: HealthCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(AppIcons.ayuno, color: c.fasting, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '2. Ventana de Ayuno Planeada',
                            style: TextStyle(
                              fontFamily: ScFonts.display,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: c.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Días activos de la semana:',
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: c.text2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List<Widget>.generate(7, (int idx) {
                        final int dayNum = idx + 1;
                        final bool isSelected =
                            _plannedFastingDays.contains(dayNum);
                        return InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            unawaited(HapticFeedback.selectionClick());
                            setState(() {
                              if (isSelected) {
                                _plannedFastingDays.remove(dayNum);
                              } else {
                                _plannedFastingDays.add(dayNum);
                              }
                            });
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (c.isFlat ? c.line2 : c.soft)
                                  : c.bg3,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? (c.isFlat ? c.text : c.accent)
                                    : (c.isFlat ? c.line2 : c.line),
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Text(
                              _dayInitials[idx],
                              style: TextStyle(
                                fontFamily: ScFonts.display,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isSelected ? c.accent : c.text2,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          'Protocolo habitual:',
                          style: TextStyle(
                            fontFamily: ScFonts.ui,
                            fontSize: 12.5,
                            color: c.text,
                          ),
                        ),
                        DropdownButton<String>(
                          value: _fastingProtocol,
                          underline: const SizedBox.shrink(),
                          items: const <DropdownMenuItem<String>>[
                            DropdownMenuItem<String>(
                              value: '14:10',
                              child: Text('14:10 (Suave)'),
                            ),
                            DropdownMenuItem<String>(
                              value: '16:8',
                              child: Text('16:8 (Estándar)'),
                            ),
                            DropdownMenuItem<String>(
                              value: '18:6',
                              child: Text('18:6 (Intenso)'),
                            ),
                            DropdownMenuItem<String>(
                              value: '20:4',
                              child: Text('20:4 (Avanzado)'),
                            ),
                          ],
                          onChanged: (String? val) {
                            if (val != null) {
                              setState(() => _fastingProtocol = val);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 4. Bloque: Rutina de Entrenamiento
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: HealthCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(Icons.fitness_center_rounded,
                            color: c.steps, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '3. Entrenamiento Físico Semanal',
                            style: TextStyle(
                              fontFamily: ScFonts.display,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: c.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Días de entrenamiento planificados:',
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: c.text2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List<Widget>.generate(7, (int idx) {
                        final int dayNum = idx + 1;
                        final bool isSelected =
                            _plannedWorkoutDays.contains(dayNum);
                        return InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            unawaited(HapticFeedback.selectionClick());
                            setState(() {
                              if (isSelected) {
                                _plannedWorkoutDays.remove(dayNum);
                              } else {
                                _plannedWorkoutDays.add(dayNum);
                              }
                            });
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (c.isFlat ? c.line2 : c.soft)
                                  : c.bg3,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? (c.isFlat ? c.text : c.steps)
                                    : (c.isFlat ? c.line2 : c.line),
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Text(
                              _dayInitials[idx],
                              style: TextStyle(
                                fontFamily: ScFonts.display,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isSelected ? c.steps : c.text2,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          'Horario habitual:',
                          style: TextStyle(
                            fontFamily: ScFonts.ui,
                            fontSize: 12.5,
                            color: c.text,
                          ),
                        ),
                        SegmentedButton<String>(
                          segments: const <ButtonSegment<String>>[
                            ButtonSegment<String>(
                              value: 'mañana',
                              label: Text('Mañana'),
                            ),
                            ButtonSegment<String>(
                              value: 'tarde',
                              label: Text('Tarde'),
                            ),
                            ButtonSegment<String>(
                              value: 'noche',
                              label: Text('Noche'),
                            ),
                          ],
                          selected: <String>{_workoutTimeOfDay},
                          onSelectionChanged: (Set<String> sel) {
                            setState(() => _workoutTimeOfDay = sel.first);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 5. Bloque: Pauta de Suplementos
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: StreamBuilder<List<SupplementsTrackerData>>(
                stream: supplementDao.watchActiveSupplements(),
                builder: (
                  BuildContext context,
                  AsyncSnapshot<List<SupplementsTrackerData>> snap,
                ) {
                  final List<SupplementsTrackerData> list =
                      snap.data ?? const <SupplementsTrackerData>[];

                  return HealthCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(Icons.medication_rounded,
                                color: c.accent, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '4. Suplementación (${list.length} activos)',
                                style: TextStyle(
                                  fontFamily: ScFonts.display,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: c.text,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                unawaited(HapticFeedback.selectionClick());
                                unawaited(
                                  SupplementTrackerSheet.show(
                                    context,
                                    dateKey: DateTime.now().dateKey,
                                  ),
                                );
                              },
                              child: const Text('Administrar'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (list.isEmpty)
                          Text(
                            'No has añadido suplementos aún. Puedes incorporar creatina, omega 3 o vitaminas.',
                            style: TextStyle(
                              fontFamily: ScFonts.ui,
                              fontSize: 12,
                              color: c.text2,
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: list.map((SupplementsTrackerData s) {
                              return Chip(
                                label: Text('${s.name} (${s.dosage})'),
                                visualDensity: VisualDensity.compact,
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // Botón Guardar Plan
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: FilledButton.icon(
                onPressed: () async {
                  unawaited(HapticFeedback.lightImpact());
                  await protocolDao.saveActiveProtocol(
                    planName: 'Protocolo Maestro $archetype',
                    fastingDaysBitmask: _plannedFastingDays.join(','),
                    workoutSlotsJson:
                        '{"days": [${_plannedWorkoutDays.join(",")}], "time": "$_workoutTimeOfDay"}',
                    dietArchetype: archetype,
                  );
                  if (!mounted || !context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Protocolo semanal guardado con éxito'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('Guardar Mi Protocolo Semanal'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProtocolAiDiagnosticsCard extends StatelessWidget {
  const _ProtocolAiDiagnosticsCard({
    required this.plannedWorkoutDays,
    required this.plannedFastingDays,
    required this.dietPhase,
    required this.archetype,
  });

  final int plannedWorkoutDays;
  final int plannedFastingDays;
  final String dietPhase;
  final String archetype;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;

    // Diagnóstico determinista de coherencia metabólica
    String status = 'Coherencia Metabólica Óptima';
    String message =
        'Tu distribución de $plannedWorkoutDays días de entreno y $plannedFastingDays días de ayuno '
        'está equilibrada para el arquetipo $archetype en fase $dietPhase. '
        'Tus ventanas de alimentación permiten reabastecer glucógeno y sostener la recuperación muscular.';

    if (plannedWorkoutDays >= 5 && plannedFastingDays >= 6 && dietPhase == 'deficit') {
      status = 'Recomendación de Recuperación';
      message =
          'Detectamos 5+ días de entrenamiento intenso y 6 días de ayuno en déficit calórico. '
          'Para proteger la masa muscular y evitar fatiga adrenal, te recomendamos programar al menos 2 días de alimentación libre o descanso dietético (Refeed).';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.isFlat ? c.bg3 : c.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: c.isFlat ? c.line2 : c.accent.withValues(alpha: 0.35),
          width: c.isFlat ? 1.4 : 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.auto_awesome_rounded, color: c.accent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  status,
                  style: TextStyle(
                    fontFamily: ScFonts.display,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: 12,
                    color: c.text,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
