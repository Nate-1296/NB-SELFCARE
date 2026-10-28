import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/clock/clock.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/models/tdee_models.dart';
import '../../../core/domain/enums.dart';
import '../../../core/l10n/l10n.dart';
import '../../../shared/theme/sc_colors.dart';
import '../../../shared/theme/sc_tokens.dart';
import '../../../shared/utils/biometric_formulas.dart';
import '../../../shared/utils/daily_targets_calculator.dart';
import '../../../shared/utils/date_time_extensions.dart';
import '../../../shared/widgets/action_tile.dart';
import '../../../shared/widgets/section_head.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../shared/widgets/top_bar.dart';
import '../../../shared/widgets/undo_snackbar.dart';
import '../../body_metrics/application/tdee_calibration_service.dart';
import '../../journal/presentation/widgets/digestive_tracker_sheet.dart';
import '../application/clinical_report_service.dart';
import '../application/daily_targets_provider.dart';
import '../application/profile_queries.dart';
import '../application/profile_service.dart';
import 'widgets/perfil/cross_analytics_card.dart';
import 'widgets/perfil/edit_goals_sheet.dart';
import 'widgets/perfil/edit_profile_sheet.dart';
import 'widgets/perfil/female_cycle_card.dart';
import 'widgets/perfil/goals_summary_card.dart';
import 'widgets/perfil/profile_hero_card.dart';
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

  Future<void> _pickProfilePhoto() async {
    final AppLocalizations l10n = context.l10n;
    try {
      final XFile? image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (image == null) return;
      await ref.read(profileServiceProvider).saveAvatar(image.path);
      if (mounted) showUndoSnackBar(context, message: l10n.perfilPhotoUpdated);
    } on Exception catch (e) {
      if (mounted) showUndoSnackBar(context, message: l10n.perfilPhotoError(e.toString()));
    }
  }

  Future<void> _calibrateTdeeNow(UserProfile profile) async {
    if (_isCalibratingTdee) return;
    setState(() => _isCalibratingTdee = true);
    unawaited(HapticFeedback.lightImpact());

    try {
      final TdeeCalibrationOutcome? outcome = await ref
          .read(tdeeCalibrationServiceProvider)
          .calibrateNow();

      if (!mounted || outcome == null) return;
      final AppLocalizations l10n = context.l10n;
      showUndoSnackBar(
        context,
        message: outcome.didCalibrate
            ? (outcome.wasClamped
                  ? l10n.perfilTdeeUpdatedClamped(
                      outcome.previousTdeeKcal ?? 0,
                      outcome.newTdeeKcal ?? 0,
                    )
                  : l10n.perfilTdeeUpdated(outcome.previousTdeeKcal ?? 0, outcome.newTdeeKcal ?? 0))
            : l10n.perfilTdeeNeedsData(
                outcome.foodDaysLogged,
                AppConstants.adaptiveTdeeMinFoodLogDays,
                outcome.weighInDaysLogged,
                AppConstants.adaptiveTdeeMinWeighInDays,
              ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCalibratingTdee = false);
      }
    }
  }

  void _showEditProfileSheet(UserProfile profile) {
    unawaited(mostrarHojaMenu<void>(context, builder: (_) => EditProfileSheet(profile: profile)));
  }

  void _showEditGoalsSheet(UserProfile profile) {
    unawaited(mostrarHojaMenu<void>(context, builder: (_) => EditGoalsSheet(profile: profile)));
  }

  Future<void> _exportClinicalPdf(UserProfile profile) async {
    unawaited(HapticFeedback.lightImpact());
    final AppLocalizations l10n = context.l10n;
    showUndoSnackBar(context, message: l10n.perfilPdfGenerating);
    try {
      await ref.read(clinicalReportServiceProvider).share(profile);
    } on Exception catch (e) {
      if (mounted) showUndoSnackBar(context, message: l10n.perfilPdfError(e.toString()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final UserProfile? profile = ref.watch(userProfileStreamProvider).value;
    final TdeeCalibration? latestCalibration = ref.watch(latestTdeeCalibrationStreamProvider).value;
    final DateTime now = ref.watch(clockProvider).now();
    final DailyMacroTargets? targets = ref.watch(dailyTargetsProvider(now.dateKey));

    if (profile == null || targets == null) {
      return Scaffold(
        backgroundColor: c.bg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: ScSpace.bottomInset),
          children: <Widget>[
            TopBar(
              title: l10n.perfilTitle,
              large: true,
              trailing: TopBarAction(
                icon: Icons.settings_outlined,
                tooltip: l10n.perfilSettings,
                onPressed: () => unawaited(context.push('/ajustes')),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: ScSpace.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  ProfileHeroCard(
                    profile: profile,
                    ageYears: BiometricFormulas.calculateDynamicAge(profile.birthDate, now),
                    onPickPhoto: _pickProfilePhoto,
                    onEditProfile: () => _showEditProfileSheet(profile),
                  ),
                  const SizedBox(height: ScSpace.cardGap),
                  GoalsSummaryCard(
                    profile: profile,
                    targets: targets,
                    latestCalibration: latestCalibration,
                    isCalibratingTdee: _isCalibratingTdee,
                    onCalibrateTdee: () => _calibrateTdeeNow(profile),
                    onEditGoals: () => _showEditGoalsSheet(profile),
                  ),
                  if (profile.biologicalSex == BiologicalSex.female) ...<Widget>[
                    const SizedBox(height: ScSpace.cardGap),
                    FemaleCycleCard(profile: profile),
                  ],
                  SectionHead(
                    title: l10n.perfilHealthTitle,
                    padding: const EdgeInsets.fromLTRB(
                      ScSpace.xs,
                      ScSpace.sectionGap,
                      ScSpace.xs,
                      ScSpace.m,
                    ),
                  ),
                  _ToolGrid(
                    tiles: <Widget>[
                      ActionTile(
                        onPage: true,
                        icon: Icons.medication_rounded,
                        title: l10n.perfilSupplements,
                        subtitle: l10n.perfilSupplementsHint,
                        onTap: () =>
                            unawaited(SupplementTrackerSheet.show(context, dateKey: now.dateKey)),
                      ),
                      ActionTile(
                        onPage: true,
                        icon: Icons.health_and_safety_rounded,
                        tone: c.water,
                        title: l10n.perfilDigestion,
                        subtitle: l10n.perfilDigestionHint,
                        onTap: () =>
                            unawaited(DigestiveTrackerSheet.show(context, dateKey: now.dateKey)),
                      ),
                      ActionTile(
                        onPage: true,
                        icon: Icons.calendar_month_rounded,
                        tone: c.carbs,
                        title: l10n.perfilProtocol,
                        subtitle: l10n.perfilProtocolHint,
                        onTap: () => unawaited(context.push('/protocolo')),
                      ),
                      ActionTile(
                        onPage: true,
                        icon: Icons.picture_as_pdf_rounded,
                        tone: c.protein,
                        title: l10n.perfilReport,
                        subtitle: l10n.perfilReportHint,
                        onTap: () => _exportClinicalPdf(profile),
                      ),
                    ],
                  ),
                  SectionHead(
                    title: l10n.perfilInsightsTitle,
                    subtitle: l10n.perfilInsightsSubtitle,
                    padding: const EdgeInsets.fromLTRB(
                      ScSpace.xs,
                      ScSpace.sectionGap,
                      ScSpace.xs,
                      ScSpace.m,
                    ),
                  ),
                  const CrossAnalyticsCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Accesos en cuadrícula de dos columnas.
class _ToolGrid extends StatelessWidget {
  const _ToolGrid({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (int i = 0; i < tiles.length; i += 2) ...<Widget>[
          if (i > 0) const SizedBox(height: ScSpace.s),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: tiles[i]),
                const SizedBox(width: ScSpace.s),
                Expanded(child: i + 1 < tiles.length ? tiles[i + 1] : const SizedBox.shrink()),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
