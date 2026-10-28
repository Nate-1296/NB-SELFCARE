import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/shared/theme/sc_theme.dart';
import 'package:nb_selfcare/shared/theme/sc_tokens.dart';
import 'package:nb_selfcare/shared/widgets/entrance.dart';
import 'package:nb_selfcare/shared/widgets/metric_value.dart';
import 'package:nb_selfcare/shared/widgets/pressable.dart';
import 'package:nb_selfcare/shared/widgets/progress_bar.dart';

Widget _app(String themeKey, Widget child, {bool disableAnimations = false}) => MaterialApp(
  // Cada tema en su propia app: sin la transición de tema de MaterialApp.
  key: ValueKey<String>('$themeKey-$disableAnimations'),
  theme: ScTheme.build(themeKey),
  home: Builder(
    builder: (BuildContext context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
      child: Scaffold(body: Center(child: child)),
    ),
  ),
);

/// Hijo con estado: si se recrea, el contador vuelve a 0.
class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int taps = 0;

  @override
  Widget build(BuildContext context) =>
      TextButton(onPressed: () => setState(() => taps++), child: Text('taps $taps'));
}

void main() {
  testWidgets('ScMotion: duraciones normales en color, cero en papel y con movimiento reducido', (
    WidgetTester tester,
  ) async {
    final List<Duration> seen = <Duration>[];
    Widget probe() => Builder(
      builder: (BuildContext context) {
        seen.add(ScMotion.of(context, ScMotion.standard));
        return const SizedBox();
      },
    );
    await tester.pumpWidget(_app('samsung_dark', probe()));
    await tester.pumpWidget(_app('nxtpaper_sepia', probe()));
    await tester.pumpWidget(_app('samsung_dark', probe(), disableAnimations: true));
    expect(seen, <Duration>[ScMotion.standard, Duration.zero, Duration.zero]);
  });

  testWidgets('Entrance anima la primera aparición sin recrear el estado del hijo', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app('samsung_dark', const Entrance(index: 2, child: _Counter())));
    await tester.tap(find.byType(TextButton));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('taps 1'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('taps 1'), findsOneWidget);
  });

  testWidgets('En papel, Entrance no programa fotogramas de animación', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app('nxtpaper_eink_light', const Entrance(index: 3, child: Text('hola'))),
    );
    expect(
      find.descendant(of: find.byType(Entrance), matching: find.byType(FadeTransition)),
      findsNothing,
    );
    expect(find.text('hola'), findsOneWidget);
  });

  testWidgets('Pressable conserva el estado del hijo al activarse o desactivarse', (
    WidgetTester tester,
  ) async {
    Widget build(bool enabled) =>
        _app('samsung_dark', Pressable(enabled: enabled, child: const _Counter()));
    await tester.pumpWidget(build(true));
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    await tester.pumpWidget(build(false));
    expect(find.text('taps 1'), findsOneWidget);
  });

  testWidgets('Las cifras y barras cambian al instante en papel (sin fotogramas intermedios)', (
    WidgetTester tester,
  ) async {
    Widget build(double v) => _app(
      'nxtpaper_eink_dark',
      Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AnimatedMetricValue(value: v, format: (double x) => x.round().toString(), unit: 'ml'),
          SizedBox(width: 200, child: ScProgressBar(value: v / 1000)),
        ],
      ),
    );
    await tester.pumpWidget(build(250));
    await tester.pumpAndSettle();
    await tester.pumpWidget(build(500));
    // Mismo fotograma: sin cuenta progresiva ni avance de la barra.
    expect(find.text('500 ml', findRichText: true), findsOneWidget);
    final FractionallySizedBox bar = tester.widget(find.byType(FractionallySizedBox));
    expect(bar.widthFactor, 0.5);
  });

  testWidgets('En color, la cifra cuenta hasta el nuevo valor', (WidgetTester tester) async {
    Widget build(double v) => _app(
      'samsung_dark',
      AnimatedMetricValue(value: v, format: (double x) => x.round().toString(), unit: 'ml'),
    );
    await tester.pumpWidget(build(0));
    await tester.pumpWidget(build(1000));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('1000 ml', findRichText: true), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('1000 ml', findRichText: true), findsOneWidget);
  });
}
