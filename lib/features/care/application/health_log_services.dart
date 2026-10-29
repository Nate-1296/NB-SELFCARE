import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock/clock.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/care_dao.dart';
import '../../../core/database/daos/food_dao.dart';
import '../../../core/database/daos/health_sync_dao.dart';
import '../../../core/database/daos/user_profile_dao.dart';
import '../../../core/domain/care_enums.dart';
import '../../../core/domain/enums.dart';
import '../../../core/platform/health_connect_gateway.dart';
import '../../../core/platform/native_call.dart';
import '../../../shared/utils/date_time_extensions.dart';
import '../domain/substance_catalog.dart';
import '../domain/vital_ranges.dart';
import '../domain/wellbeing_index.dart';

/// Síntomas: un toque y una intensidad.
class SymptomService {
  SymptomService(this._dao, this._clock);

  final CareDao _dao;
  final Clock _clock;

  Future<int?> log({required String symptom, required int intensity, String? notes}) {
    final String trimmed = symptom.trim();
    if (trimmed.isEmpty) return Future<int?>.value();
    return _dao.insertSymptom(
      dateKey: _clock.now().dateKey,
      symptom: trimmed.length > 40 ? trimmed.substring(0, 40) : trimmed,
      intensity: intensity,
      notes: notes?.trim().isEmpty ?? true ? null : notes!.trim(),
    );
  }

  Future<void> delete(int id) => _dao.deleteSymptom(id);

  Future<void> restore(SymptomLog log) => _dao.restoreSymptom(log);
}

/// Signos vitales: a mano o desde Health Connect, sin duplicados.
class VitalService {
  VitalService(this._dao, this._health, this._healthSyncDao, this._profileDao, this._clock);

  final CareDao _dao;
  final HealthConnectGateway _health;
  final HealthSyncDao _healthSyncDao;
  final UserProfileDao _profileDao;
  final Clock _clock;

  /// Días hacia atrás que se leen la primera vez.
  static const int initialLookbackDays = 30;
  static const String _checkpoint = 'vitals';

  /// Guarda una lectura manual. Devuelve `false` si el dato no puede ser real.
  Future<bool> addManual({
    required VitalKind kind,
    required double primary,
    double? secondary,
    String? context,
    DateTime? at,
  }) async {
    if (!VitalRanges.isPlausible(kind, primary, secondary)) return false;
    final DateTime now = _clock.now();
    final DateTime when = at == null || at.isAfter(now) ? now : at;
    await _dao.insertVital(
      VitalReadingsCompanion.insert(
        kind: kind.key,
        measuredAt: when,
        dateKey: when.dateKey,
        primaryValue: primary,
        secondaryValue: Value(secondary),
        context: Value(context),
      ),
    );
    return true;
  }

  Future<void> delete(int id) => _dao.deleteVital(id);

  Future<void> restore(VitalReading reading) => _dao.restoreVital(reading);

  /// Lee de Health Connect los aparatos declarados. Nunca lanza.
  Future<int> syncFromHealthConnect() async {
    final UserProfile? profile = await _profileDao.getProfile();
    if (profile == null) return 0;
    final Set<VitalKind> kinds = ProfileSets.vitalDevices(profile.vitalDevicesJson);
    if (kinds.isEmpty) return 0;
    final DateTime now = _clock.now();
    final HealthSyncCheckpoint? last = await bestEffort(
      () => _healthSyncDao.getCheckpoint(_checkpoint),
      null,
    );
    final DateTime since = (last?.lastSyncTimestamp ?? now.addDays(-initialLookbackDays)).subtract(
      const Duration(hours: 1),
    );
    final List<VitalSample> samples = await bestEffort(
      () => _health.readVitals(kinds: kinds, since: since),
      const <VitalSample>[],
    );
    int stored = 0;
    for (final VitalSample s in samples) {
      if (!VitalRanges.isPlausible(s.kind, s.primary, s.secondary)) continue;
      final int id = await _dao.insertVital(
        VitalReadingsCompanion.insert(
          kind: s.kind.key,
          measuredAt: s.at,
          dateKey: s.at.dateKey,
          primaryValue: s.primary,
          secondaryValue: Value(s.secondary),
          context: Value(s.context),
          source: const Value('health_connect'),
          externalId: Value(s.externalId),
        ),
      );
      if (id > 0) stored++;
    }
    await bestEffort(
      () => _healthSyncDao.updateCheckpoint(
        recordType: _checkpoint,
        timestamp: now,
        readCount: stored,
      ),
      null,
    );
    return stored;
  }
}

/// Alcohol y tabaco: registro de un toque, sin juicios. Las bebidas suman sus
/// kcal en Comida (como tentempié), para que el balance y el gasto adaptativo
/// las tengan en cuenta.
class SubstanceService {
  SubstanceService(this._db, this._dao, this._foodDao, this._clock);

