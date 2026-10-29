import '../../../core/domain/enums.dart';

/// Síntomas frecuentes que se registran con un toque. Lo digestivo tiene su
/// propio registro (escala de Bristol).
abstract final class SymptomCatalog {
  static const List<String> common = <String>[
    'headache',
    'migraine',
    'back_pain',
    'joint_pain',
    'muscle_pain',
    'fatigue',
    'anxiety',
    'low_mood',
    'insomnia',
    'dizziness',
    'nausea',
    'allergy',
    'congestion',
  ];

  /// Con el ciclo activo.
  static const List<String> cycle = <String>['cramps', 'breast_tenderness', 'bloating'];

  /// Perimenopausia y menopausia: a partir de los 40 años.
  static const List<String> menopause = <String>[
    'hot_flashes',
    'night_sweats',
    'brain_fog',
    'vaginal_dryness',
  ];

  static const int perimenopauseFromAge = 40;

  static List<String> forPerson({
    required BiologicalSex sex,
    required int age,
    required bool cycleTracking,
  }) => <String>[
    ...common,
    if (sex == BiologicalSex.female && cycleTracking) ...cycle,
    if (sex == BiologicalSex.female && age >= perimenopauseFromAge) ...menopause,
  ];

  static bool isCatalog(String key) =>
      common.contains(key) || cycle.contains(key) || menopause.contains(key);
}
