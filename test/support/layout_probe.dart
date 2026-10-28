import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Filas y columnas que desbordan ahora mismo, con la cadena de widgets que
/// las creó (lo que `takeException` no muestra).
String describeOverflows(WidgetTester tester) {
  final List<String> found = <String>[];
  void visit(RenderObject r) {
    if (r is RenderFlex && r.hasSize) {
      double total = 0;
      r.visitChildren((RenderObject ch) {
        if (ch is RenderBox && ch.hasSize) {
          total += r.direction == Axis.horizontal ? ch.size.width : ch.size.height;
        }
      });
      final double own = r.direction == Axis.horizontal ? r.size.width : r.size.height;
      if (total > own + 0.5) {
        final Object? creator = r.debugCreator;
        final String chain = creator is DebugCreator
            ? creator.element.debugGetCreatorChain(24)
            : '$creator';
        found.add('  +${(total - own).toStringAsFixed(1)} px $chain');
      }
    }
    r.visitChildren(visit);
  }

  for (final RenderView view in tester.binding.renderViews) {
    visit(view);
  }
  return found.isEmpty ? '' : '${found.join('\n')}\n';
}
