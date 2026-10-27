import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Configuración del arnés de capturas: fuentes reales (no la Ahem de los
/// tests) y canales nativos simulados.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final String name in <String>[
    'com.nb.selfcare/health_connect',
    'com.nb.selfcare/system',
    'com.nb.selfcare/notifications',
  ]) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(name), (MethodCall call) async => null);
  }

  Future<void> load(String family, List<String> files) async {
    final FontLoader loader = FontLoader(family);
    for (final String path in files) {
      final File file = File(path);
      if (file.existsSync()) {
        loader.addFont(Future<ByteData>.value(ByteData.sublistView(file.readAsBytesSync())));
      }
    }
    await loader.load();
  }

  final String flutterRoot = Platform.environment['FLUTTER_ROOT'] ??
      '${Platform.environment['HOME']}/flutter';
  final String materialFonts = '$flutterRoot/bin/cache/artifacts/material_fonts';
  await load('SpaceGrotesk', <String>['assets/fonts/SpaceGrotesk.ttf']);
  await load('Manrope', <String>['assets/fonts/Manrope.ttf']);
  await load('MaterialIcons', <String>['$materialFonts/MaterialIcons-Regular.otf']);
  await load('Roboto', <String>[
    '$materialFonts/Roboto-Regular.ttf',
    '$materialFonts/Roboto-Medium.ttf',
    '$materialFonts/Roboto-Bold.ttf',
  ]);
  await testMain();
}
