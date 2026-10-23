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
import '../../../shared/widgets/section_head.dart';
import '../../../shared/widgets/top_bar.dart';

/// Pantalla completa de Ayuno Intermitente, Fases Metabólicas y Cronobiología.
///
/// Accesible directamente al pulsar la barra flotante de ayuno (FastingBar).
class FastingScreen extends ConsumerStatefulWidget {
  const FastingScreen({super.key});

  @override
  ConsumerState<FastingScreen> createState() => _FastingScreenState();
}

class _FastingScreenState extends ConsumerState<FastingScreen> {
  String _selectedProtocol = '16:8';
  int _targetHours = 16;

  final List<Map<String, dynamic>> _protocols = const [
    {'name': '14:10', 'hours': 14, 'label': 'Circadiano Suave'},
    {'name': '16:8', 'hours': 16, 'label': 'Leangains Estándar'},
    {'name': '18:6', 'hours': 18, 'label': 'Autofagia y Quema'},
    {'name': '20:4', 'hours': 20, 'label': 'Guerrero / OMAD'},
  ];

  void _selectProtocol(String protocol, int hours) {
    setState(() {
      _selectedProtocol = protocol;
      _targetHours = hours;
    });
  }

  Color _getPhaseColor(double hours, ScColors c) {
    if (hours < 4.0) return const Color(0xFF64B5F6);
    if (hours < 12.0) return const Color(0xFF81C784);
    if (hours < 18.0) return const Color(0xFFFFB74D);
    if (hours < 24.0) return const Color(0xFFFF7043);
    return c.fasting;
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final fastingDao = ref.watch(fastingDaoProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            TopBar(
              title: 'Ayuno Intermitente',
              leading: IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: c.text),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/hoy');
                  }
                },
              ),
              trailing: ChipPill(
                icon: AppIcons.fuego,
                iconColor: c.fasting,
                label: 'Fases Metabólicas',
              ),
            ),
            Expanded(
              child: StreamBuilder<FastingSession?>(
                stream: fastingDao.watchActiveSession(),
                builder: (context, snapshot) {
                  final session = snapshot.data;
                  final bool isFastingActive = session != null;

                  final DateTime now = DateTime.now();
                  final double elapsedHours = isFastingActive
                      ? (now.difference(session.startedAt).inMinutes / 60.0).clamp(0.0, 999.0)
                      : 0.0;

                  final double progressRatio = isFastingActive && session.targetHours > 0
                      ? (elapsedHours / session.targetHours).clamp(0.0, 1.0)
                      : 0.0;

                  final int elapsedHoursInt = elapsedHours.floor();
                  final int elapsedMinutes = isFastingActive
                      ? now.difference(session.startedAt).inMinutes % 60
                      : 0;

                  final Color phaseColor = _getPhaseColor(elapsedHours, c);

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    children: [
                      // 1. Tarjeta Hero con Círculo de Progreso
                      HealthCard(
                        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                        child: Column(
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 200,
                                  height: 200,
                                  child: CircularProgressIndicator(
                                    value: isFastingActive ? progressRatio : 0.0,
                                    strokeWidth: 14,
                                    strokeCap: StrokeCap.round,
                                    backgroundColor: c.bg3,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isFastingActive ? phaseColor : c.line2,
                                    ),
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isFastingActive ? AppIcons.ayunoFilled : AppIcons.ayuno,
                                      size: 32,
                                      color: isFastingActive ? phaseColor : c.text3,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      isFastingActive
                                          ? '${elapsedHoursInt}h ${elapsedMinutes}m'
                                          : '0h 00m',
                                      style: TextStyle(
                                        fontFamily: ScFonts.display,
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        color: c.text,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isFastingActive
                                          ? 'Meta: ${session.targetHours}h (${(progressRatio * 100).toInt()}%)'
                                          : 'Sin ayuno activo',
                                      style: TextStyle(
                                        fontFamily: ScFonts.ui,
                                        fontSize: 12,
                                        color: c.text2,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Fila de Estados / Horas Inicio y Fin
                            if (isFastingActive)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  Column(
                                    children: [
                                      Text(
                                        'Inicio',
                                        style: TextStyle(fontFamily: ScFonts.ui, fontSize: 11, color: c.text3),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${session.startedAt.hour.toString().padLeft(2, '0')}:${session.startedAt.minute.toString().padLeft(2, '0')}',
                                        style: TextStyle(
                                          fontFamily: ScFonts.display,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: c.text,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(width: 1, height: 28, color: c.line),
                                  Column(
                                    children: [
                                      Text(
                                        'Protocolo',
                                        style: TextStyle(fontFamily: ScFonts.ui, fontSize: 11, color: c.text3),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        session.protocolName,
                                        style: TextStyle(
                                          fontFamily: ScFonts.display,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: c.accent,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(width: 1, height: 28, color: c.line),
                                  Column(
                                    children: [
                                      Text(
                                        'Fin Planeado',
                                        style: TextStyle(fontFamily: ScFonts.ui, fontSize: 11, color: c.text3),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${session.plannedEndAt.hour.toString().padLeft(2, '0')}:${session.plannedEndAt.minute.toString().padLeft(2, '0')}',
                                        style: TextStyle(
                                          fontFamily: ScFonts.display,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: c.text,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                            const SizedBox(height: 24),

                            // Botón de Acción Principal (Iniciar o Finalizar)
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: isFastingActive ? Colors.redAccent.shade700 : c.accent,
                                  foregroundColor: isFastingActive ? Colors.white : c.ink,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: () async {
                                  await HapticFeedback.heavyImpact();
                                  if (isFastingActive) {
                                    if (!context.mounted) return;
                                    final bool? confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        backgroundColor: c.bg2,
                                        title: const Text('¿Romper ayuno?'),
                                        content: const Text(
                                          'Tu esfuerzo quedará registrado con éxito en el diario biológico.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(ctx).pop(false),
                                            child: const Text('Continuar ayunando'),
                                          ),
                                          FilledButton(
                                            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                                            onPressed: () => Navigator.of(ctx).pop(true),
                                            child: const Text('Romper ayuno'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      await fastingDao.endFast(
                                        sessionId: session.id,
                                        notes: 'Ayuno completado con éxito.',
                                      );
                                    }
                                  } else {
                                    await fastingDao.startFast(
                                      protocolName: _selectedProtocol,
                                      targetHours: _targetHours,
                                      startedAt: DateTime.now(),
                                    );
                                  }
                                },
                                child: Text(
                                  isFastingActive ? 'Romper Ayuno' : 'Iniciar Ayuno ($_selectedProtocol)',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 2. Selector de Protocolos (si no hay ayuno activo)
                      if (!isFastingActive) ...[
                        const SectionHead(
                          title: 'Elegir Protocolo de Ayuno',
                          subtitle: 'Selecciona la ventana ideal según tus objetivos',
                        ),
                        const SizedBox(height: 8),
                        for (final p in _protocols)
                          Builder(
                            builder: (context) {
                              final String protoName = p['name'] as String;
                              final int protoHours = p['hours'] as int;
                              final String protoLabel = p['label'] as String;
                              final bool isSelected = _selectedProtocol == protoName;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: HealthCard(
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                  onTap: () => _selectProtocol(protoName, protoHours),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isSelected ? c.accent : c.line2,
                                            width: isSelected ? 2.5 : 1.5,
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
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              protoName,
                                              style: TextStyle(
                                                fontFamily: ScFonts.display,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: c.text,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              protoLabel,
                                              style: TextStyle(
                                                fontFamily: ScFonts.ui,
                                                fontSize: 12,
                                                color: c.text2,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '$protoHours horas',
                                        style: TextStyle(
                                          fontFamily: ScFonts.ui,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: c.accent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 16),
                      ],

                      // 3. Fases Metabólicas (Línea de Tiempo Médica)
                      const SectionHead(
                        title: 'Fases Metabólicas',
                        subtitle: 'Evolución biológica minuto a minuto',
                      ),
                      const SizedBox(height: 8),
                      HealthCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _PhaseTimelineStep(
                              hoursLabel: '0 - 4h',
                              title: 'Fase Anabólica',
                              subtitle: 'Digestión y absorción de nutrientes.',
                              isActive: isFastingActive && elapsedHours < 4.0,
                              isCompleted: isFastingActive && elapsedHours >= 4.0,
                              color: const Color(0xFF64B5F6),
                            ),
                            _PhaseTimelineStep(
                              hoursLabel: '4 - 12h',
                              title: 'Glucogenólisis',
                              subtitle: 'Liberación de glucógeno; la insulina baja al nivel basal.',
                              isActive: isFastingActive && elapsedHours >= 4.0 && elapsedHours < 12.0,
                              isCompleted: isFastingActive && elapsedHours >= 12.0,
                              color: const Color(0xFF81C784),
                            ),
                            _PhaseTimelineStep(
                              hoursLabel: '12 - 18h',
                              title: 'Lipólisis y Quema de Grasa',
                              subtitle: 'Activación de lipasa y aura energética de Nibi.',
                              isActive: isFastingActive && elapsedHours >= 12.0 && elapsedHours < 18.0,
                              isCompleted: isFastingActive && elapsedHours >= 18.0,
                              color: const Color(0xFFFFB74D),
                            ),
                            _PhaseTimelineStep(
                              hoursLabel: '18 - 24h',
                              title: 'Cetosis Activa',
                              subtitle: 'Producción de cuerpos cetónicos y lucidez mental.',
                              isActive: isFastingActive && elapsedHours >= 18.0 && elapsedHours < 24.0,
                              isCompleted: isFastingActive && elapsedHours >= 24.0,
                              color: const Color(0xFFFF7043),
                            ),
                            _PhaseTimelineStep(
                              hoursLabel: '24h+',
                              title: 'Autofagia Profunda',
                              subtitle: 'Reciclaje celular y longevidad celular.',
                              isActive: isFastingActive && elapsedHours >= 24.0,
                              isCompleted: false,
                              color: c.fasting,
                              isLast: true,
                            ),
                          ],
                        ),
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted
                    ? color
                    : (isActive ? color : c.bg3),
                border: Border.all(
                  color: isActive ? color : c.line,
                  width: isActive ? 2.5 : 1.0,
                ),
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : (isActive
                        ? Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: c.ink))
                        : null),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 48,
                color: isCompleted ? color.withValues(alpha: 0.6) : c.line,
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 13,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                        color: isActive ? color : c.text,
                      ),
                    ),
                    Text(
                      hoursLabel,
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: c.text3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: 11,
                    color: c.text2,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
