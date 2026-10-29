import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_tokens.dart';
import '../../../../shared/utils/number_formats.dart';
import '../../../../shared/widgets/sheet.dart';
import '../../../../shared/widgets/undo_snackbar.dart';
import '../../application/care_queries.dart';
import '../../application/treatment_service.dart';
import '../../domain/treatment_schedule.dart';
import '../care_l10n.dart';

/// Selector de días de la semana (L M X J V S D) sobre una máscara de bits.
class WeekdayPicker extends StatelessWidget {
  const WeekdayPicker({super.key, required this.mask, required this.onChanged});

  final int mask;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final List<String> names = context.l10n.careWeekdaysShort.split(',');
    return Wrap(
      spacing: ScSpace.xs,
      children: <Widget>[
        for (int i = 0; i < 7; i++)
          FilterChip(
            label: Text(i < names.length ? names[i] : '$i'),
            selected: mask & (1 << i) != 0,
            showCheckmark: false,
            // Los siete días en una sola fila.
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            onSelected: (bool on) {
              final int next = on ? mask | (1 << i) : mask & ~(1 << i);
              if (next & 0x7F != 0) onChanged(next);
            },
          ),
      ],
    );
  }
}

/// Alta o edición de un medicamento o suplemento.
class TreatmentEditorSheet extends ConsumerStatefulWidget {
  const TreatmentEditorSheet({super.key, this.existing});

  final SupplementsTrackerData? existing;

  static Future<void> show(BuildContext context, {SupplementsTrackerData? existing}) {
    return mostrarHojaMenu<void>(context, builder: (_) => TreatmentEditorSheet(existing: existing));
  }

  @override
  ConsumerState<TreatmentEditorSheet> createState() => _TreatmentEditorSheetState();
}

class _TreatmentEditorSheetState extends ConsumerState<TreatmentEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _dosage;
  late final TextEditingController _notes;
  late final TextEditingController _stock;
  late final TextEditingController _perDose;
  late TreatmentKind _kind;
  late List<int> _times;
  late int _days;
  late bool _reminders;
  late bool _trackStock;
  late bool _lowersGlucose;
  late bool _water;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final SupplementsTrackerData? e = widget.existing;
    final TreatmentDraft d = e == null
        ? const TreatmentDraft(name: '', dosage: '', kind: TreatmentKind.medication)
        : TreatmentDraft.of(e);
    _name = TextEditingController(text: d.name);
    _dosage = TextEditingController(text: d.dosage);
    _notes = TextEditingController(text: d.notes ?? '');
    _stock = TextEditingController(
      text: d.stockUnits == null ? '' : NumberFormats.input(d.stockUnits!),
    );
    _perDose = TextEditingController(text: NumberFormats.input(d.unitsPerDose));
    _kind = d.kind;
    _times = List<int>.of(d.times);
    _days = d.daysMask;
    _reminders = d.remindersEnabled;
    _trackStock = d.stockUnits != null;
    _lowersGlucose = d.lowersGlucose;
    _water = d.affectsWaterRetention;
  }

  @override
  void dispose() {
    _name.dispose();
    _dosage.dispose();
    _notes.dispose();
    _stock.dispose();
    _perDose.dispose();
    super.dispose();
  }

  static double? _num(String raw) => double.tryParse(raw.trim().replaceAll(',', '.'));

  Future<void> _addTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _times.isEmpty ? 8 : (_times.last ~/ 60 + 4) % 24, minute: 0),
    );
    if (picked == null) return;
    setState(
      () => _times = TreatmentSchedule.decodeTimes(
        TreatmentSchedule.encodeTimes(<int>[..._times, picked.hour * 60 + picked.minute]),
      ),
    );
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _saving) return;
    setState(() => _saving = true);
    unawaited(HapticFeedback.lightImpact());
    final String name = _name.text.trim();
    await ref
        .read(treatmentServiceProvider)
        .save(
          TreatmentDraft(
            name: name,
            dosage: _dosage.text,
            kind: _kind,
            times: _times,
            daysMask: _days,
            stockUnits: _trackStock ? (_num(_stock.text) ?? 0) : null,
            unitsPerDose: _num(_perDose.text) ?? 1,
            remindersEnabled: _reminders,
            lowersGlucose: _lowersGlucose,
            affectsWaterRetention: _water,
            notes: _notes.text,
          ),
          id: widget.existing?.id,
        );
    if (!mounted) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String message = context.l10n.careTreatmentSaved(name);
    Navigator.of(context).pop();
    messenger
