import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/clock/clock.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_tokens.dart';
import '../../../../shared/utils/date_formats.dart';
import '../../../../shared/widgets/card_header.dart';
import '../../../../shared/widgets/health_card.dart';
import '../../../../shared/widgets/sheet.dart';
import '../../../../shared/widgets/undo_snackbar.dart';
import '../../../pet_gamification/application/reward_service.dart';
import '../../application/care_queries.dart';
import '../../application/checkup_service.dart';
import '../../domain/checkup_catalog.dart';
import '../care_l10n.dart';
import 'guided_care_cards.dart';

String _statusText(AppLocalizations l10n, CheckupItem item) => switch (item.due.status) {
  CheckupStatus.due => l10n.careCheckupDue,
  CheckupStatus.dueSoon => l10n.careCheckupDueSoon('${item.due.daysUntil}'),
  CheckupStatus.neverDone => l10n.careCheckupNever,
  CheckupStatus.upToDate => l10n.careCheckupNext(
    DateFormats.shortDate(item.due.nextDue!, l10n.localeName),
  ),
};

Future<void> _markDone(BuildContext context, WidgetRef ref, CheckupItem item) async {
  final DateTime now = ref.read(clockProvider).now();
  final DateTime? picked = await showDatePicker(
    context: context,
    helpText: context.l10n.careCheckupDoneWhen,
    confirmText: context.l10n.commonAccept,
    initialDate: now,
    firstDate: DateTime(now.year - 15),
    lastDate: now,
  );
  if (picked == null || !context.mounted) return;
  unawaited(HapticFeedback.lightImpact());
  final RewardGrant grant = await ref
      .read(checkupServiceProvider)
      .markDone(item.checkup.id, doneAt: picked);
  if (!context.mounted) return;
  showUndoSnackBar(
    context,
    message: grant.granted
        ? context.l10n.careCheckupDoneCoins('${grant.coins}')
        : context.l10n.careCheckupDoneSnack,
  );
}

