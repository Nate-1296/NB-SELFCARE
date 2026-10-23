import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite3/sqlite3.dart';

import '../app_database.dart';

/// DAO especializado en el estado de la mascota Nibi y el libro mayor de monedas.
class PetDao {
  PetDao(this._db);

  final AppDatabase _db;

  /// Emite en vivo el estado actual de la mascota Nibi.
  Stream<PetStatusData?> watchPetStatus() {
    return (_db.select(_db.petStatus)..limit(1)).watchSingleOrNull();
  }

  /// Obtiene el estado actual de la mascota Nibi.
  Future<PetStatusData?> getPetStatus() {
    return (_db.select(_db.petStatus)..limit(1)).getSingleOrNull();
  }

  /// Emite el balance actual de monedas del usuario.
  Stream<int> watchCoinsBalance() {
    return watchPetStatus().map((status) => status?.coinsBalance ?? 0);
  }

  /// Otorga una recompensa en monedas con idempotencia diaria por (dateKey, actionType).
  ///
  /// Si ya se otorgó la recompensa para ese día y acción, ignora silenciosamente.
  /// Si es válida, aplica el multiplicador de sueño si corresponde y actualiza el saldo.
  Future<bool> grantDailyReward({
    required String dateKey,
    required String actionType,
    required int baseAmount,
    double sleepMultiplier = 1.0,
  }) async {
    final int finalAmount = (baseAmount * sleepMultiplier).ceil();

    return _db.transaction(() async {
      try {
        await _db.into(_db.coinLedger).insert(
              CoinLedgerCompanion(
                dateKey: Value(dateKey),
                actionType: Value(actionType),
                amount: Value(finalAmount),
                sleepMultiplierApplied: Value(sleepMultiplier),
              ),
            );

        // Actualizar saldo de monedas en PetStatus
        final PetStatusData? pet = await getPetStatus();
        if (pet != null) {
          final query = _db.update(_db.petStatus)..where((tbl) => tbl.id.equals(pet.id));
          await query.write(
            PetStatusCompanion(
              coinsBalance: Value(pet.coinsBalance + finalAmount),
            ),
          );
        }
        return true;
      } on SqliteException catch (e) {
        // Violación de restricción única: ya se reclamó hoy
        if (e.extendedResultCode == 2067 || e.resultCode == 19) {
          return false;
        }
        rethrow;
      }
    });
  }

  /// Consume un escudo de racha si está disponible. Retorna true si se usó con éxito.
  Future<bool> consumeStreakShield() async {
    final PetStatusData? pet = await getPetStatus();
    if (pet == null || pet.streakShieldsAvailable <= 0) {
      return false;
    }

    final query = _db.update(_db.petStatus)..where((tbl) => tbl.id.equals(pet.id));
    await query.write(
      PetStatusCompanion(
        streakShieldsAvailable: Value(pet.streakShieldsAvailable - 1),
      ),
    );
    return true;
  }

  /// Incrementa los días de racha activa (+1).
  Future<void> incrementStreak() async {
    final PetStatusData? pet = await getPetStatus();
    if (pet == null) return;

    final int newStreak = pet.currentStreakDays + 1;
    final int highest = newStreak > pet.highestStreakDays ? newStreak : pet.highestStreakDays;

    final query = _db.update(_db.petStatus)..where((tbl) => tbl.id.equals(pet.id));
    await query.write(
      PetStatusCompanion(
        currentStreakDays: Value(newStreak),
        highestStreakDays: Value(highest),
      ),
    );
  }

  /// Realiza la compra de un artículo de la tienda descontando monedas del libro mayor.
  Future<bool> buyShopItem({
    required String itemId,
    required int cost,
    required String dateKey,
    bool isConsumable = false,
    int shieldsToAdd = 0,
  }) async {
    return _db.transaction(() async {
      final PetStatusData? pet = await getPetStatus();
      if (pet == null || pet.coinsBalance < cost) {
        return false;
      }

      // 1. Registrar egreso en coin_ledger
      await _db.into(_db.coinLedger).insert(
            CoinLedgerCompanion(
              dateKey: Value(dateKey),
              actionType: const Value('shop_buy'),
              amount: Value(-cost),
            ),
          );

      // 2. Deserializar items desbloqueados
      final List<dynamic> unlocked = jsonDecode(pet.unlockedItemsJson) as List<dynamic>;
      if (!unlocked.contains(itemId)) {
        unlocked.add(itemId);
      }

      // 3. Actualizar PetStatus
      final query = _db.update(_db.petStatus)..where((tbl) => tbl.id.equals(pet.id));
      await query.write(
        PetStatusCompanion(
          coinsBalance: Value(pet.coinsBalance - cost),
          streakShieldsAvailable: Value(pet.streakShieldsAvailable + shieldsToAdd),
          unlockedItemsJson: Value(jsonEncode(unlocked)),
        ),
      );

      return true;
    });
  }

  /// Equipa un sombrero o fondo para la mascota.
  Future<void> equipItem({String? hatId, String? bgId}) async {
    final PetStatusData? pet = await getPetStatus();
    if (pet == null) return;

    final query = _db.update(_db.petStatus)..where((tbl) => tbl.id.equals(pet.id));
    await query.write(
      PetStatusCompanion(
        equippedHatId: Value(hatId),
        equippedBackgroundId: Value(bgId ?? pet.equippedBackgroundId),
      ),
    );
  }
}

/// Provider de Riverpod para inyectar PetDao.
final petDaoProvider = Provider<PetDao>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return PetDao(db);
});

/// StreamProvider que expone el estado de la mascota a la UI.
final petStatusStreamProvider = StreamProvider<PetStatusData?>((ref) {
  final PetDao dao = ref.watch(petDaoProvider);
  return dao.watchPetStatus();
});
