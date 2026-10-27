import 'package:flutter/material.dart';

import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_theme.dart';
import '../../../../../shared/widgets/health_card.dart';
import '../../../domain/hoy_widget_config.dart';
import '../../hoy_widget_l10n.dart';

class HiddenWidgetsTray extends StatelessWidget {
  const HiddenWidgetsTray({super.key, 
    required this.hiddenItems,
    required this.onShowWidget,
  });

  final List<HoyWidgetItemConfig> hiddenItems;
  final ValueChanged<HoyWidgetId> onShowWidget;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return HealthCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.visibility_outlined, size: 18, color: c.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.todayTarjetasOcultas(hiddenItems.length.toString()),
                  softWrap: true,
                  style: TextStyle(
                    fontFamily: ScFonts.display,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: c.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.todayTocaParaVolverAAnadir,
            softWrap: true,
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 12,
              color: c.text2,
            ),
          ),
          const SizedBox(height: 12),
          ...hiddenItems.map(
            (HoyWidgetItemConfig item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: c.bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: c.isFlat ? c.line2 : c.line,
                    width: c.isFlat ? 1.3 : 1.0,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        context.l10n.todayTexto(item.id.title(context.l10n), item.size.label.toString()),
                        softWrap: true,
                        style: TextStyle(
                          fontFamily: ScFonts.ui,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: c.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: () => onShowWidget(item.id),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text(context.l10n.todayMostrar),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