..hideCurrentSnackBar()
..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(ScSpace.xl - 4, 0, ScSpace.xl - 4, ScSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            widget.existing == null ? l10n.careTreatmentNew : l10n.careTreatmentEdit,
            style: context.text.titleLarge,
          ),
          const SizedBox(height: ScSpace.m),
          SegmentedButton<TreatmentKind>(
            segments: <ButtonSegment<TreatmentKind>>[
              ButtonSegment<TreatmentKind>(
                value: TreatmentKind.medication,
                icon: const Icon(Icons.medication_outlined),
                label: Text(l10n.careTreatmentKindMedication),
              ),
              ButtonSegment<TreatmentKind>(
                value: TreatmentKind.supplement,
                icon: const Icon(Icons.eco_outlined),
                label: Text(l10n.careTreatmentKindSupplement),
              ),
            ],
            selected: <TreatmentKind>{_kind},
            onSelectionChanged: (Set<TreatmentKind> s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: ScSpace.m),
          TextField(
            controller: _name,
            maxLength: TreatmentService.maxNameLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.careTreatmentName,
              hintText: l10n.careTreatmentNameHint,
            ),
            onChanged: (_) => setState(() {}),
          ),
          TextField(
            controller: _dosage,
            decoration: InputDecoration(
              labelText: l10n.careTreatmentDosage,
              hintText: l10n.careTreatmentDosageHint,
            ),
          ),
          const SizedBox(height: ScSpace.l),
          Text(l10n.careTreatmentTimes, style: context.text.labelLarge),
          Text(l10n.careTreatmentTimesHint, style: context.type.caption),
          const SizedBox(height: ScSpace.s),
          Wrap(
            spacing: ScSpace.s,
            runSpacing: ScSpace.xs,
            children: <Widget>[
              for (final int t in _times)
                InputChip(
                  label: Text(CareText.hhmm(t)),
                  onDeleted: () => setState(() => _times = List<int>.of(_times)..remove(t)),
                ),
              ActionChip(
                avatar: const Icon(Icons.add_alarm_rounded, size: 18),
                label: Text(l10n.careTreatmentAddTime),
                onPressed: () => unawaited(_addTime()),
              ),
            ],
          ),
          const SizedBox(height: ScSpace.m),
          Text(l10n.careTreatmentDays, style: context.text.labelLarge),
          const SizedBox(height: ScSpace.xs),
          WeekdayPicker(mask: _days, onChanged: (int m) => setState(() => _days = m)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _reminders && _times.isNotEmpty,
            onChanged: _times.isEmpty ? null : (bool v) => setState(() => _reminders = v),
            title: Text(l10n.careTreatmentReminders),
            subtitle: Text(l10n.careTreatmentRemindersHint),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _trackStock,
            onChanged: (bool v) => setState(() => _trackStock = v),
            title: Text(l10n.careTreatmentStock),
            subtitle: Text(l10n.careTreatmentStockHint),
          ),
          if (_trackStock)
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _stock,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: l10n.careTreatmentStockUnits),
                  ),
                ),
                const SizedBox(width: ScSpace.m),
                Expanded(
                  child: TextField(
                    controller: _perDose,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: l10n.careTreatmentUnitsPerDose),
                  ),
                ),
              ],
            ),
          if (_kind == TreatmentKind.medication)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _lowersGlucose,
              onChanged: (bool v) => setState(() => _lowersGlucose = v),
              title: Text(l10n.careTreatmentLowersGlucose),
              subtitle: Text(l10n.careTreatmentLowersGlucoseHint),
            )
          else
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _water,
              onChanged: (bool v) => setState(() => _water = v),
              title: Text(l10n.careTreatmentWater),
              subtitle: Text(l10n.careTreatmentWaterHint),
            ),
          TextField(
            controller: _notes,
            maxLines: 2,
            decoration: InputDecoration(labelText: l10n.careTreatmentNotes),
          ),
          const SizedBox(height: ScSpace.m),
          Text(l10n.careTreatmentDisclaimer, style: context.type.caption.copyWith(color: c.text3)),
          const SizedBox(height: ScSpace.l),
          FilledButton(
            onPressed: _name.text.trim().isEmpty || _saving ? null : () => unawaited(_save()),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
  }
}

