import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/pet_dao.dart';
import '../../../shared/utils/date_time_extensions.dart';
import '../../../shared/widgets/health_card.dart';

/// Modal de la Tienda de Recompensas y Personalización de Nibi.
class ShopModal extends ConsumerWidget {
  const ShopModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const ShopModal(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<PetStatusData?> petAsync = ref.watch(petStatusStreamProvider);
    final petDao = ref.watch(petDaoProvider);

    return petAsync.when(
      data: (pet) {
        if (pet == null) {
          return const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(child: Text('Cargando tienda...')),
          );
        }

        final int coins = pet.coinsBalance;
        final List<dynamic> unlocked =
            jsonDecode(pet.unlockedItemsJson) as List<dynamic>;

        return Padding(
          padding: EdgeInsets.only(
            left: 20.0,
            right: 20.0,
            top: 20.0,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
          ),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.75,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.storefront_rounded, color: Colors.amber, size: 28),
                        const SizedBox(width: 8.0),
                        Text(
                          'Tienda de Recompensas',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.monetization_on, color: Colors.amber, size: 20),
                        const SizedBox(width: 4.0),
                        Text(
                          '$coins',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(width: 8.0),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                Text(
                  'Gasta tus monedas ganadas con hábitos positivos. Cero compras con dinero real.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 16.0),

                // Lista de Artículos
                Expanded(
                  child: ListView(
                    children: [
                      // Categoría Cuidados y Alimentos
                      Text(
                        'Alimentos y Cuidados para tu Compañero',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      _ShopItemTile(
                        title: 'Manzana Crujiente 🍎',
                        description: 'Un delicioso snack saludable que alegra a tu mascota.',
                        cost: 10,
                        currentCoins: coins,
                        icon: Icons.apple_rounded,
                        iconColor: Colors.redAccent,
                        onBuy: () async {
                          final ok = await petDao.buyShopItem(
                            itemId: 'snack_apple',
                            cost: 10,
                            dateKey: DateTime.now().dateKey,
                            isConsumable: true,
                          );
                          if (context.mounted && ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('¡Le diste una rica manzana a tu mascota! 🍎✨')),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 8.0),
                      _ShopItemTile(
                        title: 'Agua de Manantial 💧',
                        description: 'Hidratación pura para compartir hábitos saludables.',
                        cost: 10,
                        currentCoins: coins,
                        icon: Icons.water_drop_rounded,
                        iconColor: Colors.blueAccent,
                        onBuy: () async {
                          final ok = await petDao.buyShopItem(
                            itemId: 'item_water',
                            cost: 10,
                            dateKey: DateTime.now().dateKey,
                            isConsumable: true,
                          );
                          if (context.mounted && ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('¡Tu compañero bebió agua fresca con alegría! 💧')),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 16.0),

                      // Categoría Escudos
                      Text(
                        'Escudos de Racha (Protección para vacaciones)',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      _ShopItemTile(
                        title: 'Escudo Diario de Racha',
                        description: 'Protege tu racha si olvidas registrarte 1 día.',
                        cost: 25,
                        currentCoins: coins,
                        icon: Icons.shield,
                        iconColor: Colors.blueAccent,
                        onBuy: () async {
                          final ok = await petDao.buyShopItem(
                            itemId: 'shield_daily',
                            cost: 25,
                            dateKey: DateTime.now().dateKey,
                            isConsumable: true,
                            shieldsToAdd: 1,
                          );
                          if (context.mounted && ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('¡Escudo de Racha adquirido (+1)!')),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 16.0),

                      // Categoría Accesorios de Nibi
                      Text(
                        'Accesorios y Sombreros',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      _AccessoryTile(
                        id: 'hat_chef',
                        title: 'Gorro de Chef Saludable 👨‍🍳',
                        cost: 30,
                        currentCoins: coins,
                        isUnlocked: unlocked.contains('hat_chef'),
                        isEquipped: pet.equippedHatId == 'hat_chef',
                        onBuy: () async {
                          final ok = await petDao.buyShopItem(
                            itemId: 'hat_chef',
                            cost: 30,
                            dateKey: DateTime.now().dateKey,
                          );
                          if (!context.mounted) return;
                          if (ok) {
                            await petDao.equipItem(hatId: 'hat_chef');
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('¡Gorro de Chef comprado y equipado!')),
                            );
                          }
                        },
                        onEquip: () => petDao.equipItem(hatId: 'hat_chef'),
                        onUnequip: () => petDao.equipItem(hatId: null),
                      ),
                      const SizedBox(height: 8.0),
                      _AccessoryTile(
                        id: 'hat_headband',
                        title: 'Vincha de Entrenamiento 🏃',
                        cost: 35,
                        currentCoins: coins,
                        isUnlocked: unlocked.contains('hat_headband'),
                        isEquipped: pet.equippedHatId == 'hat_headband',
                        onBuy: () async {
                          final ok = await petDao.buyShopItem(
                            itemId: 'hat_headband',
                            cost: 35,
                            dateKey: DateTime.now().dateKey,
                          );
                          if (!context.mounted) return;
                          if (ok) {
                            await petDao.equipItem(hatId: 'hat_headband');
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('¡Vincha de Entrenamiento comprada y equipada!')),
                            );
                          }
                        },
                        onEquip: () => petDao.equipItem(hatId: 'hat_headband'),
                        onUnequip: () => petDao.equipItem(hatId: null),
                      ),
                      const SizedBox(height: 8.0),
                      _AccessoryTile(
                        id: 'hat_zen_halo',
                        title: 'Halo Zen Dorado ✨',
                        cost: 45,
                        currentCoins: coins,
                        isUnlocked: unlocked.contains('hat_zen_halo'),
                        isEquipped: pet.equippedHatId == 'hat_zen_halo',
                        onBuy: () async {
                          final ok = await petDao.buyShopItem(
                            itemId: 'hat_zen_halo',
                            cost: 45,
                            dateKey: DateTime.now().dateKey,
                          );
                          if (!context.mounted) return;
                          if (ok) {
                            await petDao.equipItem(hatId: 'hat_zen_halo');
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('¡Halo Zen Dorado comprado y equipado!')),
                            );
                          }
                        },
                        onEquip: () => petDao.equipItem(hatId: 'hat_zen_halo'),
                        onUnequip: () => petDao.equipItem(hatId: null),
                      ),
                      const SizedBox(height: 8.0),
                      _AccessoryTile(
                        id: 'hat_crown',
                        title: 'Corona Real de Autocuidado 👑',
                        cost: 60,
                        currentCoins: coins,
                        isUnlocked: unlocked.contains('hat_crown'),
                        isEquipped: pet.equippedHatId == 'hat_crown',
                        onBuy: () async {
                          final ok = await petDao.buyShopItem(
                            itemId: 'hat_crown',
                            cost: 60,
                            dateKey: DateTime.now().dateKey,
                          );
                          if (!context.mounted) return;
                          if (ok) {
                            await petDao.equipItem(hatId: 'hat_crown');
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('¡Corona Real comprada y equipada!')),
                            );
                          }
                        },
                        onEquip: () => petDao.equipItem(hatId: 'hat_crown'),
                        onUnequip: () => petDao.equipItem(hatId: null),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _ShopItemTile extends StatelessWidget {
  const _ShopItemTile({
    required this.title,
    required this.description,
    required this.cost,
    required this.currentCoins,
    required this.icon,
    required this.iconColor,
    required this.onBuy,
  });

  final String title;
  final String description;
  final int cost;
  final int currentCoins;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final bool canAfford = currentCoins >= cost;

    return HealthCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 32),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2.0),
                Text(description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(width: 8.0),
          FilledButton.tonal(
            onPressed: canAfford ? onBuy : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on, size: 16, color: Colors.amber),
                const SizedBox(width: 4.0),
                Text('$cost'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessoryTile extends StatelessWidget {
  const _AccessoryTile({
    required this.id,
    required this.title,
    required this.cost,
    required this.currentCoins,
    required this.isUnlocked,
    required this.isEquipped,
    required this.onBuy,
    required this.onEquip,
    required this.onUnequip,
  });

  final String id;
  final String title;
  final int cost;
  final int currentCoins;
  final bool isUnlocked;
  final bool isEquipped;
  final VoidCallback onBuy;
  final VoidCallback onEquip;
  final VoidCallback onUnequip;

  @override
  Widget build(BuildContext context) {
    return HealthCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          Icon(
            isEquipped ? Icons.check_circle : (isUnlocked ? Icons.lock_open : Icons.lock_outline),
            color: isEquipped ? Colors.teal : (isUnlocked ? Colors.blue : Colors.grey),
            size: 28,
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          if (!isUnlocked)
            FilledButton.tonal(
              onPressed: currentCoins >= cost ? onBuy : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.monetization_on, size: 16, color: Colors.amber),
                  const SizedBox(width: 4.0),
                  Text('$cost'),
                ],
              ),
            )
          else if (isEquipped)
            OutlinedButton(
              onPressed: onUnequip,
              child: const Text('Quitar'),
            )
          else
            FilledButton(
              onPressed: onEquip,
              child: const Text('Equipar'),
            ),
        ],
      ),
    );
  }
}
