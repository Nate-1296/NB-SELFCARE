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
  });
}
