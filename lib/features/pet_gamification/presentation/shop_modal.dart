import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/pet_dao.dart';
import '../../../shared/theme/sc_colors.dart';
import '../../../shared/theme/sc_theme.dart';
import '../../../shared/utils/date_time_extensions.dart';
import '../../../shared/widgets/app_icons.dart';
import '../../../shared/widgets/health_card.dart';

/// Modal de la Tienda de Recompensas y Personalización de Nibi.
class ShopModal extends ConsumerWidget {
  const ShopModal({super.key});

  static Future<void> show(BuildContext context) {
    final ScColors c = context.sc;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.bg2,
      elevation: 0,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(
          color: c.isFlat ? c.line2 : c.line,
          width: c.isFlat ? 1.5 : 1.0,
        ),
      ),
      builder: (_) => const ShopModal(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final ThemeData theme = Theme.of(context);
    final AsyncValue<PetStatusData?> petAsync =
        ref.watch(petStatusStreamProvider);
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
        final List<String> unlocked =
            (jsonDecode(pet.unlockedItemsJson) as List<dynamic>)
                .map((e) => e.toString())
                .toList();

        return Padding(
          padding: EdgeInsets.only(
            left: 20.0,
            right: 20.0,
            top: 20.0,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
          ),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.78,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(AppIcons.tienda, color: c.warning, size: 26),
                        const SizedBox(width: 8.0),
                        Text(
                          'Tienda de Recompensas',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontFamily: ScFonts.display,
                            fontWeight: FontWeight.bold,
                            color: c.text,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(AppIcons.moneda, color: c.warning, size: 20),
                        const SizedBox(width: 4.0),
                        Text(
                          '$coins',
                          style: TextStyle(
                            fontFamily: ScFonts.display,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: c.text,
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        IconButton(
                          icon: Icon(AppIcons.close, color: c.text2),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6.0),
                Text(
                  'Canjea tus monedas ganadas con hábitos reales. 100% libre de micropagos.',
                  style: TextStyle(fontSize: 12.5, color: c.text2),
                ),
                const SizedBox(height: 16.0),
                Expanded(
                  child: ListView(
                    children: [
                      // 1. Escudos de Racha
                      Text(
                        'Escudos de Racha (Protección y descanso)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          color: c.water,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      _ShopItemTile(
                        title: 'Escudo Diario de Racha',
                        description:
                            'Protege tu racha automáticamente si descansas 1 día.',
                        cost: 25,
                        currentCoins: coins,
                        icon: AppIcons.escudo,
                        iconColor: c.water,
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
                              const SnackBar(
                                content:
                                    Text('¡Escudo de Racha adquirido (+1)!'),
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 8.0),
                      _ShopItemTile(
                        title: 'Pack Fin de Semana (3 Escudos)',
                        description:
                            'Viaja o desconecta todo un fin de semana con serenidad.',
                        cost: 65,
                        currentCoins: coins,
                        icon: AppIcons.shield,
                        iconColor: c.accent,
                        onBuy: () async {
                          final ok = await petDao.buyShopItem(
                            itemId: 'shield_weekend',
                            cost: 65,
                            dateKey: DateTime.now().dateKey,
                            isConsumable: true,
                            shieldsToAdd: 3,
                          );
                          if (context.mounted && ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    '¡3 Escudos de Racha añadidos a tu reserva!'),
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 18.0),

                      // 2. Sombreros y Accesorios
                      Text(
                        'Sombreros de Nibi',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          color: c.calories,
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
                          if (ok) {
                            await petDao.equipItem(hatId: 'hat_chef');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      '¡Gorro de Chef comprado y equipado!'),
                                ),
                              );
                            }
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
                          if (ok) {
                            await petDao.equipItem(hatId: 'hat_headband');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      '¡Vincha de Entrenamiento comprada y equipada!'),
                                ),
                              );
                            }
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
                          if (ok) {
                            await petDao.equipItem(hatId: 'hat_zen_halo');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      '¡Halo Zen Dorado comprado y equipado!'),
                                ),
                              );
                            }
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
                          if (ok) {
                            await petDao.equipItem(hatId: 'hat_crown');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('¡Corona Real comprada y equipada!'),
                                ),
                              );
                            }
                          }
                        },
                        onEquip: () => petDao.equipItem(hatId: 'hat_crown'),
                        onUnequip: () => petDao.equipItem(hatId: null),
                      ),
                      const SizedBox(height: 18.0),

                      // 3. Ambientes del Santuario
                      Text(
                        'Ambientes del Santuario',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          color: c.fasting,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      _AccessoryTile(
                        id: 'bg_zen_garden',
                        title: 'Jardín Zen de Bambú 🎋',
                        cost: 40,
                        currentCoins: coins,
                        isUnlocked: unlocked.contains('bg_zen_garden'),
                        isEquipped: pet.equippedBackgroundId == 'bg_zen_garden',
                        onBuy: () async {
                          final ok = await petDao.buyShopItem(
                            itemId: 'bg_zen_garden',
                            cost: 40,
                            dateKey: DateTime.now().dateKey,
                          );
                          if (ok) {
                            await petDao.equipItem(bgId: 'bg_zen_garden');
                          }
                        },
                        onEquip: () => petDao.equipItem(bgId: 'bg_zen_garden'),
                        onUnequip: () =>
                            petDao.equipItem(bgId: 'bg_default_room'),
                      ),
                      const SizedBox(height: 8.0),
                      _AccessoryTile(
                        id: 'bg_mountain_dawn',
                        title: 'Alba Andina Dorada 🏔️',
                        cost: 50,
                        currentCoins: coins,
                        isUnlocked: unlocked.contains('bg_mountain_dawn'),
                        isEquipped:
                            pet.equippedBackgroundId == 'bg_mountain_dawn',
                        onBuy: () async {
                          final ok = await petDao.buyShopItem(
                            itemId: 'bg_mountain_dawn',
                            cost: 50,
                            dateKey: DateTime.now().dateKey,
                          );
                          if (ok) {
                            await petDao.equipItem(bgId: 'bg_mountain_dawn');
                          }
                        },
                        onEquip: () =>
                            petDao.equipItem(bgId: 'bg_mountain_dawn'),
                        onUnequip: () =>
                            petDao.equipItem(bgId: 'bg_default_room'),
                      ),
                      const SizedBox(height: 8.0),
                      _AccessoryTile(
                        id: 'bg_starry_dojo',
                        title: 'Dojo Estelar Nocturno 🌌',
                        cost: 55,
                        currentCoins: coins,
                        isUnlocked: unlocked.contains('bg_starry_dojo'),
                        isEquipped:
                            pet.equippedBackgroundId == 'bg_starry_dojo',
                        onBuy: () async {
                          final ok = await petDao.buyShopItem(
                            itemId: 'bg_starry_dojo',
                            cost: 55,
                            dateKey: DateTime.now().dateKey,
                          );
                          if (ok) {
                            await petDao.equipItem(bgId: 'bg_starry_dojo');
                          }
                        },
                        onEquip: () => petDao.equipItem(bgId: 'bg_starry_dojo'),
                        onUnequip: () =>
                            petDao.equipItem(bgId: 'bg_default_room'),
                      ),
                      const SizedBox(height: 18.0),

                      // 4. Snacks saludables simbólicos
                      Text(
                        'Mimos Simbólicos',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          color: c.steps,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      _ShopItemTile(
                        title: 'Manzana Crujiente 🍎',
                        description:
                            'Un premio simbólico para celebrar tus buenos hábitos.',
                        cost: 10,
                        currentCoins: coins,
                        icon: Icons.apple_rounded,
                        iconColor: c.calories,
                        onBuy: () async {
                          final ok = await petDao.buyShopItem(
                            itemId: 'snack_apple',
                            cost: 10,
                            dateKey: DateTime.now().dateKey,
                            isConsumable: true,
                          );
                          if (context.mounted && ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    '¡Le diste una manzana crujiente a tu compañero! 🍎✨'),
                              ),
                            );
                          }
                        },
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
    final ScColors c = context.sc;
    final bool canAfford = currentCoins >= cost;

    return HealthCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 30),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 2.0),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: c.text2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8.0),
          FilledButton.tonal(
            onPressed: canAfford ? onBuy : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppIcons.moneda, size: 16, color: c.warning),
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
    final ScColors c = context.sc;
    return HealthCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          Icon(
            isEquipped
                ? Icons.check_circle
                : (isUnlocked ? Icons.lock_open : Icons.lock_outline),
            color: isEquipped
                ? c.accent
                : (isUnlocked ? c.water : c.text3),
            size: 26,
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: c.text,
              ),
            ),
          ),
          if (!isUnlocked)
            FilledButton.tonal(
              onPressed: currentCoins >= cost ? onBuy : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(AppIcons.moneda, size: 16, color: c.warning),
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
