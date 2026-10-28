import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Senior QA Audit: Architectural Invariants & Guardrails (AGENTS.md)', () {
    final Directory libDir = Directory('lib');
    final List<File> dartFiles = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'))
        .toList();

    test('Guardrail 1: 100% Offline-First - No telemetry or remote cloud SDK imports', () {
      final List<String> forbiddenPackages = <String>[
        'firebase',
        'supabase',
        'sentry',
        'google_analytics',
        'crashlytics',
      ];

      final List<String> violations = <String>[];

      for (final File file in dartFiles) {
        final List<String> lines = file.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          final String line = lines[i];
          if (line.trim().startsWith('import ') || line.trim().startsWith('export ')) {
            for (final String forbidden in forbiddenPackages) {
              if (line.toLowerCase().contains(forbidden)) {
                violations.add('${file.path}:${i + 1} -> $line');
              }
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Forbidden cloud/telemetry package imports found in lib/:\n${violations.join('\n')}',
      );
    });

    test('Guardrail 1b: Offline HTTP Isolation - HTTP client strictly confined to Open Food Facts', () {
      final List<String> violations = <String>[];

      for (final File file in dartFiles) {
        // Only open_food_facts_service.dart is authorized to perform external HTTP requests
        if (file.path.endsWith('open_food_facts_service.dart')) {
          continue;
        }

        final List<String> lines = file.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          final String line = lines[i].trim();
          if (line.startsWith('import ') && (line.contains('package:http/') || line.contains('package:dio/'))) {
            violations.add('${file.path}:${i + 1} -> $line');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Unauthorized HTTP client imports outside OpenFoodFactsService:\n${violations.join('\n')}',
      );
    });

    test('Guardrail 2: Zero Placeholders - No TODO, FIXME, or truncated code comments in lib/', () {
      final RegExp placeholderRegex = RegExp(r'\b(TODO|FIXME|HACK)\b', caseSensitive: true);
      final List<String> violations = <String>[];

      for (final File file in dartFiles) {
        final List<String> lines = file.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          final String line = lines[i];
          if (placeholderRegex.hasMatch(line)) {
            violations.add('${file.path}:${i + 1} -> $line');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Found TODO/FIXME/HACK placeholders in production codebase:\n${violations.join('\n')}',
      );
    });

    test('Guardrail 4: Android allowBackup="false" enforced in AndroidManifest.xml', () {
      final File manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue, reason: 'AndroidManifest.xml must exist');

      final String content = manifestFile.readAsStringSync();
      expect(
        content.contains('android:allowBackup="false"'),
        isTrue,
        reason: 'AndroidManifest.xml must explicitly contain android:allowBackup="false" to prevent data leaks',
      );
    });

    test('Guardrail 6: Radical Positivity - Nibi Virtual Pet never dies, gets sick or blames user', () {
      final Directory petDir = Directory('lib/features/pet_gamification');
      expect(petDir.existsSync(), isTrue);

      final List<File> petFiles = petDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((File f) => f.path.endsWith('.dart'))
          .toList();

      final List<String> forbiddenConcepts = <String>[
        'muere',
        'muerto',
        'muerte',
        'enfermo',
        'enfermedad',
        'culpa',
        'castigo',
        'fracaso',
        'penalización',
      ];

      for (final File file in petFiles) {
        final String petContent = file.readAsStringSync().toLowerCase();
        for (final String concept in forbiddenConcepts) {
          expect(
            petContent.contains(concept),
            isFalse,
            reason: 'Pet logic in ${file.path} violates radical positivity by referencing concept: "$concept"',
          );
        }
      }
    });

    test('Guardrail 3: Zero untyped dynamic in core DAOs and Mathematical Utilities', () {
      final Directory coreDir = Directory('lib/core');
      final Directory sharedDir = Directory('lib/shared');
      final List<File> sensitiveFiles = <File>[
        ...coreDir.listSync(recursive: true).whereType<File>(),
        ...sharedDir.listSync(recursive: true).whereType<File>(),
      ].where((File f) => f.path.endsWith('.dart') && !f.path.contains('.g.dart')).toList();

      final RegExp dynamicParamOrReturn = RegExp(r'\b(dynamic)\s+[a-zA-Z0-9_]+\s*(\(|=>|\{|=)');
      final List<String> warnings = <String>[];

      for (final File file in sensitiveFiles) {
        // Skip JSON parsing in OpenFoodFactsService if properly handled
        if (file.path.endsWith('open_food_facts_service.dart')) continue;

        final List<String> lines = file.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          final String line = lines[i];
          if (line.trim().startsWith('//')) continue;
          if (dynamicParamOrReturn.hasMatch(line)) {
            warnings.add('${file.path}:${i + 1} -> $line');
          }
        }
      }

      expect(
        warnings,
        isEmpty,
        reason: 'Found explicit untyped "dynamic" declarations in core/shared logic:\n${warnings.join('\n')}',
      );
    });

    test('Guardrail 7: La hora actual solo se obtiene a través de core/clock', () {
      const Set<String> allowed = <String>{'lib/core/clock/clock.dart'};
      final List<String> violations = <String>[];
      for (final File file in dartFiles) {
        final String path = file.path.replaceAll(r'\\', '/');
        if (allowed.contains(path) || path.endsWith('.g.dart')) continue;
        final List<String> lines = file.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          final String line = lines[i].trim();
          if (line.startsWith('//')) continue;
          if (line.contains('DateTime.now()')) violations.add('$path:${i + 1} -> $line');
        }
      }
      expect(
        violations,
        isEmpty,
        reason: 'Usa clockProvider / Clock en lugar de DateTime.now():\n${violations.join('\n')}',
      );
    });

    test('Guardrail 8: La UI no salta los casos de uso en escrituras con reglas de negocio', () {
      // Recompensas, cascada biométrica, registro de comida/agua/diario/ayuno y TDEE
      // pasan siempre por features/*/application (docs/02 §1).
      const List<String> forbiddenCalls = <String>[
        '.recordReward(',
        '.insertMeasurement(',
        '.saveNavyTapeMeasurement(',
        '.logFoodItemPortion(',
        '.logCombo(',
        '.repeatMealFromYesterday(',
        '.insertGlass(',
        '.insertEntry(',
        '.insertWorkout(',
        '.startFast(',
        '.endFast(',
        '.calibrateFromLast14Days(',
        '.upsertDailySummary(',
        '.generateMilestones(',
      ];
      final List<String> violations = <String>[];
      for (final File file in dartFiles) {
        final String path = file.path.replaceAll(r'\\', '/');
        if (!path.contains('/presentation/') && !path.startsWith('lib/shared/')) continue;
        final List<String> lines = file.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          // La llamada puede ir en la línea siguiente al `ref.read(xServiceProvider)`
          // cuando el formateador parte la cadena de métodos.
          final int from = i >= 2 ? i - 2 : 0;
          if (lines.sublist(from, i + 1).any((String l) => l.contains('ServiceProvider)'))) continue;
          for (final String call in forbiddenCalls) {
            if (lines[i].contains(call)) violations.add('$path:${i + 1} -> ${lines[i].trim()}');
          }
        }
      }
      expect(
        violations,
        isEmpty,
        reason: 'Usa el servicio de application/ correspondiente:\n${violations.join('\n')}',
      );
    });

    test('Guardrail 9: core/ y shared/ no dependen de features/', () {
      final List<String> violations = <String>[];
      for (final File file in dartFiles) {
        final String path = file.path.replaceAll(r'\\', '/');
        if (!path.startsWith('lib/core/') && !path.startsWith('lib/shared/')) continue;
        if (path.endsWith('.g.dart')) continue;
        final List<String> lines = file.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          final String line = lines[i].trim();
          if (line.startsWith('import ') && line.contains('features/')) {
            violations.add('$path:${i + 1} -> $line');
          }
        }
      }
      expect(violations, isEmpty, reason: violations.join('\n'));
    });

    test('Guardrail 10: la presentación lee y escribe por application/, nunca por DAOs', () {
      final List<String> violations = <String>[];
      for (final File file in dartFiles) {
        final String path = file.path.replaceAll(r'\\', '/');
        if (!path.contains('/presentation/')) continue;
        final List<String> lines = file.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          final String line = lines[i].trim();
          if (line.startsWith('import ') && line.contains('core/database/daos/')) {
            violations.add('$path:${i + 1} -> $line');
          }
        }
      }
      expect(violations, isEmpty, reason: violations.join('\n'));
    });
  });
}
