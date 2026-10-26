import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/body_measurements_dao.dart';
import '../../../core/database/daos/female_cycle_dao.dart';
import '../../../core/database/daos/food_dao.dart';
import '../../../core/database/daos/supplement_dao.dart';
import '../../../core/database/daos/tdee_dao.dart';
import '../../../core/database/daos/user_profile_dao.dart';
import '../../../core/services/clinical_report_pdf_service.dart';
import '../../../core/services/cross_analytics_engine.dart';
import '../../../core/services/readiness_engine.dart';
import '../../../shared/theme/sc_colors.dart';
import '../../../shared/theme/sc_theme.dart';
import '../../../shared/utils/daily_targets_calculator.dart';
import '../../../shared/utils/date_time_extensions.dart';
import '../../../shared/widgets/app_icons.dart';
import '../../../shared/widgets/health_card.dart';
import '../../../shared/widgets/science_on_demand_sheet.dart';
import '../../../shared/widgets/section_head.dart';
import '../../../shared/widgets/sheet.dart';
import '../../journal/presentation/widgets/digestive_tracker_sheet.dart';
import '../../nutrition_hydration/presentation/widgets/diet_archetype_sheets.dart';
import 'app_settings_screen.dart';
import 'widgets/supplement_tracker_sheet.dart';

/// Pantalla de Perfil de Usuario ("Perfil").
///
/// Diseño ejecutivo y limpio:
/// 1. Hero Card: Foto en grande en el centro con marco decorativo, nombre y datos biométricos dinámicos.
/// 2. Resumen Ejecutivo: Metas, gasto calórico TDEE y gráfico circular de composición metabólica.
/// 3. Correlaciones Offline: Motor estadístico Pearson r.
/// 4. Botón inferior principal: Acceso directo a "Ajustes de la Aplicación".
class PerfilYoScreen extends ConsumerStatefulWidget {
  const PerfilYoScreen({super.key});

  @override
  ConsumerState<PerfilYoScreen> createState() => _PerfilYoScreenState();
}

class _PerfilYoScreenState extends ConsumerState<PerfilYoScreen> {
  bool _isCalibratingTdee = false;
  int _analyticsRefreshEpoch = 0;

  Future<void> _pickProfilePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (image == null) return;

      final Directory appDir = await getApplicationDocumentsDirectory();
      final String ext =
          p.extension(image.path).isEmpty ? '.jpg' : p.extension(image.path);
      final File savedFile = File(p.join(appDir.path, 'profile_avatar$ext'));
      await File(image.path).copy(savedFile.path);

