import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Contrato entre Dart y el código nativo de Android: si un método se renombra
/// en un lado y no en el otro, en el teléfono la llamada falla en silencio
/// (el puente responde "no disponible"). Estas pruebas leen ambos lados.
final RegExp _dartCall = RegExp(
  r"""(?:_invoke(?:<[^>]+>)?|callNative<[^>]+>\(\w+,)\s*\(?\s*'([a-zA-Z]+)'""",
);

Set<String> _kotlinHandlers(String source, String handler) {
  final int start = source.indexOf('private fun $handler(');
  final int end = source.indexOf('\n    private fun ', start + 1);
  final String body = source.substring(start, end < 0 ? source.length : end);
  return RegExp(r'"([a-zA-Z]+)" ->').allMatches(body).map((RegExpMatch m) => m.group(1)!).toSet();
}

Set<String> _dartMethods(List<String> files) => <String>{
  for (final String f in files)
    for (final RegExpMatch m in _dartCall.allMatches(File(f).readAsStringSync())) m.group(1)!,
};

void main() {
  final String activity = File('android/app/src/main/kotlin/com/nb/selfcare/MainActivity.kt')
      .readAsStringSync();

  test('los canales nativos existen con el mismo nombre en Dart y en Kotlin', () {
    for (final String channel in <String>[
      'com.nb.selfcare/health_connect',
      'com.nb.selfcare/system',
      'com.nb.selfcare/notifications',
    ]) {
      expect(activity, contains('"$channel"'), reason: channel);
    }
  });

  test('cada método que Dart llama lo atiende Kotlin', () {
    final Map<String, (String, List<String>)> pairs = <String, (String, List<String>)>{
      'Health Connect': ('onHealthCall', <String>['lib/core/platform/health_connect_gateway.dart']),
      'Sistema': (
        'onSystemCall',
        <String>[
          'lib/core/platform/system_permissions.dart',
          'lib/core/platform/speech_gateway.dart',
        ],
      ),
      'Notificaciones': (
        'onNotificationsCall',
        <String>['lib/core/platform/notification_gateway.dart'],
      ),
    };
    pairs.forEach((String name, (String, List<String>) pair) {
      final Set<String> dart = _dartMethods(pair.$2);
      final Set<String> kotlin = _kotlinHandlers(activity, pair.$1);
      expect(dart, isNotEmpty, reason: name);
      expect(
        kotlin.containsAll(dart),
        isTrue,
        reason: '$name: Dart llama ${dart.difference(kotlin)} sin manejador',
      );
    });
  });

  test('la notificación del ayuno usa los mismos nombres de fase que la app', () {
    final Map<String, Object?> arb =
        jsonDecode(File('lib/core/l10n/arb/app_es.arb').readAsStringSync()) as Map<String, Object?>;
    final String notifier = File(
      'android/app/src/main/kotlin/com/nb/selfcare/notifications/FastingNotifier.kt',
    ).readAsStringSync();
    for (final String key in <String>[
      'fastingPhaseAnabolic',
      'fastingPhaseGlycogenolysis',
      'fastingPhaseFatBurning',
      'fastingPhaseKetosis',
      'fastingPhaseAutophagy',
    ]) {
      expect(notifier, contains('"${arb[key]}"'), reason: '$key = ${arb[key]}');
    }
  });

  test('las fronteras de fase coinciden (4 · 12 · 18 · 24 h)', () {
    final String notifier = File(
      'android/app/src/main/kotlin/com/nb/selfcare/notifications/FastingNotifier.kt',
    ).readAsStringSync();
    final String dart = File('lib/core/domain/metabolic_phase.dart').readAsStringSync();
    for (final int h in <int>[4, 12, 18, 24]) {
      expect(notifier, contains('hours < $h'), reason: 'Kotlin $h h');
      expect(dart, contains('($h)'), reason: 'Dart $h h');
    }
  });
}
