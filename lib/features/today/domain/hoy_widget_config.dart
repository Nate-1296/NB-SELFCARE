/// Identificadores únicos de los widgets modulares del tablero "Hoy".
enum HoyWidgetId {
  nibiCompanion(
    key: 'nibi_companion',
    defaultSize: HoyWidgetSize.w4x2,
  ),
  nutritionEnergy(
    key: 'nutrition_energy',
    defaultSize: HoyWidgetSize.w4x2,
  ),
  hydration(
    key: 'hydration',
    defaultSize: HoyWidgetSize.w2x2,
  ),
  bodyWeight(
    key: 'body_weight',
    defaultSize: HoyWidgetSize.w2x2,
  ),
  stepsNeat(
    key: 'steps_neat',
    defaultSize: HoyWidgetSize.w2x2,
  ),
  sleepRecovery(
    key: 'sleep_recovery',
    defaultSize: HoyWidgetSize.w2x2,
  ),
  workoutRpe(
    key: 'workout_rpe',
    defaultSize: HoyWidgetSize.w2x2,
  ),
  fastingMetabolic(
    key: 'fasting_metabolic',
    defaultSize: HoyWidgetSize.w2x2,
  ),
  dailyJournal(
    key: 'daily_journal',
    defaultSize: HoyWidgetSize.w4x4,
  );

  const HoyWidgetId({
    required this.key,
    required this.defaultSize,
  });

  final String key;
  final HoyWidgetSize defaultSize;

  /// Solo el Diario Personal utiliza el formato gigante 4×4; el resto alterna entre 2×2 y 4×2.
  bool get canResize => this != HoyWidgetId.dailyJournal;

  static HoyWidgetId? fromKey(String raw) {
    for (final value in HoyWidgetId.values) {
      if (value.key == raw) return value;
    }
    return null;
  }
}

/// Tamaños disponibles en la cuadrícula Bento de 4 columnas de "Hoy".
enum HoyWidgetSize {
  /// Cuadrado adaptable (ocupa media fila: 2 de 4 columnas).
  w2x2('w2x2', '2×2'),

  /// Tarjeta panorámica (ocupa fila completa: 4 de 4 columnas).
  w4x2('w4x2', '4×2'),

  /// Bloque gigante exclusivo del Diario Personal (4×4).
  w4x4('w4x4', '4×4');

  const HoyWidgetSize(this.storageKey, this.label);

  final String storageKey;
  final String label;

  bool get isHalfWidth => this == HoyWidgetSize.w2x2;

  static HoyWidgetSize fromStorage(String? raw, HoyWidgetId widgetId) {
    if (widgetId == HoyWidgetId.dailyJournal) {
      return HoyWidgetSize.w4x4;
    }
    if (raw == HoyWidgetSize.w4x2.storageKey) {
      return HoyWidgetSize.w4x2;
    }
    if (raw == HoyWidgetSize.w2x2.storageKey) {
      return HoyWidgetSize.w2x2;
    }
    return widgetId.defaultSize;
  }
}

/// Estado persistible de un widget individual dentro de la vista "Hoy".
class HoyWidgetItemConfig {
  const HoyWidgetItemConfig({
    required this.id,
    required this.size,
    required this.visible,
  });

  factory HoyWidgetItemConfig.fromJson(Map<String, dynamic> json) {
    final String rawId = json['id'] as String? ?? '';
    final HoyWidgetId? parsedId = HoyWidgetId.fromKey(rawId);
    if (parsedId == null) {
      throw const FormatException('Widget ID desconocido');
    }
    final HoyWidgetSize resolvedSize = HoyWidgetSize.fromStorage(
      json['size'] as String?,
      parsedId,
    );
    final bool isVisible = json['visible'] as bool? ?? true;
    return HoyWidgetItemConfig(
      id: parsedId,
      size: resolvedSize,
      visible: isVisible,
    );
  }

  final HoyWidgetId id;
  final HoyWidgetSize size;
  final bool visible;

  HoyWidgetItemConfig copyWith({
    HoyWidgetSize? size,
    bool? visible,
  }) {
    final HoyWidgetSize enforcedSize = id == HoyWidgetId.dailyJournal
        ? HoyWidgetSize.w4x4
        : (size ?? this.size);
    return HoyWidgetItemConfig(
      id: id,
      size: enforcedSize,
      visible: visible ?? this.visible,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id.key,
        'size': size.storageKey,
        'visible': visible,
      };
}
