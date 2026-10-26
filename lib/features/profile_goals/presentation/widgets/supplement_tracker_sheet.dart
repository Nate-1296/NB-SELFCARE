import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/supplement_dao.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/sheet.dart';

/// Modal interactivo para el control y adherencia de suplementos y medicación.
class SupplementTrackerSheet extends ConsumerStatefulWidget {
  const SupplementTrackerSheet({
    super.key,
    required this.dateKey,
  });

  final String dateKey;

  static Future<void> show(BuildContext context, {required String dateKey}) {
    return mostrarHojaMenu<void>(
      context,
      builder: (_) => SupplementTrackerSheet(dateKey: dateKey),
    );
  }

  @override
  ConsumerState<SupplementTrackerSheet> createState() =>
      _SupplementTrackerSheetState();
}

class _SupplementTrackerSheetState
    extends ConsumerState<SupplementTrackerSheet> {
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
              title: const Text(
                'Nuevo Suplemento',
                style: TextStyle(
                  fontFamily: ScFonts.display,
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre',
                        hintText: 'Ej. Creatina Creapure, Omega 3, Magnesio',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: dosageCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Dosis diaria',
                        hintText: 'Ej. 5 g, 2 cápsulas, 400 mg',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        '¿Afecta retención hídrica?',
                        style: TextStyle(
                          fontFamily: ScFonts.ui,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        'Actívalo para Creatina. Evita falsas alarmas de peso graso en la báscula.',
                        style: TextStyle(
                          fontFamily: ScFonts.ui,
                          fontSize: 11,
                          color: c.text2,
                        ),
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
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isNotEmpty) {
                      Navigator.of(dCtx).pop(true);
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (created == true && nameCtrl.text.trim().isNotEmpty) {
      unawaited(HapticFeedback.lightImpact());
      await ref.read(supplementDaoProvider).createSupplement(
            name: nameCtrl.text.trim(),
            dosage: dosageCtrl.text.trim().isNotEmpty
                ? dosageCtrl.text.trim()
                : '1 dosis',
            affectsWaterRetention: affectsWater,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Suplemento "${nameCtrl.text.trim()}" añadido'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final SupplementDao dao = ref.watch(supplementDaoProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: StreamBuilder<List<SupplementsTrackerData>>(
        stream: dao.watchActiveSupplements(),
        builder: (
          BuildContext context,
          AsyncSnapshot<List<SupplementsTrackerData>> suppSnap,
        ) {
          final List<SupplementsTrackerData> supplements =
              suppSnap.data ?? const <SupplementsTrackerData>[];

          return StreamBuilder<List<SupplementLog>>(
            stream: dao.watchLogsForDate(widget.dateKey),
            builder: (
              BuildContext context,
              AsyncSnapshot<List<SupplementLog>> logsSnap,
            ) {
              final List<SupplementLog> logs =
                  logsSnap.data ?? const <SupplementLog>[];
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
                            color: c.isFlat
                                ? c.line2
                                : c.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.medication_rounded,
                            color: c.accent,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Suplementación & Salud',
                                style: TextStyle(
                                  fontFamily: ScFonts.display,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: c.text,
                                ),
                              ),
                              Text(
                                '${takenIds.length} de ${supplements.length} tomados hoy (${widget.dateKey})',
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
                          border: Border.all(
                            color: c.isFlat ? c.line2 : c.line,
                          ),
                        ),
                        child: Column(
                          children: <Widget>[
                            Icon(
                              Icons.medication_outlined,
                              size: 36,
                              color: c.text2,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Aún no tienes suplementos configurados',
                              style: TextStyle(
                                fontFamily: ScFonts.display,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: c.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Añade creatina, vitaminas o minerales para llevar su adherencia y correlacionar con tu composición corporal.',
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: c.bg3,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: c.isFlat ? c.line2 : c.line,
                              width: c.isFlat ? 1.3 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              Checkbox(
                                value: takenIds.contains(item.id),
                                onChanged: (bool? val) {
                                  unawaited(HapticFeedback.selectionClick());
                                  unawaited(
                                    dao.toggleSupplementIntake(
                                      dateKey: widget.dateKey,
                                      supplementId: item.id,
                                      wasTaken: val ?? false,
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
                                            decoration:
                                                takenIds.contains(item.id)
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
                                                  : c.steps
                                                      .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Agua BIA',
                                              style: TextStyle(
                                                fontFamily: ScFonts.ui,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: c.isFlat
                                                    ? c.text
                                                    : c.steps,
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
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: c.text2,
                                ),
                                onPressed: () {
                                  unawaited(dao.deleteSupplement(item.id));
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
                        label: const Text('Añadir Suplemento o Fármaco'),
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
