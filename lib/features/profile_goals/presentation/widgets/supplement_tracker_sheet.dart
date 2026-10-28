import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/sheet.dart';
import '../../application/supplement_service.dart';

/// Modal interactivo para el control y adherencia de suplementos y medicación.
class SupplementTrackerSheet extends ConsumerStatefulWidget {
  const SupplementTrackerSheet({super.key, required this.dateKey});

  final String dateKey;

  static Future<void> show(BuildContext context, {required String dateKey}) {
    return mostrarHojaMenu<void>(context, builder: (_) => SupplementTrackerSheet(dateKey: dateKey));
  }

  @override
  ConsumerState<SupplementTrackerSheet> createState() => _SupplementTrackerSheetState();
}

class _SupplementTrackerSheetState extends ConsumerState<SupplementTrackerSheet> {
  Future<void> _openAddSupplementDialog() async {
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController dosageCtrl = TextEditingController();
    bool affectsWater = false;

    final bool? created = await showDialog<bool>(
      context: context,
      builder: (BuildContext dCtx) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setModalState) {
            final ScColors c = ctx.sc;
            return AlertDialog(
              title: Text(
                context.l10n.perfilNuevoSuplemento,
                style: const TextStyle(fontFamily: ScFonts.display, fontWeight: FontWeight.w700),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: context.l10n.perfilNombre,
                        hintText: context.l10n.perfilEjCreatinaCreapureOmega3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: dosageCtrl,
                      decoration: InputDecoration(
                        labelText: context.l10n.perfilDosisDiaria,
                        hintText: context.l10n.perfilEj5G2Capsulas,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        context.l10n.perfilAfectaRetencionHidrica,
                        style: const TextStyle(
                          fontFamily: ScFonts.ui,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        context.l10n.perfilActivaloParaCreatinaEvitaFalsas,
                        style: TextStyle(fontFamily: ScFonts.ui, fontSize: 11, color: c.text2),
                      ),
                      value: affectsWater,
                      onChanged: (bool val) {
                        setModalState(() => affectsWater = val);
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dCtx).pop(false),
                  child: Text(context.l10n.commonCancel),
                ),
                FilledButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isNotEmpty) {
                      Navigator.of(dCtx).pop(true);
                    }
                  },
                  child: Text(context.l10n.bodyRegistrarEn5Segundos),
                ),
              ],
            );
          },
        );
      },
    );

    if (created == true && nameCtrl.text.trim().isNotEmpty && mounted) {
      unawaited(HapticFeedback.lightImpact());
      final String fallbackDose = context.l10n.perfil1Dosis;
      await ref
          .read(supplementServiceProvider)
          .add(
            name: nameCtrl.text.trim(),
            dosage: dosageCtrl.text.trim().isNotEmpty ? dosageCtrl.text.trim() : fallbackDose,
            affectsWaterRetention: affectsWater,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.perfilSuplementoAnadido(nameCtrl.text.trim().toString())),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final List<SupplementsTrackerData> supplements =
        ref.watch(activeSupplementsProvider).value ?? const <SupplementsTrackerData>[];
    final List<SupplementLog> logs =
        ref.watch(supplementLogsProvider(widget.dateKey)).value ?? const <SupplementLog>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Builder(
        builder: (BuildContext context) {
          return Builder(
            builder: (BuildContext context) {
              final Set<int> takenIds = logs
                  .where((SupplementLog l) => l.wasTaken)
                  .map((SupplementLog l) => l.supplementId)
                  .toSet();

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: c.isFlat ? c.line2 : c.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.medication_rounded, color: c.accent, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                context.l10n.perfilSuplementacionSalud,
                                style: TextStyle(
                                  fontFamily: ScFonts.display,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: c.text,
                                ),
                              ),
                              Text(
                                context.l10n.perfilDeTomadosHoy(
                                  takenIds.length.toString(),
                                  supplements.length.toString(),
                                  widget.dateKey.toString(),
                                ),
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
                          icon: Icon(AppIcons.close, color: c.text2),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    if (supplements.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: c.bg3,
                          borderRadius: BorderRadius.circular(14),
                          border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
                        ),
                        child: Column(
                          children: <Widget>[
                            Icon(Icons.medication_outlined, size: 36, color: c.text2),
                            const SizedBox(height: 10),
                            Text(
                              context.l10n.perfilAunNoTienesSuplementosConfigurados,
                              style: TextStyle(
                                fontFamily: ScFonts.display,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: c.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.l10n.perfilAnadeCreatinaVitaminasOMinerales,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: ScFonts.ui,
                                fontSize: 12,
                                color: c.text2,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      for (final SupplementsTrackerData item in supplements)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: c.bg3,
                            borderRadius: BorderRadius.circular(14),
                            border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
                          ),
                          child: Row(
                            children: <Widget>[
                              Checkbox(
                                value: takenIds.contains(item.id),
                                onChanged: (bool? val) {
                                  unawaited(HapticFeedback.selectionClick());
                                  unawaited(
                                    ref
                                        .read(supplementServiceProvider)
                                        .setTaken(
                                          dateKey: widget.dateKey,
                                          supplementId: item.id,
                                          taken: val ?? false,
                                        ),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Row(
                                      children: <Widget>[
                                        Text(
                                          item.name,
                                          style: TextStyle(
                                            fontFamily: ScFonts.ui,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: c.text,
                                            decoration: takenIds.contains(item.id)
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                        ),
                                        if (item.affectsWaterRetention) ...<Widget>[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: c.isFlat
                                                  ? c.line2
                                                  : c.steps.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              context.l10n.perfilAguaBia,
                                              style: TextStyle(
                                                fontFamily: ScFonts.ui,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: c.isFlat ? c.text : c.steps,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      item.dosage,
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
                                icon: Icon(Icons.delete_outline_rounded, size: 18, color: c.text2),
                                onPressed: () {
                                  unawaited(ref.read(supplementServiceProvider).remove(item.id));
                                },
                              ),
                            ],
                          ),
                        ),

                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _openAddSupplementDialog,
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(context.l10n.perfilAnadirSuplementoOFarmaco),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
