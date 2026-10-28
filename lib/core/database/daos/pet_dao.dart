import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../clock/clock.dart';
import '../../domain/streak_policy.dart';
import '../app_database.dart';

/// DAO especializado en el estado de la mascota Nibi y el libro mayor de monedas.
class PetDao {
  PetDao(this._db, {this._clock = const Clock()});

  final Clock _clock;

  final AppDatabase _db;

  static const Object _unset = Object();

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

  /// Registra una recompensa en el libro mayor con idempotencia diaria por
  /// (`dateKey`, `ledgerKey`) y avanza la racha si es el primer hábito del día.
  ///
  /// Las reglas (montos, multiplicador de sueño) viven en `RewardPolicy`; este
  /// método solo persiste. Devuelve `false` si la recompensa ya se había reclamado.
  Future<bool> recordReward({
    required String dateKey,
    required String ledgerKey,
    required int amount,
    double multiplierApplied = 1.0,
  }) async {
    return _db.transaction(() async {
      try {
        // Ya reclamada hoy: se comprueba antes de insertar. Dejar que salte el
        // índice único dentro de una transacción anidada (el diario guarda la
        // entrada y la recompensa juntas) hacía que el aislado de Drift
        // informara la excepción como no controlada aunque aquí se capturara.
        final QueryRow? claimed = await _db.customSelect(
          'SELECT 1 AS hit FROM coin_ledger WHERE date_key = ? AND action_type = ? LIMIT 1',
          variables: [Variable.withString(dateKey), Variable.withString(ledgerKey)],
          readsFrom: {_db.coinLedger},
        ).getSingleOrNull();
        if (claimed != null) return false;

        // Revisar si es la primera recompensa positiva del día para avanzar la racha
        final priorTodayRows = await _db.customSelect(
          'SELECT COUNT(*) AS cnt FROM coin_ledger WHERE date_key = ? AND amount > 0',
          variables: [Variable.withString(dateKey)],
          readsFrom: {_db.coinLedger},
        ).getSingle();
        final bool isFirstHabitToday = (priorTodayRows.read<int>('cnt')) == 0;

        await _db.into(_db.coinLedger).insert(
              CoinLedgerCompanion(
                dateKey: Value(dateKey),
                actionType: Value(ledgerKey),
                amount: Value(amount),
                sleepMultiplierApplied: Value(multiplierApplied),
              ),
            );

        // Actualizar saldo de monedas y racha diaria en PetStatus
        final PetStatusData? pet = await getPetStatus();
        if (pet != null) {
          int nextStreak = pet.currentStreakDays;
          int nextHighest = pet.highestStreakDays;
          int nextShields = pet.streakShieldsAvailable;

          if (isFirstHabitToday) {
            final DateTime? day = DateTime.tryParse(dateKey);
            if (day != null) {
              final QueryRow lastActiveRow = await _db.customSelect(
                'SELECT MAX(date_key) AS last_key FROM coin_ledger '
                'WHERE date_key < ? AND amount > 0',
                variables: [Variable.withString(dateKey)],
                readsFrom: {_db.coinLedger},
              ).getSingle();
              final String? lastKey = lastActiveRow.readNullable<String>('last_key');

              final StreakUpdate update = StreakPolicy.onFirstHabitOfDay(
                day: day,
                lastActiveDay: lastKey == null ? null : DateTime.tryParse(lastKey),
                currentStreakDays: pet.currentStreakDays,
                highestStreakDays: pet.highestStreakDays,
                shieldsAvailable: pet.streakShieldsAvailable,
              );
              nextStreak = update.currentStreakDays;
              nextHighest = update.highestStreakDays;
              nextShields = update.shieldsAvailable;
            }
          }

          final query = _db.update(_db.petStatus)
            ..where((tbl) => tbl.id.equals(pet.id));
          await query.write(
            PetStatusCompanion(
              coinsBalance: Value(pet.coinsBalance + amount),
              currentStreakDays: Value(nextStreak),
              highestStreakDays: Value(nextHighest),
              streakShieldsAvailable: Value(nextShields),
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

    final query = _db.update(_db.petStatus)
      ..where((tbl) => tbl.id.equals(pet.id));
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
    final int highest =
        newStreak > pet.highestStreakDays ? newStreak : pet.highestStreakDays;

    final query = _db.update(_db.petStatus)
      ..where((tbl) => tbl.id.equals(pet.id));
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

      // 2. Deserializar items desbloqueados (solo añadir permanentes, no consumibles)
      final List<String> unlocked =
          (jsonDecode(pet.unlockedItemsJson) as List<dynamic>)
              .map((e) => e.toString())
              .toList();
      if (!isConsumable && !unlocked.contains(itemId)) {
        unlocked.add(itemId);
      }

      // 3. Actualizar PetStatus
      final query = _db.update(_db.petStatus)
        ..where((tbl) => tbl.id.equals(pet.id));
      await query.write(
        PetStatusCompanion(
          coinsBalance: Value(pet.coinsBalance - cost),
          streakShieldsAvailable:
              Value(pet.streakShieldsAvailable + shieldsToAdd),
          unlockedItemsJson: Value(jsonEncode(unlocked)),
        ),
      );

      return true;
    });
  }

  /// Actualiza el nombre personalizado de la mascota.
  Future<void> updatePetName(String newName) async {
    final clean = newName.trim();
    if (clean.isEmpty) return;

    final PetStatusData? pet = await getPetStatus();
    if (pet == null) return;

    final query = _db.update(_db.petStatus)
      ..where((tbl) => tbl.id.equals(pet.id));
    await query.write(
      PetStatusCompanion(
        petName: Value(clean),
      ),
    );
  }

  /// Guarda el último saludo contextual generado para Nibi.
  Future<void> saveAiGreeting(String greeting) async {
    final clean = greeting.trim();
    if (clean.isEmpty) return;

    final PetStatusData? pet = await getPetStatus();
    if (pet == null) return;

    final query = _db.update(_db.petStatus)
      ..where((tbl) => tbl.id.equals(pet.id));
    await query.write(
      PetStatusCompanion(
        lastAiGreeting: Value(clean),
        lastGreetingAt: Value(_clock.now()),
      ),
    );
  }

  /// Equipa o quita sombrero, accesorio, color y/o fondo sin tocar las ranuras no indicadas.
  Future<void> equipItem({
    Object? hatId = _unset,
    Object? accessoryId = _unset,
    Object? colorId = _unset,
    Object? bgId = _unset,
  }) async {
    final PetStatusData? pet = await getPetStatus();
    if (pet == null) return;

    final query = _db.update(_db.petStatus)
      ..where((tbl) => tbl.id.equals(pet.id));
    await query.write(
      PetStatusCompanion(
        equippedHatId: identical(hatId, _unset)
            ? const Value.absent()
            : Value(hatId as String?),
        equippedAccessoryId: identical(accessoryId, _unset)
            ? const Value.absent()
            : Value(accessoryId as String?),
        equippedColorId: identical(colorId, _unset)
            ? const Value.absent()
            : Value(colorId as String?),
        equippedBackgroundId: identical(bgId, _unset)
            ? const Value.absent()
            : Value((bgId as String?) ?? 'bg_default_room'),
      ),
    );
  }
}

/// Provider de Riverpod para inyectar PetDao.
final petDaoProvider = Provider<PetDao>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return PetDao(db, clock: ref.watch(clockProvider));
});
