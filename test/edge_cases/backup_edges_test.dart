import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/domain/enums.dart';
import 'package:nb_selfcare/core/services/backup_service.dart';
import 'package:nb_selfcare/features/fasting/application/fasting_service.dart';
import 'package:nb_selfcare/features/nutrition_hydration/application/hydration_service.dart';
import 'package:nb_selfcare/features/profile_goals/application/onboarding_service.dart';

import '../support/fake_platform.dart';
import '../support/test_container.dart';

/// Archivos de respaldo dañados o elegidos por error en el selector de
/// archivos: la restauración debe rechazarlos sin tocar los datos actuales.
final DateTime _now = DateTime(2026, 10, 27, 10);

Future<void> _seed(AppDatabase db, {required String name, int glasses = 1}) async {
  final ProviderContainer c = createTestContainer(db, now: _now);
  await c
      .read(onboardingServiceProvider)
      .complete(
        OnboardingAnswers(
          name: name,
          birthDate: DateTime(1992, 2, 29),
          sex: BiologicalSex.male,
          heightCm: 180,
          currentWeightKg: 85,
          targetWeightKg: 78,
          weeklyGoalRateKg: -0.5,
          dailyWaterGoalMl: 2500,
          dailyStepsGoal: 9000,
          dailySleepGoalHours: 8,
          themeKey: 'nxtpaper_sepia',
        ),
      );
  for (int i = 0; i < glasses; i++) {
    await c.read(hydrationServiceProvider).logGlass(dateKey: '2026-10-27', volumeMl: 250);
  }
  c.dispose();
}

void main() {
  late Directory work;
  late AppDatabase current;
  late BackupService service;

  setUp(() async {
    work = Directory.systemTemp.createTempSync('nb_backup_edges_');
    current = AppDatabase(NativeDatabase(File('${work.path}/current.sqlite')));
    await _seed(current, name: 'Actual', glasses: 3);
    service = BackupService(current, temporaryDirectory: () async => work);
  });

  tearDown(() async {
    await current.close();
    work.deleteSync(recursive: true);
  });

  Future<void> expectUntouched() async {
    expect((await current.select(current.userProfiles).getSingle()).name, 'Actual');
    expect(await current.select(current.hydrationLogs).get(), hasLength(3));
  }

  Future<File> validBackup({String name = 'Respaldo'}) async {
    final AppDatabase other = AppDatabase(NativeDatabase(File('${work.path}/other_$name.sqlite')));
    await _seed(other, name: name);
    final File f = await other.exportCleanDatabaseBackup(work.path, stamp: _now);
    await other.close();
    return f;
  }

  test('ruta inexistente, archivo vacío y archivo de 1 byte', () async {
    expect(await service.restoreDatabaseFromFile('${work.path}/no_existe.sqlite'), isFalse);
    final File empty = File('${work.path}/empty.sqlite')..writeAsBytesSync(<int>[]);
    expect(await service.restoreDatabaseFromFile(empty.path), isFalse);
    final File one = File('${work.path}/one.sqlite')..writeAsBytesSync(<int>[0]);
    expect(await service.restoreDatabaseFromFile(one.path), isFalse);
    await expectUntouched();
  });

  test('una foto, un PDF o un ZIP elegidos por error', () async {
    final Random rng = Random(1);
    for (final List<int> header in <List<int>>[
      <int>[0xFF, 0xD8, 0xFF, 0xE0], // JPEG
      '%PDF-1.7'.codeUnits,
      <int>[0x50, 0x4B, 0x03, 0x04], // ZIP
    ]) {
      final File f = File('${work.path}/fake.sqlite')
        ..writeAsBytesSync(<int>[...header, ...List<int>.generate(20000, (_) => rng.nextInt(256))]);
      expect(await service.restoreDatabaseFromFile(f.path), isFalse);
    }
    await expectUntouched();
  });

  test('respaldo truncado (descarga o copia interrumpida a la mitad)', () async {
    final File good = await validBackup();
    final List<int> bytes = good.readAsBytesSync();
    final File half = File('${work.path}/half.sqlite')
      ..writeAsBytesSync(bytes.sublist(0, bytes.length ~/ 2));
    expect(await service.restoreDatabaseFromFile(half.path), isFalse);
    await expectUntouched();
  });

  test('respaldo con páginas corrompidas (bits volteados)', () async {
    final File good = await validBackup();
    final List<int> bytes = good.readAsBytesSync();
    final Random rng = Random(3);
    for (int i = 0; i < 400; i++) {
      final int at = 4096 + rng.nextInt(bytes.length - 4096);
      bytes[at] = bytes[at] ^ 0xFF;
    }
    final File broken = File('${work.path}/broken.sqlite')..writeAsBytesSync(bytes);
    expect(await service.restoreDatabaseFromFile(broken.path), isFalse);
    await expectUntouched();
  });

  test('restaurar el mismo respaldo dos veces deja el mismo resultado', () async {
    final File good = await validBackup();
    expect(await service.restoreDatabaseFromFile(good.path), isTrue);
    final int profiles = (await current.select(current.userProfiles).get()).length;
    final int glasses = (await current.select(current.hydrationLogs).get()).length;
    expect(await service.restoreDatabaseFromFile(good.path), isTrue);
    expect(await current.select(current.userProfiles).get(), hasLength(profiles));
    expect(await current.select(current.hydrationLogs).get(), hasLength(glasses));
    expect((await current.select(current.userProfiles).getSingle()).name, 'Respaldo');
  });

  test('tras restaurar con un ayuno en curso, la notificación del cronómetro se alinea', () async {
    final AppDatabase other = AppDatabase(NativeDatabase(File('${work.path}/with_fast.sqlite')));
    await _seed(other, name: 'Con ayuno');
    final ProviderContainer c = createTestContainer(other, now: _now);
    await c.read(fastingServiceProvider).start(protocolName: '16:8', targetHours: 16);
    c.dispose();
    final File backup = await other.exportCleanDatabaseBackup(work.path, stamp: _now);
    await other.close();

    expect(await service.restoreDatabaseFromFile(backup.path), isTrue);
    final FakeNotificationGateway notes = FakeNotificationGateway();
    final ProviderContainer after = createTestContainer(current, now: _now, notifications: notes);
    addTearDown(after.dispose);
    await after.read(fastingServiceProvider).reconcileTimerNotification();
    expect(notes.fastingTimer?.protocol, '16:8');
  });

  test('exportar dos veces el mismo minuto no pisa ni corrompe el primer archivo', () async {
    final File a = await current.exportCleanDatabaseBackup(work.path, stamp: _now);
    final int sizeA = a.lengthSync();
    final File b = await current.exportCleanDatabaseBackup(work.path, stamp: _now);
    expect(service.inspectBackup(b.path).isValid, isTrue);
    expect(a.existsSync(), isTrue);
    expect(service.inspectBackup(a.path).isValid, isTrue, reason: 'tamaño original $sizeA');
  });
}
