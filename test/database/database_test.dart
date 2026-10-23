import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/database/seeder/database_seeder.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    // Usar SQLite en memoria para tests ultrarrápidos y aislados
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Persistencia y Esquema Drift (SQLite3 + FTS5)', () {
    test('Inicialización de base de datos y verificación de tablas vacías', () async {
      final userProfiles = await db.select(db.userProfiles).get();
      expect(userProfiles, isEmpty);

      final foodItems = await db.select(db.foodItems).get();
      expect(foodItems, isEmpty);
    });

    test('DatabaseSeeder puebla alimentos base USDA y estado inicial de Nibi', () async {
      await DatabaseSeeder.seedIfEmpty(db);

      // Verificar alimentos sembrados
      final foodItems = await db.select(db.foodItems).get();
      expect(foodItems.length, greaterThanOrEqualTo(20));

      // Verificar que alimentos tengan micronutrientes y electrolitos clave
      final aguacate = foodItems.firstWhere((item) => item.name.contains('Aguacate'));
      expect(aguacate.potassiumMgPer100g, greaterThan(400.0));
      expect(aguacate.magnesiumMgPer100g, greaterThan(20.0));
      expect(aguacate.fiberPer100g, greaterThan(5.0));

      final pollo = foodItems.firstWhere((item) => item.name.contains('Pechuga de pollo'));
      expect(pollo.proteinPer100g, greaterThan(25.0));
      expect(pollo.sodiumMgPer100g, greaterThan(50.0));

      // Verificar estado inicial de la mascota Nibi
      final petList = await db.select(db.petStatus).get();
      expect(petList.length, 1);
      final pet = petList.first;
      expect(pet.petName, 'Nibi');
      expect(pet.coinsBalance, 50);
      expect(pet.streakShieldsAvailable, 1);
      expect(pet.currentStreakDays, 0);

      // Si se llama nuevamente, no debe duplicar (idempotencia)
      await DatabaseSeeder.seedIfEmpty(db);
      final foodItemsAfter = await db.select(db.foodItems).get();
      expect(foodItemsAfter.length, foodItems.length);
      final petAfter = await db.select(db.petStatus).get();
      expect(petAfter.length, 1);
    });

    test('Búsqueda Full-Text FTS5 sin diacríticos encuentra palabras con y sin tilde', () async {
      await DatabaseSeeder.seedIfEmpty(db);

      // Buscar "platano" sin tilde debe coincidir con "Plátano / Banano maduro"
      final resultSinTilde = await db.customSelect(
        'SELECT rowid, name FROM food_items_fts WHERE food_items_fts MATCH ? LIMIT 5',
        variables: [Variable.withString('platano*')],
      ).get();

      expect(resultSinTilde, isNotEmpty);
      expect(resultSinTilde.first.read<String>('name'), contains('Plátano'));

      // Buscar "brocoli" sin tilde debe coincidir con "Brócoli al vapor"
      final resultBrocoli = await db.customSelect(
        'SELECT rowid, name FROM food_items_fts WHERE food_items_fts MATCH ? LIMIT 5',
        variables: [Variable.withString('brocoli*')],
      ).get();

      expect(resultBrocoli, isNotEmpty);
      expect(resultBrocoli.first.read<String>('name'), contains('Brócoli'));

      // Buscar "cafe" sin tilde debe coincidir con "Café negro"
      final resultCafe = await db.customSelect(
        'SELECT rowid, name FROM food_items_fts WHERE food_items_fts MATCH ? LIMIT 5',
        variables: [Variable.withString('cafe*')],
      ).get();

      expect(resultCafe, isNotEmpty);
      expect(resultCafe.first.read<String>('name'), contains('Café'));
    });

    test('CoinLedger hace cumplir la idempotencia diaria para recompensas', () async {
      final now = DateTime.now();
      const dateKey = '2026-10-23';

      // Insertar primera recompensa por pesaje del día
      await db.into(db.coinLedger).insert(
        CoinLedgerCompanion(
          dateKey: const Value(dateKey),
          actionType: const Value('weigh_in'),
          amount: const Value(15),
          createdAt: Value(now),
        ),
      );

      // Intentar insertar un segundo pesaje en el mismo día debe fallar por índice único
      expect(
        () async => db.into(db.coinLedger).insert(
          CoinLedgerCompanion(
            dateKey: const Value(dateKey),
            actionType: const Value('weigh_in'),
            amount: const Value(15),
            createdAt: Value(now),
          ),
        ),
        throwsA(isA<SqliteException>()),
      );

      // Pero compras en la tienda ('shop_buy') sí se permiten múltiples veces en el mismo día
      await db.into(db.coinLedger).insert(
        CoinLedgerCompanion(
          dateKey: const Value(dateKey),
          actionType: const Value('shop_buy'),
          amount: const Value(-40),
          createdAt: Value(now),
        ),
      );

      await db.into(db.coinLedger).insert(
        CoinLedgerCompanion(
          dateKey: const Value(dateKey),
          actionType: const Value('shop_buy'),
          amount: const Value(-100),
          createdAt: Value(now),
        ),
      );

      final ledgerEntries = await db.select(db.coinLedger).get();
      expect(ledgerEntries.length, 3);
    });
  });
}
