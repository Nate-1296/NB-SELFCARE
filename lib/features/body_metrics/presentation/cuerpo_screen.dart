import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/body_measurements_dao.dart';
import '../../../core/database/daos/user_profile_dao.dart';
import '../../../core/hardware/body_scale_driver.dart';
import '../../../core/hardware/drivers/xiaomi_miscale2_driver.dart';
import '../../../core/services/health_connect_service.dart';
import '../../../shared/theme/sc_colors.dart';
import '../../../shared/theme/sc_theme.dart';
import '../../../shared/utils/biometric_formulas.dart';
import '../../../shared/utils/date_time_extensions.dart';
import '../../../shared/widgets/app_icons.dart';
import '../../../shared/widgets/health_card.dart';
import '../../../shared/widgets/section_head.dart';
import '../../../shared/widgets/top_bar.dart';

/// Pestaña "Cuerpo": Pesaje Xiaomi Mi Scale 2 BLE, las 13 métricas derivadas,
/// detector de falsa subida, validación US Navy y bloques de entrenamiento RPE.
class CuerpoScreen extends ConsumerStatefulWidget {
  const CuerpoScreen({super.key});

  @override
  ConsumerState<CuerpoScreen> createState() => _CuerpoScreenState();
}

class _CuerpoScreenState extends ConsumerState<CuerpoScreen> {
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

    // Filtro de invitados (si difiere > 8% respecto a la tendencia)
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
    final double bmi = BiometricFormulas.calculateBmi(
      weightKg: weightKg,
      heightCm: profile.heightCm,
    );

    // Derivar métricas BIA solo si hay impedancia real medida por electrodos
    final metrics = impedanceOhms != null
        ? BiometricFormulas.deriveAllMetrics(
            weightKg: weightKg,
            heightCm: profile.heightCm,
            ageYears: age,
            isMale: isMale,
            impedanceOhms: impedanceOhms,
          )
        : null;

    final double currentEma = BiometricFormulas.calculateWeightEma(
      currentWeightKg: weightKg,
      previousEmaKg: latest?.trendWeightKg,
    );

    final double? currentWater = metrics?.waterPercentage ?? latest?.waterPercentage;
    final bool isRetention = latest != null &&
        currentWater != null &&
        BiometricFormulas.detectWaterRetentionSpike(
          currentWeightKg: weightKg,
          previousWeightKg: latest.weightKg,
          currentWaterPct: currentWater,
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
      bmi: drift.Value(bmi),
      bodyFatPercentage: drift.Value(metrics?.bodyFatPercentage ?? latest?.bodyFatPercentage),
      muscleMassKg: drift.Value(metrics?.muscleMassKg ?? latest?.muscleMassKg),
      waterPercentage: drift.Value(currentWater),
      visceralFatIndex: drift.Value(metrics?.visceralFatIndex ?? latest?.visceralFatIndex),
      boneMassKg: drift.Value(metrics?.boneMassKg ?? latest?.boneMassKg),
      proteinPercentage: drift.Value(metrics?.proteinPercentage ?? latest?.proteinPercentage),
      basalMetabolicRateKcal: drift.Value(metrics?.basalMetabolicRateKcal ?? latest?.basalMetabolicRateKcal),
      metabolicAge: drift.Value(metrics?.metabolicAgeYears ?? latest?.metabolicAge),
      leanBodyMassKg: drift.Value(metrics?.leanBodyMassKg ?? latest?.leanBodyMassKg),
      bodyScore: drift.Value(metrics?.bodyScore ?? latest?.bodyScore),
      somatotype: drift.Value(metrics?.bodyType ?? latest?.somatotype),
      isWaterRetentionSpike: drift.Value(isRetention),
    );

    final measurementsDao = ref.read(bodyMeasurementsDaoProvider);
    await measurementsDao.insertMeasurement(companion);

