import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock/clock.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/pet_dao.dart';
import '../../../shared/utils/date_time_extensions.dart';
import '../domain/pet_catalog.dart';
import '../domain/reward_policy.dart';
import 'nibi_overview.dart';
import 'reward_service.dart';

enum PurchaseOutcome { purchased, alreadyOwned, notEnoughCoins, unavailable }

/// Casos de uso de la tienda, el armario y el santuario de Nibi.
class PetService {
  PetService(this._dao, this._clock, this._rewards);

  final PetDao _dao;
  final Clock _clock;
  final RewardService _rewards;

  /// Longitud máxima del nombre de la mascota (cabe en la barra inferior).
  static const int maxNameLength = 16;

  Future<PurchaseOutcome> buy(PetItem item) async {
    final PetStatusData? pet = await _dao.getPetStatus();
    if (pet == null || item.cost <= 0) return PurchaseOutcome.unavailable;
    if (!item.isConsumable && decodeUnlockedItems(pet.unlockedItemsJson).contains(item.id)) {
      return PurchaseOutcome.alreadyOwned;
    }
    if (pet.coinsBalance < item.cost) return PurchaseOutcome.notEnoughCoins;
    final bool ok = await _dao.buyShopItem(
      itemId: item.id,
      cost: item.cost,
      dateKey: _clock.now().dateKey,
      isConsumable: item.isConsumable,
      shieldsToAdd: item.shields,
    );
    if (!ok) return PurchaseOutcome.notEnoughCoins;
    // Lo recién comprado se lleva puesto.
    if (item.isCosmetic) await equip(item);
    return PurchaseOutcome.purchased;
  }

  /// Equipa un cosmético desbloqueado.
  Future<bool> equip(PetItem item) async {
    final PetStatusData? pet = await _dao.getPetStatus();
    if (pet == null || !decodeUnlockedItems(pet.unlockedItemsJson).contains(item.id)) return false;
    switch (item.kind) {
      case PetItemKind.hat:
        await _dao.equipItem(hatId: item.id);
      case PetItemKind.accessory:
        await _dao.equipItem(accessoryId: item.id);
      case PetItemKind.color:
        await _dao.equipItem(colorId: item.id == PetCatalog.defaultColor ? null : item.id);
      case PetItemKind.habitat:
        await _dao.equipItem(bgId: item.id);
      case PetItemKind.shield:
        return false;
    }
    return true;
  }

  /// Quita el sombrero o el accesorio (el color y el escenario siempre tienen uno).
  Future<void> unequip(PetItemKind kind) async {
    switch (kind) {
      case PetItemKind.hat:
        await _dao.equipItem(hatId: null);
      case PetItemKind.accessory:
        await _dao.equipItem(accessoryId: null);
      case PetItemKind.color:
      case PetItemKind.habitat:
      case PetItemKind.shield:
        return;
    }
  }

  /// Cambia el nombre (recortado a [maxNameLength]); `false` si queda vacío.
  Future<bool> rename(String raw) async {
    final String name = raw.trim();
    if (name.isEmpty) return false;
    await _dao.updatePetName(name.length > maxNameLength ? name.substring(0, maxNameLength).trimRight() : name);
    return true;
  }

  /// Sesión de respiración terminada: monedas la primera vez del día.
  Future<RewardGrant> completeBreathing() =>
      _rewards.grant(RewardAction.mindfulBreath, dateKey: _clock.now().dateKey);
}

final petServiceProvider = Provider<PetService>(
  (Ref ref) => PetService(ref.watch(petDaoProvider), ref.watch(clockProvider), ref.watch(rewardServiceProvider)),
);
