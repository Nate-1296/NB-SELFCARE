import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/journal_dao.dart';
import '../../../core/database/daos/user_profile_dao.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/services/cross_analytics_engine.dart';
import '../../../core/services/local_ai_service.dart';
import '../../../shared/utils/date_time_extensions.dart';
import '../../../shared/widgets/nxtpaper_card.dart';

/// Pantalla unificada de Diario Privado, Analítica Cruzada y Perfil Vivo.
class JournalAnalyticsProfileScreen extends ConsumerStatefulWidget {
  const JournalAnalyticsProfileScreen({super.key});

  @override
  ConsumerState<JournalAnalyticsProfileScreen> createState() =>
      _JournalAnalyticsProfileScreenState();
}

class _JournalAnalyticsProfileScreenState
    extends ConsumerState<JournalAnalyticsProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final _entryController = TextEditingController();
  int _moodScore = 4;
  int _energyLevel = 4;
  int _stressLevel = 2;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  Future<void> _saveJournalEntry() async {
    final text = _entryController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final companion = JournalEntriesCompanion(
        dateKey: drift.Value(now.dateKey),
        createdAt: drift.Value(now),
        content: drift.Value(text),
        moodScore: drift.Value(_moodScore),
        energyLevel: drift.Value(_energyLevel),
        stressLevel: drift.Value(_stressLevel),
        tagsJson: const drift.Value('["reflexion_personal"]'),
      );

      final journalDao = ref.read(journalDaoProvider);
      await journalDao.insertEntry(companion);

      _entryController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Entrada de diario guardada! (+10 Monedas Nibi)'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<UserProfile?> profileAsync = ref.watch(userProfileStreamProvider);

    return profileAsync.when(
      data: (UserProfile? profile) {
        if (profile == null) {
          return const Scaffold(body: Center(child: Text('Perfil no encontrado')));
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Diario, Analítica y Perfil'),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.book_outlined), text: 'Diario'),
                Tab(icon: Icon(Icons.insights_rounded), text: 'Analítica'),
                Tab(icon: Icon(Icons.person_outline), text: 'Perfil'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Diario Privado
              _buildJournalTab(theme),

              // Tab 2: Analítica Cruzada
              _buildAnalyticsTab(theme),

              // Tab 3: Perfil Vivo y Respaldo SQLite
              _buildProfileTab(theme, profile),
            ],
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }

  Widget _buildJournalTab(ThemeData theme) {
    final journalDao = ref.watch(journalDaoProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      children: [
        NxtpaperCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.lock_outline_rounded, color: Colors.teal, size: 20),
                  const SizedBox(width: 6.0),
                  Text(
                    'Tu Diario 100% Privado y Offline',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12.0),
              TextField(
                controller: _entryController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: '¿Cómo te sentiste hoy? Energía, sensaciones corporales, reflexiones...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 6.0),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    final text = _entryController.text.trim();
                    if (text.isEmpty) return;

                    final aiService = ref.read(localAiServiceProvider);
                    final analysis = await aiService.analyzeJournal(text);

                    setState(() {
                      _moodScore = analysis.moodScore;
                      _energyLevel = analysis.energyLevel;
                      _stressLevel = analysis.stressLevel;
                    });

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('IA Local: "${analysis.oneLineInsight}"'),
                          backgroundColor: Colors.teal,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Auto-evaluar con IA Local'),
                ),
              ),
              const SizedBox(height: 10.0),

              // Sliders de Estado de Ánimo, Energía y Estrés
              Text('Estado de Ánimo (1 = Bajo, 5 = Excelente): $_moodScore/5'),
              Slider(
                value: _moodScore.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                onChanged: (v) => setState(() => _moodScore = v.toInt()),
              ),
              const SizedBox(height: 4.0),

              Text('Nivel de Energía: $_energyLevel/5'),
              Slider(
                value: _energyLevel.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                onChanged: (v) => setState(() => _energyLevel = v.toInt()),
              ),
              const SizedBox(height: 4.0),

              Text('Nivel de Estrés: $_stressLevel/5'),
              Slider(
                value: _stressLevel.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                activeColor: Colors.deepOrange,
                onChanged: (v) => setState(() => _stressLevel = v.toInt()),
              ),
              const SizedBox(height: 12.0),

              FilledButton.icon(
                onPressed: _isSaving ? null : _saveJournalEntry,
                icon: const Icon(Icons.save_outlined),
                label: Text(_isSaving ? 'Guardando...' : 'Guardar Entrada en SQLite'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16.0),

        // Entradas Anteriores
        Text(
          'Entradas Recientes',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8.0),

        StreamBuilder<List<JournalEntry>>(
          stream: journalDao.watchRecentEntries(),
          builder: (context, snapshot) {
            final entries = snapshot.data ?? [];
            if (entries.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(
                  child: Text('Aún no has escrito entradas en tu diario.', style: TextStyle(color: Colors.grey)),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8.0),
              itemBuilder: (c, idx) {
                final entry = entries[idx];
                return NxtpaperCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(entry.dateKey, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Row(
                            children: [
                              Chip(
                                label: Text('Ánimo ${entry.moodScore}/5'),
                                visualDensity: VisualDensity.compact,
                              ),
                              const SizedBox(width: 4.0),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18),
                                onPressed: () => journalDao.deleteEntry(entry.id),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6.0),
                      Text(entry.content, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 32.0),
      ],
    );
  }

  Widget _buildAnalyticsTab(ThemeData theme) {
    final analyticsEngine = ref.watch(crossAnalyticsEngineProvider);

    return FutureBuilder<List<CrossCorrelationInsight>>(
      future: analyticsEngine.computeInsights(),
      builder: (context, snapshot) {
        final insights = snapshot.data ?? [];

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          children: [
            NxtpaperCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.analytics_outlined, color: Colors.indigo, size: 22),
                      const SizedBox(width: 8.0),
                      Text(
                        'Motor Estadístico de Pearson',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    'Cruza tus variables biométricas (sueño, estrés, ayuno y peso) '
                    'buscando relaciones significativas tras 10+ días de registro.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16.0),

            if (insights.isEmpty) ...[
              NxtpaperCard(
                color: Colors.blue.withValues(alpha: 0.08),
                child: Column(
                  children: [
                    const Icon(Icons.lightbulb_outline, size: 36, color: Colors.blue),
                    const SizedBox(height: 8.0),
                    const Text(
                      'Reuniendo Datos para Analítica Cruzada',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      'Continúa registrando tus comidas, ayunos y diario. '
                      'El motor Pearson requiere al menos 10 pares de datos válidos para generar correlaciones con honestidad estadística.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ] else ...[
              ...insights.map((insight) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: NxtpaperCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(insight.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Chip(
                              label: Text('r = ${insight.correlationR.toStringAsFixed(2)}'),
                              backgroundColor: Colors.teal.shade50,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4.0),
                        Text(insight.strengthLabel, style: const TextStyle(fontSize: 11, color: Colors.teal, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8.0),
                        Text(insight.description, style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 6.0),
                        Text('Muestra: ${insight.sampleSize} días evaluados', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                );
              }),
            ],
            const SizedBox(height: 32.0),
          ],
        );
      },
    );
  }

  Widget _buildProfileTab(ThemeData theme, UserProfile profile) {
    final backupService = ref.watch(backupServiceProvider);
    final double age = DateTime.now().difference(profile.birthDate).inDays / 365.25;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      children: [
        NxtpaperCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(profile.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  Chip(
                    label: Text('${age.toStringAsFixed(1)} años'),
                    backgroundColor: theme.colorScheme.primaryContainer,
                  ),
                ],
              ),
              const SizedBox(height: 8.0),
              Text('Sexo Biológico: ${profile.biologicalSex == "male" ? "Masculino" : "Femenino"}'),
              Text('Estatura: ${profile.heightCm.toStringAsFixed(0)} cm'),
              Text('Peso Objetivo: ${profile.targetWeightKg.toStringAsFixed(1)} kg'),
              Text('TDEE Adaptativo Actual: ${profile.currentAdaptiveTdeeKcal} kcal'),
              Text('Meta Diaria de Agua: ${profile.dailyWaterGoalMl} ml'),
              Text('Meta Diaria de Pasos: ${profile.dailyStepsGoal}'),
            ],
          ),
        ),
        const SizedBox(height: 16.0),

        // Sección Portabilidad Total: Respaldo .sqlite
        NxtpaperCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.save_rounded, color: Colors.teal, size: 22),
                  const SizedBox(width: 8.0),
                  Text(
                    'Portabilidad Total y Copia de Seguridad',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8.0),
              Text(
                'Tu santuario es 100% tuyo. Exporta o comparte un único archivo .sqlite '
                'limpio generado con VACUUM INTO, compatible con cualquier lector SQLite estándar.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16.0),
              FilledButton.icon(
                onPressed: () async {
                  try {
                    await backupService.shareDatabaseBackup();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error al exportar: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.share_outlined),
                label: const Text('Exportar y Compartir .sqlite'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32.0),
      ],
    );
  }
}
