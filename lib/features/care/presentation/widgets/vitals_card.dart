import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/domain/care_enums.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_tokens.dart';
import '../../../../shared/utils/date_formats.dart';
import '../../../../shared/widgets/card_header.dart';
import '../../../../shared/widgets/health_card.dart';
import '../../../../shared/widgets/sheet.dart';
import '../../../../shared/widgets/undo_snackbar.dart';
import '../../application/care_queries.dart';
import '../../application/health_log_services.dart';
import '../../domain/vital_ranges.dart';
import '../care_l10n.dart';
import 'guided_care_cards.dart';

Color _bandColor(ScColors c, VitalBand band) {
  if (c.isFlat) return c.text;
  return switch (band) {
    VitalBand.normal => c.success,
    VitalBand.elevated || VitalBand.low => c.warning,
    VitalBand.high || VitalBand.consultSoon => c.danger,
  };
}

VitalBand _bandOf(VitalKind kind, VitalReading r) => VitalRanges.bandFor(
  kind: kind,
  primary: r.primaryValue,
  secondary: r.secondaryValue,
  context: r.context,
);

/// Signos vitales de los aparatos declarados: última lectura y su lectura orientativa.
class VitalsCard extends ConsumerWidget {
  const VitalsCard({super.key, required this.kinds});

  final Set<VitalKind> kinds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final List<VitalKind> ordered = VitalKind.values.where(kinds.contains).toList();
    return HealthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          CardHeader(
            icon: Icons.monitor_heart_outlined,
            tone: c.danger,
            title: l10n.careVitalsTitle,
            subtitle: l10n.careVitalsHint,
            trailing: const LearnMoreButton(spec: CareScience.vitals),
          ),
          const SizedBox(height: ScSpace.s),
          for (final (int i, VitalKind kind) in ordered.indexed) ...<Widget>[
            if (i > 0) Divider(height: 1, color: c.isFlat ? c.line2 : c.line),
            _VitalRow(kind: kind),
          ],
        ],
      ),
    );
  }
}

class _VitalRow extends ConsumerWidget {
  const _VitalRow({required this.kind});

  final VitalKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final List<VitalReading> readings =
        ref.watch(vitalReadingsProvider(kind)).value ?? const <VitalReading>[];
    final VitalReading? last = readings.firstOrNull;
    final VitalBand? band = last == null ? null : _bandOf(kind, last);
    return InkWell(
      onTap: () => unawaited(VitalHistorySheet.show(context, kind)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: ScSpace.s + 2),
        child: Row(
          children: <Widget>[
            Icon(kind.icon, color: c.text2, size: 22),
            const SizedBox(width: ScSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(kind.label(l10n), style: context.text.titleSmall),
                  Text(
                    last == null
                        ? l10n.careVitalNone
                        : '${band!.label(l10n)} · ${DateFormats.shortDate(last.measuredAt, l10n.localeName)}',
                    style: context.type.caption.copyWith(
                      color: band == null ? c.text3 : _bandColor(c, band),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            if (last != null)
              Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    TextSpan(
                      text: kind.format(last.primaryValue, last.secondaryValue),
                      style: context.type.metricS,
                    ),
                    TextSpan(text: ' ${kind.unit(l10n)}', style: context.type.caption),
                  ],
                ),
              ),
            IconButton(
              tooltip: l10n.careVitalAdd,
              onPressed: () => unawaited(VitalEntrySheet.show(context, kind)),
              icon: Icon(Icons.add_circle_outline_rounded, color: c.isFlat ? c.text : c.accent),
            ),
          ],
        ),
      ),
    );
  }
}

/// Registro manual de una medición.
class VitalEntrySheet extends ConsumerStatefulWidget {
  const VitalEntrySheet({super.key, required this.kind});

  final VitalKind kind;

  static Future<void> show(BuildContext context, VitalKind kind) =>
      mostrarHojaMenu<void>(context, builder: (_) => VitalEntrySheet(kind: kind));

  @override
  ConsumerState<VitalEntrySheet> createState() => _VitalEntrySheetState();
}

class _VitalEntrySheetState extends ConsumerState<VitalEntrySheet> {
  final TextEditingController _primary = TextEditingController();
  final TextEditingController _secondary = TextEditingController();
  GlucoseContext _context = GlucoseContext.fasting;
  String? _error;

  @override
  void dispose() {
    _primary.dispose();
    _secondary.dispose();
    super.dispose();
  }

  static double? _num(String raw) => double.tryParse(raw.trim().replaceAll(',', '.'));

