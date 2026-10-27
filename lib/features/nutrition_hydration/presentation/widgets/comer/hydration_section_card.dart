import 'package:flutter/material.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_theme.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/health_card.dart';

/// Tarjeta completa de Hidratación del Día (+250 ml, +500 ml, vaso personalizado e historial).
class HydrationSectionCard extends StatelessWidget {
  const HydrationSectionCard({super.key, 
    required this.logs,
    required this.goalMl,
    required this.formatClock,
    required this.onAdd250,
    required this.onAdd500,
    required this.onOpenCustom,
    required this.onDeleteGlass,
  });

  final List<HydrationLog> logs;
  final int goalMl;
  final String Function(DateTime) formatClock;
  final VoidCallback onAdd250;
  final VoidCallback onAdd500;
  final VoidCallback onOpenCustom;
  final ValueChanged<HydrationLog> onDeleteGlass;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final int totalMl = logs.fold(
      0,
      (int sum, HydrationLog item) => sum + item.volumeMl,
    );
    final double ratio =
        goalMl > 0 ? (totalMl / goalMl).clamp(0.0, 1.0) : 0.0;
    final int pct = (ratio * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
          child: Text(
            context.l10n.comerHidratacion,
            style: TextStyle(
              fontFamily: ScFonts.display,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: c.text,
            ),
          ),
        ),
        HealthCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.isFlat
                          ? c.bg3
                          : c.water.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: c.isFlat
                            ? c.line2
                            : c.water.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(
                      AppIcons.gota,
                      color: c.isFlat ? c.text : c.water,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          context.l10n.comerAguaAcumulada,
                          style: TextStyle(
                            fontFamily: ScFonts.display,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: c.text,
                          ),
                        ),
                        Text(
                          context.l10n.comerMl((totalMl).toString(), (goalMl).toString(), (pct).toString()),
                          softWrap: true,
                          style: TextStyle(
                            fontFamily: ScFonts.ui,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: c.text2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: ratio,
                backgroundColor: c.bg3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  c.isFlat ? c.text : c.water,
                ),
                borderRadius: BorderRadius.circular(5),
                minHeight: 7,
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: onAdd250,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      icon: const Icon(AppIcons.add, size: 17),
                      label: Text(
                        context.l10n.comer250Ml,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: onAdd500,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      icon: const Icon(AppIcons.add, size: 17),
                      label: Text(
                        context.l10n.comer500Ml,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onOpenCustom,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: Text(
                        context.l10n.comerAMedida,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
              if (logs.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: logs.map((HydrationLog item) {
                    return InputChip(
                      label: Text(
                        context.l10n.comerMl2(item.volumeMl.toString(), formatClock(item.loggedAt).toString()),
                        style: TextStyle(
                          fontFamily: ScFonts.ui,
                          fontSize: 11.5,
                          color: c.text2,
                        ),
                      ),
                      visualDensity: VisualDensity.compact,
                      onDeleted: () => onDeleteGlass(item),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
