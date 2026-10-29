import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/l10n/l10n.dart';
import 'package:nb_selfcare/features/care/presentation/widgets/treatment_sheets.dart';
import 'package:nb_selfcare/shared/theme/sc_theme.dart';
import 'package:nb_selfcare/shared/widgets/undo_snackbar.dart';

void main() {
  testWidgets('los siete días caben en una fila en un teléfono de 360 dp', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2460);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ScTheme.build('samsung_dark'),
        home: Scaffold(
          body: Padding(
            // El mismo margen que la hoja del tratamiento.
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: WeekdayPicker(mask: 127, onChanged: (_) {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final List<double> tops = tester
        .widgetList<FilterChip>(find.byType(FilterChip))
        .map((FilterChip c) => tester.getTopLeft(find.byWidget(c)).dy)
        .toSet()
        .toList();
    expect(tops, hasLength(1), reason: 'Todos los chips en la misma fila');
  });

  testWidgets('un aviso con Deshacer se va solo y no se queda debajo de otro', (WidgetTester tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('es'),
        home: Scaffold(
          body: Builder(
            builder: (BuildContext c) {
              ctx = c;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    showUndoSnackBar(ctx, message: 'Primero', onUndo: () {});
    await tester.pump();
    showUndoSnackBar(ctx, message: 'Segundo', onUndo: () {});
    await tester.pumpAndSettle();
    expect(find.text('Segundo'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Primero'), findsNothing);
    expect(find.text('Segundo'), findsNothing);
  });
}
