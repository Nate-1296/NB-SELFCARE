import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/database/daos/body_measurements_dao.dart';
import 'package:nb_selfcare/core/database/daos/pet_dao.dart';
import 'package:nb_selfcare/core/domain/enums.dart';

void main() {
  late AppDatabase db;
  late BodyMeasurementsDao dao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = BodyMeasurementsDao(db);
    await db.into(db.petStatus).insert(const PetStatusCompanion());
  });

  tearDown(() => db.close());

  Future<void> weighIn(String dateKey, double weight, double trend) {
    return dao.insertMeasurement(
      BodyMeasurementsCompanion.insert(
        dateKey: dateKey,
        measuredAt: drift.Value(DateTime.parse('${dateKey}T07:00:00')),
        source: MeasurementSource.miScale2Ble,
        weightKg: weight,
        trendWeightKg: trend,
        bmi: 24,
        bodyFatPercentage: const drift.Value(22),
      ),
    );
  }

  Future<bool> tape(String dateKey) => dao.saveNavyTapeMeasurement(
        dateKey: dateKey,
        measuredAt: DateTime.parse('${dateKey}T20:00:00'),
        waistCm: 84,
        neckCm: 38,
        validatedBodyFatPercentage: 21,
        navyBodyFatPercentage: 19.5,
      );

  test('Con pesaje el mismo día completa esa fila sin crear otra', () async {
    await weighIn('2026-10-20', 80, 80.4);
    expect(await tape('2026-10-20'), isTrue);

    final List<BodyMeasurement> rows = await db.select(db.bodyMeasurements).get();
    expect(rows, hasLength(1));
    expect(rows.single.waistCm, 84);
    expect(rows.single.validatedBodyFatPercentage, 21);
  });

  test('Sin pesaje ese día no sobrescribe un pesaje antiguo', () async {
    await weighIn('2026-10-01', 80, 80.4);
    expect(await tape('2026-10-20'), isTrue);

    final List<BodyMeasurement> rows = await (db.select(db.bodyMeasurements)
          ..orderBy([(t) => drift.OrderingTerm.asc(t.measuredAt)]))
        .get();
    expect(rows, hasLength(2));
    expect(rows.first.waistCm, isNull, reason: 'El pesaje del día 1 no debe tocarse');

    final BodyMeasurement tapeRow = rows.last;
    expect(tapeRow.source, MeasurementSource.navyTape);
    expect(tapeRow.weightKg, 80, reason: 'Arrastra el último peso real');
    expect(tapeRow.trendWeightKg, 80.4, reason: 'La EMA no se reinicia');
  });

  test('La fila de cinta no otorga monedas de pesaje', () async {
    await weighIn('2026-10-01', 80, 80.4);
    final int coinsBefore = (await PetDao(db).getPetStatus())!.coinsBalance;
    await tape('2026-10-20');
    expect((await PetDao(db).getPetStatus())!.coinsBalance, coinsBefore);
  });

  test('Sin ningún peso registrado no inventa un peso', () async {
    expect(await tape('2026-10-20'), isFalse);
    expect(await db.select(db.bodyMeasurements).get(), isEmpty);
  });

  test('La grasa BIA de referencia ignora las filas de cinta', () async {
    await weighIn('2026-10-01', 80, 80.4);
    await tape('2026-10-20');
    expect(await dao.getLatestBiaBodyFat(), 22);
  });
}
