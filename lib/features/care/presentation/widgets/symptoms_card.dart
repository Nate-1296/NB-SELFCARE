import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_tokens.dart';
import '../../../../shared/utils/biometric_formulas.dart';
import '../../../../shared/utils/current_date_provider.dart';
import '../../../../shared/utils/date_formats.dart';
import '../../../../shared/widgets/card_header.dart';
import '../../../../shared/widgets/health_card.dart';
import '../../../../shared/widgets/sheet.dart';
import '../../../../shared/widgets/undo_snackbar.dart';
import '../../../journal/presentation/widgets/digestive_tracker_sheet.dart';
import '../../../profile_goals/application/profile_queries.dart';
import '../../application/care_queries.dart';
import '../../application/health_log_services.dart';
import '../../domain/symptom_catalog.dart';
import '../care_l10n.dart';

/// Síntomas: un toque en el nombre, luego la intensidad.
class SymptomsCard extends ConsumerWidget {
  const SymptomsCard({super.key, required this.dateKey});

  final String dateKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final UserProfile? profile = ref.watch(userProfileStreamProvider).value;
    final DateTime today = ref.watch(currentDateProvider);
    final List<String> catalog = profile == null
        ? SymptomCatalog.common
        : SymptomCatalog.forPerson(
            sex: profile.biologicalSex,
            age: BiometricFormulas.calculateDynamicAge(profile.birthDate, today).floor(),
            cycleTracking:
                profile.isCycleTrackingEnabled && profile.biologicalSex == BiologicalSex.female,
          );
    final List<SymptomLog> recent = ref.watch(recentSymptomsProvider).value ?? const <SymptomLog>[];
    return HealthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          CardHeader(
            icon: Icons.healing_outlined,
            tone: c.protein,
            title: l10n.careSymptomsTitle,
            subtitle: l10n.careSymptomsHint,
            trailing: TextButton(
              onPressed: () => unawaited(DigestiveTrackerSheet.show(context, dateKey: dateKey)),
              child: Text(l10n.careDigestion),
            ),
          ),
          const SizedBox(height: ScSpace.m),
          Wrap(
            spacing: ScSpace.s,
            runSpacing: ScSpace.s,
            children: <Widget>[
              for (final String key in catalog)
                ActionChip(
                  label: Text(CareText.symptom(l10n, key)),
                  onPressed: () => unawaited(SymptomEntrySheet.show(context, symptom: key)),
                ),
              ActionChip(
                avatar: const Icon(Icons.edit_outlined, size: 18),
                label: Text(l10n.careSymptomsOther),
                onPressed: () => unawaited(SymptomEntrySheet.show(context)),
              ),
            ],
          ),
          if (recent.isNotEmpty) ...<Widget>[
            const SizedBox(height: ScSpace.m),
            Text(l10n.careSymptomsRecent, style: context.text.labelLarge),
            for (final SymptomLog s in recent.take(5)) _SymptomRow(log: s),
          ],
          const SizedBox(height: ScSpace.s),
          Text(l10n.careSymptomsSeeDoctor, style: context.type.caption.copyWith(color: c.text3)),
        ],
      ),
    );
  }
}

class _SymptomRow extends ConsumerWidget {
  const _SymptomRow({required this.log});

  final SymptomLog log;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ScColors c = context.sc;
    final SymptomService service = ref.read(symptomServiceProvider);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(CareText.symptom(l10n, log.symptom)),
      subtitle: Text(
        '${CareText.intensity(l10n, log.intensity)} · ${DateFormats.shortDate(log.loggedAt, l10n.localeName)}'
        '${log.notes == null ? '' : ' · ${log.notes}'}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        tooltip: l10n.commonDelete,
        icon: Icon(Icons.close_rounded, color: c.text3, size: 20),
        onPressed: () async {
          await service.delete(log.id);
          if (context.mounted) {
            showUndoSnackBar(
              context,
              message: l10n.careSymptomDeleted,
              onUndo: () => unawaited(service.restore(log)),
            );
          }
        },
      ),
    );
  }
}

/// Intensidad (1–5) y nota opcional de un síntoma.
class SymptomEntrySheet extends ConsumerStatefulWidget {
  const SymptomEntrySheet({super.key, this.symptom});

  /// Clave del catálogo; `null` = texto propio.
  final String? symptom;

  static Future<void> show(BuildContext context, {String? symptom}) =>
      mostrarHojaMenu<void>(context, builder: (_) => SymptomEntrySheet(symptom: symptom));

  @override
  ConsumerState<SymptomEntrySheet> createState() => _SymptomEntrySheetState();
}

class _SymptomEntrySheetState extends ConsumerState<SymptomEntrySheet> {
  final TextEditingController _other = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  int _intensity = 2;

  @override
  void dispose() {
    _other.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String symptom = widget.symptom ?? _other.text.trim();
    if (symptom.isEmpty) return;
    unawaited(HapticFeedback.lightImpact());
    await ref
        .read(symptomServiceProvider)
        .log(symptom: symptom, intensity: _intensity, notes: _notes.text);
    if (!mounted) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String message = context.l10n.careSymptomLogged(CareText.symptom(context.l10n, symptom));
    Navigator.of(context).pop();
    messenger
..hideCurrentSnackBar()
..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool custom = widget.symptom == null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(ScSpace.xl - 4, 0, ScSpace.xl - 4, ScSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (custom)
            TextField(
              controller: _other,
              autofocus: true,
              maxLength: 40,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.careSymptomsOtherHint),
              onChanged: (_) => setState(() {}),
            )
          else
            Text(CareText.symptom(l10n, widget.symptom!), style: context.text.titleLarge),
          const SizedBox(height: ScSpace.m),
          Text(l10n.careSymptomIntensity, style: context.text.labelLarge),
          const SizedBox(height: ScSpace.s),
          Wrap(
            spacing: ScSpace.s,
            runSpacing: ScSpace.s,
            children: <Widget>[
              for (int i = 1; i <= 5; i++)
                ChoiceChip(
                  label: Text(CareText.intensity(l10n, i)),
                  selected: i == _intensity,
                  onSelected: (_) => setState(() => _intensity = i),
                ),
            ],
          ),
          const SizedBox(height: ScSpace.m),
          TextField(
            controller: _notes,
            decoration: InputDecoration(labelText: l10n.careSymptomNotes),
          ),
          const SizedBox(height: ScSpace.l),
          FilledButton(
            onPressed: custom && _other.text.trim().isEmpty ? null : () => unawaited(_save()),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
  }
}
