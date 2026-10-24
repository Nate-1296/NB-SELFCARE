import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/tdee_dao.dart';
import '../../../core/database/daos/user_profile_dao.dart';
import '../../../core/services/cross_analytics_engine.dart';
import '../../../shared/theme/sc_colors.dart';
import '../../../shared/theme/sc_theme.dart';
import '../../../shared/utils/daily_targets_calculator.dart';
import '../../../shared/widgets/app_icons.dart';
import '../../../shared/widgets/health_card.dart';
import '../../../shared/widgets/section_head.dart';
import '../../../shared/widgets/sheet.dart';
import 'app_settings_screen.dart';

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
  final int _analyticsRefreshEpoch = 0;

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

                const SizedBox(height: 16),

                // ==========================================
                // 3. Correlaciones y Descubrimientos Offline
                // ==========================================
                const SectionHead(
                  title: 'Correlaciones y Descubrimientos',
                  subtitle:
                      'Patrones cruzados entre nutrición, sueño, ayuno y diario',
                  padding: EdgeInsets.symmetric(vertical: 4),
                ),
                const SizedBox(height: 8),
                _CrossAnalyticsCard(refreshEpoch: _analyticsRefreshEpoch),

                const SizedBox(height: 24),

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
          // Cabecera espaciosa y limpia
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
            'Calibración adaptativa en ventana de 14 días',
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 12,
              color: c.text2,
            ),
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

          // Cuadrícula 2x2 de tarjetas para los datos pequeños
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

class _ExecutiveStatCard extends StatelessWidget {
  const _ExecutiveStatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.subtext,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String subtext;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Container(
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
  const _CrossAnalyticsCard({required this.refreshEpoch});

  final int refreshEpoch;

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
  late double _weeklyRateKg;

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
    _weeklyRateKg = widget.profile.weeklyGoalRateKg.clamp(-1.0, 0.5);
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _waterCtrl.dispose();
    _stepsCtrl.dispose();
    _sleepCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;

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
                'Ajustar Metas Personales',
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
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Ritmo semanal deseado:',
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
          const SizedBox(height: 14),
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

                await ref.read(userProfileDaoProvider).updateProfile(
                      UserProfilesCompanion(
                        targetWeightKg: drift.Value(targetWeight),
                        weeklyGoalRateKg: drift.Value(_weeklyRateKg),
                        dailyWaterGoalMl: drift.Value(water),
                        dailyStepsGoal: drift.Value(steps),
                        dailySleepGoalHours: drift.Value(sleep),
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
    );
  }
}
