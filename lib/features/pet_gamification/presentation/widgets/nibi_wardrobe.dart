import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_tokens.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/pressable.dart';
import '../../application/nibi_overview.dart';
import '../../domain/pet_catalog.dart';
import '../nibi/habitat_painter.dart';
import '../nibi/nibi_view.dart';
import '../pet_l10n.dart';

/// Armario: solo lo que Nibi ya tiene (sombreros, accesorios, colores y
/// escenarios), con su vista previa real. Si en una fila aún no hay nada
/// comprado, un acceso a la tienda ocupa su lugar.
class NibiWardrobe extends StatelessWidget {
  const NibiWardrobe({
    super.key,
    required this.overview,
    required this.onEquip,
    required this.onUnequip,
    required this.onShop,
  });

  final NibiOverview overview;
  final ValueChanged<PetItem> onEquip;

  /// Quitar el sombrero o el accesorio.
  final ValueChanged<PetItemKind> onUnequip;
  final VoidCallback onShop;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final NibiLook look = overview.look;
    List<PetItem> owned(PetItemKind kind) => PetCatalog.ofKind(kind).where(overview.owns).toList();

    Widget row(String title, List<Widget> tiles, {required bool nothingBought}) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: context.type.label),
            const SizedBox(height: ScSpace.s),
            // Fila desplazable que toma el alto de su contenido (crece con el
            // tamaño de letra del sistema en vez de desbordar).
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    ...tiles,
                    if (nothingBought)
                      _Tile(
                        label: l10n.nibiMoreInShop,
                        selected: false,
                        preview: const _ShopThumb(),
                        onTap: onShop,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: ScSpace.l),
          ],
        );

    Widget tile(PetItem item, Widget preview) => _Tile(
          label: item.title(l10n),
          selected: overview.isEquipped(item),
          preview: preview,
          onTap: () => onEquip(item),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        row(l10n.nibiHats, <Widget>[
          _Tile(
            label: l10n.nibiNoHat,
            selected: look.hatId == null,
            preview: NibiAvatar(size: 64, look: NibiLook(colorId: look.colorId)),
            onTap: () => onUnequip(PetItemKind.hat),
          ),
          for (final PetItem hat in owned(PetItemKind.hat))
            tile(hat, NibiAvatar(size: 64, look: NibiLook(hatId: hat.id, colorId: look.colorId))),
        ], nothingBought: owned(PetItemKind.hat).isEmpty),
        row(l10n.nibiAccessories, <Widget>[
          _Tile(
            label: l10n.nibiNoAccessory,
            selected: look.accessoryId == null,
            preview: NibiAvatar(size: 64, look: NibiLook(colorId: look.colorId)),
            onTap: () => onUnequip(PetItemKind.accessory),
          ),
          for (final PetItem acc in owned(PetItemKind.accessory))
            tile(acc, NibiAvatar(size: 64, look: NibiLook(accessoryId: acc.id, colorId: look.colorId))),
        ], nothingBought: owned(PetItemKind.accessory).isEmpty),
        row(l10n.nibiColors, <Widget>[
          for (final PetItem color in owned(PetItemKind.color))
            tile(color, NibiAvatar(size: 64, look: NibiLook(colorId: color.id))),
        ], nothingBought: owned(PetItemKind.color).length <= 1),
        row(l10n.nibiHabitats, <Widget>[
          for (final PetItem habitat in owned(PetItemKind.habitat)) tile(habitat, HabitatThumb(id: habitat.id)),
        ], nothingBought: owned(PetItemKind.habitat).length <= 1),
      ],
    );
  }
}

/// Escenario en miniatura (armario y tienda).
class HabitatThumb extends StatelessWidget {
  const HabitatThumb({super.key, required this.id, this.width = 84, this.height = 64});

  final String id;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return ClipRRect(
      borderRadius: BorderRadius.circular(ScRadius.controlOf(c)),
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(painter: HabitatPainter(habitatId: id, colors: c)),
      ),
    );
  }
}

class _ShopThumb extends StatelessWidget {
  const _ShopThumb();

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.isFlat ? c.bg2 : c.warning.withValues(alpha: 0.14),
        border: Border.all(color: c.isFlat ? c.line2 : c.warning.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Icon(AppIcons.tienda, size: 28, color: c.isFlat ? c.text : c.warning),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.selected,
    required this.preview,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Widget preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(right: ScSpace.s),
      child: Semantics(
        selected: selected,
        button: true,
        label: label,
        excludeSemantics: true,
        child: Pressable(
          child: Material(
            color: c.isFlat ? c.bg2 : c.bg3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ScRadius.tileOf(c)),
              side: BorderSide(
                color: selected ? (c.isFlat ? c.text : c.accent) : (c.isFlat ? c.line2 : Colors.transparent),
                width: selected ? 2 : 1.5,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                width: 108,
                child: Padding(
                  padding: const EdgeInsets.all(ScSpace.s),
                  child: Column(
                    children: <Widget>[
                      SizedBox(height: 64, child: Center(child: preview)),
                      const SizedBox(height: ScSpace.s),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.type.caption.copyWith(color: c.text, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        selected ? l10n.nibiEquipped : ' ',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.type.caption.copyWith(
                          fontSize: 11,
                          color: c.isFlat ? c.text : c.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