      await ref.read(userProfileDaoProvider).updateProfile(
            UserProfilesCompanion(
              avatarPath: drift.Value(savedFile.path),
            ),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Foto de perfil actualizada! 📸')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo cargar la imagen: $e')),
        );
      }
    }
  }

  Future<void> _calibrateTdeeNow(UserProfile profile) async {
    if (_isCalibratingTdee) return;
    setState(() => _isCalibratingTdee = true);
    unawaited(HapticFeedback.lightImpact());

    try {
      final TdeeCalibrationOutcome outcome =
          await ref.read(tdeeDaoProvider).calibrateFromLast14Days(
                profile: profile,
                profileDao: ref.read(userProfileDaoProvider),
              );

      if (!mounted) return;
      if (outcome.didCalibrate) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '¡TDEE calibrado: ${outcome.previousTdeeKcal} → ${outcome.newTdeeKcal} kcal!'
              '${outcome.wasClamped ? " (ajuste suavizado por seguridad)" : ""}',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Aún faltan registros en los últimos 14 días: '
              '${outcome.foodDaysLogged}/${AppConstants.adaptiveTdeeMinFoodLogDays} días de comida y '
              '${outcome.weighInDaysLogged}/${AppConstants.adaptiveTdeeMinWeighInDays} pesajes.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCalibratingTdee = false);
      }
    }
  }

  void _showEditProfileSheet(UserProfile profile) {
    unawaited(
      mostrarHojaMenu<void>(
        context,
        builder: (_) => _EditProfileSheet(profile: profile),
      ),
    );
  }

  void _showEditGoalsSheet(UserProfile profile) {
    unawaited(
      mostrarHojaMenu<void>(
        context,
        builder: (_) => _EditGoalsSheet(profile: profile),
      ),
    );
  }

  Future<void> _exportClinicalPdf(UserProfile profile) async {
    try {
      unawaited(HapticFeedback.lightImpact());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Generando reporte clínico en PDF... 📄')),
        );
      }

      final BodyMeasurementsDao bodyDao = ref.read(bodyMeasurementsDaoProvider);
      final FoodDao foodDao = ref.read(foodDaoProvider);
      final SupplementDao supplementDao = ref.read(supplementDaoProvider);
      final ReadinessEngine readinessEngine = ref.read(readinessEngineProvider);

      final BodyMeasurement? latest = await bodyDao.getLatestMeasurement();
      final List<BodyMeasurement> recent =
          await bodyDao.getRecentMeasurements(limit: 14);

      final DateTime now = DateTime.now();
      double totalKcal = 0;
      double totalProtein = 0;
      double totalCarbs = 0;
      double totalFat = 0;
      int daysCount = 0;
      for (int i = 0; i < 7; i++) {
        final String key = now.subtract(Duration(days: i)).dateKey;
        final List<FoodLog> logs = await foodDao.getLogsForDate(key);
        if (logs.isNotEmpty) {
          daysCount++;
          for (final FoodLog l in logs) {
            totalKcal += l.totalKcal;
            totalProtein += l.totalProteinG;
            totalCarbs += l.totalCarbsG;
            totalFat += l.totalFatG;
          }
        }
      }

      final List<SupplementsTrackerData> activeSupps =
          await supplementDao.getActiveSupplements();
      final DailyReadinessResult readiness = readinessEngine.compute(
        actualSleepHours: 7.5,
        targetSleepHours: profile.dailySleepGoalHours,
        recent3DayWorkoutHours: 1.5,
        averageRecentRpe: 6.0,
      );

      final double avgKcal = daysCount > 0 ? totalKcal / daysCount : 0.0;
      final double avgP = daysCount > 0 ? totalProtein / daysCount : 0.0;
      final double avgC = daysCount > 0 ? totalCarbs / daysCount : 0.0;
      final double avgF = daysCount > 0 ? totalFat / daysCount : 0.0;

      await ref.read(clinicalReportPdfServiceProvider).shareOrPrintReport(
            profile: profile,
            latestMeasurement: latest,
            recentMeasurements: recent,
            averageDailyKcal: avgKcal.round(),
            averageProteinG: avgP,
            averageCarbsG: avgC,
            averageFatG: avgF,
            averageSleepHours: 7.5,
            activeSupplements: activeSupps,
            readinessScore: readiness.totalScore,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AsyncValue<UserProfile?> profileAsync =
        ref.watch(userProfileStreamProvider);
    final TdeeCalibration? latestCalibration =
        ref.watch(latestTdeeCalibrationStreamProvider).value;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: profileAsync.when(
          data: (UserProfile? profile) {
            if (profile == null) {
              return const Center(child: Text('Perfil no encontrado'));
            }

            // Edad dinámica calculada al vuelo según regla arquitectónica innegociable
            final double ageYears =
                DateTime.now().difference(profile.birthDate).inDays / 365.25;
            final DailyMacroTargets targets = DailyTargetsCalculator.compute(
              profile: profile,
            );

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              children: <Widget>[
                // ==========================================
                // 1. Tarjeta Hero de Identidad Personal
                // ==========================================
                _ProfileHeroCard(
                  profile: profile,
                  ageYears: ageYears,
                  onPickPhoto: _pickProfilePhoto,
                  onEditProfile: () => _showEditProfileSheet(profile),
                ),

                const SizedBox(height: 16),

                // ==========================================
                // 2. Resumen de Metas y Gasto Calórico
                // ==========================================
                _ProfileExecutiveSummaryCard(
                  profile: profile,
                  targets: targets,
                  latestCalibration: latestCalibration,
                  isCalibratingTdee: _isCalibratingTdee,
                  onCalibrateTdee: () => _calibrateTdeeNow(profile),
                  onEditGoals: () => _showEditGoalsSheet(profile),
                ),

                // ==========================================
                // 3. Salud Femenina (ÚNICAMENTE si el perfil es femenino)
                // ==========================================
                if (profile.biologicalSex == 'female') ...[
                  const SizedBox(height: 16),
                  _FemaleCycleCard(profile: profile),
                ],

                const SizedBox(height: 16),

                // Suplementación y Digestión
                IntrinsicHeight(
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            unawaited(HapticFeedback.selectionClick());
                            unawaited(
                              SupplementTrackerSheet.show(
                                context,
                                dateKey: DateTime.now().dateKey,
                              ),
                            );
                          },
                          icon: const Icon(Icons.medication_rounded, size: 18),
                          label: const Text('Suplementos'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            side: BorderSide(
                              color: c.isFlat ? c.line2 : c.line,
                              width: c.isFlat ? 1.4 : 1.0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            unawaited(HapticFeedback.selectionClick());
                            unawaited(
                              DigestiveTrackerSheet.show(
                                context,
                                dateKey: DateTime.now().dateKey,
                              ),
                            );
                          },
                          icon: const Icon(Icons.health_and_safety_rounded,
                              size: 18),
                          label: const Text('Salud Digestiva'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            side: BorderSide(
                              color: c.isFlat ? c.line2 : c.line,
                              width: c.isFlat ? 1.4 : 1.0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ==========================================
                // 4. Correlaciones y Descubrimientos Offline
                // ==========================================
                const SectionHead(
                  title: 'Correlaciones y Descubrimientos',
                  subtitle:
                      'Patrones cruzados entre nutrición, sueño, ayuno y diario',
                  padding: EdgeInsets.symmetric(vertical: 4),
                ),
                const SizedBox(height: 8),
                _CrossAnalyticsCard(
                  refreshEpoch: _analyticsRefreshEpoch,
                  onRefresh: () {
                    setState(() {
                      _analyticsRefreshEpoch++;
                    });
                  },
                ),

                const SizedBox(height: 20),

                // ==========================================
                // Mi Protocolo y Reporte Clínico PDF
                // ==========================================
                IntrinsicHeight(
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            unawaited(HapticFeedback.lightImpact());
                            unawaited(context.push('/protocolo'));
                          },
                          icon: const Icon(Icons.calendar_month_rounded, size: 19),
                          label: const Text('Mi Protocolo'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            side: BorderSide(
                              color: c.isFlat ? c.line2 : c.line,
                              width: c.isFlat ? 1.4 : 1.0,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _exportClinicalPdf(profile),
                          icon: const Icon(Icons.picture_as_pdf_rounded, size: 19),
                          label: const Text('Reporte PDF'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            side: BorderSide(
                              color: c.isFlat ? c.line2 : c.line,
                              width: c.isFlat ? 1.4 : 1.0,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ==========================================
                // 4. Botón Principal: Ajustes de la Aplicación
                // ==========================================
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                        color: c.isFlat ? c.line2 : Colors.transparent,
                        width: c.isFlat ? 1.5 : 0.0,
                      ),
                    ),
                    backgroundColor: c.isFlat ? c.bg3 : c.accent,
                    foregroundColor: c.isFlat ? c.text : c.ink,
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.settings_outlined, size: 21),
                  label: const Text(
                    'Ajustes de la Aplicación',
                    style: TextStyle(
                      fontFamily: ScFonts.display,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.1,
                    ),
                  ),
                  onPressed: () {
                    unawaited(HapticFeedback.lightImpact());
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AppSettingsScreen(),
                      ),
                    );
                  },
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
}

/// Tarjeta Hero de Perfil con foto en grande en medio, decoración radial,
/// nombre destacado y datos biométricos dinámicos sin texto redundante.
class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.profile,
    required this.ageYears,
    required this.onPickPhoto,
    required this.onEditProfile,
  });

  final UserProfile profile;
  final double ageYears;
  final VoidCallback onPickPhoto;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final bool hasAvatar = profile.avatarPath != null &&
        File(profile.avatarPath!).existsSync();
    final String sexLabel =
        profile.biologicalSex == 'male' ? 'Hombre' : 'Mujer';

    return HealthCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: <Widget>[
          // Foto en grande rodeada de anillo decorativo reactivo al tema
          Center(
            child: GestureDetector(
              onTap: onPickPhoto,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  // Marco radial decorativo exterior
                  Container(
                    width: 126,
                    height: 126,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.isFlat ? c.bg3 : c.soft,
                      border: Border.all(
                        color: c.isFlat
                            ? c.line2
                            : c.accent.withValues(alpha: 0.45),
                        width: c.isFlat ? 2.0 : 1.8,
                      ),
                    ),
                  ),
                  // Avatar de usuario
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.bg3,
                      border: Border.all(
                        color: c.isFlat ? c.text : c.accent,
                        width: 2.2,
                      ),
                      image: hasAvatar
                          ? DecorationImage(
                              image: FileImage(File(profile.avatarPath!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: hasAvatar
                        ? null
                        : Center(
                            child: Text(
                              profile.name.isNotEmpty
                                  ? profile.name[0].toUpperCase()
                                  : 'U',
                              style: TextStyle(
                                fontFamily: ScFonts.display,
                                fontSize: 44,
                                fontWeight: FontWeight.w800,
                                color: c.accent,
                              ),
                            ),
                          ),
                  ),
                  // Botón flotante para cambiar foto
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: c.isFlat ? c.text : c.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.bg2, width: 2),
                      ),
                      child: Icon(
                        Icons.camera_alt_rounded,
                        size: 16,
                        color: c.isFlat ? c.bg : c.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Nombre de usuario en tipografía display destacada
          Text(
            profile.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: ScFonts.display,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: c.text,
            ),
          ),

          const SizedBox(height: 10),

          // Chips ordenados de datos biométricos dinámicos
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: <Widget>[
              _StatChip(
                icon: Icons.cake_rounded,
                label: '${ageYears.floor()} años',
              ),
              _StatChip(
                icon: profile.biologicalSex == 'male'
                    ? Icons.male_rounded
                    : Icons.female_rounded,
                label: sexLabel,
              ),
              _StatChip(
                icon: Icons.height_rounded,
                label: '${profile.heightCm.toStringAsFixed(0)} cm',
              ),
              _StatChip(
                icon: AppIcons.cuerpo,
                label: '${profile.targetWeightKg.toStringAsFixed(1)} kg meta',
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Botón para editar perfil
          SizedBox(
            width: 170,
            child: OutlinedButton.icon(
              onPressed: onEditProfile,
              icon: Icon(AppIcons.edit, size: 15, color: c.accent),
              label: Text(
                'Editar Perfil',
                style: TextStyle(
                  fontFamily: ScFonts.ui,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                ),
              ),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                side: BorderSide(color: c.isFlat ? c.line2 : c.line),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.bg3,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: c.isFlat ? c.line2 : c.line,
          width: c.isFlat ? 1.3 : 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: c.isFlat ? c.text : c.accent),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: c.text2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de Resumen Ejecutivo con gráfico circular centrado y tarjetas de métricas.
class _ProfileExecutiveSummaryCard extends StatelessWidget {
  const _ProfileExecutiveSummaryCard({
    required this.profile,
    required this.targets,
    required this.latestCalibration,
    required this.isCalibratingTdee,
    required this.onCalibrateTdee,
    required this.onEditGoals,
  });

  final UserProfile profile;
  final DailyMacroTargets targets;
  final TdeeCalibration? latestCalibration;
  final bool isCalibratingTdee;
  final VoidCallback onCalibrateTdee;
  final VoidCallback onEditGoals;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;

    final double pKcal = targets.proteinTargetG * 4.0;
    final double cKcal = targets.carbsTargetG * 4.0;
    final double fKcal = targets.fatTargetG * 9.0;
    final double totalMacroKcal = math.max(1.0, pKcal + cKcal + fKcal);

    final double pPct = (pKcal / totalMacroKcal) * 100;
    final double cPct = (cKcal / totalMacroKcal) * 100;
    final double fPct = (fKcal / totalMacroKcal) * 100;

    return HealthCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Cabecera espaciosa y limpia con acceso a ciencia pedagógica
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Metas y Gasto Calórico',
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 17.5,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      profile.isManualMacroMode == true
                          ? 'Modo Manual / Prescripción Médica'
                          : 'Calibración adaptativa en ventana de 14 días',
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
                icon: Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: c.accent,
                ),
                tooltip: 'Ciencia del cálculo calórico',
                onPressed: () => _showTdeeScience(context),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // Gráfico circular centrado y en grande
          Center(
            child: SizedBox(
              width: 148,
              height: 148,
              child: CustomPaint(
                painter: _NutritionalPieChartPainter(
                  proteinPct: pPct,
                  carbsPct: cPct,
                  fatPct: fPct,
                  proteinColor: c.protein,
                  carbsColor: c.carbs,
                  fatColor: c.fat,
                  backgroundColor: c.bg3,
                  isFlat: c.isFlat,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '${targets.effectiveCalorieTargetKcal}',
                        style: TextStyle(
                          fontFamily: ScFonts.display,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: c.text,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'kcal / día',
                        style: TextStyle(
                          fontFamily: ScFonts.ui,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: c.text3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Leyenda horizontal espaciosa con gramos y porcentajes
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 6,
              children: <Widget>[
                _LegendDot(
                  color: c.protein,
                  label:
                      'Proteína ${targets.proteinTargetG.toStringAsFixed(0)}g (${pPct.toStringAsFixed(0)}%)',
                ),
                _LegendDot(
                  color: c.carbs,
                  label:
                      'Carbos ${targets.carbsTargetG.toStringAsFixed(0)}g (${cPct.toStringAsFixed(0)}%)',
                ),
                _LegendDot(
                  color: c.fat,
                  label:
                      'Grasas ${targets.fatTargetG.toStringAsFixed(0)}g (${fPct.toStringAsFixed(0)}%)',
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Cuadrícula 2x2 de tarjetas para los datos pequeños con ciencia pedagógica al toque
          Row(
            children: <Widget>[
              Expanded(
                child: _ExecutiveStatCard(
                  icon: AppIcons.fuego,
                  iconColor: c.calories,
                  label: 'TDEE Adaptativo',
                  value: '${profile.currentAdaptiveTdeeKcal} kcal',
                  subtext: latestCalibration != null
                      ? 'Calibrado ${latestCalibration!.dateKey}'
                      : 'Estimación inicial',
                  onTap: () => _showTdeeScience(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ExecutiveStatCard(
                  icon: AppIcons.cuerpo,
                  iconColor: c.accent,
                  label: 'Meta de Peso',
                  value: '${profile.targetWeightKg.toStringAsFixed(1)} kg',
                  subtext: 'Objetivo corporal',
                  onTap: () => _showWeightTrendScience(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _ExecutiveStatCard(
                  icon: AppIcons.gota,
                  iconColor: c.water,
                  label: 'Meta Hidratación',
                  value: '${profile.dailyWaterGoalMl} ml',
                  subtext:
                      '${(profile.dailyWaterGoalMl / 250).round()} vasos recomendados',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ExecutiveStatCard(
                  icon: AppIcons.pasos,
                  iconColor: c.steps,
                  label: 'Pasos y Sueño',
                  value: '${profile.dailyStepsGoal} pasos',
                  subtext:
                      '${profile.dailySleepGoalHours.toStringAsFixed(1)}h descanso meta',
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Botón 1: Ajustar Metas (arriba de auto-calibrar, expandido y destacado)
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.tonalIcon(
              onPressed: onEditGoals,
              icon: Icon(AppIcons.edit, size: 16, color: c.accent),
              label: const Text(
                'Ajustar Metas Nutricionales y Calóricas',
                style: TextStyle(
                  fontFamily: ScFonts.ui,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: c.isFlat ? c.line2 : Colors.transparent,
                    width: c.isFlat ? 1.5 : 0.0,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Botón 2: Auto-Calibrar TDEE (abajo, expandido con estilo outline)
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: isCalibratingTdee ? null : onCalibrateTdee,
              icon: Icon(
                isCalibratingTdee
                    ? Icons.hourglass_top_rounded
                    : Icons.auto_awesome_rounded,
                size: 16,
                color: c.accent,
              ),
              label: Text(
                isCalibratingTdee
                    ? 'Evaluando últimos 14 días...'
                    : 'Auto-Calibrar TDEE con IA Local (14 días)',
                style: const TextStyle(
                  fontFamily: ScFonts.ui,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: c.isFlat ? c.line2 : c.line,
                  width: c.isFlat ? 1.5 : 1.0,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _showTdeeScience(BuildContext context) {
  unawaited(
    ScienceOnDemandSheet.show(
      context,
      const ScienceSpec(
        title: 'Gasto Energético Diario (TDEE)',
        badgeLabel: 'Metabolismo Basal + Actividad',
        icon: AppIcons.fuego,
        quickTake:
            'Tu TDEE es la energía real gastada por tu organismo en 24 horas sumando metabolismo basal, digestión y movimiento.',
        howItWorks:
            'A diferencia de las fórmulas estándar estáticas que asumen factores teóricos fijos, NB Selfcare utiliza un filtro de suavizado exponencial (EMA) de 14 días cruzando tu ingesta calórica diaria con la oscilación real del peso filtrado para calcular con exactitud tu gasto metabólico verdadero.',
        formula:
            'TDEE = Ingesta Diaria (kcal) - [Δ Peso Filtrado (kg) × 7700 kcal / Días]',
        scientificReferences: <String>[
          'Hall, K. D. et al. (2011). Quantification of the effect of energy imbalance on bodyweight. The Lancet.',
          'Mifflin, M. D. et al. (1990). A new predictive equation for resting energy expenditure.',
        ],
        actionableAdvice:
            'Registra tus comidas y pésate con frecuencia. Cuantos más días consecutivos con registros existan, mayor precisión matemática tendrá la calibración.',
      ),
    ),
  );
}

void _showWeightTrendScience(BuildContext context) {
  unawaited(
    ScienceOnDemandSheet.show(
      context,
      const ScienceSpec(
        title: 'Tendencia de Peso y Fluctuaciones',
        badgeLabel: 'Masa Grasa vs Agua Transitoria',
        icon: AppIcons.cuerpo,
        quickTake:
            'Las subidas o bajadas bruscas de peso de un día para otro casi nunca son grasa corporal, sino variaciones de agua, glucógeno y contenido digestivo.',
        howItWorks:
            'Almacenar 1 gramo de glucógeno retiene entre 3 y 4 gramos de agua intracelular. Una comida con más carbohidratos o sodio, un entrenamiento muscular intenso, la ingesta de creatina o la fase lútea pueden alterar el peso en 1 a 2.5 kg de pura agua transitoria.',
        formula: '1g Glucógeno = +3.5g H₂O retención celular',
        scientificReferences: <String>[
          'Fernández-Elías, V. E. et al. (2015). Relationship between muscle water and glycogen recovery.',
          'Davy, K. P. & Hall, J. E. (2004). Weight gain and hormonal fluid retention.',
        ],
        actionableAdvice:
            'No te alarmes por picos puntuales. Observa siempre la media móvil semanal suavizada (EMA) y el porcentaje de grasa medido por impedancia.',
      ),
    ),
  );
}

class _ExecutiveStatCard extends StatelessWidget {
  const _ExecutiveStatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.subtext,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String subtext;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final Widget cardBody = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: c.bg3,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: c.isFlat ? c.line2 : c.line,
          width: c.isFlat ? 1.4 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 15, color: c.isFlat ? c.text : iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: c.text2,
                  ),
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.help_outline_rounded,
                  size: 13,
                  color: c.text3,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: ScFonts.display,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: c.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 10,
              color: c.text3,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: cardBody,
        ),
      );
    }

    return cardBody;
  }
}

/// Tarjeta de Salud Femenina y Seguimiento Hormonal (oculta 100% para hombres).
class _FemaleCycleCard extends ConsumerWidget {
  const _FemaleCycleCard({required this.profile});

  final UserProfile profile;

  void _showCycleScience(BuildContext context) {
    unawaited(
      ScienceOnDemandSheet.show(
        context,
        const ScienceSpec(
          title: 'Ciclo Hormonal y Gasto Calórico',
          badgeLabel: 'Progesterona, Fase Lútea y Retención',
          icon: Icons.female_rounded,
          quickTake:
              'Durante la fase lútea (entre la ovulación y el inicio del período), el aumento de progesterona eleva la temperatura corporal y acelera el gasto basal.',
          howItWorks:
              'En la fase lútea el gasto energético en reposo sube entre 100 y 300 kcal/día. Simultáneamente, el alza hormonal retiene sodio y agua (+1 a +2 kg), reflejándose en la báscula sin que exista aumento de grasa corporal.',
          formula: 'Gasto Lúteo = BMR + 100~300 kcal/día | Retención = +1~2 kg H₂O',
          scientificReferences: <String>[
            'Webb, P. (1986). 24-hour energy expenditure and the menstrual cycle.',
            'Barr, S. I. et al. (1995). Rest energy expenditure increases in the luteal phase.',
          ],
          actionableAdvice:
              'Si tu peso sube durante la segunda mitad de tu ciclo, ¡es agua transitoria! NB Selfcare ajusta automáticamente tus calorías diarias para acompañarte.',
        ),
      ),
    );
  }

  Future<void> _logNewPeriod(BuildContext context, WidgetRef ref) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 60)),
      lastDate: now,
      helpText: 'Selecciona la fecha de inicio del período',
    );
    if (picked != null) {
      await ref.read(femaleCycleDaoProvider).logCycleStart(
            cycleStartDate: picked,
            cycleLengthDays: 28,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Inicio de ciclo registrado con éxito! 🌸'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final AsyncValue<FemaleCycleLog?> cycleAsync =
        ref.watch(latestFemaleCycleStreamProvider);

    return HealthCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    Icons.female_rounded,
                    size: 20,
                    color: c.isFlat ? c.text : c.accent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Salud Femenina y Ciclo',
                    style: TextStyle(
                      fontFamily: ScFonts.display,
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      color: c.text,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: c.accent,
                ),
                tooltip: 'Ciencia del ciclo hormonal',
                onPressed: () => _showCycleScience(context),
              ),
            ],
          ),
          const SizedBox(height: 10),
          cycleAsync.when(
            data: (FemaleCycleLog? latest) {
              if (latest == null) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.bg3,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: c.isFlat ? c.line2 : c.line,
                      width: c.isFlat ? 1.3 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Registra el inicio de tu ciclo actual',
                        style: TextStyle(
                          fontFamily: ScFonts.ui,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: c.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Permite calibrar el gasto metabólico de la fase lútea (+150 kcal/día) y contextualizar fluctuaciones normales de retención hídrica en la báscula.',
                        style: TextStyle(
                          fontFamily: ScFonts.ui,
                          fontSize: 11.5,
                          color: c.text2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          side: BorderSide(color: c.isFlat ? c.line2 : c.accent),
                        ),
                        onPressed: () => _logNewPeriod(context, ref),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Registrar inicio de período'),
                      ),
                    ],
                  ),
                );
              }

              final DateTime today = DateTime.now();
              final int diffDays =
                  today.difference(latest.cycleStartDate).inDays;
              final int cycleLength =
                  latest.cycleLengthDays > 0 ? latest.cycleLengthDays : 28;
              final int currentCycleDay = (diffDays % cycleLength) + 1;

              String phaseName;
              String phaseDesc;
              bool isLuteal = false;

              if (currentCycleDay <= 5) {
                phaseName = 'Fase Menstrual';
                phaseDesc =
                    'Días de renovación. Prioriza descanso e hidratación.';
              } else if (currentCycleDay <= 13) {
                phaseName = 'Fase Folicular';
                phaseDesc =
                    'Sensibilidad a la insulina óptima y mayor energía física.';
              } else if (currentCycleDay <= 16) {
                phaseName = 'Fase de Ovulación';
                phaseDesc =
                    'Pico de estrógenos. Fuerza y capacidad de trabajo máxima.';
              } else {
                phaseName = 'Fase Lútea (Premenstrual)';
                phaseDesc =
                    'Aumento de progesterona. Gasto basal aumentado (+150 kcal/día) y posible retención hídrica en báscula.';
                isLuteal = true;
              }

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.bg3,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: c.isFlat ? c.line2 : c.line,
                    width: c.isFlat ? 1.3 : 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: c.isFlat
                                ? c.line2
                                : (isLuteal
                                    ? c.accent.withValues(alpha: 0.18)
                                    : c.soft),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$phaseName • Día $currentCycleDay de $cycleLength',
                            style: TextStyle(
                              fontFamily: ScFonts.display,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: c.isFlat ? c.text : c.accent,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _logNewPeriod(context, ref),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text(
                            'Nuevo ciclo',
                            style: TextStyle(fontSize: 11.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      phaseDesc,
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 12,
                        color: c.text2,
                        height: 1.3,
                      ),
                    ),
                    if (isLuteal) ...<Widget>[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: c.isFlat
                              ? c.bg2
                              : c.accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: c.isFlat
                                ? c.line2
                                : c.accent.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.local_fire_department_rounded,
                              size: 16,
                              color: c.calories,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Ajuste metabólico activo: +150 kcal añadidas a tu meta diaria para sostener la termogénesis lútea.',
                                style: TextStyle(
                                  fontFamily: ScFonts.ui,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: c.text,
                                ),
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
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (Object e, _) => Text(
              'No se pudo cargar el ciclo: $e',
              style: TextStyle(color: c.text3, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontFamily: ScFonts.ui,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: c.text2,
          ),
        ),
      ],
    );
  }
}

/// CustomPainter para el gráfico de pastel/anillo de composición nutricional
/// garantizando definición nítida en modo dual (OLED y Papel E-Ink).
class _NutritionalPieChartPainter extends CustomPainter {
  _NutritionalPieChartPainter({
    required this.proteinPct,
    required this.carbsPct,
    required this.fatPct,
    required this.proteinColor,
    required this.carbsColor,
    required this.fatColor,
    required this.backgroundColor,
    required this.isFlat,
  });

  final double proteinPct;
  final double carbsPct;
  final double fatPct;
  final Color proteinColor;
  final Color carbsColor;
  final Color fatColor;
  final Color backgroundColor;
  final bool isFlat;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double strokeWidth = isFlat ? 18.0 : 16.0;
    final double radius = (size.width - strokeWidth) / 2;

    final Paint bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, bgPaint);

    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    int activeSegments = 0;
    if (proteinPct > 0) activeSegments++;
    if (carbsPct > 0) activeSegments++;
    if (fatPct > 0) activeSegments++;

    // Separación angular limpia entre rebanadas (indispensable para NXTPAPER / E-Ink y estética de calidad)
    final double gapAngle = activeSegments > 1 ? (isFlat ? 0.08 : 0.05) : 0.0;
    double currentAngle = -math.pi / 2;

    void drawSegment(double pct, Color color) {
      if (pct <= 0) return;
      final double totalSweep = (pct / 100.0) * 2 * math.pi;
      final double sweepAngle = math.max(0.01, totalSweep - gapAngle);
      final double startWithGap = currentAngle + (gapAngle / 2);

      final Paint paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = isFlat ? StrokeCap.butt : StrokeCap.round;

      canvas.drawArc(rect, startWithGap, sweepAngle, false, paint);

      // Si estamos en modo plano / papel E-Ink, dibujamos además divisores nítidos
      if (isFlat && activeSegments > 1) {
        final Paint dividerPaint = Paint()
          ..color = backgroundColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;

        final double x1 = center.dx +
            (radius - strokeWidth / 2 - 1) * math.cos(currentAngle);
        final double y1 = center.dy +
            (radius - strokeWidth / 2 - 1) * math.sin(currentAngle);
        final double x2 = center.dx +
            (radius + strokeWidth / 2 + 1) * math.cos(currentAngle);
        final double y2 = center.dy +
            (radius + strokeWidth / 2 + 1) * math.sin(currentAngle);
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), dividerPaint);
      }

      currentAngle += totalSweep;
    }

    drawSegment(proteinPct, proteinColor);
    drawSegment(carbsPct, carbsColor);
    drawSegment(fatPct, fatColor);

    // Si es modo plano / papel, dibujar bordes exterior e interior sutiles para definición nítida E-Ink
    if (isFlat) {
      final Paint rimPaint = Paint()
        ..color = backgroundColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(center, radius - strokeWidth / 2, rimPaint);
      canvas.drawCircle(center, radius + strokeWidth / 2, rimPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NutritionalPieChartPainter oldDelegate) {
    return oldDelegate.proteinPct != proteinPct ||
        oldDelegate.carbsPct != carbsPct ||
        oldDelegate.fatPct != fatPct ||
        oldDelegate.proteinColor != proteinColor ||
        oldDelegate.carbsColor != carbsColor ||
        oldDelegate.fatColor != fatColor ||
        oldDelegate.isFlat != isFlat;
  }
}

/// Tarjeta de Correlaciones Pearson Offline.
class _CrossAnalyticsCard extends ConsumerWidget {
  const _CrossAnalyticsCard({
    required this.refreshEpoch,
    this.onRefresh,
  });

  final int refreshEpoch;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final CrossAnalyticsEngine engine = ref.watch(crossAnalyticsEngineProvider);

    return FutureBuilder<List<CrossCorrelationInsight>>(
      key: ValueKey<int>(refreshEpoch),
      future: engine.computeInsights(),
      builder: (BuildContext context,
          AsyncSnapshot<List<CrossCorrelationInsight>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const HealthCard(
            margin: EdgeInsets.zero,
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final List<CrossCorrelationInsight> insights =
            snapshot.data ?? const <CrossCorrelationInsight>[];

        return HealthCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.hub_rounded, size: 20, color: c.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Correlaciones Estadísticas (Pearson r)',
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: c.text,
                      ),
                    ),
                  ),
                  if (onRefresh != null)
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      tooltip: 'Recalcular correlaciones',
                      onPressed: () {
                        unawaited(HapticFeedback.selectionClick());
                        onRefresh!();
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (insights.isEmpty) ...<Widget>[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.bg3,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: c.isFlat ? c.line2 : c.line,
                      width: c.isFlat ? 1.3 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.auto_graph_rounded,
                            size: 16,
                            color: c.isFlat ? c.text : c.accent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Calibrando correlaciones multivariables',
                              style: TextStyle(
                                fontFamily: ScFonts.ui,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: c.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'El motor offline requiere al menos 10 días de registros para correlacionar con significancia estadística variables de nutrición, sueño, ayuno y energía.',
                        style: TextStyle(
                          fontFamily: ScFonts.ui,
                          fontSize: 11.5,
                          height: 1.35,
                          color: c.text2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 13,
                            color: c.text3,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              '100% Offline • Cero telemetría • Computación local',
                              style: TextStyle(
                                fontFamily: ScFonts.ui,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: c.text3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...<Widget>[
                Text(
                  'Descubrimientos matemáticos cruzando tus métricas y el diario de Hoy:',
                  style: TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: 12,
                    color: c.text2,
                  ),
                ),
                const SizedBox(height: 10),
                for (final CrossCorrelationInsight ins in insights)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.bg3,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: c.isFlat ? c.line2 : c.line,
                          width: c.isFlat ? 1.3 : 1.0,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: c.isFlat
                                  ? c.line2
                                  : c.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'r = ${ins.correlationR.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontFamily: ScFonts.display,
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: c.isFlat ? c.text : c.accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  ins.title,
                                  style: TextStyle(
                                    fontFamily: ScFonts.ui,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: c.text,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  ins.description,
                                  style: TextStyle(
                                    fontFamily: ScFonts.ui,
                                    fontSize: 11.5,
                                    color: c.text2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Hoja modal rediseñada para editar datos personales con recálculo dinámico de edad.
class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _heightCtrl;
  late final TextEditingController _weightCtrl;
  late String _sex;
  late DateTime _birthDate;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.profile.name);
    _heightCtrl = TextEditingController(
      text: widget.profile.heightCm.toStringAsFixed(0),
    );
    _weightCtrl = TextEditingController(
      text: widget.profile.targetWeightKg.toStringAsFixed(1),
    );
    _sex = widget.profile.biologicalSex;
    _birthDate = widget.profile.birthDate;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final double dynamicAge =
        DateTime.now().difference(_birthDate).inDays / 365.25;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Editar Datos Personales',
                style: TextStyle(
                  fontFamily: ScFonts.display,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: c.text,
                ),
              ),
              IconButton(
                icon: Icon(AppIcons.close, color: c.text2),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Nombre o Alias',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: const <ButtonSegment<String>>[
                ButtonSegment<String>(
                  value: 'male',
                  label: Text('Hombre'),
                  icon: Icon(Icons.male_rounded),
                ),
                ButtonSegment<String>(
                  value: 'female',
                  label: Text('Mujer'),
                  icon: Icon(Icons.female_rounded),
                ),
              ],
              selected: <String>{_sex},
              onSelectionChanged: (Set<String> set) =>
                  setState(() => _sex = set.first),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: c.isFlat ? c.line2 : c.line),
            ),
            title: const Text(
              'Fecha de Nacimiento',
              style: TextStyle(fontSize: 13),
            ),
            subtitle: Text(
              '${_birthDate.day}/${_birthDate.month}/${_birthDate.year} (${dynamicAge.floor()} años calculados)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            trailing: const Icon(Icons.calendar_today_rounded, size: 20),
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: _birthDate,
                firstDate: DateTime(1920),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() => _birthDate = picked);
              }
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _heightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Altura',
                    suffixText: 'cm',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _weightCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Peso Meta',
                    suffixText: 'kg',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () async {
                final String newName = _nameCtrl.text.trim();
                final double newHeight = double.tryParse(
                      _heightCtrl.text.replaceAll(',', '.'),
                    ) ??
                    widget.profile.heightCm;
                final double newWeight = double.tryParse(
                      _weightCtrl.text.replaceAll(',', '.'),
                    ) ??
                    widget.profile.targetWeightKg;

                if (newName.isNotEmpty) {
                  await ref.read(userProfileDaoProvider).updateProfile(
                        UserProfilesCompanion(
                          name: drift.Value(newName),
                          biologicalSex: drift.Value(_sex),
                          birthDate: drift.Value(_birthDate),
                          heightCm: drift.Value(newHeight),
                          targetWeightKg: drift.Value(newWeight),
                        ),
                      );
                }

                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text(
                'Guardar Cambios',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hoja modal rediseñada para ajustar metas personales sin desbordes.
class _EditGoalsSheet extends ConsumerStatefulWidget {
  const _EditGoalsSheet({required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<_EditGoalsSheet> createState() => _EditGoalsSheetState();
}

class _EditGoalsSheetState extends ConsumerState<_EditGoalsSheet> {
  late final TextEditingController _weightCtrl;
  late final TextEditingController _waterCtrl;
  late final TextEditingController _stepsCtrl;
  late final TextEditingController _sleepCtrl;
  late final TextEditingController _manualKcalCtrl;
  late final TextEditingController _manualProteinCtrl;
  late final TextEditingController _manualCarbsCtrl;
  late final TextEditingController _manualFatCtrl;

  late double _weeklyRateKg;
  late bool _isManualMode;
  late String _activeDietPhase;

  @override
  void initState() {
    super.initState();
    _weightCtrl = TextEditingController(
      text: widget.profile.targetWeightKg.toStringAsFixed(1),
    );
    _waterCtrl = TextEditingController(
      text: widget.profile.dailyWaterGoalMl.toString(),
    );
    _stepsCtrl = TextEditingController(
      text: widget.profile.dailyStepsGoal.toString(),
    );
    _sleepCtrl = TextEditingController(
      text: widget.profile.dailySleepGoalHours.toStringAsFixed(1),
    );
    _manualKcalCtrl = TextEditingController(
      text: (widget.profile.manualKcalTarget ?? 2000).toString(),
    );
    _manualProteinCtrl = TextEditingController(
      text: (widget.profile.manualProteinG ?? 150).toString(),
    );
    _manualCarbsCtrl = TextEditingController(
      text: (widget.profile.manualCarbsG ?? 200).toString(),
    );
    _manualFatCtrl = TextEditingController(
      text: (widget.profile.manualFatG ?? 60).toString(),
    );

    _weeklyRateKg = widget.profile.weeklyGoalRateKg.clamp(-1.0, 0.5);
    _isManualMode = widget.profile.isManualMacroMode;
    _activeDietPhase = widget.profile.activeDietPhase;
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _waterCtrl.dispose();
    _stepsCtrl.dispose();
    _sleepCtrl.dispose();
    _manualKcalCtrl.dispose();
    _manualProteinCtrl.dispose();
    _manualCarbsCtrl.dispose();
    _manualFatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'Ajustar Metas Nutricionales',
                  style: TextStyle(
                    fontFamily: ScFonts.display,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: c.text,
                  ),
                ),
                IconButton(
                  icon: Icon(AppIcons.close, color: c.text2),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Selector de Modo: Adaptativo vs Manual
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                segments: const <ButtonSegment<bool>>[
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('Modo Adaptativo'),
                    icon: Icon(Icons.auto_awesome_rounded),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('Modo Manual'),
                    icon: Icon(Icons.tune_rounded),
                  ),
                ],
                selected: <bool>{_isManualMode},
                onSelectionChanged: (Set<bool> sel) {
                  setState(() => _isManualMode = sel.first);
                },
              ),
            ),
            const SizedBox(height: 14),

            if (_isManualMode) ...<Widget>[
              // Sección de Macros Manuales
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.bg3,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: c.isFlat ? c.line2 : c.line,
                    width: c.isFlat ? 1.3 : 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Prescripción Manual de Macronutrientes',
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sobrescribe el algoritmo adaptativo con tus propios valores o prescripción médica/nutricional.',
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 11,
                        color: c.text2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: _manualKcalCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Calorías',
                              suffixText: 'kcal',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _manualProteinCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Proteína',
                              suffixText: 'g',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: _manualCarbsCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Carbohidratos',
                              suffixText: 'g',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _manualFatCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Grasas',
                              suffixText: 'g',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else ...<Widget>[
              // Selector de Fase de Dieta
              Text(
                'Fase Metabólica Activa:',
                style: TextStyle(
                  fontFamily: ScFonts.ui,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _activeDietPhase,
                decoration: const InputDecoration(
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(
                    value: 'deficit',
                    child: Text('Déficit Calórico (Pérdida de grasa)'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'maintenance',
                    child: Text('Mantenimiento (Consolidación)'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'diet_break',
                    child: Text('Descanso Dietético / Refeed (TDEE completo)'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'reverse_diet',
                    child: Text('Dieta Inversa / Recuperación (+100 kcal)'),
                  ),
                ],
                onChanged: (String? val) {
                  if (val != null) setState(() => _activeDietPhase = val);
                },
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  unawaited(DietArchetypePickerSheet.show(context));
                },
                icon: const Icon(Icons.restaurant_menu_rounded, size: 16),
                label: const Text('Configurar Arquetipo y Calorie Cycling'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(40),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'Ritmo semanal:',
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                  Text(
                    _weeklyRateKg == 0.0
                        ? 'Mantenimiento'
                        : '${_weeklyRateKg > 0 ? "+" : ""}${_weeklyRateKg.toStringAsFixed(2)} kg/sem',
                    style: TextStyle(
                      fontFamily: ScFonts.display,
                      fontWeight: FontWeight.w800,
                      color: c.accent,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _weeklyRateKg,
                min: -1.0,
                max: 0.5,
                divisions: 6,
                label: '${_weeklyRateKg.toStringAsFixed(2)} kg/sem',
                onChanged: (double v) => setState(() => _weeklyRateKg = v),
              ),
            ],

            const SizedBox(height: 14),

            // Metas de Estilo de Vida
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _weightCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Peso Objetivo',
                      suffixText: 'kg',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _waterCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Agua Diaria',
                      suffixText: 'ml',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _stepsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Meta Pasos',
                      suffixText: 'pasos',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _sleepCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Sueño Meta',
                      suffixText: 'horas',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () async {
                  final double targetWeight = double.tryParse(
                        _weightCtrl.text.replaceAll(',', '.'),
                      ) ??
                      widget.profile.targetWeightKg;
                  final int water = int.tryParse(_waterCtrl.text) ??
                      widget.profile.dailyWaterGoalMl;
                  final int steps = int.tryParse(_stepsCtrl.text) ??
                      widget.profile.dailyStepsGoal;
                  final double sleep = double.tryParse(
                        _sleepCtrl.text.replaceAll(',', '.'),
                      ) ??
                      widget.profile.dailySleepGoalHours;

                  final int? manualKcal = int.tryParse(_manualKcalCtrl.text);
                  final int? manualProtein =
                      int.tryParse(_manualProteinCtrl.text);
                  final int? manualCarbs = int.tryParse(_manualCarbsCtrl.text);
                  final int? manualFat = int.tryParse(_manualFatCtrl.text);

                  await ref.read(userProfileDaoProvider).updateProfile(
                        UserProfilesCompanion(
                          targetWeightKg: drift.Value(targetWeight),
                          weeklyGoalRateKg: drift.Value(_weeklyRateKg),
                          dailyWaterGoalMl: drift.Value(water),
                          dailyStepsGoal: drift.Value(steps),
                          dailySleepGoalHours: drift.Value(sleep),
                          isManualMacroMode: drift.Value(_isManualMode),
                          manualKcalTarget: drift.Value(
                            _isManualMode ? manualKcal : null,
                          ),
                          manualProteinG: drift.Value(
                            _isManualMode ? manualProtein : null,
                          ),
                          manualCarbsG: drift.Value(
                            _isManualMode ? manualCarbs : null,
                          ),
                          manualFatG: drift.Value(
                            _isManualMode ? manualFat : null,
                          ),
                          activeDietPhase: drift.Value(_activeDietPhase),
                        ),
                      );

                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: const Text(
                  'Guardar Metas',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
