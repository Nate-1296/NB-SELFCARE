import 'package:flutter/material.dart';

import '../../../../shared/theme/sc_tokens.dart';
import '../../domain/hoy_widget_config.dart';

/// Distribuye las tarjetas de Hoy: las 2×2 se emparejan en filas y las 4×2 y
/// 4×4 ocupan el ancho completo. El orden y el tamaño los decide el usuario.
class TodayBentoGrid extends StatelessWidget {
  const TodayBentoGrid({super.key, required this.items, required this.tileBuilder});

  final List<HoyWidgetItemConfig> items;

  /// Construye la tarjeta (ya envuelta en modo edición si corresponde) y recibe
  /// su posición entre las visibles.
  final Widget Function(HoyWidgetItemConfig item, int index) tileBuilder;

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = <Widget>[];
    int i = 0;
    while (i < items.length) {
      final HoyWidgetItemConfig current = items[i];
      if (current.size != HoyWidgetSize.w2x2) {
        rows.add(tileBuilder(current, i));
        i += 1;
        continue;
      }
      final bool hasPair = i + 1 < items.length && items[i + 1].size == HoyWidgetSize.w2x2;
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: tileBuilder(current, i)),
              const SizedBox(width: ScSpace.cardGap),
              Expanded(child: hasPair ? tileBuilder(items[i + 1], i + 1) : const SizedBox.shrink()),
            ],
          ),
        ),
      );
      i += hasPair ? 2 : 1;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final Widget row in rows) ...<Widget>[row, const SizedBox(height: ScSpace.cardGap)],
      ],
    );
  }
}
