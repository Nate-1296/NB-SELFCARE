import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';

/// Identificadores únicos de los widgets modulares del tablero "Hoy".
enum HoyWidgetId {
  nibiCompanion(
    key: 'nibi_companion',
    title: 'Compañero Nibi (IA)',
    defaultSize: HoyWidgetSize.w4x2,
  ),
  nutritionEnergy(
    key: 'nutrition_energy',
    title: 'Objetivos del Día',
    defaultSize: HoyWidgetSize.w4x2,
  ),
  hydration(
    key: 'hydration',
    title: 'Hidratación',
    defaultSize: HoyWidgetSize.w2x2,
  ),
  bodyWeight(
    key: 'body_weight',
    title: 'Peso y Tendencia',
    defaultSize: HoyWidgetSize.w2x2,
  ),
  stepsNeat(
    key: 'steps_neat',
    title: 'Pasos NEAT',
    defaultSize: HoyWidgetSize.w2x2,
  ),
  sleepRecovery(
    key: 'sleep_recovery',
    title: 'Sueño y Descanso',
    defaultSize: HoyWidgetSize.w2x2,
  ),
  workoutRpe(
    key: 'workout_rpe',
    title: 'Entrenamiento',
    defaultSize: HoyWidgetSize.w2x2,
  ),
  fastingMetabolic(
    key: 'fasting_metabolic',
    title: 'Ayuno Intermitente',
    defaultSize: HoyWidgetSize.w2x2,
  ),
  dailyJournal(
    key: 'daily_journal',
    title: 'Diario Personal',
    defaultSize: HoyWidgetSize.w4x4,
  );

  const HoyWidgetId({
    required this.key,
    required this.title,
    required this.defaultSize,
  });

  final String key;
  final String title;
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

/// Controlador reactivo que administra el orden, visibilidad y tamaño (2×2 / 4×2 / 4×4)
/// de los widgets de "Hoy", persistiendo todo localmente en SQLite (`ui_preferences`).
class HoyLayoutController extends Notifier<List<HoyWidgetItemConfig>> {
  static const String _prefKey = 'hoy_bento_layout_v1';
  bool _hydrated = false;
  bool _disposed = false;

  static List<HoyWidgetItemConfig> buildDefaultLayout() {
    return HoyWidgetId.values
        .map(
          (id) => HoyWidgetItemConfig(
            id: id,
            size: id.defaultSize,
            visible: true,
          ),
        )
        .toList(growable: false);
  }

  @override
  List<HoyWidgetItemConfig> build() {
    _hydrated = false;
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    final db = ref.watch(appDatabaseProvider);
    unawaited(_hydrateFromDb(db));
    return buildDefaultLayout();
  }

  Future<void> _hydrateFromDb(AppDatabase db) async {
    try {
      final String? raw = await db.readUiPreference(_prefKey);
      if (_disposed || raw == null || raw.isEmpty || _hydrated) return;

      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return;

      final List<HoyWidgetItemConfig> loaded = <HoyWidgetItemConfig>[];
      final Set<HoyWidgetId> seen = <HoyWidgetId>{};

      for (final Object? entry in decoded) {
        if (entry is Map<String, dynamic>) {
          try {
            final item = HoyWidgetItemConfig.fromJson(entry);
            if (seen.add(item.id)) {
              loaded.add(item);
            }
          } catch (_) {
            // Ignora entradas obsoletas sin romper la configuración del usuario.
          }
        }
      }

      // Garantizar que cualquier nuevo widget del catálogo quede incluido al final
      for (final HoyWidgetId id in HoyWidgetId.values) {
        if (!seen.contains(id)) {
          loaded.add(
            HoyWidgetItemConfig(
              id: id,
              size: id.defaultSize,
              visible: true,
            ),
          );
        }
      }

      if (_disposed || _hydrated) return;
      _hydrated = true;
      state = List<HoyWidgetItemConfig>.unmodifiable(loaded);
    } catch (_) {
      // En caso de base de datos cerrada en desmontaje de test, mantener layout actual.
    }
  }

  Future<void> _persist(List<HoyWidgetItemConfig> next) async {
    _hydrated = true;
    state = List<HoyWidgetItemConfig>.unmodifiable(next);
    try {
      final db = ref.read(appDatabaseProvider);
      final String encoded =
          jsonEncode(next.map((item) => item.toJson()).toList());
      await db.writeUiPreference(_prefKey, encoded);
    } catch (_) {}
  }

  /// Alterna un widget estándar entre cuadrado (2×2) y panorámico (4×2).
  Future<void> toggleSize(HoyWidgetId id) async {
    if (!id.canResize) return;
    final List<HoyWidgetItemConfig> next = state.map((item) {
      if (item.id != id) return item;
      final HoyWidgetSize targetSize = item.size == HoyWidgetSize.w2x2
          ? HoyWidgetSize.w4x2
          : HoyWidgetSize.w2x2;
      return item.copyWith(size: targetSize);
    }).toList();
    await _persist(next);
  }

  /// Muestra u oculta un widget del resumen de "Hoy".
  Future<void> setVisible(HoyWidgetId id, bool visible) async {
    // Evitar que el usuario se quede con 0 widgets visibles por accidente
    if (!visible) {
      final int visibleCount = state.where((w) => w.visible).length;
      if (visibleCount <= 1) return;
    }
    final List<HoyWidgetItemConfig> next = state.map((item) {
      if (item.id != id) return item;
      return item.copyWith(visible: visible);
    }).toList();
    await _persist(next);
  }

  /// Sube el widget una posición respecto al anterior widget visible.
  Future<void> moveUp(HoyWidgetId id) async {
    final List<HoyWidgetItemConfig> list = List<HoyWidgetItemConfig>.of(state);
    final int currentIndex = list.indexWhere((w) => w.id == id);
    if (currentIndex <= 0) return;

    int prevVisibleIndex = -1;
    for (int i = currentIndex - 1; i >= 0; i--) {
      if (list[i].visible) {
        prevVisibleIndex = i;
        break;
      }
    }
    if (prevVisibleIndex < 0) return;

    final HoyWidgetItemConfig item = list.removeAt(currentIndex);
    list.insert(prevVisibleIndex, item);
    await _persist(list);
  }

  /// Baja el widget una posición respecto al siguiente widget visible.
  Future<void> moveDown(HoyWidgetId id) async {
    final List<HoyWidgetItemConfig> list = List<HoyWidgetItemConfig>.of(state);
    final int currentIndex = list.indexWhere((w) => w.id == id);
    if (currentIndex < 0 || currentIndex >= list.length - 1) return;

    int nextVisibleIndex = -1;
    for (int i = currentIndex + 1; i < list.length; i++) {
      if (list[i].visible) {
        nextVisibleIndex = i;
        break;
      }
    }
    if (nextVisibleIndex < 0) return;

    final HoyWidgetItemConfig item = list.removeAt(currentIndex);
    list.insert(nextVisibleIndex, item);
    await _persist(list);
  }

  /// Restaura el orden, visibilidad y tamaños predeterminados del tablero.
  Future<void> resetToDefaults() async {
    await _persist(buildDefaultLayout());
  }
}

final hoyLayoutControllerProvider =
    NotifierProvider<HoyLayoutController, List<HoyWidgetItemConfig>>(
  HoyLayoutController.new,
);
