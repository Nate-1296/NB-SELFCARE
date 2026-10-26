import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/body_measurements_dao.dart';
import '../../../core/database/daos/female_cycle_dao.dart';
import '../../../core/database/daos/food_dao.dart';
import '../../../core/database/daos/health_sync_dao.dart';
import '../../../core/database/daos/supplement_dao.dart';
import '../../../core/database/daos/user_profile_dao.dart';
import '../../../core/database/daos/workout_dao.dart';
import '../../../core/hardware/body_scale_driver.dart';
import '../../../core/hardware/drivers/xiaomi_miscale2_driver.dart';
import '../../../core/services/health_connect_service.dart';
import '../../../shared/theme/sc_colors.dart';
import '../../../shared/theme/sc_theme.dart';
import '../../../shared/utils/biometric_formulas.dart';
import '../../../shared/utils/current_date_provider.dart';
import '../../../shared/utils/date_time_extensions.dart';
import '../../../shared/widgets/app_icons.dart';
import '../../../shared/widgets/health_card.dart';
import '../../../shared/widgets/section_head.dart';
import '../../../shared/widgets/top_bar.dart';
import 'widgets/body_sheets.dart';
import 'widgets/mini_milestones_card.dart';
import 'widgets/quick_rpe_workout_sheet.dart';
import 'widgets/weight_trend_chart_card.dart';

/// Pestaña "Cuerpo": Pesaje Xiaomi Mi Scale 2 BLE, las 13 métricas fisiológicas,
/// evolución temporal interactiva, detector fisiológico de retención hídrica,
/// bloques RPE de hoy, NEAT pasivo y validación antropométrica US Navy.
class CuerpoScreen extends ConsumerStatefulWidget {
  const CuerpoScreen({super.key});

  @override
  ConsumerState<CuerpoScreen> createState() => _CuerpoScreenState();
}

class _CuerpoScreenState extends ConsumerState<CuerpoScreen> {
  StreamSubscription<ScaleMeasurementEvent>? _bleSubscription;
  ScaleMeasurementEvent? _liveEvent;
  Timer? _impedanceGraceTimer;
  bool _isScanning = false;
  String? _statusMessage;

  @override
  void dispose() {
    _impedanceGraceTimer?.cancel();
    unawaited(_bleSubscription?.cancel());
    super.dispose();
  }

  static String _formatearFechaCorta(DateTime date) {
    final String dd = date.day.toString().padLeft(2, '0');
    final String mm = date.month.toString().padLeft(2, '0');
    final String yyyy = date.year.toString().padLeft(4, '0');
    return '$dd/$mm/$yyyy';
  }

  static String _translateWorkoutCategory(String category) {
    return switch (category) {
      'weights' => 'Pesas / Fuerza',
      'calisthenics' => 'Funcional / Calistenia',
      'cardio' => 'Cardio',
      'sports' => 'Deporte',
      _ => category,
    };
  }

  static String _translateRpe(String rpe) {
    return switch (rpe) {
      'light' => 'RPE Ligero',
      'moderate' => 'RPE Moderado',
      'intense' => 'RPE Intenso',
      _ => rpe,
    };
  }

  void _startScaleScan(UserProfile profile) {
    setState(() {
      _isScanning = true;
      _liveEvent = null;
      _statusMessage =
          'Buscando Xiaomi Mi Scale 2... Sube descalzo sobre los 4 electrodos.';
    });

    final driver = ref.read(xiaomiMiScale2DriverProvider);
    _impedanceGraceTimer?.cancel();
    _impedanceGraceTimer = null;
    unawaited(_bleSubscription?.cancel());

    _bleSubscription = driver
        .scanAndStreamMeasurements(targetMacAddress: profile.scaleMacAddress)
        .listen(
      (ScaleMeasurementEvent event) {
        if (!mounted) return;
        setState(() {
          _liveEvent = event;
        });

        if (event.isStabilized) {
          if (event.hasImpedance &&
              event.impedanceOhms != null &&
              event.impedanceOhms! > 0) {
            _impedanceGraceTimer?.cancel();
            _impedanceGraceTimer = null;
            setState(() {
              _statusMessage =
                  '¡Peso e impedancia capturados! (${event.weightKg.toStringAsFixed(1)} kg, ${event.impedanceOhms}Ω)';
            });
            unawaited(_onWeightStabilized(event, profile));
          } else {
            setState(() {
              _statusMessage =
                  'Peso estabilizado: ${event.weightKg.toStringAsFixed(1)} kg. Midiendo bioimpedancia... permanece descalzo.';
            });
            // Ventana de gracia de 10 segundos para permitir a los 4 electrodos de Mi Scale 2 completar el barrido
            _impedanceGraceTimer ??= Timer(const Duration(seconds: 10), () {
              if (_liveEvent != null && mounted && _isScanning) {
                unawaited(_onWeightStabilized(_liveEvent!, profile));
              }
            });
          }
        } else {
          setState(() {
            _statusMessage = 'Midiendo peso en vivo... permanece inmóvil.';
          });
        }
      },
      onError: (Object err) {
        if (!mounted) return;
        setState(() {
          _isScanning = false;
          _statusMessage = 'Error en escaneo Bluetooth: $err';
        });
      },
    );
  }

