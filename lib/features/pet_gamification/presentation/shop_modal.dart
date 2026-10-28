import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../shared/theme/sc_colors.dart';
import '../../../shared/theme/sc_tokens.dart';
import '../../../shared/utils/number_formats.dart';
import '../../../shared/widgets/app_icons.dart';
import '../../../shared/widgets/metric_value.dart';
import '../../../shared/widgets/quick_action_button.dart';
import '../../../shared/widgets/sheet.dart';
import '../application/nibi_overview.dart';
import '../application/pet_service.dart';
import '../domain/pet_catalog.dart';
import 'nibi/nibi_view.dart';
import 'pet_l10n.dart';
import 'widgets/nibi_wardrobe.dart';

/// Tienda de Nibi: escudos de racha y cosméticos del [PetCatalog]. Solo
/// muestra lo que aún está a la venta (lo comprado pasa al armario) y lo
/// recién comprado se pone al momento.
class ShopModal extends ConsumerWidget {
  const ShopModal({super.key});

  static Future<void> show(BuildContext context) =>
      mostrarHojaMenu<void>(context, builder: (_) => const ShopModal());

  Future<void> _buy(BuildContext context, WidgetRef ref, PetItem item, NibiOverview data) async {
    final AppLocalizations l10n = context.l10n;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final PurchaseOutcome outcome = await ref.read(petServiceProvider).buy(item);
    unawaited(HapticFeedback.mediumImpact());
    final String? message = switch (outcome) {
      PurchaseOutcome.purchased when item.isConsumable => l10n.shopBought(item.title(l10n)),
      PurchaseOutcome.purchased => l10n.shopBoughtEquipped(item.title(l10n)),
      PurchaseOutcome.notEnoughCoins => l10n.shopNotEnough('${item.cost - data.pet.coinsBalance}'),
      PurchaseOutcome.alreadyOwned || PurchaseOutcome.unavailable => null,
    };
    if (message != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final NibiOverview? data = ref.watch(nibiOverviewProvider).value;
    if (data == null) {
      return const Padding(padding: EdgeInsets.all(ScSpace.xxl), child: Center(child: CircularProgressIndicator()));
    }

    Widget section(String title, PetItemKind kind, {String? hint}) {
      final List<PetItem> forSale = PetCatalog.ofKind(kind)
          .where((PetItem i) => i.cost > 0 && (i.isConsumable || !data.owns(i)))
          .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: ScSpace.l),
          Text(title, style: context.text.titleLarge),
          if (hint != null) Text(hint, style: context.type.caption),
          const SizedBox(height: ScSpace.s),
          if (forSale.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: ScSpace.s),
              child: Text(l10n.shopAllOwned, style: context.type.caption.copyWith(color: c.text2)),
            ),
          for (final PetItem item in forSale)
            _ShopRow(
              item: item,
              colorId: data.look.colorId,
              affordable: data.pet.coinsBalance >= item.cost,
              onBuy: () => unawaited(_buy(context, ref, item, data)),
            ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(ScSpace.gutter + 4, 0, ScSpace.gutter + 4, ScSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(AppIcons.tienda, color: c.isFlat ? c.text : c.warning),
              const SizedBox(width: ScSpace.s),
              Expanded(child: Text(l10n.shopTitle, style: context.text.headlineSmall)),
              Icon(AppIcons.moneda, size: 20, color: c.isFlat ? c.text : c.warning),
              const SizedBox(width: ScSpace.xs),
              MetricValue(value: NumberFormats.integer(data.pet.coinsBalance, l10n.localeName), size: 20),
            ],
          ),
          section(l10n.shopShieldsTitle, PetItemKind.shield, hint: l10n.shopShieldsHint),
          section(l10n.shopHatsTitle, PetItemKind.hat),
          section(l10n.shopAccessoriesTitle, PetItemKind.accessory),
          section(l10n.shopColorsTitle, PetItemKind.color, hint: l10n.shopColorsHint),
          section(l10n.shopHabitatsTitle, PetItemKind.habitat),
        ],
      ),
    );
  }
}

class _ShopRow extends StatelessWidget {
  const _ShopRow({
    required this.item,
    required this.colorId,
    required this.affordable,
    required this.onBuy,
  });

  final PetItem item;

  /// Color actual de Nibi, para ver cómo le quedaría el sombrero o el accesorio.
  final String colorId;
  final bool affordable;
  final VoidCallback onBuy;

  Widget _preview(ScColors c) => switch (item.kind) {
        PetItemKind.hat => NibiAvatar(size: 52, look: NibiLook(hatId: item.id, colorId: colorId)),
        PetItemKind.accessory => NibiAvatar(size: 52, look: NibiLook(accessoryId: item.id, colorId: colorId)),
        PetItemKind.color => NibiAvatar(size: 52, look: NibiLook(colorId: item.id)),
        PetItemKind.habitat => HabitatThumb(id: item.id, width: 52, height: 52),
        PetItemKind.shield => Icon(AppIcons.escudo, size: 30, color: c.isFlat ? c.text : c.success),
      };

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ScSpace.xs + 2),
      child: Row(
        children: <Widget>[
          SizedBox(width: 56, child: Center(child: _preview(c))),
          const SizedBox(width: ScSpace.m),
          Expanded(child: Text(item.title(l10n), style: context.type.label)),
          const SizedBox(width: ScSpace.s),
          Flexible(
            child: QuickActionButton(
              label: NumberFormats.integer(item.cost, l10n.localeName),
              icon: AppIcons.moneda,
              tone: c.warning,
              emphasized: affordable,
              expand: false,
              onPressed: onBuy,
            ),
          ),
        ],
      ),
    );
  }
}
