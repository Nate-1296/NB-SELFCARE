import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/fasting_dao.dart';
import '../../../shared/theme/sc_colors.dart';
import '../../../shared/theme/sc_theme.dart';
import '../../../shared/widgets/app_icons.dart';
import '../../../shared/widgets/chip_pill.dart';
import '../../../shared/widgets/health_card.dart';
import '../../../shared/widgets/top_bar.dart';

/// Subpágina de Ayuno Intermitente, Fases Metabólicas, Ajuste de Inicio e Historial.
class FastingScreen extends ConsumerStatefulWidget {
  const FastingScreen({super.key});

  @override
  ConsumerState<FastingScreen> createState() => _FastingScreenState();
}

class _FastingScreenState extends ConsumerState<FastingScreen> {
  String _selectedProtocol = '16:8';
  int _targetHours = 16;
  DateTime? _customStartTime;
  Timer? _tickTimer;
  bool? _lastFlatMode;

  static const List<({String name, int hours, String label})> _protocols =
      <({String name, int hours, String label})>[
    (name: '14:10', hours: 14, label: 'Circadiano suave y sostenible'),
    (name: '16:8', hours: 16, label: 'Leangains clásico equilibrado'),
    (name: '18:6', hours: 18, label: 'Mayor lipólisis y flexibilidad'),
    (name: '20:4', hours: 20, label: 'Ventana concentrada avanzada'),
    (name: 'Personalizado', hours: 15, label: 'Elige tus horas exactas'),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool isFlat = context.sc.isFlat;
    if (_lastFlatMode != isFlat) {
      _lastFlatMode = isFlat;
      _tickTimer?.cancel();
      // En modo E-Ink refrescamos cada 60s para cero ghosting; en OLED/Material cada 1s
      _tickTimer = Timer.periodic(
        isFlat ? const Duration(seconds: 60) : const Duration(seconds: 1),
        (_) {
          if (mounted) setState(() {});
        },
      );
    }
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  void _selectProtocol(String protocol, int hours) {
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _selectedProtocol = protocol;
      if (protocol != 'Personalizado' || _targetHours < 12) {
        _targetHours = hours;
      }
    });
  }

  Color _getPhaseColor(double hours, ScColors c) {
    if (c.isFlat) return c.accent;
    if (hours < 4.0) return c.water;
    if (hours < 12.0) return c.steps;
    if (hours < 18.0) return c.carbs;
    if (hours < 24.0) return c.calories;
    return c.fasting;
  }

  String _currentPhaseName(double hours) {
    if (hours < 4.0) return 'Fase anabólica';
    if (hours < 12.0) return 'Glucogenólisis';
    if (hours < 18.0) return 'Lipólisis activa';
    if (hours < 24.0) return 'Cetosis ligera';
    return 'Autofagia profunda';
  }

  Future<DateTime?> _pickCustomDateTime(DateTime initial) async {
    final DateTime now = DateTime.now();
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: now.subtract(const Duration(days: 7)),
      lastDate: now,
    );
    if (pickedDate == null || !mounted) return null;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (pickedTime == null || !mounted) return null;

    final DateTime candidate = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    return candidate.isAfter(now) ? now : candidate;
  }

  String _fmtClock(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final FastingDao fastingDao = ref.watch(fastingDaoProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            TopBar(
              title: 'Ayuno Intermitente',
              subtitle: 'Ritmo metabólico y descanso digestivo',
              subtitleBelowTitle: true,
              uppercaseSubtitle: false,
              leading: IconButton(
                tooltip: 'Volver',
                icon: Icon(Icons.arrow_back_rounded, color: c.text),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/comer');
                  }
                },
              ),
            ),
            Expanded(
              child: StreamBuilder<FastingSession?>(
                stream: fastingDao.watchActiveSession(),
                builder: (
                  BuildContext context,
                  AsyncSnapshot<FastingSession?> snapshot,
                ) {
                  final FastingSession? session = snapshot.data;
                  final bool isFastingActive = session != null;

                  final DateTime now = DateTime.now();
                  final int elapsedSecs = isFastingActive
                      ? now
                          .difference(session.startedAt)
                          .inSeconds
                          .clamp(0, 864000)
                      : 0;
                  final double elapsedHours = elapsedSecs / 3600.0;

                  final double progressRatio =
                      isFastingActive && session.targetHours > 0
                          ? (elapsedHours / session.targetHours).clamp(0.0, 1.0)
                          : 0.0;

                  final int elapsedHoursInt = elapsedSecs ~/ 3600;
                  final int elapsedMinutes = (elapsedSecs % 3600) ~/ 60;
                  final int elapsedSecondsRem = elapsedSecs % 60;

                  final Color phaseColor = _getPhaseColor(elapsedHours, c);

                  return ListView(
                    padding: const EdgeInsets.only(bottom: 96),
                    children: <Widget>[
                      // 1. Tarjeta Hero con Anillo Metabólico en Vivo
                      HealthCard(
                        padding: const EdgeInsets.symmetric(
                          vertical: 24,
                          horizontal: 20,
                        ),
                        child: Column(
                          children: <Widget>[
                            if (isFastingActive) ...<Widget>[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: c.isFlat
                                      ? c.bg3
                                      : phaseColor.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: c.isFlat ? c.line2 : phaseColor,
                                  ),
                                ),
                                child: Text(
                                  _currentPhaseName(elapsedHours),
                                  style: TextStyle(
                                    fontFamily: ScFonts.ui,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: c.isFlat ? c.text : phaseColor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            Stack(
                              alignment: Alignment.center,
                              children: <Widget>[
                                SizedBox(
                                  width: 204,
                                  height: 204,
                                  child: CircularProgressIndicator(
                                    value:
                                        isFastingActive ? progressRatio : 0.0,
                                    strokeWidth: 14,
                                    strokeCap: c.isFlat
                                        ? StrokeCap.butt
                                        : StrokeCap.round,
                                    backgroundColor: c.bg3,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isFastingActive ? phaseColor : c.line2,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Icon(
                                        isFastingActive
                                            ? AppIcons.ayunoFilled
                                            : AppIcons.ayuno,
                                        size: 28,
                                        color: isFastingActive
                                            ? phaseColor
                                            : c.text3,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        isFastingActive
                                            ? (c.isFlat
                                                ? '${elapsedHoursInt}h ${elapsedMinutes.toString().padLeft(2, '0')}m'
                                                : '${elapsedHoursInt}h ${elapsedMinutes.toString().padLeft(2, '0')}m ${elapsedSecondsRem.toString().padLeft(2, '0')}s')
                                            : '0h 00m',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontFamily: ScFonts.display,
                                          fontSize:
                                              isFastingActive && !c.isFlat
                                                  ? 22
                                                  : 26,
                                          fontWeight: FontWeight.w800,
                                          color: c.text,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isFastingActive
                                            ? 'Meta ${session.targetHours}h · ${(progressRatio * 100).toInt()}%'
                                            : (_customStartTime != null
                                                ? 'Inicio: ${_fmtClock(_customStartTime!)}'
                                                : 'Listo para comenzar'),
                                        textAlign: TextAlign.center,
                                        softWrap: true,
                                        style: TextStyle(
                                          fontFamily: ScFonts.ui,
                                          fontSize: 12,
                                          color: c.text2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 22),

                            if (isFastingActive) ...<Widget>[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: c.bg3,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: c.isFlat ? c.line2 : c.line,
                                  ),
                                ),
                                child: Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(10),
                                        onTap: () async {
                                          final DateTime? updated =
                                              await _pickCustomDateTime(
                                            session.startedAt,
                                          );
                                          if (updated != null) {
                                            await fastingDao
                                                .updateActiveFastStart(
                                              sessionId: session.id,
                                              newStartedAt: updated,
                                            );
                                          }
                                        },
                                        child: Column(
                                          children: <Widget>[
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: <Widget>[
                                                Text(
                                                  'Inicio',
                                                  style: TextStyle(
                                                    fontFamily: ScFonts.ui,
                                                    fontSize: 11,
                                                    color: c.text3,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Icon(
                                                  AppIcons.edit,
                                                  size: 12,
                                                  color: c.accent,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _fmtClock(session.startedAt),
                                              style: TextStyle(
                                                fontFamily: ScFonts.display,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                                color: c.text,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 28,
                                      color: c.line,
                                    ),
                                    Expanded(
                                      child: Column(
                                        children: <Widget>[
                                          Text(
                                            'Protocolo',
                                            style: TextStyle(
                                              fontFamily: ScFonts.ui,
                                              fontSize: 11,
                                              color: c.text3,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            session.protocolName,
                                            softWrap: true,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontFamily: ScFonts.display,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: c.accent,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 28,
                                      color: c.line,
                                    ),
                                    Expanded(
                                      child: Column(
                                        children: <Widget>[
                                          Text(
                                            'Fin previsto',
                                            style: TextStyle(
                                              fontFamily: ScFonts.ui,
                                              fontSize: 11,
                                              color: c.text3,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _fmtClock(session.plannedEndAt),
                                            style: TextStyle(
                                              fontFamily: ScFonts.display,
                                              fontSize: 14,
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
                            ] else ...<Widget>[
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                runSpacing: 8,
                                children: <Widget>[
                                  ChipPill(
                                    label: 'Iniciar ahora',
                                    active: _customStartTime == null,
                                    onTap: () =>
                                        setState(() => _customStartTime = null),
                                  ),
                                  ChipPill(
                                    label: 'Elegir hora de inicio',
                                    icon: AppIcons.edit,
                                    active: _customStartTime != null,
                                    onTap: () async {
                                      final DateTime? picked =
                                          await _pickCustomDateTime(
                                        _customStartTime ?? now,
                                      );
                                      if (picked != null) {
                                        setState(
                                          () => _customStartTime = picked,
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],

                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor:
                                      isFastingActive ? c.bg3 : c.accent,
                                  foregroundColor:
                                      isFastingActive ? c.text : c.ink,
                                  side: isFastingActive
                                      ? BorderSide(
                                          color: c.isFlat ? c.line2 : c.warning,
                                          width: 1.5,
                                        )
                                      : null,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: () async {
                                  unawaited(HapticFeedback.heavyImpact());
                                  if (isFastingActive) {
                                    if (!context.mounted) return;
                                    final bool? confirm =
                                        await showDialog<bool>(
                                      context: context,
                                      builder: (BuildContext ctx) => AlertDialog(
                                        backgroundColor: c.bg2,
                                        title: const Text('¿Cerrar ventana de ayuno?'),
                                        content: Text(
                                          elapsedHours >= 14.0
                                              ? '¡Completaste ${elapsedHours.toStringAsFixed(1)} h! Recibirás +20 monedas para Nibi.'
                                              : 'Tu sesión de ${elapsedHours.toStringAsFixed(1)} h se guardará tranquilamente en tu historial.',
                                        ),
                                        actions: <Widget>[
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(ctx).pop(false),
                                            child: const Text(
                                              'Seguir en ayuno',
                                            ),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.of(ctx).pop(true),
                                            child: const Text(
                                              'Finalizar ayuno',
                                            ),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      await fastingDao.endFast(
                                        sessionId: session.id,
                                        notes: 'Sesión registrada.',
                                      );
                                    }
                                  } else {
                                    final String protoLabel =
                                        _selectedProtocol == 'Personalizado'
                                            ? '${_targetHours}h'
                                            : _selectedProtocol;
                                    await fastingDao.startFast(
                                      protocolName: protoLabel,
                                      targetHours: _targetHours,
                                      startedAt:
                                          _customStartTime ?? DateTime.now(),
                                    );
                                    if (mounted) {
                                      setState(() => _customStartTime = null);
                                    }
                                  }
                                },
                                child: Text(
                                  isFastingActive
                                      ? 'Finalizar Ayuno'
                                      : (_selectedProtocol == 'Personalizado'
                                          ? 'Iniciar Ayuno (${_targetHours}h)'
                                          : 'Iniciar Ayuno ($_selectedProtocol)'),
                                  style: const TextStyle(
                                    fontFamily: ScFonts.display,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 2. Selector de Protocolos (si no hay ayuno activo)
                      if (!isFastingActive) ...<Widget>[
                        const _CalmSectionHeader(
                          title: 'Elegir Protocolo de Ayuno',
                          subtitle: 'Selecciona la ventana que mejor se adapte a tu día',
                        ),
                        for (final ({String name, int hours, String label}) p
                            in _protocols)
                          Builder(
                            builder: (BuildContext context) {
                              final bool isSelected =
                                  _selectedProtocol == p.name;

                              return HealthCard(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 16,
                                ),
                                borderColor: isSelected ? c.accent : null,
                                onTap: () => _selectProtocol(p.name, p.hours),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Row(
                                      children: <Widget>[
                                        Container(
                                          width: 22,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isSelected
                                                  ? c.accent
                                                  : c.line2,
                                              width: isSelected ? 2.4 : 1.5,
                                            ),
                                          ),
                                          child: isSelected
                                              ? Center(
                                                  child: Container(
                                                    width: 10,
                                                    height: 10,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: c.accent,
                                                    ),
                                                  ),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Text(
                                                p.name,
                                                softWrap: true,
                                                style: TextStyle(
                                                  fontFamily: ScFonts.display,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
                                                  color: c.text,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                p.label,
                                                softWrap: true,
                                                style: TextStyle(
                                                  fontFamily: ScFonts.ui,
                                                  fontSize: 12.5,
                                                  color: c.text2,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          p.name == 'Personalizado' &&
                                                  isSelected
                                              ? '$_targetHours horas'
                                              : '${p.hours} horas',
                                          style: TextStyle(
                                            fontFamily: ScFonts.display,
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800,
                                            color: c.accent,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (p.name == 'Personalizado' &&
                                        isSelected) ...<Widget>[
                                      const SizedBox(height: 10),
                                      Slider(
                                        value: _targetHours
                                            .toDouble()
                                            .clamp(12.0, 36.0),
                                        min: 12,
                                        max: 36,
                                        divisions: 24,
                                        label: '$_targetHours horas',
                                        onChanged: (double v) {
                                          setState(
                                            () => _targetHours = v.round(),
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                      ],

                      // 3. Fases Metabólicas (Línea de Tiempo sin cortes)
                      const _CalmSectionHeader(
                        title: 'Fases Metabólicas',
                        subtitle: 'Evolución fisiológica estimada durante el ayuno',
                      ),
                      HealthCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: <Widget>[
                            _PhaseTimelineStep(
                              hoursLabel: '0 – 4 h',
                              title: 'Fase Anabólica',
                              subtitle:
                                  'Digestión y asimilación de los nutrientes recientes.',
                              isActive: isFastingActive && elapsedHours < 4.0,
                              isCompleted:
                                  isFastingActive && elapsedHours >= 4.0,
                              color: c.water,
                            ),
                            _PhaseTimelineStep(
                              hoursLabel: '4 – 12 h',
                              title: 'Glucogenólisis',
                              subtitle:
                                  'Uso gradual del glucógeno hepático mientras baja la insulina.',
                              isActive: isFastingActive &&
                                  elapsedHours >= 4.0 &&
                                  elapsedHours < 12.0,
                              isCompleted:
                                  isFastingActive && elapsedHours >= 12.0,
                              color: c.steps,
                            ),
                            _PhaseTimelineStep(
                              hoursLabel: '12 – 18 h',
                              title: 'Lipólisis y Quema de Grasa',
                              subtitle:
                                  'Movilización de ácidos grasos y energía estable.',
                              isActive: isFastingActive &&
                                  elapsedHours >= 12.0 &&
                                  elapsedHours < 18.0,
                              isCompleted:
                                  isFastingActive && elapsedHours >= 18.0,
                              color: c.carbs,
                            ),
                            _PhaseTimelineStep(
                              hoursLabel: '18 – 24 h',
                              title: 'Cetosis Activa',
                              subtitle:
                                  'Síntesis de cuerpos cetónicos y claridad mental sostenida.',
                              isActive: isFastingActive &&
                                  elapsedHours >= 18.0 &&
                                  elapsedHours < 24.0,
                              isCompleted:
                                  isFastingActive && elapsedHours >= 24.0,
                              color: c.calories,
                            ),
                            _PhaseTimelineStep(
                              hoursLabel: '24 h+',
                              title: 'Autofagia Profunda',
                              subtitle:
                                  'Renovación celular y reciclaje de componentes internos.',
                              isActive: isFastingActive && elapsedHours >= 24.0,
                              isCompleted: false,
                              color: c.fasting,
                              isLast: true,
                            ),
                          ],
                        ),
                      ),

                      // 4. Historial de Ayunos Recientes
                      StreamBuilder<List<FastingSession>>(
                        stream: fastingDao.watchRecentSessions(limit: 10),
                        builder: (
                          BuildContext context,
                          AsyncSnapshot<List<FastingSession>> histSnap,
                        ) {
                          final List<FastingSession> history =
                              histSnap.data ?? const <FastingSession>[];
                          if (history.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const _CalmSectionHeader(
                                title: 'Historial de Ayunos',
                                subtitle: 'Últimas sesiones registradas',
                              ),
                              for (final FastingSession s in history)
                                Builder(
                                  builder: (BuildContext context) {
                                    final DateTime end =
                                        s.actualEndedAt ?? s.plannedEndAt;
                                    final int durMin = end
                                        .difference(s.startedAt)
                                        .inMinutes
                                        .clamp(0, 99999);
                                    final int h = durMin ~/ 60;
                                    final int m = durMin % 60;
                                    final String dateLabel =
                                        '${s.startedAt.day.toString().padLeft(2, '0')}/${s.startedAt.month.toString().padLeft(2, '0')}/${s.startedAt.year}';

                                    return HealthCard(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        children: <Widget>[
                                          Icon(
                                            s.isCompleted
                                                ? AppIcons.check
                                                : AppIcons.fasting,
                                            size: 19,
                                            color: s.isCompleted
                                                ? (c.isFlat
                                                    ? c.text
                                                    : c.success)
                                                : c.text2,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: <Widget>[
                                                Text(
                                                  'Protocolo ${s.protocolName} · ${h}h ${m.toString().padLeft(2, '0')}m',
                                                  softWrap: true,
                                                  style: TextStyle(
                                                    fontFamily: ScFonts.display,
                                                    fontSize: 14.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: c.text,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '$dateLabel  •  ${_fmtClock(s.startedAt)} → ${_fmtClock(end)}',
                                                  softWrap: true,
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
                                            tooltip: 'Eliminar sesión',
                                            icon: Icon(
                                              AppIcons.delete,
                                              size: 18,
                                              color: c.text3,
                                            ),
                                            onPressed: () {
                                              unawaited(
                                                fastingDao.deleteSession(s.id),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalmSectionHeader extends StatelessWidget {
  const _CalmSectionHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            softWrap: true,
            style: TextStyle(
              fontFamily: ScFonts.display,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: c.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            softWrap: true,
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 12.5,
              color: c.text2,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhaseTimelineStep extends StatelessWidget {
  const _PhaseTimelineStep({
    required this.hoursLabel,
    required this.title,
    required this.subtitle,
    required this.isActive,
    required this.isCompleted,
    required this.color,
    this.isLast = false,
  });

  final String hoursLabel;
  final String title;
  final String subtitle;
  final bool isActive;
  final bool isCompleted;
  final Color color;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final Color resolvedColor = c.isFlat ? c.text : color;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Column(
            children: <Widget>[
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isCompleted || isActive) ? resolvedColor : c.bg3,
                  border: Border.all(
                    color: isActive ? resolvedColor : c.line2,
                    width: isActive ? 2.4 : 1.2,
                  ),
                ),
                child: Center(
                  child: isCompleted
                      ? Icon(Icons.check, size: 13, color: c.ink)
                      : (isActive
                          ? Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: c.ink,
                              ),
                            )
                          : null),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCompleted
                        ? resolvedColor.withValues(alpha: 0.65)
                        : c.line,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 2 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          title,
                          softWrap: true,
                          style: TextStyle(
                            fontFamily: ScFonts.display,
                            fontSize: 14,
                            fontWeight:
                                isActive ? FontWeight.w800 : FontWeight.w700,
                            color: isActive ? resolvedColor : c.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        hoursLabel,
                        style: TextStyle(
                          fontFamily: ScFonts.ui,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: c.text3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    softWrap: true,
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
        ],
      ),
    );
  }
}
