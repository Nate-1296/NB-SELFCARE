import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_tokens.dart';
import '../../../../shared/widgets/card_header.dart';
import '../../../../shared/widgets/health_card.dart';
import '../../../../shared/widgets/sheet.dart';
import '../../../../shared/widgets/undo_snackbar.dart';
import '../../../pet_gamification/application/reward_service.dart';
import '../../application/care_queries.dart';
import '../../application/habit_service.dart';
import '../care_l10n.dart';
import 'treatment_sheets.dart';

/// Hábitos propios del día: cada uno se marca con un toque.
class HabitsCard extends ConsumerWidget {
  const HabitsCard({super.key, required this.dateKey});

  final String dateKey;

  Future<void> _toggle(BuildContext context, WidgetRef ref, CustomHabit habit, bool done) async {
    unawaited(HapticFeedback.selectionClick());
    final RewardGrant grant = await ref
        .read(habitServiceProvider)
        .setDone(habitId: habit.id, dateKey: dateKey, done: done);
    if (grant.granted && context.mounted) {
      showUndoSnackBar(context, message: context.l10n.careHabitsAllDoneCoins('${grant.coins}'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final List<CustomHabit> all = ref.watch(habitsProvider).value ?? const <CustomHabit>[];
    final List<({CustomHabit habit, bool done})> today = ref.watch(todayHabitsProvider(dateKey));
    final int done = today.where((({CustomHabit habit, bool done}) h) => h.done).length;
    return HealthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          CardHeader(
            icon: Icons.auto_awesome_outlined,
            tone: c.steps,
            title: l10n.careHabitsTitle,
            subtitle: all.isEmpty
                ? l10n.careHabitsEmpty
                : (today.isEmpty
                      ? l10n.careHabitsNoneToday
                      : (done == today.length
                            ? l10n.careHabitsAllDone
                            : l10n.careHabitsDoneCount('$done', '${today.length}'))),
            trailing: TextButton(
              onPressed: () => unawaited(
                all.isEmpty ? HabitEditorSheet.show(context) : HabitsManageSheet.show(context),
              ),
              child: Text(all.isEmpty ? l10n.careTreatmentsAdd : l10n.careTreatmentsManage),
            ),
          ),
          if (today.isNotEmpty) ...<Widget>[
            const SizedBox(height: ScSpace.m),
            Wrap(
              spacing: ScSpace.s,
              runSpacing: ScSpace.s,
              children: <Widget>[
                for (final ({CustomHabit habit, bool done}) h in today)
                  FilterChip(
                    avatar: Icon(CareText.habitIcon(h.habit.iconKey), size: 18),
                    label: Text(h.habit.name),
                    selected: h.done,
                    onSelected: (bool v) => unawaited(_toggle(context, ref, h.habit, v)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Crear un hábito: nombre, icono y días.
class HabitEditorSheet extends ConsumerStatefulWidget {
  const HabitEditorSheet({super.key});

  static Future<void> show(BuildContext context) =>
      mostrarHojaMenu<void>(context, builder: (_) => const HabitEditorSheet());

  @override
  ConsumerState<HabitEditorSheet> createState() => _HabitEditorSheetState();
}

class _HabitEditorSheetState extends ConsumerState<HabitEditorSheet> {
  final TextEditingController _name = TextEditingController();
  String _icon = HabitService.iconKeys.first;
  int _days = 127;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    unawaited(HapticFeedback.lightImpact());
    await ref.read(habitServiceProvider).add(name: _name.text, iconKey: _icon, daysMask: _days);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ScColors c = context.sc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(ScSpace.xl - 4, 0, ScSpace.xl - 4, ScSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l10n.careHabitsAdd, style: context.text.titleLarge),
          const SizedBox(height: ScSpace.m),
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: HabitService.maxNameLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.careHabitName,
              hintText: l10n.careHabitNameHint,
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => unawaited(_save()),
          ),
          const SizedBox(height: ScSpace.s),
          Text(l10n.careHabitIcon, style: context.text.labelLarge),
          const SizedBox(height: ScSpace.xs),
          Wrap(
            spacing: ScSpace.xs,
            runSpacing: ScSpace.xs,
            children: <Widget>[
              for (final String key in HabitService.iconKeys)
                IconButton(
                  isSelected: key == _icon,
                  onPressed: () => setState(() => _icon = key),
                  icon: Icon(CareText.habitIcon(key), color: c.text2),
                  selectedIcon: Icon(CareText.habitIcon(key), color: c.isFlat ? c.text : c.accent),
                  style: IconButton.styleFrom(
                    backgroundColor: key == _icon ? (c.isFlat ? c.bg3 : c.soft) : null,
                    side: c.isFlat && key == _icon ? BorderSide(color: c.line2, width: 1.5) : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: ScSpace.m),
          Text(l10n.careTreatmentDays, style: context.text.labelLarge),
          const SizedBox(height: ScSpace.xs),
          WeekdayPicker(mask: _days, onChanged: (int m) => setState(() => _days = m)),
          const SizedBox(height: ScSpace.l),
          FilledButton(
            onPressed: _name.text.trim().isEmpty ? null : () => unawaited(_save()),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
  }
}

/// Lista de hábitos con "Quitar" (con Deshacer).
class HabitsManageSheet extends ConsumerWidget {
  const HabitsManageSheet({super.key});

  static Future<void> show(BuildContext context) =>
      mostrarHojaMenu<void>(context, builder: (_) => const HabitsManageSheet());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final List<CustomHabit> all = ref.watch(habitsProvider).value ?? const <CustomHabit>[];
    final HabitService service = ref.read(habitServiceProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(ScSpace.xl - 4, 0, ScSpace.xl - 4, ScSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l10n.careHabitsTitle, style: context.text.titleLarge),
          for (final CustomHabit h in all)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(CareText.habitIcon(h.iconKey)),
              title: Text(h.name),
              subtitle: Text(CareText.weekdays(l10n, h.daysOfWeekBitmask)),
              trailing: TextButton(
                onPressed: () async {
                  await service.archive(h.id);
                  if (context.mounted) {
                    showUndoSnackBar(
                      context,
                      message: l10n.careHabitArchived(h.name),
                      onUndo: () => unawaited(service.unarchive(h.id)),
                    );
                  }
                },
                child: Text(l10n.careHabitArchive),
              ),
            ),
          const SizedBox(height: ScSpace.m),
          OutlinedButton.icon(
            onPressed: () => unawaited(HabitEditorSheet.show(context)),
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.careHabitsAdd),
          ),
        ],
      ),
    );
  }
}