    final healthConnect = ref.read(healthConnectServiceProvider);
    unawaited(
      healthConnect.writeWeightAndBodyFat(
        weightKg: weightKg,
        bodyFatPercentage: metrics?.bodyFatPercentage ?? latest?.bodyFatPercentage,
        timestamp: now,
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Pesaje guardado: ${weightKg.toStringAsFixed(1)} kg! (+15 Monedas)'),
        ),
      );
    }
  }

  void _openManualWeighInDialog(UserProfile profile, BodyMeasurement? latest) {
    final weightCtrl = TextEditingController(text: (latest?.weightKg ?? 70.0).toStringAsFixed(1));
    final impedanceCtrl = TextEditingController(text: '480');

    unawaited(showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pesaje Manual'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: weightCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Peso en kilogramos', suffixText: 'kg'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: impedanceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Impedancia (opcional, ej. 480Ω)', suffixText: 'Ω'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              final double? w = double.tryParse(weightCtrl.text.trim());
              final int? imp = int.tryParse(impedanceCtrl.text.trim());
              if (w != null && w > 0) {
                Navigator.of(ctx).pop();
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
    ));
  }

  void _openNavyTapeMeasureDialog(UserProfile profile, BodyMeasurement? latest) {
    final waistCtrl = TextEditingController(text: '80.0');
    final neckCtrl = TextEditingController(text: '38.0');
    final hipCtrl = TextEditingController(text: '95.0');
    final bool isFemale = profile.biologicalSex == 'female';

    unawaited(showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Validación US Navy (Cinta)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: waistCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Circunferencia Cintura', suffixText: 'cm'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: neckCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Circunferencia Cuello', suffixText: 'cm'),
              ),
              if (isFemale) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: hipCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Circunferencia Cadera', suffixText: 'cm'),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
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

                // Persistir en SQLite (actualiza el último registro o inserta uno nuevo)
                await ref.read(bodyMeasurementsDaoProvider).saveNavyTapeMeasurement(
                  existingMeasurementId: latest?.id,
                  dateKey: DateTime.now().dateKey,
                  waistCm: waist,
                  neckCm: neck,
                  hipCm: hip,
                  validatedBodyFatPercentage: validatedFat,
                  navyBodyFatPercentage: navyFat,
                  defaultWeightKg: latest?.weightKg ?? profile.targetWeightKg,
                  heightCm: profile.heightCm,
                );

                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                }
                if (mounted) {
                  unawaited(showDialog<void>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Resultado Antropométrico'),
                      content: Text(
                        '• Grasa US Navy: ${navyFat.toStringAsFixed(1)}%\n'
                        '• Grasa BIA (Báscula): ${biaFat.toStringAsFixed(1)}%\n'
                        '• Grasa Validada (60/40): ${validatedFat.toStringAsFixed(1)}%\n\n'
                        '¡Excelente para verificar recomposición corporal sin sesgo hídrico!',
                      ),
                      actions: [
                        FilledButton(onPressed: () => Navigator.of(c).pop(), child: const Text('Entendido')),
                      ],
                    ),
                  ));
                }
              }
            },
            child: const Text('Calcular'),
          ),
        ],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AsyncValue<UserProfile?> profileAsync = ref.watch(userProfileStreamProvider);
    final AsyncValue<BodyMeasurement?> latestAsync = ref.watch(latestMeasurementStreamProvider);

    return profileAsync.when(
      data: (UserProfile? profile) {
        if (profile == null) {
          return const Scaffold(body: Center(child: Text('Perfil no inicializado')));
        }

        final latest = latestAsync.value;

        return Scaffold(
          body: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              TopBar(
                title: 'Composición Corporal',
                avatarInicial: profile.name.isNotEmpty ? profile.name[0] : 'N',
                avatarFoto: profile.avatarPath != null && File(profile.avatarPath!).existsSync()
                    ? FileImage(File(profile.avatarPath!))
                    : null,
                onProfile: () => context.go('/perfil'),
              ),

              // Banner de Escaneo en Vivo o Báscula
              HealthCard(
                backgroundColor: _isScanning ? c.accent.withValues(alpha: 0.12) : null,
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
                          ),
                          child: Icon(
                            AppIcons.bluetooth,
                            size: 22,
                            color: _isScanning ? c.ink : c.text,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isScanning ? 'Conectando a Xiaomi Mi Scale 2...' : 'Báscula Xiaomi Mi Scale 2',
                                style: const TextStyle(fontFamily: ScFonts.display, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                _statusMessage ?? 'Lectura pasiva de 13 bytes en BLE 0x181B.',
                                style: TextStyle(fontFamily: ScFonts.ui, fontSize: 12.5, color: c.text2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_liveEvent != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        '${_liveEvent!.weightKg.toStringAsFixed(1)} kg',
                        style: TextStyle(fontFamily: ScFonts.display, fontSize: 36, fontWeight: FontWeight.w800, color: c.accent),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _isScanning ? _stopScaleScan : () => _startScaleScan(profile),
                            icon: Icon(_isScanning ? Icons.stop : AppIcons.bluetooth),
                            label: Text(_isScanning ? 'Detener' : 'Escanear Báscula'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: () => _openManualWeighInDialog(profile, latest),
                          child: const Text('Manual'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Tarjeta Principal de Peso Bruto vs Peso Tendencia EMA / Meta
              HealthCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Peso Actual', style: TextStyle(fontFamily: ScFonts.ui, fontSize: 13, color: c.text3)),
                        Text(
                          latest != null ? latest.dateKey : 'Sin pesaje registrado',
                          style: TextStyle(fontFamily: ScFonts.ui, fontSize: 12, color: c.text3),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          latest != null ? latest.weightKg.toStringAsFixed(1) : '--',
                          style: TextStyle(
                            fontFamily: ScFonts.display,
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                            color: c.text,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('kg', style: TextStyle(fontFamily: ScFonts.display, fontSize: 18, color: c.text2)),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Meta personal:', style: TextStyle(fontSize: 11, color: c.text3)),
                            Text(
                              '${profile.targetWeightKg.toStringAsFixed(1)} kg',
                              style: TextStyle(
                                fontFamily: ScFonts.display,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: c.accent,
                              ),
                            ),
                            if (latest != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Tendencia: ${latest.trendWeightKg.toStringAsFixed(1)} kg',
                                style: TextStyle(fontSize: 11.5, color: c.text2),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    if (latest?.isWaterRetentionSpike == true) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 18, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Variación de líquidos detectada: retención por sodio o carbohidratos, no es grasa.',
                                style: TextStyle(fontSize: 12, color: c.text),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Rejilla de las 13 Métricas Fisiológicas
              const SectionHead(
                title: 'Composición Corporal (13 Métricas)',
                subtitle: 'Derivadas con bioimpedancia o cálculo corporal',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _MetricTile(
                      icon: AppIcons.corazon,
                      title: 'Grasa Corporal',
                      value: latest?.bodyFatPercentage != null
                          ? '${latest!.bodyFatPercentage!.toStringAsFixed(1)}%'
                          : '-- %',
                      hint: 'Tejido adiposo',
                    ),
                    _MetricTile(
                      icon: AppIcons.protein,
                      title: 'Masa Muscular',
                      value: latest?.muscleMassKg != null
                          ? '${latest!.muscleMassKg!.toStringAsFixed(1)} kg'
                          : '-- kg',
                      hint: 'Músculo activo',
                    ),
                    _MetricTile(
                      icon: AppIcons.gota,
                      title: 'Agua Corporal',
                      value: latest?.waterPercentage != null
                          ? '${latest!.waterPercentage!.toStringAsFixed(1)}%'
                          : '-- %',
                      hint: 'Hidratación total',
                    ),
                    _MetricTile(
                      icon: AppIcons.fuego,
                      title: 'Grasa Visceral',
                      value: latest?.visceralFatIndex != null
                          ? 'Nivel ${latest!.visceralFatIndex}'
                          : 'Nivel --',
                      hint: 'Salud visceral (1-9)',
                    ),
                    _MetricTile(
                      icon: Icons.fitness_center_rounded,
                      title: 'Masa Ósea',
                      value: latest?.boneMassKg != null
                          ? '${latest!.boneMassKg!.toStringAsFixed(2)} kg'
                          : '-- kg',
                      hint: 'Estructura ósea',
                    ),
                    _MetricTile(
                      icon: Icons.egg_alt_rounded,
                      title: 'Proteína',
                      value: latest?.proteinPercentage != null
                          ? '${latest!.proteinPercentage!.toStringAsFixed(1)}%'
                          : '-- %',
                      hint: 'Reserva proteica',
                    ),
                    _MetricTile(
                      icon: Icons.bolt_rounded,
                      title: 'Metabolismo Basal',
                      value: latest?.basalMetabolicRateKcal != null
                          ? '${latest!.basalMetabolicRateKcal} kcal'
                          : '-- kcal',
                      hint: 'Gasto en reposo',
                    ),
                    _MetricTile(
                      icon: Icons.cake_rounded,
                      title: 'Edad Metabólica',
                      value: latest?.metabolicAge != null
                          ? '${latest!.metabolicAge} años'
                          : '-- años',
                      hint: 'Salud biológica',
                    ),
                    _MetricTile(
                      icon: Icons.accessibility_new_rounded,
                      title: 'Masa Libre de Grasa',
                      value: latest?.leanBodyMassKg != null
                          ? '${latest!.leanBodyMassKg!.toStringAsFixed(1)} kg'
                          : '-- kg',
                      hint: 'Huesos, agua y músculo',
                    ),
                    _MetricTile(
                      icon: Icons.layers_rounded,
                      title: 'Grasa Subcutánea',
                      value: latest?.bodyFatPercentage != null
                          ? '${(latest!.bodyFatPercentage! * 0.85).toStringAsFixed(1)}%'
                          : '-- %',
                      hint: 'Bajo la piel',
                    ),
                    _MetricTile(
                      icon: Icons.speed_rounded,
                      title: 'IMC',
                      value: latest != null ? latest.bmi.toStringAsFixed(1) : '--',
                      hint: 'Masa / Altura²',
                    ),
                    _MetricTile(
                      icon: Icons.star_rounded,
                      title: 'Puntuación Corporal',
                      value: latest?.bodyScore != null ? '${latest!.bodyScore}/100' : '--/100',
                      hint: 'Índice de bienestar',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Botón Validación Cinta US Navy
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: OutlinedButton.icon(
                  onPressed: () => _openNavyTapeMeasureDialog(profile, latest),
                  icon: const Icon(AppIcons.tape),
                  label: const Text('Medir Cintura y Cuello (Fórmula US Navy)'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.title,
    required this.value,
    this.icon,
    this.hint,
  });

  final String title;
  final String value;
  final IconData? icon;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final double width = (MediaQuery.sizeOf(context).width - 46) / 2;

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.bg2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.isFlat ? c.line2 : c.line, width: c.isFlat ? 1.5 : 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: c.accent),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontFamily: ScFonts.ui, fontSize: 11.5, color: c.text3),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: ScFonts.display,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: c.text,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(
              hint!,
              style: TextStyle(fontFamily: ScFonts.ui, fontSize: 10.5, color: c.text3),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

