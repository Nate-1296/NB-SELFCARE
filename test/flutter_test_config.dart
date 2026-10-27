import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Canales nativos propios de la app. En los tests no hay código Android: se
/// responden con `null` (equivalente a "no disponible") de forma inmediata para
/// que los widget tests no esperen respuestas del bucle real de eventos.
const List<String> _nativeChannels = <String>[
  'com.nb.selfcare/health_connect',
  'com.nb.selfcare/system',
  'com.nb.selfcare/notifications',
];

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final String name in _nativeChannels) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(name), (MethodCall call) async => null);
  }
  await testMain();
}
