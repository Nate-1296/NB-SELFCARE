import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/pet_dao.dart';
import '../../../core/database/daos/user_profile_dao.dart';
import '../../../shared/widgets/nxtpaper_card.dart';
import '../../body_metrics/presentation/body_and_workout_screen.dart';

/// Pantalla principal y centro de mando de NB Selfcare.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({required this.profile, super.key});

  final UserProfile profile;

  double get _derivedAge {
    return DateTime.now().difference(profile.birthDate).inDays / 365.25;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final String currentEngine = ref.watch(themeEngineProvider);
    final AsyncValue<PetStatusData?> petStatusAsync = ref.watch(petStatusStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Hola, ${profile.name}'),
        actions: [
          IconButton(
            tooltip: currentEngine == 'nxtpaper_eink'
                ? 'Cambiar a Material You'
                : 'Cambiar a Modo Papel NXTPAPER',
            icon: Icon(
              currentEngine == 'nxtpaper_eink'
                  ? Icons.palette_outlined
                  : Icons.menu_book_outlined,
            ),
            onPressed: () {
              final notifier = ref.read(themeEngineProvider.notifier);
              notifier.toggle();
              unawaited(
                ref.read(userProfileDaoProvider).updateThemeMode(
                      currentEngine == 'nxtpaper_eink'
                          ? 'material_you'
                          : 'nxtpaper_eink',
                    ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          children: [
            // Resumen de Monedas y Racha
            petStatusAsync.when(
              data: (pet) {
                final int coins = pet?.coinsBalance ?? 0;
                final int streak = pet?.currentStreakDays ?? 0;
                final int shields = pet?.streakShieldsAvailable ?? 0;

                return NxtpaperCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.monetization_on_rounded, color: Colors.amber),
                              const SizedBox(width: 4.0),
                              Text(
                                '$coins',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2.0),
                          Text('Monedas Nibi', style: theme.textTheme.bodySmall),
                        ],
                      ),
                      Container(
                        height: 36,
                        width: 1,
                        color: theme.colorScheme.outlineVariant,
                      ),
                      Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.local_fire_department_rounded, color: Colors.deepOrange),
                              const SizedBox(width: 4.0),
                              Text(
                                '$streak d',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2.0),
                          Text('Racha Positiva', style: theme.textTheme.bodySmall),
                        ],
                      ),
                      Container(
                        height: 36,
                        width: 1,
                        color: theme.colorScheme.outlineVariant,
                      ),
                      Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.shield_outlined, color: Colors.blueAccent),
                              const SizedBox(width: 4.0),
                              Text(
                                '$shields',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2.0),
                          Text('Escudos de Racha', style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: LinearProgressIndicator()),
              error: (err, _) => Text('Error al cargar mascota: $err'),
            ),
            const SizedBox(height: 16.0),

            // Tarjeta de Perfil Biométrico Dinámico
            NxtpaperCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.monitor_weight_outlined, color: theme.colorScheme.primary),
                          const SizedBox(width: 8.0),
                          Text(
                            'Perfil Biométrico Dinámico',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Chip(
                        label: Text(
                          '${_derivedAge.toStringAsFixed(1)} años',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: theme.colorScheme.primaryContainer,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12.0),
                  Text(
                    'Altura: ${profile.heightCm.toStringAsFixed(0)} cm · Sexo: ${profile.biologicalSex == 'male' ? 'Masculino' : 'Femenino'} · Peso Meta: ${profile.targetWeightKg.toStringAsFixed(1)} kg',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 6.0),
                  Text(
                    'Meta de Agua: ${profile.dailyWaterGoalMl} ml · Pasos: ${profile.dailyStepsGoal} · TDEE Adaptativo: ${profile.currentAdaptiveTdeeKcal} kcal',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16.0),

            // Bento Grid: Módulos del Sistema
            Text(
              'Módulos del Santuario',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8.0),

            Row(
              children: [
                Expanded(
                  child: NxtpaperCard(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const BodyAndWorkoutScreen(),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.scale_rounded, color: Colors.teal, size: 28),
                        const SizedBox(height: 8.0),
                        Text(
                          'Laboratorio Corporal',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          'Mi Scale 2 BLE & 13 Métricas',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: NxtpaperCard(
                    onTap: () {
                      // Módulo preparado para enlazar con Fase 3
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.restaurant_rounded, color: Colors.orange, size: 28),
                        const SizedBox(height: 8.0),
                        Text(
                          'Nutrición & OFF',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          'Electrolitos y Escáner',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12.0),
            Row(
              children: [
                Expanded(
                  child: NxtpaperCard(
                    onTap: () {
                      // Módulo preparado para enlazar con Fase 5
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.timer_outlined, color: Colors.purple, size: 28),
                        const SizedBox(height: 8.0),
                        Text(
                          'Ayuno Intermitente',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          'Fases metabólicas',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: NxtpaperCard(
                    onTap: () {
                      // Módulo preparado para enlazar con Fase 5
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.auto_stories_outlined, color: Colors.indigo, size: 28),
                        const SizedBox(height: 8.0),
                        Text(
                          'Diario & Analítica',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          'Correlaciones cruzadas',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24.0),

            // Estado del Motor Visual
            Center(
              child: Text(
                'Motor Activo: ${currentEngine == 'nxtpaper_eink' ? 'Modo Papel E-Ink (TCL NXTPAPER)' : 'Material You Monet'}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
