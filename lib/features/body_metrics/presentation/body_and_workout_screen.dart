import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/met_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/body_measurements_dao.dart';
import '../../../core/database/daos/pet_dao.dart';
import '../../../core/database/daos/user_profile_dao.dart';
import '../../../core/database/daos/workout_dao.dart';
import '../../../core/hardware/body_scale_driver.dart';
import '../../../core/hardware/drivers/xiaomi_miscale2_driver.dart';
import '../../../core/services/health_connect_service.dart';
import '../../../shared/utils/biometric_formulas.dart';
import '../../../shared/utils/date_time_extensions.dart';
import '../../../shared/widgets/nxtpaper_card.dart';

/// Pantalla del Laboratorio Corporal, Báscula BLE y Entrenamiento RPE.
class BodyAndWorkoutScreen extends ConsumerStatefulWidget {
  const BodyAndWorkoutScreen({super.key});

  @override
  ConsumerState<BodyAndWorkoutScreen> createState() => _BodyAndWorkoutScreenState();
}

class _BodyAndWorkoutScreenState extends ConsumerState<BodyAndWorkoutScreen> {
  StreamSubscription<ScaleMeasurementEvent>? _bleSubscription;
  ScaleMeasurementEvent? _liveEvent;
  bool _isScanning = false;
  String? _statusMessage;

  @override
  void dispose() {
    unawaited(_bleSubscription?.cancel());
    super.dispose();
  }

  void _startScaleScan(UserProfile profile) {
    setState(() {
      _isScanning = true;
      _liveEvent = null;
      _statusMessage = 'Buscando báscula Xiaomi Mi Scale 2... Sube descalzo.';
    });

    final driver = ref.read(xiaomiMiScale2DriverProvider);
    unawaited(_bleSubscription?.cancel());
    _bleSubscription = driver
        .scanAndStreamMeasurements(targetMacAddress: profile.scaleMacAddress)
        .listen(
      (ScaleMeasurementEvent event) {
        setState(() {
          _liveEvent = event;
          _statusMessage = event.isStabilized
              ? '¡Peso estabilizado! ${event.hasImpedance ? "Bioimpedancia completada." : "Calculando..."}'
              : 'Midiendo... permanece quieto.';
        });

        if (event.isStabilized) {
          unawaited(_onWeightStabilized(event, profile));
        }
      },
      onError: (Object err) {
        setState(() {
          _isScanning = false;
          _statusMessage = 'Error en escaneo Bluetooth: $err';
        });
      },
    );
  }

  Future<void> _stopScaleScan() async {
    final driver = ref.read(xiaomiMiScale2DriverProvider);
    await driver.stopScan();
    await _bleSubscription?.cancel();
    _bleSubscription = null;
    setState(() {
      _isScanning = false;
      _statusMessage = null;
    });
  }