/// Chequeos preventivos: lo que toca primero; el resto en "Ver todos".
class CheckupsCard extends ConsumerWidget {
  const CheckupsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final List<CheckupItem> active = ref
        .watch(checkupItemsProvider)
        .where((CheckupItem i) => i.checkup.isEnabled)
        .toList();
    final List<CheckupItem> pending = active
        .where((CheckupItem i) => i.due.status != CheckupStatus.upToDate)
        .take(3)
        .toList();
    return HealthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          CardHeader(
            icon: Icons.event_available_rounded,
            tone: c.water,
            title: l10n.careCheckupsTitle,
            subtitle: pending.isEmpty && active.isNotEmpty ? l10n.careCheckupsAllGood : null,
            trailing: const LearnMoreButton(spec: CareScience.checkups),
          ),
          for (final CheckupItem item in pending)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(CareText.checkup(l10n, item.checkup.catalogKey, item.checkup.customName)),
              subtitle: Text(
                '${_statusText(l10n, item)} · ${CareText.interval(l10n, item.checkup.intervalMonths)}',
                style: context.type.caption.copyWith(
                  color: item.due.status == CheckupStatus.due && !c.isFlat ? c.warning : c.text2,
                ),
              ),
              trailing: TextButton(
                onPressed: () => unawaited(_markDone(context, ref, item)),
                child: Text(l10n.careCheckupMarkDone),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => unawaited(CheckupsSheet.show(context)),
              child: Text(l10n.careCheckupsSeeAll),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lista completa: marcar, cambiar intervalo, activar o desactivar y añadir propios.
class CheckupsSheet extends ConsumerWidget {
  const CheckupsSheet({super.key});

  static Future<void> show(BuildContext context) =>
      mostrarHojaMenu<void>(context, builder: (_) => const CheckupsSheet());

  Future<void> _editInterval(BuildContext context, WidgetRef ref, Checkup checkup) async {
    final TextEditingController ctrl = TextEditingController(text: '${checkup.intervalMonths}');
    final int? months = await showDialog<int>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(ctx.l10n.careCheckupInterval),
        content: TextField(controller: ctrl, autofocus: true, keyboardType: TextInputType.number),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(ctx.l10n.commonCancel)),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(int.tryParse(ctrl.text.trim())),
            child: Text(ctx.l10n.commonSave),
          ),
        ],
      ),
    );
    if (months != null && months > 0) {
      await ref.read(checkupServiceProvider).setInterval(checkup.id, months);
    }
  }

  Future<void> _addCustom(BuildContext context, WidgetRef ref) async {
    final TextEditingController name = TextEditingController();
    final TextEditingController months = TextEditingController(text: '12');
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(ctx.l10n.careCheckupAddCustom),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: ctx.l10n.careCheckupCustomName),
            ),
            TextField(
              controller: months,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: ctx.l10n.careCheckupInterval),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.l10n.commonSave),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref
          .read(checkupServiceProvider)
          .addCustom(name: name.text, intervalMonths: int.tryParse(months.text.trim()) ?? 12);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final List<CheckupItem> items = ref.watch(checkupItemsProvider);
    final CheckupService service = ref.read(checkupServiceProvider);
    Widget tile(CheckupItem item) {
      final Checkup ch = item.checkup;
      final CheckupLog? last = item.lastLog;
      return ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          CareText.checkup(l10n, ch.catalogKey, ch.customName),
          style: TextStyle(color: ch.isEnabled ? c.text : c.text3),
        ),
        subtitle: Text(
          <String>[
            if (ch.isEnabled) _statusText(l10n, item),
            CareText.interval(l10n, ch.intervalMonths),
            if (last != null)
              l10n.careCheckupLast(DateFormats.shortDate(last.doneAt, l10n.localeName)),
          ].join(' · '),
          style: context.type.caption,
        ),
        onTap: ch.isEnabled ? () => unawaited(_markDone(context, ref, item)) : null,
        trailing: PopupMenuButton<String>(
          onSelected: (String action) async {
            switch (action) {
              case 'interval':
                await _editInterval(context, ref, ch);
              case 'toggle':
                await service.setEnabled(ch.id, enabled: !ch.isEnabled);
              case 'undo_last':
                if (last != null) {
                  await service.deleteLog(last.id);
                  if (context.mounted) {
                    showUndoSnackBar(
                      context,
                      message: l10n.careCheckupHistoryDeleted,
                      onUndo: () => unawaited(service.restoreLog(last)),
                    );
                  }
                }
              case 'remove':
                await service.remove(ch.id);
            }
          },
          itemBuilder: (BuildContext ctx) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(value: 'interval', child: Text(l10n.careCheckupInterval)),
            PopupMenuItem<String>(
              value: 'toggle',
              child: Text(ch.isEnabled ? l10n.careCheckupDisable : l10n.careCheckupEnable),
            ),
            if (last != null)
              PopupMenuItem<String>(value: 'undo_last', child: Text(l10n.careDoseUndo)),
            if (ch.catalogKey == CheckupCatalog.custom)
              PopupMenuItem<String>(value: 'remove', child: Text(l10n.careCheckupRemove)),
          ],
        ),
      );
    }

    final List<CheckupItem> active = items.where((CheckupItem i) => i.checkup.isEnabled).toList();
    final List<CheckupItem> off = items.where((CheckupItem i) => !i.checkup.isEnabled).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(ScSpace.xl - 4, 0, ScSpace.xl - 4, ScSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l10n.careCheckupsTitle, style: context.text.titleLarge),
          for (final CheckupItem i in active) tile(i),
          if (off.isNotEmpty) ...<Widget>[
            const SizedBox(height: ScSpace.m),
            Text(l10n.careCheckupDisabled, style: context.text.labelLarge),
            for (final CheckupItem i in off) tile(i),
          ],
          const SizedBox(height: ScSpace.m),
          OutlinedButton.icon(
            onPressed: () => unawaited(_addCustom(context, ref)),
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.careCheckupAddCustom),
          ),
        ],
      ),
    );
  }
}
