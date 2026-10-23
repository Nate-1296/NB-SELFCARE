import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/fasting_dao.dart';
import '../../../shared/widgets/nxtpaper_card.dart';

/// Pantalla de Ayuno Intermitente, Fases Metabólicas y Cronobiología.
class FastingScreen extends ConsumerStatefulWidget {
  const FastingScreen({super.key});

  @override
  ConsumerState<FastingScreen> createState() => _FastingScreenState();
}

class _FastingScreenState extends ConsumerState<FastingScreen> {
  String _selectedProtocol = '16:8';
  int _targetHours = 16;

  void _selectProtocol(String protocol, int hours) {
    setState(() {
      _selectedProtocol = protocol;
      _targetHours = hours;
    });
  }

  String _getMetabolicPhaseName(double hours) {
    if (hours < 4.0) return 'Fase Anabólica (Digestión y absorción)';
    if (hours < 12.0) return 'Glucogenólisis (Caída de insulina a nivel basal)';
    if (hours < 18.0) return 'Lipólisis y Quema de Grasa (Aura de Nibi activa)';
    if (hours < 24.0) return 'Cetosis Activa (Producción de cuerpos cetónicos)';
    return 'Autofagia Profunda (Reciclaje celular y longevidad)';
  }

  String _getMetabolicPhaseDescription(double hours) {
    if (hours < 4.0) {
      return 'Los nutrientes consumidos se absorben en sangre. La insulina promueve el almacenamiento de energía.';
    }
    if (hours < 12.0) {
      return 'El hígado libera glucógeno almacenado para mantener la glucosa estable mientras la insulina desciende.';
    }
    if (hours < 18.0) {
      return 'Se agota el glucógeno hepático; la lipasa sensible a hormonas moviliza ácidos grasos para energía.';
    }
    if (hours < 24.0) {
      return 'El hígado convierte grasas en cetonas para alimentar el cerebro y músculos con máxima claridad mental.';
    }
    return 'Las células degradan orgánulos y proteínas dañadas. Asegura una buena ingesta de agua con sodio y magnesio.';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final fastingDao = ref.watch(fastingDaoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayuno Intermitente y Cronobiología'),
      ),
      body: StreamBuilder<FastingSession?>(
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

          final int elapsedMinutes = isFastingActive
              ? now.difference(session.startedAt).inMinutes % 60
              : 0;

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            children: [
              // Tarjeta Principal del Cronómetro
              NxtpaperCard(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              color: isFastingActive ? Colors.teal : Colors.grey,
                              size: 24,
                            ),
                            const SizedBox(width: 8.0),
                            Text(
                              isFastingActive
                                  ? 'Ayuno en Curso (${session.protocolName})'
                                  : 'Temporizador de Ayuno',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (isFastingActive)
                          Chip(
                            label: Text(
                              elapsedHours >= session.targetHours ? 'Meta Cumplida' : 'En Proceso',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                            backgroundColor: elapsedHours >= session.targetHours
                                ? Colors.green.shade100
                                : Colors.teal.shade100,
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16.0),

                    if (isFastingActive) ...[
                      Text(
                        '${elapsedHours.toInt()}h ${elapsedMinutes.toString().padLeft(2, '0')}m',
                        style: theme.textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      Text(
                        'Meta: ${session.targetHours} horas planificadas',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12.0),
                      LinearProgressIndicator(
                        value: progressRatio,
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      const SizedBox(height: 16.0),
                      FilledButton.icon(
                        onPressed: () async {
                          final bool completed = await fastingDao.endFast(sessionId: session.id);
                          if (context.mounted && completed) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  elapsedHours >= 14.0
                                      ? '¡Ayuno finalizado con éxito (${elapsedHours.toStringAsFixed(1)}h)! (+20 Monedas Nibi)'
                                      : 'Ayuno finalizado (${elapsedHours.toStringAsFixed(1)}h). ¡Buen esfuerzo!',
                                ),
                                backgroundColor: Colors.teal,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: const Text('Finalizar Ayuno y Registrar'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.teal,
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ] else ...[
                      Text(
                        'Selecciona tu protocolo:',
                        style: theme.textTheme.labelMedium,
                      ),
                      const SizedBox(height: 10.0),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: [
                          ChoiceChip(
                            label: const Text('16:8 (16h)'),
                            selected: _selectedProtocol == '16:8',
                            onSelected: (_) => _selectProtocol('16:8', 16),
                          ),
                          ChoiceChip(
                            label: const Text('18:6 (18h)'),
                            selected: _selectedProtocol == '18:6',
                            onSelected: (_) => _selectProtocol('18:6', 18),
                          ),
                          ChoiceChip(
                            label: const Text('20:4 (20h)'),
                            selected: _selectedProtocol == '20:4',
                            onSelected: (_) => _selectProtocol('20:4', 20),
                          ),
                          ChoiceChip(
                            label: const Text('OMAD 23:1 (23h)'),
                            selected: _selectedProtocol == 'OMAD',
                            onSelected: (_) => _selectProtocol('OMAD', 23),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16.0),
                      FilledButton.icon(
                        onPressed: () async {
                          await fastingDao.startFast(
                            protocolName: _selectedProtocol,
                            targetHours: _targetHours,
                            startedAt: DateTime.now(),
                          );
                        },
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text('Iniciar Ayuno de $_targetHours Horas'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16.0),

              // Fase Metabólica Actual
              NxtpaperCard(
                color: isFastingActive ? Colors.teal.withValues(alpha: 0.1) : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.science_outlined, color: Colors.teal),
                        const SizedBox(width: 8.0),
                        Text(
                          'Fase Fisiológica Actual',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      _getMetabolicPhaseName(elapsedHours),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade800,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      _getMetabolicPhaseDescription(elapsedHours),
                      style: theme.textTheme.bodySmall,
                    ),
                    if (elapsedHours >= 24.0) ...[
                      const SizedBox(height: 10.0),
                      Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.deepOrange, size: 20),
                            SizedBox(width: 8.0),
                            Expanded(
                              child: Text(
                                'Aviso de Seguridad: En ayunos mayores a 24h es indispensable mantener hidratación con electrolitos (sodio y magnesio).',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16.0),

              // Línea de Tiempo Educativa de las 5 Fases
              Text(
                'Línea de Tiempo Metabólica',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8.0),
              const _MetabolicStageCard(
                interval: '0 - 4 horas',
                title: 'Fase Anabólica',
                description: 'Absorción de glucosa y aminoácidos, elevación de insulina.',
              ),
              const SizedBox(height: 8.0),
              const _MetabolicStageCard(
                interval: '4 - 12 horas',
                title: 'Caída de Insulina',
                description: 'El hígado utiliza glucógeno para mantener glucemia basal.',
              ),
              const SizedBox(height: 8.0),
              const _MetabolicStageCard(
                interval: '12 - 18 horas',
                title: 'Lipólisis y Quema de Grasa',
                description: 'Beta-oxidación acelerada de ácidos grasos. Se activa el aura de Nibi.',
              ),
              const SizedBox(height: 8.0),
              const _MetabolicStageCard(
                interval: '18 - 24 horas',
                title: 'Cetosis Activa',
                description: 'Producción elevada de cuerpos cetónicos para cerebro y corazón.',
              ),
              const SizedBox(height: 8.0),
              const _MetabolicStageCard(
                interval: '> 24 horas',
                title: 'Autofagia Profunda',
                description: 'Limpieza lisosomal de proteínas y orgánulos envejecidos.',
              ),
              const SizedBox(height: 32.0),
            ],
          );
        },
      ),
    );
  }
}

class _MetabolicStageCard extends StatelessWidget {
  const _MetabolicStageCard({
    required this.interval,
    required this.title,
    required this.description,
  });

  final String interval;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return NxtpaperCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              interval,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal),
            ),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2.0),
                Text(description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