  final AppDatabase _db;
  final CareDao _dao;
  final FoodDao _foodDao;
  final Clock _clock;

  /// Nombre del alimento en Comida (dato del catálogo, como la semilla USDA).
  static const Map<String, String> _foodNames = <String, String>{
    'beer': 'Cerveza (330 ml)',
    'wine': 'Vino (copa de 150 ml)',
    'spirit': 'Aguardiente o ron (trago de 30 ml)',
    'cocktail': 'Cóctel (200 ml)',
  };

  Future<int> log(SubstancePreset preset, {int units = 1}) {
    final int n = units.clamp(1, 40);
    final DateTime now = _clock.now();
    return _db.transaction(() async {
      final int? foodLogId = preset.kind == SubstanceKind.alcohol
          ? await _logDrinkInFood(preset, n, now.dateKey)
          : null;
      return _dao.insertSubstance(
        SubstanceLogsCompanion.insert(
          dateKey: now.dateKey,
          loggedAt: now,
          kind: preset.kind.key,
          presetKey: preset.key,
          standardDrinks: Value(preset.standardDrinks * n),
          kcal: Value(preset.kcal * n),
          units: Value(n),
          foodLogId: Value(foodLogId),
        ),
      );
    });
  }

  Future<int?> _logDrinkInFood(SubstancePreset preset, int units, String dateKey) async {
    final String barcode = 'nb-drink-${preset.key}';
    FoodItem? food = await _foodDao.getByBarcode(barcode);
    if (food == null) {
      final int id = await _foodDao.insertFood(
        FoodItemsCompanion.insert(
          barcode: Value(barcode),
          name: _foodNames[preset.key] ?? preset.key,
          source: FoodSource.userCustom,
          defaultServingGrams: Value(preset.volumeMl.toDouble()),
          servingLabel: Value('${preset.volumeMl} ml'),
          kcalPer100g: preset.kcalPer100ml,
          proteinPer100g: 0,
          carbsPer100g: preset.carbsPer100ml,
          fatPer100g: 0,
          novaGroup: const Value(4),
        ),
      );
      food = await _foodDao.getById(id);
    }
    if (food == null) return null;
    return _foodDao.logFoodItemPortion(
      food: food,
      grams: preset.volumeMl * units.toDouble(),
      dateKey: dateKey,
      mealType: MealType.snack,
    );
  }

  Future<void> delete(SubstanceLog log) {
    return _db.transaction(() async {
      await _dao.deleteSubstance(log.id);
      final int? foodLogId = log.foodLogId;
      if (foodLogId != null) await _foodDao.deleteFoodLog(foodLogId);
    });
  }

  /// Deshacer un registro recién hecho.
  Future<void> undo(int id) async {
    final SubstanceLog? row = await _dao.getSubstance(id);
    if (row != null) await delete(row);
  }

  /// Deshacer un borrado: vuelve a sumar la bebida en Comida.
  Future<void> restore(SubstanceLog log) {
    return _db.transaction(() async {
      final SubstancePreset? preset = SubstancePreset.byKey(log.presetKey);
      final int? foodLogId = preset != null && preset.kind == SubstanceKind.alcohol
          ? await _logDrinkInFood(preset, log.units, log.dateKey)
          : null;
      await _dao.restoreSubstance(log.copyWith(foodLogId: Value(foodLogId)));
    });
  }
}

/// Índice de bienestar OMS-5 (revisión del domingo).
class WellbeingService {
  WellbeingService(this._dao, this._clock);

  final CareDao _dao;
  final Clock _clock;

  Future<int> save(List<int> answers) async {
    final int percent = WellbeingIndex.percent(answers);
    await _dao.insertWellbeing(
      dateKey: _clock.now().dateKey,
      answersJson: jsonEncode(
        answers.map((int a) => a.clamp(0, WellbeingIndex.maxAnswer)).toList(),
      ),
      percentScore: percent,
    );
    return percent;
  }
}

final symptomServiceProvider = Provider<SymptomService>(
  (Ref ref) => SymptomService(ref.watch(careDaoProvider), ref.watch(clockProvider)),
);

final vitalServiceProvider = Provider<VitalService>((Ref ref) {
  return VitalService(
    ref.watch(careDaoProvider),
    ref.watch(healthConnectGatewayProvider),
    ref.watch(healthSyncDaoProvider),
    ref.watch(userProfileDaoProvider),
    ref.watch(clockProvider),
  );
});

final substanceServiceProvider = Provider<SubstanceService>((Ref ref) {
  return SubstanceService(
    ref.watch(appDatabaseProvider),
    ref.watch(careDaoProvider),
    ref.watch(foodDaoProvider),
    ref.watch(clockProvider),
  );
});

final wellbeingServiceProvider = Provider<WellbeingService>(
  (Ref ref) => WellbeingService(ref.watch(careDaoProvider), ref.watch(clockProvider)),
);
