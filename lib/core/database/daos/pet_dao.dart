import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../constants/app_constants.dart';
import '../app_database.dart';

/// DAO especializado en el estado de la mascota Nibi y el libro mayor de monedas.
class PetDao {
  PetDao(this._db);

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

  /// Otorga una recompensa en monedas con idempotencia diaria por (dateKey, actionType).
  ///
  /// Si ya se otorgó la recompensa para ese día y acción, ignora silenciosamente.
  /// Si `sleepMultiplier` es `1.0`, verifica si el usuario registró sueño reparador hoy
  /// (`>= 7.5h` o `REM + Profundo >= 90 min`) para aplicar `1.5x` automáticamente,
  /// y actualiza la racha diaria de forma positiva al completar el primer hábito del día.
  Future<bool> grantDailyReward({
    required String dateKey,
    required String actionType,
    required int baseAmount,
    double sleepMultiplier = 1.0,
  }) async {
    return _db.transaction(() async {
      try {
        double effectiveMultiplier = sleepMultiplier;
        if (effectiveMultiplier == 1.0) {
          final DailySummary? summary = await (_db.select(_db.dailySummaries)
                ..where((tbl) => tbl.dateKey.equals(dateKey)))
              .getSingleOrNull();
          if (summary != null) {
            final int restorativeMin =
                summary.sleepDeepMinutes + summary.sleepRemMinutes;
            if (restorativeMin >= 90 || summary.sleepDurationMinutes >= 450) {
              effectiveMultiplier = AppConstants.goodSleepMultiplier;
            }
          }
        }

        final int finalAmount = (baseAmount * effectiveMultiplier).ceil();

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
                actionType: Value(actionType),
                amount: Value(finalAmount),
                sleepMultiplierApplied: Value(effectiveMultiplier),
              ),
            );

        // Actualizar saldo de monedas y racha diaria en PetStatus
        final PetStatusData? pet = await getPetStatus();
        if (pet != null) {
          int nextStreak = pet.currentStreakDays;
          int nextHighest = pet.highestStreakDays;
          int nextShields = pet.streakShieldsAvailable;

          if (isFirstHabitToday) {
            final DateTime? parsedDate = DateTime.tryParse(dateKey);
            if (parsedDate != null && pet.currentStreakDays > 0) {
              final DateTime y = parsedDate.subtract(const Duration(days: 1));
              final String yesterdayKey =
                  '${y.year.toString().padLeft(4, '0')}-${y.month.toString().padLeft(2, '0')}-${y.day.toString().padLeft(2, '0')}';

              final yesterdayRows = await _db.customSelect(
                'SELECT COUNT(*) AS cnt FROM coin_ledger WHERE date_key = ? AND amount > 0',
                variables: [Variable.withString(yesterdayKey)],
                readsFrom: {_db.coinLedger},
              ).getSingle();
              final bool activeYesterday =
                  yesterdayRows.read<int>('cnt') > 0;

              final earlierRows = await _db.customSelect(
                'SELECT COUNT(*) AS cnt FROM coin_ledger WHERE date_key < ? AND amount > 0',
                variables: [Variable.withString(yesterdayKey)],
                readsFrom: {_db.coinLedger},
              ).getSingle();
              final bool hadEarlierHistory = earlierRows.read<int>('cnt') > 0;

              if (!activeYesterday && hadEarlierHistory) {
                if (nextShields > 0) {
                  nextShields -= 1;
                } else {
                  nextStreak = 0;
                }
              }
            }

            nextStreak += 1;
            if (nextStreak > nextHighest) {
              nextHighest = nextStreak;
            }
          }

          final query = _db.update(_db.petStatus)
            ..where((tbl) => tbl.id.equals(pet.id));
          await query.write(
            PetStatusCompanion(
              coinsBalance: Value(pet.coinsBalance + finalAmount),
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
        lastGreetingAt: Value(DateTime.now()),
      ),
    );
  }

  /// Equipa o desequipa un sombrero y/o fondo sin sobrescribir la ranura no indicada.
  Future<void> equipItem({
    Object? hatId = _unset,
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
  return PetDao(db);
});

/// StreamProvider que expone el estado de la mascota a la UI.
final petStatusStreamProvider = StreamProvider<PetStatusData?>((ref) {
  final PetDao dao = ref.watch(petDaoProvider);
  return dao.watchPetStatus();
});