  Future<void> _save() async {
    final double? primary = _num(_primary.text);
    final double? secondary = widget.kind == VitalKind.bloodPressure ? _num(_secondary.text) : null;
    final bool ok =
        primary != null &&
        await ref
            .read(vitalServiceProvider)
            .addManual(
              kind: widget.kind,
              primary: primary,
              secondary: secondary,
              context: widget.kind == VitalKind.glucose ? _context.key : null,
            );
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = context.l10n.careVitalImplausible);
      return;
    }
    unawaited(HapticFeedback.lightImpact());
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String message = context.l10n.careVitalSaved;
    Navigator.of(context).pop();
    messenger
..hideCurrentSnackBar()
..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ScColors c = context.sc;
    final bool bp = widget.kind == VitalKind.bloodPressure;
    return Padding(
      padding: const EdgeInsets.fromLTRB(ScSpace.xl - 4, 0, ScSpace.xl - 4, ScSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(widget.kind.label(l10n), style: context.text.titleLarge),
          const SizedBox(height: ScSpace.m),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _primary,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: bp ? l10n.careVitalSystolic : l10n.careVitalValue,
                    helperText: bp ? l10n.careVitalSystolicHint : null,
                    suffixText: widget.kind.unit(l10n),
                  ),
                ),
              ),
              if (bp) ...<Widget>[
                const SizedBox(width: ScSpace.m),
                Expanded(
                  child: TextField(
                    controller: _secondary,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.careVitalDiastolic,
                      helperText: l10n.careVitalDiastolicHint,
                      suffixText: widget.kind.unit(l10n),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (widget.kind == VitalKind.glucose) ...<Widget>[
            const SizedBox(height: ScSpace.m),
            Wrap(
              spacing: ScSpace.s,
              children: <Widget>[
                for (final GlucoseContext g in GlucoseContext.values)
                  ChoiceChip(
                    label: Text(g.label(l10n)),
                    selected: g == _context,
                    onSelected: (_) => setState(() => _context = g),
                  ),
              ],
            ),
          ],
          if (_error != null) ...<Widget>[
            const SizedBox(height: ScSpace.s),
            Text(
              _error!,
              style: context.type.caption.copyWith(color: c.isFlat ? c.text : c.danger),
            ),
          ],
          const SizedBox(height: ScSpace.m),
          Text(l10n.careVitalsDisclaimer, style: context.type.caption.copyWith(color: c.text3)),
          const SizedBox(height: ScSpace.l),
          FilledButton(
            onPressed: () => unawaited(_save()),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
  }
}

/// Historial de un signo vital con borrado (y Deshacer).
class VitalHistorySheet extends ConsumerWidget {
  const VitalHistorySheet({super.key, required this.kind});

  final VitalKind kind;

  static Future<void> show(BuildContext context, VitalKind kind) =>
      mostrarHojaMenu<void>(context, builder: (_) => VitalHistorySheet(kind: kind));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final List<VitalReading> readings =
        ref.watch(vitalReadingsProvider(kind)).value ?? const <VitalReading>[];
    final VitalService service = ref.read(vitalServiceProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(ScSpace.xl - 4, 0, ScSpace.xl - 4, ScSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(kind.label(l10n), style: context.text.titleLarge)),
              TextButton.icon(
                onPressed: () => unawaited(VitalEntrySheet.show(context, kind)),
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.careVitalAdd),
              ),
            ],
          ),
          Text(l10n.careVitalsHistory, style: context.text.labelLarge),
          if (readings.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: ScSpace.l),
              child: Text(l10n.careVitalNone, style: context.type.caption),
            ),
          for (final VitalReading r in readings)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${kind.format(r.primaryValue, r.secondaryValue)} ${kind.unit(l10n)}'
                '${kind == VitalKind.glucose ? ' · ${GlucoseContext.fromKey(r.context).label(l10n)}' : ''}',
              ),
              subtitle: Text(
                '${_bandOf(kind, r).label(l10n)} · ${DateFormats.shortDate(r.measuredAt, l10n.localeName)} '
                '${DateFormats.time(r.measuredAt, l10n.localeName)}'
                '${r.source == 'health_connect' ? ' · ${l10n.careVitalFromHealthConnect}' : ''}',
                style: context.type.caption.copyWith(color: _bandColor(c, _bandOf(kind, r))),
              ),
              trailing: IconButton(
                tooltip: l10n.commonDelete,
                icon: Icon(Icons.delete_outline_rounded, color: c.text3),
                onPressed: () async {
                  await service.delete(r.id);
                  if (context.mounted) {
                    showUndoSnackBar(
                      context,
                      message: l10n.careVitalDeleted,
                      onUndo: () => unawaited(service.restore(r)),
                    );
                  }
                },
              ),
            ),
          const SizedBox(height: ScSpace.s),
          Text(l10n.careVitalsDisclaimer, style: context.type.caption.copyWith(color: c.text3)),
        ],
      ),
    );
  }
}
