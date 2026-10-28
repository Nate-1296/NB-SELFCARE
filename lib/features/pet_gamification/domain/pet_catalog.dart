/// Tipos de artículo de la tienda de Nibi.
enum PetItemKind { hat, accessory, color, habitat, shield }

/// Artículo del catálogo. Los nombres visibles viven en el ARB (`petItem_<id>`).
class PetItem {
  const PetItem({
    required this.id,
    required this.kind,
    required this.cost,
    this.shields = 0,
  });

  final String id;
  final PetItemKind kind;
  final int cost;

  /// Escudos de racha que añade (solo [PetItemKind.shield]).
  final int shields;

  /// Los escudos se gastan; lo demás (cosméticos) se queda para siempre.
  bool get isConsumable => kind == PetItemKind.shield;

  /// Lo que se pone Nibi (sombrero, accesorio, color o escenario).
  bool get isCosmetic => !isConsumable;
}

/// Lo que Nibi lleva puesto: sombrero, accesorio y color.
class NibiLook {
  const NibiLook({this.hatId, this.accessoryId, this.colorId = PetCatalog.defaultColor});

  final String? hatId;
  final String? accessoryId;
  final String colorId;

  NibiLook copyWith({String? hatId, String? accessoryId, String? colorId}) => NibiLook(
        hatId: hatId ?? this.hatId,
        accessoryId: accessoryId ?? this.accessoryId,
        colorId: colorId ?? this.colorId,
      );

  @override
  bool operator ==(Object other) =>
      other is NibiLook && other.hatId == hatId && other.accessoryId == accessoryId && other.colorId == colorId;

  @override
  int get hashCode => Object.hash(hatId, accessoryId, colorId);
}

/// Catálogo único de la tienda, el armario, el avatar y el servicio.
abstract final class PetCatalog {
  static const String defaultHabitat = 'bg_default_room';
  static const String defaultColor = 'color_jade';

  /// Lo que se tiene desde el principio (gratis, no aparece en la tienda).
  static const Set<String> starterItems = <String>{defaultHabitat, defaultColor};

  static const List<PetItem> items = <PetItem>[
    PetItem(id: 'shield_daily', kind: PetItemKind.shield, cost: 25, shields: 1),
    PetItem(id: 'shield_weekend', kind: PetItemKind.shield, cost: 65, shields: 3),
    PetItem(id: 'hat_party', kind: PetItemKind.hat, cost: 25),
    PetItem(id: 'hat_chef', kind: PetItemKind.hat, cost: 30),
    PetItem(id: 'hat_beanie', kind: PetItemKind.hat, cost: 30),
    PetItem(id: 'hat_cap', kind: PetItemKind.hat, cost: 35),
    PetItem(id: 'hat_headband', kind: PetItemKind.hat, cost: 35),
    PetItem(id: 'hat_flowers', kind: PetItemKind.hat, cost: 40),
    PetItem(id: 'hat_zen_halo', kind: PetItemKind.hat, cost: 45),
    PetItem(id: 'hat_crown', kind: PetItemKind.hat, cost: 60),
    PetItem(id: 'hat_wizard', kind: PetItemKind.hat, cost: 70),
    PetItem(id: 'acc_bowtie', kind: PetItemKind.accessory, cost: 25),
    PetItem(id: 'acc_scarf', kind: PetItemKind.accessory, cost: 30),
    PetItem(id: 'acc_bell', kind: PetItemKind.accessory, cost: 30),
    PetItem(id: 'acc_glasses', kind: PetItemKind.accessory, cost: 35),
    PetItem(id: 'acc_sunglasses', kind: PetItemKind.accessory, cost: 45),
    PetItem(id: defaultColor, kind: PetItemKind.color, cost: 0),
    PetItem(id: 'color_ocean', kind: PetItemKind.color, cost: 50),
    PetItem(id: 'color_lilac', kind: PetItemKind.color, cost: 50),
    PetItem(id: 'color_coral', kind: PetItemKind.color, cost: 55),
    PetItem(id: 'color_ember', kind: PetItemKind.color, cost: 60),
    PetItem(id: 'color_midnight', kind: PetItemKind.color, cost: 80),
    PetItem(id: 'color_gold', kind: PetItemKind.color, cost: 90),
    PetItem(id: defaultHabitat, kind: PetItemKind.habitat, cost: 0),
    PetItem(id: 'bg_zen_garden', kind: PetItemKind.habitat, cost: 40),
    PetItem(id: 'bg_beach', kind: PetItemKind.habitat, cost: 45),
    PetItem(id: 'bg_forest', kind: PetItemKind.habitat, cost: 45),
    PetItem(id: 'bg_mountain_dawn', kind: PetItemKind.habitat, cost: 50),
    PetItem(id: 'bg_snow', kind: PetItemKind.habitat, cost: 50),
    PetItem(id: 'bg_starry_dojo', kind: PetItemKind.habitat, cost: 55),
    PetItem(id: 'bg_sakura', kind: PetItemKind.habitat, cost: 60),
    PetItem(id: 'bg_space', kind: PetItemKind.habitat, cost: 75),
  ];

  static Iterable<PetItem> ofKind(PetItemKind kind) => items.where((PetItem i) => i.kind == kind);

  static PetItem? byId(String? id) {
    for (final PetItem i in items) {
      if (i.id == id) return i;
    }
    return null;
  }

  /// Id válido del tipo pedido, o `null` si no existe en el catálogo (datos
  /// viejos o corruptos no deben romper el dibujo).
  static String? validId(String? id, PetItemKind kind) {
    final PetItem? item = byId(id);
    return item != null && item.kind == kind ? item.id : null;
  }
}