/// Lista de tratamientos: editar, pausar o borrar (con Deshacer).
class TreatmentsManageSheet extends ConsumerWidget {
  const TreatmentsManageSheet({super.key});

  static Future<void> show(BuildContext context) {
    return mostrarHojaMenu<void>(context, builder: (_) => const TreatmentsManageSheet());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final List<SupplementsTrackerData> all =
        ref.watch(treatmentsProvider).value ?? const <SupplementsTrackerData>[];
    final TreatmentService service = ref.read(treatmentServiceProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(ScSpace.xl - 4, 0, ScSpace.xl - 4, ScSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l10n.careTreatmentsListTitle, style: context.text.titleLarge),
          const SizedBox(height: ScSpace.s),
          for (final SupplementsTrackerData t in all)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                TreatmentKind.fromKey(t.kind) == TreatmentKind.medication
                    ? Icons.medication_outlined
                    : Icons.eco_outlined,
                color: t.isEnabled ? (c.isFlat ? c.text : c.accent) : c.text3,
              ),
              title: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(_summary(l10n, t), maxLines: 2, overflow: TextOverflow.ellipsis),
              onTap: () => unawaited(TreatmentEditorSheet.show(context, existing: t)),
              trailing: PopupMenuButton<String>(
                onSelected: (String action) async {
                  switch (action) {
                    case 'pause':
                      await service.setActive(t.id, active: !t.isEnabled);
                    case 'delete':
                      await service.remove(t.id);
                      if (context.mounted) {
                        showUndoSnackBar(
                          context,
                          message: l10n.careTreatmentDeleted(t.name),
                          onUndo: () => unawaited(service.restore(t)),
                        );
                      }
                  }
                },
                itemBuilder: (BuildContext ctx) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'pause',
                    child: Text(t.isEnabled ? l10n.careTreatmentPause : l10n.careTreatmentResume),
                  ),
                  PopupMenuItem<String>(value: 'delete', child: Text(l10n.commonDelete)),
                ],
              ),
            ),
          const SizedBox(height: ScSpace.m),
          OutlinedButton.icon(
            onPressed: () => unawaited(TreatmentEditorSheet.show(context)),
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.careTreatmentNew),
          ),
        ],
      ),
    );
  }

  static String _summary(AppLocalizations l10n, SupplementsTrackerData t) {
    final List<int> times = TreatmentSchedule.decodeTimes(t.scheduleJson);
    final List<String> parts = <String>[
      if (t.dosage.isNotEmpty) t.dosage,
      if (times.isEmpty) l10n.careDoseAnytime else times.map(CareText.hhmm).join(', '),
      CareText.weekdays(l10n, t.daysOfWeekBitmask),
      if (t.stockUnits != null)
        l10n.careTreatmentStockLeft(
          NumberFormats.input(t.stockUnits!),
          '${TreatmentSchedule.daysOfStockLeft(stockUnits: t.stockUnits, unitsPerDose: t.unitsPerDose, dosesPerDay: times.length.clamp(1, 24), daysMask: t.daysOfWeekBitmask) ?? 0}',
        ),
      if (!t.isEnabled) l10n.careTreatmentPaused,
    ];
    return parts.join(' · ');
  }
}
