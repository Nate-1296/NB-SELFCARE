import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/met_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/body_measurements_dao.dart';
import '../../../core/database/daos/fasting_dao.dart';
import '../../../core/database/daos/food_dao.dart';
import '../../../core/database/daos/hydration_dao.dart';
import '../../../core/database/daos/journal_dao.dart';
import '../../../core/database/daos/pet_dao.dart';
import '../../../core/database/daos/user_profile_dao.dart';
import '../../../core/database/daos/workout_dao.dart';
import '../../../core/services/health_connect_service.dart';
import '../../../core/services/local_ai_service.dart';
import '../../../shared/theme/sc_colors.dart';
import '../../../shared/theme/sc_theme.dart';
import '../../../shared/utils/biometric_formulas.dart';
import '../../../shared/utils/date_time_extensions.dart';
import '../../../shared/widgets/app_icons.dart';
import '../../../shared/widgets/chip_pill.dart';
import '../../../shared/widgets/health_card.dart';
import '../../../shared/widgets/section_head.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../shared/widgets/top_bar.dart';

/// Pestaña "Hoy": panel de control diario inspirado en el nuevo Samsung Health.
///
/// Presenta los anillos y barras de actividad (calorías, proteína, agua y pasos),
/// un dock de acciones en 1 toque y el estado de cronobiología sin ruido visual.
class HoyScreen extends ConsumerStatefulWidget {
  const HoyScreen({super.key});

  @override
  ConsumerState<HoyScreen> createState() => _HoyScreenState();
}

class _HoyScreenState extends ConsumerState<HoyScreen> {
  final DateTime _today = DateTime.now();
  String get _dateKey => _today.dateKey;
  String get _yesterdayDateKey =>
      _today.subtract(const Duration(days: 1)).dateKey;

