import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/body_measurements_dao.dart';
import '../../../core/database/daos/food_dao.dart';
import '../../../core/database/daos/hydration_dao.dart';
import '../../../core/database/daos/pet_dao.dart';
import '../../../core/database/daos/user_profile_dao.dart';
import '../../../shared/utils/date_time_extensions.dart';
import '../../../shared/widgets/nxtpaper_card.dart';
import '../../../shared/widgets/reactive_macro_ring.dart';
import '../../body_metrics/presentation/body_and_workout_screen.dart';
import '../../nutrition_hydration/presentation/nutrition_screen.dart';
import 'widgets/pet_habitat_widget.dart';

/// Pantalla principal y centro de mando de NB Selfcare.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({required this.profile, super.key});

  final UserProfile profile;

  double get _derivedAge {
    return DateTime.now().difference(profile.birthDate).inDays / 365.25;
  }

  String get _todayDateKey => DateTime.now().dateKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final String currentEngine = ref.watch(themeEngineProvider);
    final AsyncValue<PetStatusData?> petStatusAsync = ref.watch(petStatusStreamProvider);
    final AsyncValue<BodyMeasurement?> latestMeasurementAsync = ref.watch(latestMeasurementStreamProvider);
    final foodDao = ref.watch(foodDaoProvider);
    final hydrationDao = ref.watch(hydrationDaoProvider);

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

            // Hábitat de Nibi y Diálogo Contextual
            StreamBuilder<int>(
              stream: hydrationDao.watchTotalWaterMl(_todayDateKey),
              builder: (context, waterSnapshot) {
                final int totalWater = waterSnapshot.data ?? 0;
                final double hydrationRatio = profile.dailyWaterGoalMl > 0
                    ? (totalWater / profile.dailyWaterGoalMl).clamp(0.0, 1.5)
                    : 0.8;

                return PetHabitatWidget(
                  profile: profile,
                  hydrationRatio: hydrationRatio,
                  isFastingKetosis: false,
                );
              },
            ),
            const SizedBox(height: 16.0),

            // Anillos de Calorías y Bento Grid Nutricional
            StreamBuilder<List<FoodLog>>(
              stream: foodDao.watchLogsForDate(_todayDateKey),
              builder: (context, logsSnapshot) {
                final logs = logsSnapshot.data ?? [];
                double consumedKcal = 0;
                double pGrams = 0;
                double cGrams = 0;
                double fGrams = 0;

                for (final l in logs) {
                  consumedKcal += l.totalKcal;
                  pGrams += l.totalProteinG;
                  cGrams += l.totalCarbsG;
                  fGrams += l.totalFatG;
                }

                final double targetKcal = profile.currentAdaptiveTdeeKcal.toDouble();

                return NxtpaperCard(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Calorías y Balance Nutricional',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const NutritionScreen(),
                                ),
                              );
                            },
                            child: const Text('Ver Detalle'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12.0),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          ReactiveMacroRing(
                            consumedCalories: consumedKcal,
                            targetCalories: targetKcal,
                            proteinRatio: (pGrams / 150.0).clamp(0.0, 1.0),
                            carbsRatio: (cGrams / 220.0).clamp(0.0, 1.0),
                            fatRatio: (fGrams / 65.0).clamp(0.0, 1.0),
                            size: 150,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _NutrientRow(label: 'Consumidas', value: '${consumedKcal.toStringAsFixed(0)} kcal', color: Colors.teal),
                              const SizedBox(height: 6.0),
                              _NutrientRow(label: 'Meta TDEE', value: '${targetKcal.toStringAsFixed(0)} kcal', color: theme.colorScheme.onSurface),
                              const SizedBox(height: 6.0),
                              _NutrientRow(label: 'Proteína', value: '${pGrams.toStringAsFixed(0)}g', color: Colors.blue),
                              const SizedBox(height: 6.0),
                              _NutrientRow(label: 'Carbos', value: '${cGrams.toStringAsFixed(0)}g', color: Colors.amber.shade800),
                              const SizedBox(height: 6.0),
                              _NutrientRow(label: 'Grasa', value: '${fGrams.toStringAsFixed(0)}g', color: Colors.purple),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16.0),

            // Bento Grid: Hidratación y Peso Tendencia
            Row(
              children: [
                // Bento 1: Hidratación en Vivo
                Expanded(
                  child: StreamBuilder<int>(
                    stream: hydrationDao.watchTotalWaterMl(_todayDateKey),
                    builder: (context, snapshot) {
                      final int ml = snapshot.data ?? 0;
                      return NxtpaperCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Icon(Icons.water_drop, color: Colors.blue, size: 24),
                                Text('${profile.dailyWaterGoalMl} ml', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                            const SizedBox(height: 8.0),
                            Text('$ml ml', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            const Text('Agua de hoy', style: TextStyle(fontSize: 12)),
                            const SizedBox(height: 8.0),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                  onPressed: () {
                                    unawaited(
                                      hydrationDao.logGlass(
                                        dateKey: _todayDateKey,
                                        volumeMl: 250,
                                        dailyGoalMl: profile.dailyWaterGoalMl,
                                      ),
                                    );
                                  },
                                  child: const Text('+250ml', style: TextStyle(fontSize: 11)),
                                ),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                  onPressed: () {
                                    unawaited(
                                      hydrationDao.logGlass(
                                        dateKey: _todayDateKey,
                                        volumeMl: 500,
                                        dailyGoalMl: profile.dailyWaterGoalMl,
                                      ),
                                    );
                                  },
                                  child: const Text('+500ml', style: TextStyle(fontSize: 11)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12.0),

                // Bento 2: Peso y EMA
                Expanded(
                  child: latestMeasurementAsync.when(
                    data: (latest) {
                      final String weightStr = latest != null ? '${latest.weightKg.toStringAsFixed(1)} kg' : '--';
                      final String emaStr = latest != null ? '${latest.trendWeightKg.toStringAsFixed(1)} kg' : '--';

                      return NxtpaperCard(
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
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Icon(Icons.scale_rounded, color: Colors.teal, size: 24),
                                Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                              ],
                            ),
                            const SizedBox(height: 8.0),
                            Text(weightStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            const Text('Último peso', style: TextStyle(fontSize: 12)),
                            const SizedBox(height: 4.0),
                            Text('Tendencia EMA: $emaStr', style: const TextStyle(fontSize: 11, color: Colors.teal, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2.0),
                            Text('Meta: ${profile.targetWeightKg.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      );
                    },
                    loading: () => const NxtpaperCard(child: Center(child: LinearProgressIndicator())),
                    error: (_, _) => const NxtpaperCard(child: Text('Error')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16.0),

            // Dock de Acción Rápida (1 Toque)
            Text(
              'Acciones Rápidas (1 Toque)',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8.0),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const NutritionScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.qr_code_scanner, size: 18),
                    label: const Text('Escanear', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const BodyAndWorkoutScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.bluetooth_searching, size: 18),
                    label: const Text('Pesarme', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const BodyAndWorkoutScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.fitness_center, size: 18),
                    label: const Text('Entrenar', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20.0),

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

class _NutrientRow extends StatelessWidget {
  const _NutrientRow({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6.0),
        Text('$label: ', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
