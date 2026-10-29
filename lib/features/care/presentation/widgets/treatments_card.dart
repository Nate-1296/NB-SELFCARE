import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_tokens.dart';
import '../../../../shared/utils/number_formats.dart';
import '../../../../shared/widgets/card_header.dart';
import '../../../../shared/widgets/health_card.dart';
import '../../../../shared/widgets/undo_snackbar.dart';
import '../../application/care_queries.dart';
import '../../application/treatment_service.dart';
import '../../domain/treatment_schedule.dart';
import '../care_l10n.dart';
import 'treatment_sheets.dart';

/// Tomas de hoy: un toque para marcar, pulsación larga para omitir.
class TreatmentsCard extends ConsumerWidget {
  const TreatmentsCard({super.key, required this.dateKey});

  final String dateKey;

  Future<void> _mark(
    BuildContext context,
    WidgetRef ref,
    TodayDose dose, {
    required bool taken,
  }) async {
    unawaited(HapticFeedback.selectionClick());
    final TreatmentService service = ref.read(treatmentServiceProvider);
    await service.markDose(
      dateKey: dateKey,
      treatmentId: dose.treatment.id,
      slotMinutes: dose.slot.slotMinutes,
      taken: taken,
    );
    if (!context.mounted) return;
    showUndoSnackBar(
      context,
      message: taken
          ? context.l10n.careDoseTakenSnack(dose.treatment.name)
          : context.l10n.careDoseSkippedSnack(dose.treatment.name),
      onUndo: () => unawaited(
        service.clearDose(
          dateKey: dateKey,
          treatmentId: dose.treatment.id,
          slotMinutes: dose.slot.slotMinutes,
        ),
      ),
    );
  }

  Future<void> _clear(WidgetRef ref, TodayDose dose) {
    unawaited(HapticFeedback.selectionClick());
    return ref
        .read(treatmentServiceProvider)
        .clearDose(
          dateKey: dateKey,
          treatmentId: dose.treatment.id,
          slotMinutes: dose.slot.slotMinutes,
        );
  }

  Future<void> _refill(BuildContext context, WidgetRef ref, SupplementsTrackerData t) async {
    final double? units = await RefillDialog.show(context);
    if (units == null || !context.mounted) return;
    await ref.read(treatmentServiceProvider).refill(t.id, units);
    if (context.mounted) showUndoSnackBar(context, message: context.l10n.careRefillDone(t.name));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final List<SupplementsTrackerData> all =
        ref.watch(treatmentsProvider).value ?? const <SupplementsTrackerData>[];
    final List<TodayDose> doses = ref.watch(todayDosesProvider(dateKey));
    final List<({SupplementsTrackerData treatment, int daysLeft})> lowStock = ref.watch(
      lowStockTreatmentsProvider,
    );
    final bool allDone =
        doses.isNotEmpty && doses.every((TodayDose d) => d.slot.status != DoseStatus.pending);

    return HealthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          CardHeader(
            icon: Icons.medication_outlined,
            title: l10n.careTreatmentsTitle,
            subtitle: all.isEmpty
                ? l10n.careTreatmentsEmpty
                : (doses.isEmpty
                      ? l10n.careDosesNoneToday
                      : (allDone ? l10n.careDosesAllDone : null)),
            trailing: TextButton(
              onPressed: () => unawaited(
                all.isEmpty
                    ? TreatmentEditorSheet.show(context)
                    : TreatmentsManageSheet.show(context),
              ),
              child: Text(all.isEmpty ? l10n.careTreatmentsAdd : l10n.careTreatmentsManage),
            ),
          ),
          if (doses.isNotEmpty) const SizedBox(height: ScSpace.s),
          for (final TodayDose dose in doses)
            _DoseRow(
              dose: dose,
              onTap: () => dose.slot.status == DoseStatus.pending
                  ? unawaited(_mark(context, ref, dose, taken: true))
                  : unawaited(_clear(ref, dose)),
              onLongPress: dose.slot.status == DoseStatus.pending
                  ? () => unawaited(_mark(context, ref, dose, taken: false))
                  : null,
            ),
          for (final ({SupplementsTrackerData treatment, int daysLeft}) low
              in lowStock) ...<Widget>[
            const SizedBox(height: ScSpace.s),
            Row(
              children: <Widget>[
                Icon(Icons.inventory_2_outlined, size: 18, color: c.isFlat ? c.text : c.warning),
                const SizedBox(width: ScSpace.s),
                Expanded(
                  child: Text(
                    l10n.careLowStock(low.treatment.name, '${low.daysLeft}'),
                    style: context.type.caption.copyWith(color: c.text2),
                  ),
                ),
                TextButton(
                  onPressed: () => unawaited(_refill(context, ref, low.treatment)),
                  child: Text(l10n.careRefill),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DoseRow extends StatelessWidget {
  const _DoseRow({required this.dose, required this.onTap, required this.onLongPress});

  final TodayDose dose;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final DoseStatus status = dose.slot.status;
    final int? slot = dose.slot.slotMinutes;
    final String time = slot == null ? l10n.careDoseAnytime : CareText.hhmm(slot);
    final String statusText = switch (status) {
      DoseStatus.taken => l10n.careDoseTaken,
      DoseStatus.skipped => l10n.careDoseSkipped,
      DoseStatus.pending => '',
    };
    final IconData icon = switch (status) {
      DoseStatus.taken => Icons.check_circle_rounded,
      DoseStatus.skipped => Icons.remove_circle_outline_rounded,
      DoseStatus.pending => Icons.radio_button_unchecked_rounded,
    };
    final Color tint = c.isFlat
        ? c.text
        : (status == DoseStatus.taken
              ? c.success
              : (status == DoseStatus.skipped ? c.text3 : c.accent));
    return Semantics(
      button: true,
      label: '$time, ${dose.treatment.name}, ${dose.treatment.dosage}. $statusText',
      hint: status == DoseStatus.pending ? l10n.careDoseSkip : l10n.careDoseUndo,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(ScRadius.controlOf(c)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 64,
                child: Text(time, style: context.type.label.copyWith(color: c.text2), maxLines: 2),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      dose.treatment.name,
                      style: context.text.titleSmall?.copyWith(
                        decoration: status == DoseStatus.pending
                            ? null
                            : TextDecoration.lineThrough,
                        color: status == DoseStatus.pending ? c.text : c.text2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (dose.treatment.dosage.isNotEmpty || statusText.isNotEmpty)
                      Text(
                        <String>[
                          dose.treatment.dosage,
                          statusText,
                        ].where((String s) => s.isNotEmpty).join(' · '),
                        style: context.type.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Icon(icon, color: tint, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

/// Unidades repuestas.
class RefillDialog {
  static Future<double?> show(BuildContext context) async {
    final TextEditingController ctrl = TextEditingController(text: '30');
    final double? result = await showDialog<double>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(ctx.l10n.careRefillTitle),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: ctx.l10n.careTreatmentStockUnits),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(ctx.l10n.commonCancel)),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(double.tryParse(ctrl.text.trim().replaceAll(',', '.'))),
            child: Text(ctx.l10n.commonSave),
          ),
        ],
      ),
    );
    return result == null || result <= 0 ? null : result;
  }

  static String units(double value) => NumberFormats.input(value);
}