  String _saludoSegunHora() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Buenos días';
    if (hour >= 12 && hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  Future<void> _logWaterGlass(int volumeMl, int goalMl) async {
    final hydrationDao = ref.read(hydrationDaoProvider);
    await hydrationDao.logGlass(
      dateKey: _dateKey,
      volumeMl: volumeMl,
      dailyGoalMl: goalMl,
    );

    final healthConnect = ref.read(healthConnectServiceProvider);
    unawaited(
      healthConnect.writeHydration(
        amountMl: volumeMl,
        timestamp: DateTime.now(),
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('+$volumeMl ml de agua registrados 💧'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _repeatYesterday() async {
    final foodDao = ref.read(foodDaoProvider);
    int total = 0;
    for (final meal in ['breakfast', 'lunch', 'dinner', 'snack']) {
      final inserted = await foodDao.repeatMealFromYesterday(
        fromDateKey: _yesterdayDateKey,
        toDateKey: _dateKey,
        mealType: meal,
      );
      total += inserted.length;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(total > 0
              ? '¡Repetidas las comidas de ayer ($total alimentos)!'
              : 'No hay comidas registradas ayer para repetir'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _openQuickWeighInModal(UserProfile profile) {
    final latestMeas = ref.read(latestMeasurementStreamProvider).value;
    final weightCtrl = TextEditingController(text: (latestMeas?.weightKg ?? 70.0).toStringAsFixed(1));

    unawaited(showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar Peso'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: weightCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Peso corporal',
                suffixText: 'kg',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              final double? w = double.tryParse(weightCtrl.text.trim());
              if (w != null && w > 0) {
                Navigator.of(ctx).pop();
                final double bmi = BiometricFormulas.calculateBmi(
                  weightKg: w,
                  heightCm: profile.heightCm,
                );
                final double ema = BiometricFormulas.calculateWeightEma(
                  currentWeightKg: w,
                  previousEmaKg: latestMeas?.trendWeightKg,
                );

                final now = DateTime.now();
                await ref.read(bodyMeasurementsDaoProvider).insertMeasurement(
                  BodyMeasurementsCompanion.insert(
                    measuredAt: drift.Value(now),
                    dateKey: now.dateKey,
                    source: 'manual_hoy',
                    weightKg: w,
                    trendWeightKg: ema,
                    bmi: bmi,
                    bodyFatPercentage: drift.Value(latestMeas?.bodyFatPercentage),
                    muscleMassKg: drift.Value(latestMeas?.muscleMassKg),
                    waterPercentage: drift.Value(latestMeas?.waterPercentage),
                    visceralFatIndex: drift.Value(latestMeas?.visceralFatIndex),
                    boneMassKg: drift.Value(latestMeas?.boneMassKg),
                    proteinPercentage: drift.Value(latestMeas?.proteinPercentage),
                    basalMetabolicRateKcal: drift.Value(latestMeas?.basalMetabolicRateKcal),
                    metabolicAge: drift.Value(latestMeas?.metabolicAge),
                    leanBodyMassKg: drift.Value(latestMeas?.leanBodyMassKg),
                    bodyScore: drift.Value(latestMeas?.bodyScore),
                    somatotype: drift.Value(latestMeas?.somatotype),
                  ),
                );

                await ref.read(petDaoProvider).grantDailyReward(
                  dateKey: now.dateKey,
                  actionType: 'weigh_in',
                  baseAmount: 15,
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('¡Peso registrado: ${w.toStringAsFixed(1)} kg! (+15 Monedas)')),
                  );
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ));
  }

  void _openJournalModal() {
    final journalCtrl = TextEditingController();
    int mood = 4;
    final List<String> moodEmojis = ['😞', '😐', '🙂', '😊', '🤩'];
    bool isSaving = false;

    unawaited(mostrarHojaMenu<void>(
      context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final c = context.sc;
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 14,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Reflexión del Día',
                        style: TextStyle(
                          fontFamily: ScFonts.display,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '¿Cómo te has sentido hoy? Registra tus pensamientos en un entorno 100% privado.',
                    style: TextStyle(fontFamily: ScFonts.ui, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(moodEmojis.length, (idx) {
                      final score = idx + 1;
                      final isSelected = mood == score;
                      return GestureDetector(
                        onTap: () => setModalState(() => mood = score),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? c.accent.withValues(alpha: 0.2) : Colors.transparent,
                            border: Border.all(
                              color: isSelected ? c.accent : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Text(moodEmojis[idx], style: const TextStyle(fontSize: 26)),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: journalCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Hoy me sentí con buena energía tras caminar por la mañana...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final text = journalCtrl.text.trim();
                              if (text.isEmpty) return;

                              setModalState(() => isSaving = true);
                              final now = DateTime.now();
                              final localAi = ref.read(localAiServiceProvider);
                              final analysis = await localAi.analyzeJournal(text);

                              await ref.read(journalDaoProvider).insertEntry(
                                    JournalEntriesCompanion.insert(
                                      dateKey: now.dateKey,
                                      content: text,
                                      moodScore: drift.Value(mood),
                                      energyLevel: const drift.Value(4),
                                      stressLevel: const drift.Value(2),
                                      tagsJson: drift.Value('["${analysis.tags.join('","')}"]'),
                                      aiInsightSummary: drift.Value(analysis.oneLineInsight),
                                      createdAt: drift.Value(now),
                                    ),
                                  );

                              await ref.read(petDaoProvider).grantDailyReward(
                                    dateKey: now.dateKey,
                                    actionType: 'journal_entry',
                                    baseAmount: 10,
                                  );

                              if (context.mounted) {
                                Navigator.of(ctx).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('¡Reflexión guardada! (+10 Monedas Nibi) 🪙')),
                                );
                              }
                            },
                      icon: const Icon(Icons.check),
                      label: Text(isSaving ? 'Guardando...' : 'Guardar Reflexión'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ));
  }

  void _openQuickWorkoutModal(UserProfile profile) {
    unawaited(mostrarHojaMenu<void>(
      context,
      builder: (ctx) {
        WorkoutCategory selectedCategory = WorkoutCategory.weights;
        RpeIntensity selectedRpe = RpeIntensity.moderate;
        int durationMinutes = 45;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final latestMeas = ref.watch(latestMeasurementStreamProvider).value;
            final double userWeight =
                latestMeas?.weightKg ?? profile.targetWeightKg;
            final double met =
                MetConstants.getMet(selectedCategory, selectedRpe);
            final double netKcal =
                BiometricFormulas.calculateNetExerciseCalories(
              met: met,
              weightKg: userWeight,
              durationMinutes: durationMinutes,
            );

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Entrenamiento en 5 Segundos',
                        style: TextStyle(
                          fontFamily: ScFonts.display,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('1. Disciplina',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  SegmentedButton<WorkoutCategory>(
                    segments: const [
                      ButtonSegment(
                          value: WorkoutCategory.weights, label: Text('Pesas')),
                      ButtonSegment(
                          value: WorkoutCategory.calisthenics,
                          label: Text('Funcional')),
                      ButtonSegment(
                          value: WorkoutCategory.cardio, label: Text('Cardio')),
                      ButtonSegment(
                          value: WorkoutCategory.sports,
                          label: Text('Deporte')),
                    ],
                    selected: {selectedCategory},
                    onSelectionChanged: (set) =>
                        setModalState(() => selectedCategory = set.first),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('2. Duración:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('$durationMinutes min',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: durationMinutes.toDouble(),
                    min: 10,
                    max: 180,
                    divisions: 17,
                    label: '$durationMinutes min',
                    onChanged: (val) =>
                        setModalState(() => durationMinutes = val.toInt()),
                  ),
                  const SizedBox(height: 8),
                  const Text('3. Esfuerzo (RPE)',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  SegmentedButton<RpeIntensity>(
                    segments: const [
                      ButtonSegment(
                          value: RpeIntensity.light, label: Text('Ligero')),
                      ButtonSegment(
                          value: RpeIntensity.moderate,
                          label: Text('Moderado')),
                      ButtonSegment(
                          value: RpeIntensity.intense, label: Text('Intenso')),
                    ],
                    selected: {selectedRpe},
                    onSelectionChanged: (set) =>
                        setModalState(() => selectedRpe = set.first),
                  ),
                  const SizedBox(height: 16),
                  HealthCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.all(12),
                    backgroundColor: Colors.amber.withValues(alpha: 0.12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Gasto neto estimado:',
                                style: TextStyle(fontSize: 12)),
                            Text(
                              '${netKcal.toStringAsFixed(0)} kcal netas',
                              style: const TextStyle(
                                fontFamily: ScFonts.display,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.deepOrange,
                              ),
                            ),
                          ],
                        ),
                        Text('MET: ${met.toStringAsFixed(1)}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () async {
                      final now = DateTime.now();
                      final companion = WorkoutBlocksCompanion.insert(
                        dateKey: now.dateKey,
                        category: selectedCategory.name,
                        durationMinutes: durationMinutes,
                        rpeIntensity: selectedRpe.name,
                        appliedMet: met,
                        userWeightAtTimeKg: userWeight,
                        netCaloriesBurned: netKcal.round(),
                        performedAt: drift.Value(now),
                      );

                      await ref.read(workoutDaoProvider).insertWorkout(companion);
                      await ref.read(petDaoProvider).grantDailyReward(
                            dateKey: now.dateKey,
                            actionType: 'workout_done',
                            baseAmount: 20,
                          );

                      if (context.mounted) {
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                '¡Entrenamiento registrado! ${netKcal.toStringAsFixed(0)} kcal netas (+20 monedas)'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(AppIcons.protein),
                    label: const Text('Registrar en 5 segundos'),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48)),
                  ),
                ],
              ),
            );
          },
        );
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AsyncValue<UserProfile?> profileAsync =
        ref.watch(userProfileStreamProvider);

    return profileAsync.when(
      data: (UserProfile? profile) {
        if (profile == null) {
          return const Scaffold(
              body: Center(child: Text('Perfil no inicializado')));
        }

        final String saludo =
            '${_saludoSegunHora()}, ${profile.name.split(" ").first}';
        final foodDao = ref.watch(foodDaoProvider);
        final hydrationDao = ref.watch(hydrationDaoProvider);
        final workoutDao = ref.watch(workoutDaoProvider);
        final fastingDao = ref.watch(fastingDaoProvider);

        return Scaffold(
          body: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: <Widget>[
              TopBar(
                title: saludo,
                subtitle: null,
                avatarInicial: profile.name.isNotEmpty ? profile.name[0] : 'N',
                avatarFoto: profile.avatarPath != null && File(profile.avatarPath!).existsSync()
                    ? FileImage(File(profile.avatarPath!))
                    : null,
                large: true,
                onProfile: () => context.go('/perfil'),
              ),

              // 1. Tarjeta Resumen de Actividad Diaria (Estilo Samsung Health)
              StreamBuilder<List<FoodLog>>(
                stream: foodDao.watchLogsForDate(_dateKey),
                builder: (context, foodSnap) {
                  final logs = foodSnap.data ?? [];
                  final double consumedKcal = logs.fold(
                      0.0, (acc, item) => acc + item.totalKcal);
                  final double consumedProtein = logs.fold(
                      0.0, (acc, item) => acc + item.totalProteinG);

                  return StreamBuilder<int>(
                    stream: hydrationDao.watchTotalWaterMl(_dateKey),
                    builder: (context, waterSnap) {
                      final int waterMl = waterSnap.data ?? 0;

                      return StreamBuilder<int>(
                        stream: workoutDao.watchNetCaloriesForDate(_dateKey),
                        builder: (context, workoutSnap) {
                          final int netBurnedKcal = workoutSnap.data ?? 0;
                          final int goalKcal = profile.currentAdaptiveTdeeKcal;
                          final int effectiveGoalKcal = goalKcal + netBurnedKcal;
                          final int goalWater = profile.dailyWaterGoalMl;
                          final double goalProtein =
                              (profile.targetWeightKg * 2.0).clamp(60.0, 220.0);

                          final double kcalRatio =
                              effectiveGoalKcal > 0 ? (consumedKcal / effectiveGoalKcal).clamp(0.0, 1.5) : 0.0;
                          final double proteinRatio =
                              goalProtein > 0 ? (consumedProtein / goalProtein).clamp(0.0, 1.5) : 0.0;
                          final double waterRatio =
                              goalWater > 0 ? (waterMl / goalWater).clamp(0.0, 1.5) : 0.0;

                          return HealthCard(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(AppIcons.calories,
                                            size: 20, color: c.calories),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Objetivos del Día',
                                          style: TextStyle(
                                            fontFamily: ScFonts.display,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: c.text,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      netBurnedKcal > 0
                                          ? 'TDEE: $goalKcal + $netBurnedKcal kcal'
                                          : 'TDEE: $goalKcal kcal',
                                      style: TextStyle(
                                        fontFamily: ScFonts.ui,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: c.text3,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Fila de Indicadores Principales
                                Row(
                                  children: [
                                    Expanded(
                                      child: _SummaryMetricColumn(
                                        label: 'Calorías',
                                        value: '${consumedKcal.toInt()} / $effectiveGoalKcal',
                                        unit: 'kcal',
                                        ratio: kcalRatio,
                                        color: c.calories,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: _SummaryMetricColumn(
                                        label: 'Proteína',
                                        value: '${consumedProtein.toInt()} / ${goalProtein.toInt()}',
                                        unit: 'g',
                                        ratio: proteinRatio,
                                        color: c.protein,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: _SummaryMetricColumn(
                                        label: 'Agua',
                                        value: '$waterMl / $goalWater',
                                        unit: 'ml',
                                        ratio: waterRatio,
                                        color: c.water,
                                      ),
                                    ),
                                  ],
                                ),

                                if (netBurnedKcal > 0) ...[
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: c.bg3,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(AppIcons.protein,
                                                size: 16, color: c.accent),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Gasto neto en entrenamientos:',
                                              style: TextStyle(
                                                fontFamily: ScFonts.ui,
                                                fontSize: 12.5,
                                                color: c.text2,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          '-$netBurnedKcal kcal',
                                          style: TextStyle(
                                            fontFamily: ScFonts.display,
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: c.accent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),

              // 2. Dock de Accesos Rápidos
              const SectionHead(title: 'Acciones Rápidas'),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    ChipPill(
                      label: '+250 ml',
                      icon: AppIcons.water,
                      activeColor: c.water,
                      onTap: () => _logWaterGlass(250, profile.dailyWaterGoalMl),
                    ),
                    const SizedBox(width: 8),
                    ChipPill(
                      label: '+500 ml',
                      icon: AppIcons.water,
                      activeColor: c.water,
                      onTap: () => _logWaterGlass(500, profile.dailyWaterGoalMl),
                    ),
                    const SizedBox(width: 8),
                    ChipPill(
                      label: 'Repetir ayer',
                      icon: AppIcons.repeat,
                      onTap: _repeatYesterday,
                    ),
                    const SizedBox(width: 8),
                    ChipPill(
                      label: 'Pesarme',
                      icon: AppIcons.cuerpo,
                      onTap: () => _openQuickWeighInModal(profile),
                    ),
                    const SizedBox(width: 8),
                    ChipPill(
                      label: 'Entreno 5s',
                      icon: AppIcons.protein,
                      onTap: () => _openQuickWorkoutModal(profile),
                    ),
                    const SizedBox(width: 8),
                    ChipPill(
                      label: 'Diario',
                      icon: AppIcons.edit,
                      onTap: _openJournalModal,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 3. Tarjeta de Ayuno Intermitente en Hoy
              StreamBuilder<FastingSession?>(
                stream: fastingDao.watchActiveSession(),
                builder: (context, fastSnap) {
                  final activeFast = fastSnap.data;
                  final isFasting = activeFast != null;

                  return HealthCard(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 8),
                    onTap: () => context.push('/ayuno'),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isFasting
                                ? c.fasting.withValues(alpha: 0.15)
                                : c.bg3,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            AppIcons.fasting,
                            size: 22,
                            color: isFasting ? c.fasting : c.text3,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isFasting
                                    ? 'Ayuno en Curso (${activeFast.protocolName})'
                                    : 'Temporizador de Ayuno',
                                style: TextStyle(
                                  fontFamily: ScFonts.display,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: c.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isFasting
                                    ? 'Toca para ver fases celulares y autofagia'
                                    : 'Inicia tu ventana de descanso digestivo',
                                style: TextStyle(
                                  fontFamily: ScFonts.ui,
                                  fontSize: 12.5,
                                  color: c.text3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(AppIcons.chevronRight, size: 20, color: c.text3),
                      ],
                    ),
                  );
                },
              ),

              // 4. Diario Personal Snippet
              StreamBuilder<List<JournalEntry>>(
                stream: ref.watch(journalDaoProvider).watchRecentEntries(limit: 1),
                builder: (context, journalSnap) {
                  final entries = journalSnap.data ?? [];
                  final latestEntry = entries.isNotEmpty ? entries.first : null;

                  return HealthCard(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 8),
                    onTap: _openJournalModal,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(AppIcons.edit,
                                    size: 18, color: Colors.teal),
                                const SizedBox(width: 8),
                                Text(
                                  'Reflexión del Día',
                                  style: TextStyle(
                                    fontFamily: ScFonts.display,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: c.text,
                                  ),
                                ),
                              ],
                            ),
                            Icon(AppIcons.chevronRight,
                                size: 18, color: c.text3),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          latestEntry != null
                              ? '"${latestEntry.content}"'
                              : 'No has registrado ninguna reflexión hoy. Un minuto de pausa fomenta la calma.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: ScFonts.ui,
                            fontSize: 13,
                            color: latestEntry != null ? c.text : c.text3,
                            fontStyle: latestEntry != null
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _SummaryMetricColumn extends StatelessWidget {
  const _SummaryMetricColumn({
    required this.label,
    required this.value,
    required this.unit,
    required this.ratio,
    required this.color,
  });

  final String label;
  final String value;
  final String unit;
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: ScFonts.ui,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: c.text3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontFamily: ScFonts.display,
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: c.text,
          ),
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: ratio,
          minHeight: 5,
          borderRadius: BorderRadius.circular(3),
          backgroundColor: c.bg3,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
    );
  }
}

