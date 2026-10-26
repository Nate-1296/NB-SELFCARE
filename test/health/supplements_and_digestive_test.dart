import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/database/daos/digestive_dao.dart';
import 'package:nb_selfcare/core/database/daos/supplement_dao.dart';

void main() {
  late AppDatabase db;
  late SupplementDao supplementDao;
  late DigestiveDao digestiveDao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    supplementDao = SupplementDao(db);
    digestiveDao = DigestiveDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Fase 6: SupplementDao & Water Retention Tests', () {
    test('createSupplement and toggleSupplementIntake tracks daily adherence', () async {
      final int suppId = await supplementDao.createSupplement(
        name: 'Creatina Creapure',
        dosage: '5g',
        affectsWaterRetention: true,
      );

      expect(suppId, greaterThan(0));

      final List<SupplementsTrackerData> active =
          await supplementDao.getAllSupplements();
      expect(active.length, 1);
      expect(active.first.affectsWaterRetention, isTrue);

      // Registrar toma de hoy
      const String todayKey = '2026-10-26';
      await supplementDao.toggleSupplementIntake(
        dateKey: todayKey,
        supplementId: suppId,
        wasTaken: true,
      );

      final List<SupplementLog> logs =
          await supplementDao.getLogsForDate(todayKey);
      expect(logs.length, 1);
      expect(logs.first.wasTaken, isTrue);
    });

    test('hasActiveWaterRetentionSupplement returns true only with sufficient adherence (>=3 logs)', () async {
      final int suppId = await supplementDao.createSupplement(
        name: 'Creatina Creapure',
        dosage: '5g',
        affectsWaterRetention: true,
      );

      // Con 1 toma aún no califica para retención continuada
      await supplementDao.toggleSupplementIntake(
        dateKey: '2026-10-24',
        supplementId: suppId,
        wasTaken: true,
      );
      bool hasRetention =
          await supplementDao.hasActiveWaterRetentionSupplement('2026-10-26');
      expect(hasRetention, isFalse);

      // Al acumular 3 tomas recientes en los últimos días
      await supplementDao.toggleSupplementIntake(
        dateKey: '2026-10-25',
        supplementId: suppId,
        wasTaken: true,
      );
      await supplementDao.toggleSupplementIntake(
        dateKey: '2026-10-26',
        supplementId: suppId,
        wasTaken: true,
      );

      hasRetention =
          await supplementDao.hasActiveWaterRetentionSupplement('2026-10-26');
      expect(hasRetention, isTrue);
    });
  });

  group('Fase 6: DigestiveDao & Bristol Scale Tests', () {
    test('logDigestiveEvent logs Bristol Type 4 with symptoms and retrieves successfully', () async {
      const String todayKey = '2026-10-26';
      final int id = await digestiveDao.logDigestiveEvent(
        dateKey: todayKey,
        bristolType: 4,
        discomfortLevel: 1,
        symptomsJson: '["Sin hinchazón"]',
        notes: 'Digestión ligera tras almuerzo mediterráneo',
      );

      expect(id, greaterThan(0));

      final List<DigestiveLog> logs =
          await digestiveDao.getLogsForDate(todayKey);
      expect(logs.length, 1);
      final DigestiveLog log = logs.first;
      expect(log.bristolType, 4);
      expect(log.discomfortLevel, 1);
      expect(log.notes, contains('mediterráneo'));
    });

    test('logDigestiveEvent throws ArgumentError on out-of-bounds Bristol type (<1 or >7)', () async {
      expect(
        () => digestiveDao.logDigestiveEvent(
          dateKey: '2026-10-26',
          bristolType: 0,
        ),
        throwsArgumentError,
      );

      expect(
        () => digestiveDao.logDigestiveEvent(
          dateKey: '2026-10-26',
          bristolType: 8,
        ),
        throwsArgumentError,
      );
    });
  });
}
