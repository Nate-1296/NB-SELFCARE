import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock/clock.dart';
import '../../../core/database/app_database.dart';
import '../../../core/domain/enums.dart';
import '../../../core/hardware/body_scale_driver.dart';
import '../../../core/l10n/l10n.dart';
import '../../../shared/theme/sc_colors.dart';
import '../../../shared/theme/sc_tokens.dart';
import '../../../shared/utils/current_date_provider.dart';
import '../../../shared/utils/cycle_phase_calculator.dart';
import '../../../shared/utils/date_formats.dart';
import '../../../shared/utils/number_formats.dart';
import '../../../shared/widgets/entrance.dart';
import '../../../shared/widgets/section_head.dart';
import '../../../shared/widgets/top_bar.dart';
import '../../../shared/widgets/undo_snackbar.dart';
import '../../profile_goals/application/profile_queries.dart';
import '../../profile_goals/application/profile_service.dart';
import '../application/body_queries.dart';
import '../application/scale_session.dart';
import '../application/tape_measurement_service.dart';
import '../application/weigh_in_service.dart';
import '../application/workout_service.dart';
import 'widgets/cuerpo/body_composition_section.dart';
import 'widgets/cuerpo/manual_weigh_in_card.dart';
import 'widgets/cuerpo/movement_section.dart';
import 'widgets/cuerpo/scale_station_card.dart';
import 'widgets/cuerpo/weight_hero_card.dart';
import 'widgets/manual_weigh_in_sheet.dart';
import 'widgets/mini_milestones_card.dart';
import 'widgets/quick_rpe_workout_sheet.dart';
import 'widgets/scale_settings_sheet.dart';
import 'widgets/tape_measure_sheet.dart';
import 'widgets/weight_trend_chart_card.dart';

/// Pestaña "Cuerpo": pesaje (báscula Bluetooth, manual o cinta), evolución,
/// composición corporal y movimiento del día.
class CuerpoScreen extends ConsumerStatefulWidget {
  const CuerpoScreen({super.key});

  @override
  ConsumerState<CuerpoScreen> createState() => _CuerpoScreenState();
}

class _CuerpoScreenState extends ConsumerState<CuerpoScreen> {
  ScaleSession get _scale => ref.read(scaleSessionProvider.notifier);

  void _startScan(UserProfile profile) {
    unawaited(HapticFeedback.selectionClick());
    _scale.start(
      targetMacAddress: profile.scaleMacAddress,
      weightOnly: profile.hasImpedanceContraindication,
    );
  }

  Future<void> _onCapture(ScaleMeasurementEvent event) async {
    _scale.consumeCapture();
    final UserProfile? profile = ref.read(userProfileStreamProvider).value;
    if (profile == null || !await _confirmIsUser(event.weightKg)) {
      if (mounted) showUndoSnackBar(context, message: context.l10n.cuerpoGuestDiscarded);
      return;
    }
    await _recordWeighIn(
      weightKg: event.weightKg,
      impedanceOhms: event.impedanceOhms,
      source: MeasurementSource.miScale2Ble,
      profile: profile,
      detectedDeviceMac: event.deviceAddress,
    );
  }