  Future<void> _onWeightStabilized(
    ScaleMeasurementEvent event,
    UserProfile profile,
  ) async {
    await _stopScaleScan();

    final measurementsDao = ref.read(bodyMeasurementsDaoProvider);
    final BodyMeasurement? latest = await measurementsDao.getLatestMeasurement();

    // Filtro de Invitados: si el peso difiere > 8% respecto a la tendencia
    final double? previousEma = latest?.trendWeightKg;
    if (previousEma != null && previousEma > 0) {
      final double diffRatio = (event.weightKg - previousEma).abs() / previousEma;
      if (diffRatio > 0.08 && mounted) {
        final bool? isUser = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('¿Eres tú?'),
            content: Text(
              'El peso detectado (${event.weightKg.toStringAsFixed(1)} kg) difiere '
              'un ${(diffRatio * 100).toStringAsFixed(0)}% de tu tendencia (${previousEma.toStringAsFixed(1)} kg).\n\n'
              '¿Deseas registrar este pesaje en tu perfil personal?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('No (Descartar)'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Sí, registrar'),
              ),
            ],
          ),
        );

        if (isUser != true) {
          setState(() {
            _liveEvent = null;
            _statusMessage = 'Pesaje descartado (modo invitado).';
          });
          return;
        }
      }
    }

    // Procesar y guardar medición completa
    await _saveMeasurement(
      weightKg: event.weightKg,
      impedanceOhms: event.impedanceOhms,
      source: 'mi_scale_2_ble',
      profile: profile,
      latest: latest,
    );
  }

  Future<void> _saveMeasurement({
    required double weightKg,
    required int? impedanceOhms,
    required String source,
    required UserProfile profile,
    required BodyMeasurement? latest,
  }) async {
    final double age = BiometricFormulas.calculateDynamicAge(profile.birthDate);
    final bool isMale = profile.biologicalSex == 'male';

    // 1. Derivar las 13 métricas
    final metrics = BiometricFormulas.deriveAllMetrics(
      weightKg: weightKg,
      heightCm: profile.heightCm,
      ageYears: age,
      isMale: isMale,
      impedanceOhms: impedanceOhms ?? 500,
    );

    // 2. Calcular Peso Tendencia (EMA)
    final double currentEma = BiometricFormulas.calculateWeightEma(
      currentWeightKg: weightKg,
      previousEmaKg: latest?.trendWeightKg,
    );

    // 3. Evaluar Detector de Falsa Subida (retención de agua)
    final bool isRetention = latest != null &&
        BiometricFormulas.detectWaterRetentionSpike(
          currentWeightKg: weightKg,
          previousWeightKg: latest.weightKg,
          currentWaterPct: metrics.waterPercentage,
          previousWaterPct: latest.waterPercentage,
        );

    final now = DateTime.now();
    final companion = BodyMeasurementsCompanion(
      measuredAt: drift.Value(now),
      dateKey: drift.Value(now.dateKey),
      source: drift.Value(source),
      weightKg: drift.Value(weightKg),
      trendWeightKg: drift.Value(currentEma),
      impedanceOhms: drift.Value(impedanceOhms),
      bmi: drift.Value(metrics.bmi),
      bodyFatPercentage: drift.Value(metrics.bodyFatPercentage),
      muscleMassKg: drift.Value(metrics.muscleMassKg),
      waterPercentage: drift.Value(metrics.waterPercentage),
      visceralFatIndex: drift.Value(metrics.visceralFatIndex),
      boneMassKg: drift.Value(metrics.boneMassKg),
      proteinPercentage: drift.Value(metrics.proteinPercentage),
      basalMetabolicRateKcal: drift.Value(metrics.basalMetabolicRateKcal),
      metabolicAge: drift.Value(metrics.metabolicAgeYears),
      leanBodyMassKg: drift.Value(metrics.leanBodyMassKg),
      bodyScore: drift.Value(metrics.bodyScore),
      somatotype: drift.Value(metrics.bodyType),
      isWaterRetentionSpike: drift.Value(isRetention),
    );

    final measurementsDao = ref.read(bodyMeasurementsDaoProvider);
    await measurementsDao.insertMeasurement(companion);

    // Sincronizar en segundo plano con Health Connect
    final healthConnect = ref.read(healthConnectServiceProvider);
    unawaited(
      healthConnect.writeWeightAndBodyFat(
        weightKg: weightKg,
        bodyFatPercentage: metrics.bodyFatPercentage,
        timestamp: now,
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '¡Pesaje guardado: ${weightKg.toStringAsFixed(1)} kg! (+15 Monedas Nibi)',
          ),
          backgroundColor: Colors.teal,
        ),
      );
    }
  }

  void _openManualWeighInDialog(UserProfile profile) {
    final weightCtrl = TextEditingController(text: '70.0');
    final impedanceCtrl = TextEditingController(text: '480');

    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Registro Manual de Peso'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: weightCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Peso (kg)',
                  suffixText: 'kg',
                ),
              ),
              const SizedBox(height: 12.0),
              TextField(
                controller: impedanceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Impedancia opcional (Ω)',
                  hintText: 'Ej. 480 (o dejar vacío)',
                  suffixText: 'Ω',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final double? w = double.tryParse(weightCtrl.text.trim());
                final int? imp = int.tryParse(impedanceCtrl.text.trim());
                if (w != null && w > 0) {
                  Navigator.of(ctx).pop();
                  final latest = await ref
                      .read(bodyMeasurementsDaoProvider)
                      .getLatestMeasurement();
                  await _saveMeasurement(
                    weightKg: w,
                    impedanceOhms: imp,
                    source: 'manual',
                    profile: profile,
                    latest: latest,
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _openNavyTapeMeasureDialog(UserProfile profile, BodyMeasurement? latest) {
    final waistCtrl = TextEditingController(text: '80.0');
    final neckCtrl = TextEditingController(text: '38.0');
    final hipCtrl = TextEditingController(text: '95.0');
    final bool isFemale = profile.biologicalSex == 'female';

    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Validación Cinta US Navy'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Compensa las variaciones hídricas de la bioimpedancia '
                'fusionando el cálculo BIA con tus medidas antropométricas cada 14 días.',
                style: TextStyle(fontSize: 13.0),
              ),
              const SizedBox(height: 16.0),
              TextField(
                controller: waistCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Cintura (cm)',
                  suffixText: 'cm',
                ),
              ),
              const SizedBox(height: 8.0),
              TextField(
                controller: neckCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Cuello (cm)',
                  suffixText: 'cm',
                ),
              ),
              if (isFemale) ...[
                const SizedBox(height: 8.0),
                TextField(
                  controller: hipCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Cadera (cm)',
                    suffixText: 'cm',
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cerrar'),
            ),
            FilledButton(
              onPressed: () async {
                final double? waist = double.tryParse(waistCtrl.text.trim());
                final double? neck = double.tryParse(neckCtrl.text.trim());
                final double? hip = isFemale ? double.tryParse(hipCtrl.text.trim()) : null;

                if (waist != null && neck != null) {
                  final double navyFat = BiometricFormulas.calculateNavyBodyFatPercentage(
                    heightCm: profile.heightCm,
                    waistCm: waist,
                    neckCm: neck,
                    isMale: profile.biologicalSex == 'male',
                    hipCm: hip,
                  );

                  final double biaFat = latest?.bodyFatPercentage ?? 18.0;
                  final double validatedFat = BiometricFormulas.calculateValidatedBodyFat(
                    biaBodyFatPercentage: biaFat,
                    navyBodyFatPercentage: navyFat,
                  );

                  Navigator.of(ctx).pop();

                  if (mounted) {
                    await showDialog<void>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Resultado Antropométrico'),
                        content: Text(
                          '• Grasa US Navy: ${navyFat.toStringAsFixed(1)}%\n'
                          '• Grasa BIA (Báscula): ${biaFat.toStringAsFixed(1)}%\n'
                          '• Grasa Validada (60/40): ${validatedFat.toStringAsFixed(1)}%\n\n'
                          '¡Excelente para verificar recomposición corporal sin sesgo de agua!',
                        ),
                        actions: [
                          FilledButton(
                            onPressed: () => Navigator.of(c).pop(),
                            child: const Text('Entendido'),
                          ),
                        ],
                      ),
                    );
                  }
                }
              },
              child: const Text('Calcular Fusión'),
            ),
          ],
        ),
      ),
    );
  }

  void _openQuickWorkoutModal(UserProfile profile, BodyMeasurement? latest) {
    WorkoutCategory selectedCategory = WorkoutCategory.weights;
    RpeIntensity selectedRpe = RpeIntensity.moderate;
    int durationMinutes = 45;

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              final double userWeight = latest?.weightKg ?? profile.targetWeightKg;
              final double met = MetConstants.getMet(selectedCategory, selectedRpe);
              final double netKcal = BiometricFormulas.calculateNetExerciseCalories(
                met: met,
                weightKg: userWeight,
                durationMinutes: durationMinutes,
              );

              return Padding(
                padding: EdgeInsets.only(
                  left: 20.0,
                  right: 20.0,
                  top: 20.0,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Entrenamiento en 5 Segundos',
                          style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12.0),

                    // 1. Selector de Categoría
                    const Text('1. Categoría de Ejercicio', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6.0),
                    SegmentedButton<WorkoutCategory>(
                      segments: const [
                        ButtonSegment(value: WorkoutCategory.weights, label: Text('Pesas')),
                        ButtonSegment(value: WorkoutCategory.calisthenics, label: Text('Funcional')),
                        ButtonSegment(value: WorkoutCategory.cardio, label: Text('Cardio')),
                        ButtonSegment(value: WorkoutCategory.sports, label: Text('Deporte')),
                      ],
                      selected: {selectedCategory},
                      onSelectionChanged: (set) => setModalState(() => selectedCategory = set.first),
                    ),
                    const SizedBox(height: 16.0),

                    // 2. Duración
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('2. Duración:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('$durationMinutes min', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Slider(
                      value: durationMinutes.toDouble(),
                      min: 10,
                      max: 180,
                      divisions: 17,
                      label: '$durationMinutes min',
                      onChanged: (val) => setModalState(() => durationMinutes = val.toInt()),
                    ),
                    const SizedBox(height: 8.0),

                    // 3. Nivel de Esfuerzo (RPE)
                    const Text('3. Esfuerzo Percibido (RPE)', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6.0),
                    SegmentedButton<RpeIntensity>(
                      segments: const [
                        ButtonSegment(value: RpeIntensity.light, label: Text('Ligero (5-6)')),
                        ButtonSegment(value: RpeIntensity.moderate, label: Text('Moderado (7-8)')),
                        ButtonSegment(value: RpeIntensity.intense, label: Text('Intenso (9-10)')),
                      ],
                      selected: {selectedRpe},
                      onSelectionChanged: (set) => setModalState(() => selectedRpe = set.first),
                    ),
                    const SizedBox(height: 20.0),

                    // Resumen de Quema Neta
                    Container(
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Gasto Neto (sin metabolismo basal):', style: TextStyle(fontSize: 12)),
                              Text(
                                '${netKcal.toStringAsFixed(0)} kcal netas',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                              ),
                            ],
                          ),
                          Text(
                            'MET: ${met.toStringAsFixed(1)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16.0),

                    // Botón Guardar
                    FilledButton.icon(
                      onPressed: () async {
                        final now = DateTime.now();
                        final companion = WorkoutBlocksCompanion(
                          performedAt: drift.Value(now),
                          dateKey: drift.Value(now.dateKey),
                          category: drift.Value(selectedCategory.name),
                          durationMinutes: drift.Value(durationMinutes),
                          rpeIntensity: drift.Value(selectedRpe.name),
                          appliedMet: drift.Value(met),
                          userWeightAtTimeKg: drift.Value(userWeight),
                          netCaloriesBurned: drift.Value(netKcal.round()),
                        );

                        await ref.read(workoutDaoProvider).insertWorkout(companion);

                        // Otorgar recompensa en monedas por entrenar
                        await ref.read(petDaoProvider).grantDailyReward(
                              dateKey: now.dateKey,
                              actionType: 'workout_done',
                              baseAmount: 20,
                            );

                        if (context.mounted) {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('¡Entrenamiento registrado! ${netKcal.toStringAsFixed(0)} kcal netas (+20 monedas)'),
                              backgroundColor: Colors.deepOrange,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.fitness_center),
                      label: const Text('Registrar en 5 segundos'),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<UserProfile?> profileAsync = ref.watch(userProfileStreamProvider);
    final AsyncValue<BodyMeasurement?> latestMeasurementAsync = ref.watch(latestMeasurementStreamProvider);

    return profileAsync.when(
      data: (UserProfile? profile) {
        if (profile == null) {
          return const Scaffold(body: Center(child: Text('Perfil no encontrado')));
        }

        final BodyMeasurement? latest = latestMeasurementAsync.asData?.value;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Laboratorio Corporal y Movimiento'),
            actions: [
              IconButton(
                tooltip: 'Medición con Cinta US Navy',
                icon: const Icon(Icons.straighten_outlined),
                onPressed: () => _openNavyTapeMeasureDialog(profile, latest),
              ),
              IconButton(
                tooltip: 'Ingresar Peso Manualmente',
                icon: const Icon(Icons.edit_note_outlined),
                onPressed: () => _openManualWeighInDialog(profile),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            children: [
              // Banner de Escaneo en Vivo o Fluctuación de Báscula
              NxtpaperCard(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.bluetooth_searching_rounded,
                              color: _isScanning ? Colors.teal : theme.colorScheme.onSurface,
                            ),
                            const SizedBox(width: 8.0),
                            Text(
                              'Xiaomi Mi Scale 2 BLE',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        FilledButton.tonal(
                          onPressed: () {
                            if (_isScanning) {
                              unawaited(_stopScaleScan());
                            } else {
                              _startScaleScan(profile);
                            }
                          },
                          child: Text(_isScanning ? 'Detener' : 'Pesarme'),
                        ),
                      ],
                    ),
                    if (_statusMessage != null) ...[
                      const SizedBox(height: 12.0),
                      Text(
                        _statusMessage!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _isScanning ? Colors.teal : theme.colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (_liveEvent != null) ...[
                      const SizedBox(height: 16.0),
                      Text(
                        '${_liveEvent!.weightKg.toStringAsFixed(2)} kg',
                        style: theme.textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _liveEvent!.isStabilized ? Colors.teal : theme.colorScheme.primary,
                        ),
                      ),
                      if (_liveEvent!.hasImpedance)
                        Text(
                          'Impedancia: ${_liveEvent!.impedanceOhms} Ω',
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16.0),

              // Alerta de Falsa Subida (Retención Hídrica)
              if (latest?.isWaterRetentionSpike == true) ...[
                NxtpaperCard(
                  color: Colors.blue.withValues(alpha: 0.1),
                  child: Row(
                    children: [
                      const Icon(Icons.water_drop_outlined, color: Colors.blue, size: 36),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Detector de Falsa Subida Activo',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                            ),
                            const SizedBox(height: 4.0),
                            Text(
                              'La subida de peso detectada coincide con mayor retención de agua/sodio o glucógeno, no grasa corporal.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16.0),
              ],

              // Tarjeta Resumen: Último Peso vs Tendencia EMA
              if (latest != null) ...[
                NxtpaperCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Último Pesaje Registrado', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12.0),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text('${latest.weightKg.toStringAsFixed(1)} kg', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                              const Text('Peso Bruto'),
                            ],
                          ),
                          Container(height: 40, width: 1, color: theme.colorScheme.outlineVariant),
                          Column(
                            children: [
                              Text('${latest.trendWeightKg.toStringAsFixed(1)} kg', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.teal)),
                              const Text('Peso Tendencia (EMA)'),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 24.0),

                      // Grid de las 13 métricas derivadas
                      Text('Composición Corporal (13 Métricas)', style: theme.textTheme.labelMedium),
                      const SizedBox(height: 8.0),
                      Wrap(
                        spacing: 12.0,
                        runSpacing: 8.0,
                        children: [
                          _MetricChip(label: 'Grasa', value: '${latest.bodyFatPercentage?.toStringAsFixed(1) ?? "--"}%'),
                          _MetricChip(label: 'Músculo', value: '${latest.muscleMassKg?.toStringAsFixed(1) ?? "--"} kg'),
                          _MetricChip(label: 'Agua', value: '${latest.waterPercentage?.toStringAsFixed(1) ?? "--"}%'),
                          _MetricChip(label: 'Grasa Visceral', value: 'Nivel ${latest.visceralFatIndex ?? "--"}'),
                          _MetricChip(label: 'Hueso', value: '${latest.boneMassKg?.toStringAsFixed(1) ?? "--"} kg'),
                          _MetricChip(label: 'Proteína', value: '${latest.proteinPercentage?.toStringAsFixed(1) ?? "--"}%'),
                          _MetricChip(label: 'TMB Basal', value: '${latest.basalMetabolicRateKcal ?? "--"} kcal'),
                          _MetricChip(label: 'Edad Metabólica', value: '${latest.metabolicAge ?? "--"} años'),
                          _MetricChip(label: 'Puntaje', value: '${latest.bodyScore ?? "--"}/100'),
                          _MetricChip(label: 'Somatotipo', value: latest.somatotype ?? '--'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16.0),
              ],

              // Sección Entrenamiento RPE en 5 Segundos
              NxtpaperCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.fitness_center_rounded, color: Colors.deepOrange),
                            const SizedBox(width: 8.0),
                            Text(
                              'Entrenamiento en 5 Segundos',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        FilledButton.icon(
                          onPressed: () => _openQuickWorkoutModal(profile, latest),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Registrar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      'Separa tu actividad NEAT (pasos de Health Connect) de tus bloques intencionales de fuerza o cardio.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32.0),
            ],
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value', style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
    );
  }
}