  Future<void> _stopScaleScan() async {
    _impedanceGraceTimer?.cancel();
    _impedanceGraceTimer = null;
    final driver = ref.read(xiaomiMiScale2DriverProvider);
    await driver.stopScan();
    await _bleSubscription?.cancel();
    _bleSubscription = null;
    if (!mounted) return;
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
    final BodyMeasurement? latest =
        await measurementsDao.getLatestMeasurement();

    // Filtro anti-invitados (> 8% de desviación respecto a tendencia EMA)
    final double? previousEma = latest?.trendWeightKg;
    if (previousEma != null && previousEma > 0) {
      final double diffRatio =
          (event.weightKg - previousEma).abs() / previousEma;
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
                child: const Text('No (Invitado)'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Sí, registrar'),
              ),
            ],
          ),
        );

        if (isUser != true) {
          if (mounted) {
            setState(() {
              _liveEvent = null;
              _statusMessage = 'Pesaje descartado (modo invitado).';
            });
          }
          return;
        }
      }
    }

    await _saveMeasurement(
      weightKg: event.weightKg,
      impedanceOhms: event.impedanceOhms,
      source: 'mi_scale_2_ble',
      profile: profile,
      latest: latest,
      detectedDeviceMac: event.deviceAddress,
    );
  }

  Future<void> _saveMeasurement({
    required double weightKg,
    required int? impedanceOhms,
    required String source,
    required UserProfile profile,
    required BodyMeasurement? latest,
    String? detectedDeviceMac,
  }) async {
    final now = DateTime.now();
    final String todayKey = now.dateKey;

    final double age = BiometricFormulas.calculateDynamicAge(profile.birthDate);
    final bool isMale = profile.biologicalSex == 'male';
    final double bmi = BiometricFormulas.calculateBmi(
      weightKg: weightKg,
      heightCm: profile.heightCm,
    );

    final metrics = BiometricFormulas.deriveMetrics(
      weightKg: weightKg,
      heightCm: profile.heightCm,
      ageYears: age,
      isMale: isMale,
      impedanceOhms: impedanceOhms,
    );

    final double currentEma = BiometricFormulas.calculateWeightEma(
      currentWeightKg: weightKg,
      previousEmaKg: latest?.trendWeightKg,
    );

    final nutritionContext = await ref
        .read(foodDaoProvider)
        .getRetentionNutritionContext(todayKey);

    final double currentWater = metrics.waterPercentage;
    final bool isRetention = latest != null &&
        BiometricFormulas.detectWaterRetentionSpike(
          currentWeightKg: weightKg,
          previousWeightKg: latest.weightKg,
          yesterdaySodiumMg: nutritionContext.yesterdaySodiumMg,
          yesterdayCarbsGrams: nutritionContext.yesterdayCarbsG,
          avg7dCarbsGrams: nutritionContext.avg7dCarbsG,
          currentWaterPct: currentWater,
          previousWaterPct: latest.waterPercentage,
        );

    String? spikeExplanation;
    if (isRetention) {
      final List<String> reasons = <String>[];
      if (nutritionContext.yesterdaySodiumMg != null &&
          nutritionContext.yesterdaySodiumMg! > 2500) {
        reasons.add(
          'sodio elevado ayer (${nutritionContext.yesterdaySodiumMg} mg)',
        );
      }
      if (nutritionContext.yesterdayCarbsG != null &&
          nutritionContext.avg7dCarbsG != null &&
          nutritionContext.avg7dCarbsG! > 0 &&
          nutritionContext.yesterdayCarbsG! >
              1.30 * nutritionContext.avg7dCarbsG!) {
        reasons.add(
          'recarga de glucógeno (${nutritionContext.yesterdayCarbsG!.round()}g carbos ayer)',
        );
      }
      if (latest.waterPercentage != null &&
          (currentWater - latest.waterPercentage!) >= 0.40) {
        reasons.add(
          '+${(currentWater - latest.waterPercentage!).toStringAsFixed(1)}% agua corporal BIA',
        );
      }

      if (!isMale && profile.isCycleTrackingEnabled) {
        final CyclePhaseInfo phaseInfo =
            await ref.read(femaleCycleDaoProvider).calculateCurrentPhase(now);
        if (phaseInfo.phase == FemaleCyclePhase.luteal) {
          reasons.add(
            'fase lútea (retención fisiológica por progesterona y aldosterona)',
          );
        }
      }

      final bool hasRetentionSupplement = await ref
          .read(supplementDaoProvider)
          .hasActiveWaterRetentionSupplement(todayKey);
      if (hasRetentionSupplement) {
        reasons.add(
          'hidratación celular por creatina (+1 a +2 kg en agua intracelular)',
        );
      }

      spikeExplanation = reasons.isNotEmpty
          ? 'Variación hídrica temporal (${reasons.join(", ")}), no tejido graso.'
          : 'Variación temporal de agua y glucógeno muscular, no es aumento de grasa.';
    }

    final companion = BodyMeasurementsCompanion(
      measuredAt: drift.Value(now),
      dateKey: drift.Value(todayKey),
      source: drift.Value(source),
      weightKg: drift.Value(weightKg),
      trendWeightKg: drift.Value(currentEma),
      impedanceOhms: drift.Value(impedanceOhms),
      bmi: drift.Value(bmi),
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
      spikeExplanation: drift.Value(spikeExplanation),
    );

    await ref.read(bodyMeasurementsDaoProvider).insertMeasurement(companion);

    unawaited(
      ref.read(healthConnectServiceProvider).writeWeightAndBodyFat(
            weightKg: weightKg,
            bodyFatPercentage: metrics.bodyFatPercentage,
            timestamp: now,
          ),
    );

    if (!mounted) return;
    final bool canBindMac = detectedDeviceMac != null &&
        detectedDeviceMac.isNotEmpty &&
        (profile.scaleMacAddress == null || profile.scaleMacAddress!.isEmpty);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '¡Pesaje guardado: ${weightKg.toStringAsFixed(1)} kg! (+${AppConstants.coinsWeighIn} Monedas) 🪙',
        ),
        action: canBindMac
            ? SnackBarAction(
                label: 'Vincular MAC',
                onPressed: () {
                  unawaited(
                    ref.read(userProfileDaoProvider).updateProfile(
                          UserProfilesCompanion(
                            scaleMacAddress: drift.Value(detectedDeviceMac),
                          ),
                        ),
                  );
                },
              )
            : null,
      ),
    );
  }

  Future<void> _deleteMeasurementWithUndo(BodyMeasurement m) async {
    unawaited(HapticFeedback.selectionClick());
    final dao = ref.read(bodyMeasurementsDaoProvider);
    await dao.deleteMeasurement(m.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Pesaje de ${m.weightKg.toStringAsFixed(1)} kg (${m.dateKey}) eliminado.',
        ),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () {
            unawaited(dao.restoreMeasurement(m));
          },
        ),
      ),
    );
  }

  Future<void> _deleteWorkoutWithUndo(WorkoutBlock block) async {
    unawaited(HapticFeedback.selectionClick());
    final dao = ref.read(workoutDaoProvider);
    await dao.deleteWorkout(block.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Bloque de entrenamiento eliminado.'),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () {
            unawaited(dao.restoreWorkout(block));
          },
        ),
      ),
    );
  }

  Future<void> _openManualWeighInDialog(
    UserProfile profile,
    BodyMeasurement? latest,
  ) async {
    final ({double weightKg, int? impedanceOhms})? result =
        await ManualWeighInSheet.show(
      context: context,
      initialWeightKg: latest?.weightKg ?? 70.0,
      profile: profile,
      latestMeasurement: latest,
    );

    if (!mounted || result == null) return;
    await _saveMeasurement(
      weightKg: result.weightKg,
      impedanceOhms: result.impedanceOhms,
      source: 'manual',
      profile: profile,
      latest: latest,
    );
  }

  Future<void> _openNavyTapeMeasureDialog(
    UserProfile profile,
    BodyMeasurement? latest,
  ) async {
    final bool isFemale = profile.biologicalSex == 'female';
    final ({double waistCm, double neckCm, double? hipCm})? tape =
        await NavyTapeMeasureSheet.show(
      context: context,
      profile: profile,
      latestMeasurement: latest,
    );

    if (!mounted || tape == null) return;

    final double navyFat = BiometricFormulas.calculateNavyBodyFatPercentage(
      heightCm: profile.heightCm,
      waistCm: tape.waistCm,
      neckCm: tape.neckCm,
      isMale: !isFemale,
      hipCm: tape.hipCm,
    );

    final double biaFat = latest?.bodyFatPercentage ?? navyFat;
    final double validatedFat = BiometricFormulas.calculateValidatedBodyFat(
      biaBodyFatPercentage: biaFat,
      navyBodyFatPercentage: navyFat,
    );

    await ref.read(bodyMeasurementsDaoProvider).saveNavyTapeMeasurement(
          existingMeasurementId: latest?.id,
          dateKey: DateTime.now().dateKey,
          waistCm: tape.waistCm,
          neckCm: tape.neckCm,
          hipCm: tape.hipCm,
          validatedBodyFatPercentage: validatedFat,
          navyBodyFatPercentage: navyFat,
          defaultWeightKg: latest?.weightKg ?? profile.targetWeightKg,
          heightCm: profile.heightCm,
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '¡Medidas guardadas! Grasa Navy: ${navyFat.toStringAsFixed(1)}% · Validada: ${validatedFat.toStringAsFixed(1)}%',
        ),
      ),
    );
  }

  Future<void> _openMacConfig(UserProfile profile) async {
    final String? newMac = await ScaleMacConfigSheet.show(
      context: context,
      currentMac: profile.scaleMacAddress,
    );
    if (!mounted || newMac == null) return;

    await ref.read(userProfileDaoProvider).updateProfile(
          UserProfilesCompanion(
            scaleMacAddress: drift.Value(newMac.isEmpty ? null : newMac),
          ),
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newMac.isEmpty
              ? 'Báscula en modo escaneo automático'
              : 'Báscula vinculada a $newMac',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final DateTime currentDay = ref.watch(currentDateProvider);
    final String todayKey = ref.watch(currentDateKeyProvider);
    final AsyncValue<UserProfile?> profileAsync =
        ref.watch(userProfileStreamProvider);
    final AsyncValue<BodyMeasurement?> latestAsync =
        ref.watch(latestMeasurementStreamProvider);
    final AsyncValue<List<BodyMeasurement>> recentAsync =
        ref.watch(recentMeasurementsStreamProvider);
    final workoutDao = ref.watch(workoutDaoProvider);
    final healthSyncDao = ref.watch(healthSyncDaoProvider);

    return profileAsync.when(
      data: (UserProfile? profile) {
        if (profile == null) {
          return const Scaffold(
            body: Center(child: Text('Perfil no inicializado')),
          );
        }

        final latest = latestAsync.value;
        final recentMeasurements = recentAsync.value ?? [];
        final bool hasBoundMac = profile.scaleMacAddress != null &&
            profile.scaleMacAddress!.isNotEmpty;

        final double? deltaGoal = latest != null
            ? latest.weightKg - profile.targetWeightKg
            : null;

        final metricSpecs = BiometricMetricCatalog.buildAll(
          profile: profile,
          latest: latest,
          referenceDate: currentDay,
        );

        return Scaffold(
          backgroundColor: c.bg,
          body: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 120),
              children: [
                // Encabezado Unificado con Fecha DD/MM/YYYY
                TopBar(
                  title: 'Cuerpo',
                  subtitle: _formatearFechaCorta(currentDay),
                  subtitleBelowTitle: true,
                  uppercaseSubtitle: false,
                  large: true,
                  pageIcon: Icons.accessibility_new_rounded,
                  onProfile: () => context.go('/perfil'),
                ),

                // 1. Tarjeta Hero de Peso Actual vs Meta y Tendencia EMA
                HealthCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Peso Actual',
                                  style: TextStyle(
                                    fontFamily: ScFonts.ui,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: c.text3,
                                  ),
                                ),
                                Text(
                                  latest != null
                                      ? '${latest.dateKey} · ${latest.source == "mi_scale_2_ble" ? "Mi Scale 2" : (latest.source == "manual_navy_tape" ? "US Navy" : "Manual")}'
                                      : 'Sin pesaje registrado',
                                  style: TextStyle(
                                    fontFamily: ScFonts.ui,
                                    fontSize: 12,
                                    color: c.text2,
                                  ),
                                  softWrap: true,
                                ),
                              ],
                            ),
                          ),
                          if (latest?.bodyScore != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: c.soft,
                                borderRadius: BorderRadius.circular(999),
                                border: c.isFlat
                                    ? Border.all(color: c.line2, width: 1.2)
                                    : null,
                              ),
                              child: Text(
                                '${latest!.bodyScore}/100 Pts',
                                style: TextStyle(
                                  fontFamily: ScFonts.display,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: c.accent,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                latest != null
                                    ? latest.weightKg.toStringAsFixed(1)
                                    : '--',
                                style: TextStyle(
                                  fontFamily: ScFonts.display,
                                  fontSize: 38,
                                  fontWeight: FontWeight.w800,
                                  color: c.text,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'kg',
                                style: TextStyle(
                                  fontFamily: ScFonts.display,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: c.text2,
                                ),
                              ),
                            ],
                          ),
                          if (deltaGoal != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: c.bg3,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: c.isFlat ? c.line2 : c.line,
                                  width: c.isFlat ? 1.5 : 1.0,
                                ),
                              ),
                              child: Text(
                                deltaGoal.abs() < 0.1
                                    ? '¡Meta alcanzada!'
                                    : '${deltaGoal > 0 ? "+" : ""}${deltaGoal.toStringAsFixed(1)} kg a meta',
                                style: TextStyle(
                                  fontFamily: ScFonts.ui,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: c.accent,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: c.bg3,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: c.isFlat ? c.line2 : c.line,
                                  width: c.isFlat ? 1.5 : 1.0,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tendencia EMA',
                                    style: TextStyle(
                                      fontFamily: ScFonts.ui,
                                      fontSize: 11,
                                      color: c.text3,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    latest != null
                                        ? '${latest.trendWeightKg.toStringAsFixed(1)} kg'
                                        : '-- kg',
                                    style: TextStyle(
                                      fontFamily: ScFonts.display,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: c.text,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: c.bg3,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: c.isFlat ? c.line2 : c.line,
                                  width: c.isFlat ? 1.5 : 1.0,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Meta personal',
                                    style: TextStyle(
                                      fontFamily: ScFonts.ui,
                                      fontSize: 11,
                                      color: c.text3,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${profile.targetWeightKg.toStringAsFixed(1)} kg',
                                    style: TextStyle(
                                      fontFamily: ScFonts.display,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: c.accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (latest?.isWaterRetentionSpike == true) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: c.bg3,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: c.water,
                              width: c.isFlat ? 1.5 : 1.2,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(AppIcons.gota, size: 20, color: c.water),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Variación hídrica natural detectada',
                                      style: TextStyle(
                                        fontFamily: ScFonts.display,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: c.text,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      latest?.spikeExplanation ??
                                          'Variación de líquidos detectada: retención por sodio o glucógeno muscular, no es tejido graso.',
                                      style: TextStyle(
                                        fontFamily: ScFonts.ui,
                                        fontSize: 12,
                                        height: 1.35,
                                        color: c.text2,
                                      ),
                                      softWrap: true,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Mini-Hitos Psicológicos (Happy Scale 1.5 kg)
                MiniMilestonesCard(
                  currentWeightKg: latest?.trendWeightKg ?? latest?.weightKg ?? profile.targetWeightKg,
                  targetWeightKg: profile.targetWeightKg,
                  weeklyGoalRateKg: profile.weeklyGoalRateKg,
                ),

                // 2. Estación de Pesaje Xiaomi Mi Scale 2 BLE & Entradas Corporales
                HealthCard(
                  backgroundColor: _isScanning && !c.isFlat
                      ? c.accent.withValues(alpha: 0.08)
                      : null,
                  borderColor: _isScanning ? c.accent : null,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _isScanning ? c.accent : c.bg3,
                              shape: BoxShape.circle,
                              border: c.isFlat
                                  ? Border.all(color: c.line2, width: 1.2)
                                  : null,
                            ),
                            child: Icon(
                              AppIcons.bluetooth,
                              size: 22,
                              color: _isScanning ? c.ink : c.text,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isScanning
                                      ? 'Conectando a Xiaomi Mi Scale 2...'
                                      : 'Báscula Xiaomi Mi Scale 2',
                                  style: TextStyle(
                                    fontFamily: ScFonts.display,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: c.text,
                                  ),
                                  softWrap: true,
                                ),
                                Text(
                                  _statusMessage ??
                                      (hasBoundMac
                                          ? 'Vinculada (${profile.scaleMacAddress}) · Escaneo pasivo BLE.'
                                          : 'Escaneo pasivo BLE 0x181B / 0x181D automático.'),
                                  style: TextStyle(
                                    fontFamily: ScFonts.ui,
                                    fontSize: 12,
                                    color: c.text2,
                                  ),
                                  softWrap: true,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => _openMacConfig(profile),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: c.bg3,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: c.isFlat ? c.line2 : c.line,
                                  width: c.isFlat ? 1.5 : 1.0,
                                ),
                              ),
                              child: Text(
                                hasBoundMac ? 'MAC' : 'Auto',
                                style: TextStyle(
                                  fontFamily: ScFonts.display,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: c.accent,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_liveEvent != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: c.bg3,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: c.accent,
                              width: c.isFlat ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    _liveEvent!.weightKg.toStringAsFixed(1),
                                    style: TextStyle(
                                      fontFamily: ScFonts.display,
                                      fontSize: 40,
                                      fontWeight: FontWeight.w800,
                                      color: c.accent,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'kg',
                                    style: TextStyle(
                                      fontFamily: ScFonts.display,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: c.text2,
                                    ),
                                  ),
                                  if (_liveEvent!.impedanceOhms != null) ...[
                                    const SizedBox(width: 14),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: c.bg2,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: c.success,
                                          width: 1.2,
                                        ),
                                      ),
                                      child: Text(
                                        '${_liveEvent!.impedanceOhms} Ω BIA',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: c.success,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (_liveEvent!.isStabilized &&
                                  !_liveEvent!.hasImpedance) ...[
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: () => unawaited(
                                    _onWeightStabilized(_liveEvent!, profile),
                                  ),
                                  icon: const Icon(AppIcons.check, size: 16),
                                  label: const Text('Guardar solo peso ahora'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: _isScanning
                            ? _stopScaleScan
                            : () => _startScaleScan(profile),
                        icon: Icon(
                          _isScanning ? Icons.stop : AppIcons.bluetooth,
                        ),
                        label: Text(
                          _isScanning ? 'Detener' : 'Escanear Báscula',
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _openManualWeighInDialog(profile, latest),
                              icon: const Icon(AppIcons.edit, size: 16),
                              label: const Text('Manual'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(44),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _openNavyTapeMeasureDialog(profile, latest),
                              icon: const Icon(AppIcons.tape, size: 16),
                              label: const Text('Cinta US Navy'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(44),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 3. Vista de Gráficas Temporales Interactivas (Peso, Grasa, Músculo, etc.)
                WeightTrendChartCard(
                  measurements: recentMeasurements,
                  targetWeightKg: profile.targetWeightKg,
                  onDeleteMeasurement: _deleteMeasurementWithUndo,
                ),

                // 4. Sección de Composición Corporal (Las 13 Métricas Fisiológicas)
                const SectionHead(
                  title: 'Composición Corporal',
                  subtitle:
                      'Derivadas de Mi Scale 2 (BIA) o modelo antropométrico',
                ),

                if (latest != null && latest.impedanceOhms == null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: c.bg3,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: c.isFlat ? c.line2 : c.line,
                          width: c.isFlat ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: c.text3),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Último pesaje sin ohmios BIA: valores estimados con fórmula Deurenberg. Sube descalzo para lectura bioeléctrica directa.',
                              style: TextStyle(
                                fontFamily: ScFonts.ui,
                                fontSize: 11.5,
                                color: c.text2,
                              ),
                              softWrap: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Cuadrícula 2x2 + Card Fenotipo para Composición Corporal (Cero truncamiento)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      // Tarjeta destacada de Somatotipo y Fenotipo Corporal
                      _SomatotypeHeroCard(
                        spec: metricSpecs.firstWhere(
                          (s) => s.kind == BiometricMetricKind.somatotype,
                        ),
                        onTap: () => BiometricMetricDetailSheet.show(
                          context: context,
                          spec: metricSpecs.firstWhere(
                            (s) => s.kind == BiometricMetricKind.somatotype,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 12 tarjetas en pares 2x2 perfectamente simétricas
                      for (int i = 0; i < 12; i += 2) ...[
                        Row(
                          children: [
                            Expanded(
                              child: _MetricGridCard(
                                spec: metricSpecs[i],
                                onTap: () => BiometricMetricDetailSheet.show(
                                  context: context,
                                  spec: metricSpecs[i],
                                  onActionTap: metricSpecs[i].kind ==
                                          BiometricMetricKind.validatedNavyFat
                                      ? () => _openNavyTapeMeasureDialog(
                                            profile,
                                            latest,
                                          )
                                      : null,
                                  actionLabel: metricSpecs[i].kind ==
                                          BiometricMetricKind.validatedNavyFat
                                      ? 'Medir cinta US Navy'
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _MetricGridCard(
                                spec: metricSpecs[i + 1],
                                onTap: () => BiometricMetricDetailSheet.show(
                                  context: context,
                                  spec: metricSpecs[i + 1],
                                  onActionTap: metricSpecs[i + 1].kind ==
                                          BiometricMetricKind.validatedNavyFat
                                      ? () => _openNavyTapeMeasureDialog(
                                            profile,
                                            latest,
                                          )
                                      : null,
                                  actionLabel: metricSpecs[i + 1].kind ==
                                          BiometricMetricKind.validatedNavyFat
                                      ? 'Medir cinta US Navy'
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (i < 10) const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 5. Sección de Movimiento y Ejercicio (RPE + NEAT)
                const SectionHead(
                  title: 'Movimiento y Ejercicio',
                  subtitle:
                      'Entrenamiento intencional (RPE) y actividad diaria (NEAT)',
                ),

                // Resumen NEAT Pasivo (Pasos y Kcal de pasos de Health Connect)
                StreamBuilder<DailySummary?>(
                  stream: healthSyncDao.watchDailySummary(todayKey),
                  builder: (context, snap) {
                    final summary = snap.data;
                    final int steps = summary?.stepsCount ?? 0;
                    final int stepsGoal = profile.dailyStepsGoal;
                    final int activeKcal =
                        summary?.activeCaloriesFromSteps ?? 0;

                    return HealthCard(
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: c.soft,
                              borderRadius: BorderRadius.circular(14),
                              border: c.isFlat
                                  ? Border.all(color: c.line2, width: 1.5)
                                  : null,
                            ),
                            child: Icon(
                              AppIcons.pasos,
                              color: c.accent,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Actividad Diaria (NEAT)',
                                  style: TextStyle(
                                    fontFamily: ScFonts.display,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: c.text,
                                  ),
                                ),
                                Text(
                                  '$steps / $stepsGoal pasos · $activeKcal kcal activas registradas',
                                  style: TextStyle(
                                    fontFamily: ScFonts.ui,
                                    fontSize: 12,
                                    color: c.text2,
                                  ),
                                  softWrap: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Tarjeta de Entrenamientos RPE del Día
                StreamBuilder<List<WorkoutBlock>>(
                  stream: workoutDao.watchWorkoutsForDate(todayKey),
                  builder: (context, snap) {
                    final workouts = snap.data ?? [];
                    final int totalNetKcal = workouts.fold(
                      0,
                      (sum, b) => sum + b.netCaloriesBurned,
                    );

                    return HealthCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Entrenamientos RPE de Hoy',
                                      style: TextStyle(
                                        fontFamily: ScFonts.display,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: c.text,
                                      ),
                                    ),
                                    Text(
                                      workouts.isEmpty
                                          ? 'Registra tu esfuerzo en 5 segundos sin contar series'
                                          : '${workouts.length} sesión(es) · +$totalNetKcal kcal netas',
                                      style: TextStyle(
                                        fontFamily: ScFonts.ui,
                                        fontSize: 12,
                                        color: c.text2,
                                      ),
                                      softWrap: true,
                                    ),
                                  ],
                                ),
                              ),
                              if (totalNetKcal > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: c.bg3,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: c.accent,
                                      width: c.isFlat ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Text(
                                    '+$totalNetKcal kcal',
                                    style: TextStyle(
                                      fontFamily: ScFonts.display,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: c.accent,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (workouts.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Divider(height: 1, color: c.line),
                            for (final block in workouts)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      AppIcons.pesa,
                                      size: 18,
                                      color: c.accent,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _translateWorkoutCategory(
                                              block.category,
                                            ),
                                            style: TextStyle(
                                              fontFamily: ScFonts.ui,
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w600,
                                              color: c.text,
                                            ),
                                          ),
                                          Text(
                                            '${block.durationMinutes} min · ${_translateRpe(block.rpeIntensity)} · MET ${block.appliedMet.toStringAsFixed(1)}',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: c.text2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '+${block.netCaloriesBurned} kcal',
                                      style: TextStyle(
                                        fontFamily: ScFonts.display,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: c.accent,
                                      ),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      tooltip: 'Eliminar entrenamiento',
                                      icon: Icon(
                                        AppIcons.delete,
                                        size: 16,
                                        color: c.text3,
                                      ),
                                      onPressed: () =>
                                          _deleteWorkoutWithUndo(block),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                          const SizedBox(height: 12),
                          FilledButton.tonalIcon(
                            onPressed: () => QuickRpeWorkoutSheet.show(
                              context: context,
                              ref: ref,
                              profile: profile,
                            ),
                            icon: const Icon(AppIcons.add, size: 18),
                            label: const Text('Registrar entrenamiento (5s)'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}

class _SomatotypeHeroCard extends StatelessWidget {
  const _SomatotypeHeroCard({
    required this.spec,
    required this.onTap,
  });

  final BiometricMetricSpec spec;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: c.bg2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: c.isFlat ? c.line2 : c.line,
            width: c.isFlat ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: c.soft,
                borderRadius: BorderRadius.circular(14),
                border: c.isFlat
                    ? Border.all(color: c.line2, width: 1.2)
                    : null,
              ),
              child: Icon(spec.icon, color: c.accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spec.title,
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 12,
                      color: c.text3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    spec.valueLabel,
                    style: TextStyle(
                      fontFamily: ScFonts.display,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: c.text,
                    ),
                    softWrap: true,
                  ),
                  Text(
                    spec.subtitle,
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 11,
                      color: c.text2,
                    ),
                    softWrap: true,
                  ),
                ],
              ),
            ),
            Icon(AppIcons.chevronRight, size: 20, color: c.text3),
          ],
        ),
      ),
    );
  }
}

class _MetricGridCard extends StatelessWidget {
  const _MetricGridCard({
    required this.spec,
    required this.onTap,
  });

  final BiometricMetricSpec spec;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final Color toneCol = BiometricMetricCatalog.toneColor(c, spec.tone);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: c.bg2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: c.isFlat ? c.line2 : c.line,
            width: c.isFlat ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(spec.icon, size: 15, color: c.accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    spec.title,
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.text3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              spec.valueLabel,
              style: TextStyle(
                fontFamily: ScFonts.display,
                fontSize: 17.5,
                fontWeight: FontWeight.w800,
                color: c.text,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: toneCol,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    spec.statusLabel,
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: c.isFlat ? c.text2 : toneCol,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