  /// Filtro de invitados (docs/04 §1): pregunta "¿Eres tú?" si el peso se aleja
  /// más de un 8 % de la tendencia.
  Future<bool> _confirmIsUser(double weightKg) async {
    final double? deviation = await ref.read(weighInServiceProvider).guestDeviation(weightKg);
    if (deviation == null) return true;
    if (!mounted) return false;
    final AppLocalizations l10n = context.l10n;
    final bool? isUser = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(l10n.cuerpoGuestTitle),
        content: Text(
          l10n.cuerpoGuestBody(
            NumberFormats.fixed(weightKg, 1),
            NumberFormats.fixed(deviation * 100, 0),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cuerpoGuestNo),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.cuerpoGuestYes),
          ),
        ],
      ),
    );
    return isUser ?? false;
  }

  Future<void> _recordWeighIn({
    required double weightKg,
    required int? impedanceOhms,
    required MeasurementSource source,
    required UserProfile profile,
    String? detectedDeviceMac,
  }) async {
    final WeighInResult result = await ref
        .read(weighInServiceProvider)
        .record(weightKg: weightKg, impedanceOhms: impedanceOhms, source: source);
    if (!mounted) return;
    final AppLocalizations l10n = context.l10n;
    final bool canBindMac =
        detectedDeviceMac != null &&
        detectedDeviceMac.isNotEmpty &&
        (profile.scaleMacAddress == null || profile.scaleMacAddress!.isEmpty);
    final String kg = NumberFormats.fixed(weightKg, 1);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            result.reward.granted
                ? l10n.cuerpoWeighInSavedCoins(kg, result.reward.coins)
                : l10n.cuerpoWeighInSaved(kg),
          ),
          // Con acción, Flutter lo dejaría fijo hasta deslizarlo: se va solo.
          persist: false,
          action: canBindMac
              ? SnackBarAction(
                  label: l10n.cuerpoBindScale,
                  onPressed: () => unawaited(
                    ref.read(profileServiceProvider).setScaleMacAddress(detectedDeviceMac),
                  ),
                )
              : null,
        ),
      );
  }

  Future<void> _deleteMeasurementWithUndo(BodyMeasurement m) async {
    unawaited(HapticFeedback.selectionClick());
    final WeighInService service = ref.read(weighInServiceProvider);
    await service.deleteMeasurement(m.id);
    if (!mounted) return;
    showUndoSnackBar(
      context,
      message: context.l10n.cuerpoWeighInDeleted(
        NumberFormats.fixed(m.weightKg, 1),
        DateFormats.shortDate(m.measuredAt, context.l10n.localeName),
      ),
      onUndo: () => unawaited(service.restoreMeasurement(m)),
    );
  }

  Future<void> _deleteWorkoutWithUndo(WorkoutBlock block) async {
    unawaited(HapticFeedback.selectionClick());
    final WorkoutService service = ref.read(workoutServiceProvider);
    await service.delete(block.id);
    if (!mounted) return;
    showUndoSnackBar(
      context,
      message: context.l10n.cuerpoWorkoutDeleted,
      onUndo: () => unawaited(service.restore(block)),
    );
  }

  Future<void> _openManualWeighIn(UserProfile profile, BodyMeasurement? latest) async {
    final ({double weightKg, int? impedanceOhms})? result = await ManualWeighInSheet.show(
      context: context,
      initialWeightKg: latest?.weightKg ?? 70.0,
      profile: profile,
      latestMeasurement: latest,
    );
    if (!mounted || result == null) return;
    await _recordWeighIn(
      weightKg: result.weightKg,
      impedanceOhms: result.impedanceOhms,
      source: MeasurementSource.manual,
      profile: profile,
    );
  }

  Future<void> _openTapeMeasure(UserProfile profile, BodyMeasurement? latest) async {
    final ({double waistCm, double neckCm, double? hipCm})? tape = await NavyTapeMeasureSheet.show(
      context: context,
      profile: profile,
      latestMeasurement: latest,
    );
    if (!mounted || tape == null) return;
    final TapeMeasurementResult result = await ref
        .read(tapeMeasurementServiceProvider)
        .save(waistCm: tape.waistCm, neckCm: tape.neckCm, hipCm: tape.hipCm);
    if (!mounted) return;
    final AppLocalizations l10n = context.l10n;
    showUndoSnackBar(
      context,
      message: result.saved
          ? l10n.cuerpoTapeSaved(
              NumberFormats.fixed(result.navyBodyFatPercentage, 1),
              NumberFormats.fixed(result.validatedBodyFatPercentage, 1),
            )
          : l10n.cuerpoTapeNeedsWeighIn,
    );
  }

  Future<void> _openScaleSettings(UserProfile profile) async {
    final String? newMac = await ScaleMacConfigSheet.show(
      context: context,
      currentMac: profile.scaleMacAddress,
    );
    if (!mounted || newMac == null) return;
    await ref.read(profileServiceProvider).setScaleMacAddress(newMac);
    if (!mounted) return;
    showUndoSnackBar(
      context,
      message: newMac.isEmpty
          ? context.l10n.cuerpoScaleAuto
          : context.l10n.cuerpoScaleBound(newMac),
    );
  }

  /// En fase lútea o menstrual se retiene agua: se avisa para leer la
  /// tendencia y no el número del día (positividad, ADR-08).
  static String? _cycleWaterNote(
    AppLocalizations l10n,
    UserProfile profile,
    FemaleCycleLog? cycle,
    DateTime day,
  ) {
    if (!profile.isCycleTrackingEnabled ||
        profile.biologicalSex != BiologicalSex.female ||
        cycle == null) {
      return null;
    }
    final FemaleCyclePhase phase = CyclePhaseCalculator.phaseFor(
      cycleStart: cycle.cycleStartDate,
      cycleLengthDays: cycle.cycleLengthDays,
      date: day,
    ).phase;
    return switch (phase) {
      FemaleCyclePhase.luteal => l10n.cuerpoCycleWaterNote(l10n.cyclePhaseLuteal),
      FemaleCyclePhase.menstrual => l10n.cuerpoCycleWaterNote(l10n.cyclePhaseMenstrual),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ScaleSessionState>(scaleSessionProvider, (
      ScaleSessionState? prev,
      ScaleSessionState next,
    ) {
      final ScaleMeasurementEvent? capture = next.capture;
      if (capture != null && !identical(capture, prev?.capture)) unawaited(_onCapture(capture));
    });

    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final DateTime currentDay = ref.watch(currentDateProvider);
    final String todayKey = ref.watch(currentDateKeyProvider);
    final UserProfile? profile = ref.watch(userProfileStreamProvider).value;
    if (profile == null) {
      return Scaffold(
        backgroundColor: c.bg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final BodyMeasurement? latest = ref.watch(latestMeasurementStreamProvider).value;
    final List<BodyMeasurement> recent =
        ref.watch(recentMeasurementsStreamProvider).value ?? const <BodyMeasurement>[];
    final ScaleSessionState scale = ref.watch(scaleSessionProvider);
    final String formattedDate = DateFormats.weekdayDayMonth(currentDay, l10n.localeName);
    final String? cycleNote = _cycleWaterNote(
      l10n,
      profile,
      ref.watch(latestFemaleCycleStreamProvider).value,
      currentDay,
    );

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: ScSpace.bottomInset),
          children: <Widget>[
            TopBar(
              title: l10n.cuerpoTitle,
              subtitle: formattedDate[0].toUpperCase() + formattedDate.substring(1),
              large: true,
            ),
            Entrance(
              index: 0,
              child: WeightHeroCard(profile: profile, latest: latest),
            ),
            MiniMilestonesCard(
              currentWeightKg: latest?.trendWeightKg ?? latest?.weightKg ?? profile.targetWeightKg,
              targetWeightKg: profile.targetWeightKg,
              weeklyGoalRateKg: profile.weeklyGoalRateKg,
            ),
            if (cycleNote != null) _CycleWaterNote(text: cycleNote),
            if (profile.hasSmartScale)
              ScaleStationCard(
                session: scale,
                isBound: profile.scaleMacAddress?.isNotEmpty ?? false,
                weightOnly: profile.hasImpedanceContraindication,
                onScan: () => _startScan(profile),
                onStop: () => unawaited(_scale.stop()),
                onAcceptWeightOnly: _scale.acceptWeightOnly,
                onManual: () => _openManualWeighIn(profile, latest),
                onTape: () => _openTapeMeasure(profile, latest),
                onConfigure: () => _openScaleSettings(profile),
              )
            else
              ManualWeighInCard(
                onManual: () => _openManualWeighIn(profile, latest),
                onTape: () => _openTapeMeasure(profile, latest),
              ),
            WeightTrendChartCard(
              now: ref.read(clockProvider).now(),
              measurements: recent,
              targetWeightKg: profile.targetWeightKg,
              onDeleteMeasurement: _deleteMeasurementWithUndo,
            ),
            SectionHead(
              title: l10n.cuerpoCompositionTitle,
              subtitle: profile.hasSmartScale
                  ? l10n.cuerpoCompositionSubtitle
                  : l10n.cuerpoCompositionSubtitleNoScale,
            ),
            BodyCompositionSection(
              hasSmartScale: profile.hasSmartScale,
              profile: profile,
              latest: latest,
              referenceDate: currentDay,
              onMeasureTape: () => _openTapeMeasure(profile, latest),
            ),
            SectionHead(title: l10n.cuerpoMovementTitle),
            MovementSection(
              dateKey: todayKey,
              stepsGoal: profile.dailyStepsGoal,
              onLogWorkout: () =>
                  QuickRpeWorkoutSheet.show(context: context, ref: ref, profile: profile),
              onDeleteWorkout: _deleteWorkoutWithUndo,
            ),
          ],
        ),
      ),
    );
  }
}

class _CycleWaterNote extends StatelessWidget {
  const _CycleWaterNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ScSpace.gutter + 4,
        ScSpace.xs,
        ScSpace.gutter + 4,
        ScSpace.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.water_drop_outlined, size: 16, color: c.isFlat ? c.text : c.water),
          const SizedBox(width: ScSpace.s),
          Expanded(
            child: Text(text, style: context.type.caption.copyWith(color: c.text2)),
          ),
        ],
      ),
    );
  }
}
