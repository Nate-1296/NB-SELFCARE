import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/database/daos/pet_dao.dart';
import 'package:nb_selfcare/features/pet_gamification/application/nibi_overview.dart';
import 'package:nb_selfcare/features/pet_gamification/application/pet_service.dart';
import 'package:nb_selfcare/features/pet_gamification/application/reward_service.dart';
import 'package:nb_selfcare/features/pet_gamification/domain/nibi_activity.dart';
import 'package:nb_selfcare/features/pet_gamification/domain/pet_catalog.dart';
import 'package:nb_selfcare/features/pet_gamification/presentation/nibi/nibi_painter.dart';
import 'package:nb_selfcare/features/pet_gamification/presentation/nibi/nibi_palette.dart';
import 'package:nb_selfcare/features/pet_gamification/presentation/nibi/nibi_pose.dart';
import 'package:nb_selfcare/features/pet_gamification/presentation/nibi/nibi_view.dart';
import 'package:nb_selfcare/shared/theme/sc_colors.dart';
import 'package:nb_selfcare/shared/theme/sc_theme.dart';

import '../support/test_container.dart';

void main() {
  group('Ánimo de base (datos reales → actividad)', () {
    NibiActivity at(NibiVitals v) => NibiMoodResolver.resolve(v).activity;

    test('de noche duerme, aunque haya ayuno o metas cumplidas', () {
      expect(at(const NibiVitals(hour: 23, hydrationRatio: 1, sleptWell: true)), NibiActivity.sleeping);
      expect(at(const NibiVitals(hour: 3, fastingHours: 15)), NibiActivity.sleeping);
      expect(NibiMoodResolver.resolve(const NibiVitals(hour: 3, fastingHours: 15)).aura, isTrue);
    });

    test('ayuno ≥ 12 h: zen con aura', () {
      final NibiMood m = NibiMoodResolver.resolve(const NibiVitals(hour: 14, fastingHours: 12.5));
      expect(m.activity, NibiActivity.zen);
      expect(m.aura, isTrue);
    });

    test('agua y sueño completos: celebra; uno solo, contento', () {
      expect(at(const NibiVitals(hour: 18, hydrationRatio: 1, sleptWell: true, mealsLoggedToday: 3)), NibiActivity.celebrating);
      expect(at(const NibiVitals(hour: 18, hydrationRatio: 1, mealsLoggedToday: 3)), NibiActivity.happy);
      expect(at(const NibiVitals(hour: 10, workedOutToday: true)), NibiActivity.happy);
      expect(at(const NibiVitals(hour: 10, streakDays: 8)), NibiActivity.happy);
    });

    test('sin registros a mediodía: curiosidad (nunca reproche)', () {
      expect(at(const NibiVitals(hour: 13)), NibiActivity.curious);
      expect(at(const NibiVitals(hour: 9)), NibiActivity.idle);
      expect(at(const NibiVitals(hour: 13, mealsLoggedToday: 1)), NibiActivity.idle);
    });

    test('ninguna combinación de datos da un estado fuera del catálogo positivo', () {
      for (int h = 0; h < 24; h++) {
        for (final double water in <double>[0, 0.5, 1, 2]) {
          for (final double? fast in <double?>[null, 4, 13, 40]) {
            final NibiMood m = NibiMoodResolver.resolve(
              NibiVitals(hour: h, hydrationRatio: water, fastingHours: fast, sleptWell: h.isEven),
            );
            expect(NibiActivity.values, contains(m.activity));
          }
        }
      }
    });
  });

  group('Coreografías', () {
    test('posturas finitas y dentro de rango durante 30 s a 60 fps', () {
      for (final NibiActivity a in NibiActivity.values) {
        for (int i = 0; i < 1800; i++) {
          final NibiPose p = NibiChoreography.pose(a, i / 60, aura: i.isEven);
          expect(p.isFinite, isTrue, reason: '$a t=${i / 60}');
          expect(p.eyeOpen, inInclusiveRange(0, 1), reason: '$a');
          expect(p.bodyY, inInclusiveRange(-20, 10), reason: '$a');
          expect(p.squash, inInclusiveRange(0.9, 1.15), reason: '$a');
          expect(p.leftArm.abs(), lessThanOrEqualTo(3.14), reason: '$a');
          expect(p.rightArm.abs(), lessThanOrEqualTo(3.14), reason: '$a');
          expect(p.aura, inInclusiveRange(0, 1), reason: '$a');
        }
      }
    });

    test('deterministas: el mismo instante da la misma postura', () {
      final NibiPose a = NibiChoreography.pose(NibiActivity.celebrating, 7.25);
      final NibiPose b = NibiChoreography.pose(NibiActivity.celebrating, 7.25);
      expect(a.bodyY, b.bodyY);
      expect(a.rightArm, b.rightArm);
    });

    test('parpadea de verdad: ojos cerrados un instante cada pocos segundos', () {
      final List<double> samples = <double>[for (int i = 0; i < 60 * 16; i++) NibiChoreography.blink(i / 60)];
      expect(samples.where((double v) => v < 0.3).length, inInclusiveRange(4, 40));
      expect(samples.every((double v) => v >= 0 && v <= 1), isTrue);
    });

    test('dormido de verdad (P0-5): ojos cerrados, no el dragón saludando', () {
      final NibiPose p = NibiChoreography.pose(NibiActivity.sleeping, 3);
      expect(p.eyes, NibiEyes.closed);
      expect(p.eyeOpen, 0);
      expect(p.mouth, NibiMouth.sleepy);
    });

    test('reacciones: finitas, empiezan y acaban en la postura base', () {
      final NibiPose base = NibiChoreography.pose(NibiActivity.idle, 1);
      for (final NibiReaction r in NibiReaction.values) {
        for (int i = 0; i <= 120; i++) {
          final double age = r.seconds * i / 120;
          final NibiPose p = NibiChoreography.react(base, r, age);
          expect(p.isFinite, isTrue, reason: '$r $age');
          expect(p.turn.abs(), inInclusiveRange(0.05, 1), reason: '$r $age');
          expect(p.bodyY, inInclusiveRange(-30, 10), reason: '$r $age');
        }
        expect(NibiChoreography.react(base, r, 0).bodyY, base.bodyY, reason: '$r');
        expect(NibiChoreography.react(base, r, r.seconds).turn, base.turn, reason: '$r');
      }
    });

    test('la vuelta pasa de espaldas y vuelve de frente', () {
      final NibiPose base = NibiChoreography.pose(NibiActivity.idle, 0);
      final double mid = NibiChoreography.react(base, NibiReaction.spin, NibiReaction.spin.seconds / 2).turn;
      expect(mid, lessThan(0));
    });

    test('respiración guiada: Nibi se expande al inhalar', () {
      final NibiPose base = NibiChoreography.pose(NibiActivity.zen, 0);
      final NibiPose empty = NibiChoreography.guided(base, 0);
      final NibiPose full = NibiChoreography.guided(base, 1);
      expect(full.breath, greaterThan(empty.breath));
      expect(full.bodyY, lessThan(empty.bodyY));
      expect(full.wingFlap, greaterThan(empty.wingFlap));
    });

    test('jugar: la pelota bota entre el suelo y arriba', () {
      final List<double> h = <double>[for (int i = 0; i < 240; i++) NibiChoreography.ballHeight(i / 60)];
      expect(h.reduce(math.min), closeTo(0, 0.01));
      expect(h.reduce(math.max), closeTo(1, 0.01));
    });

    test('transición: la interpolación empieza y termina en las posturas', () {
      final NibiPose a = NibiChoreography.pose(NibiActivity.idle, 0);
      final NibiPose b = NibiChoreography.pose(NibiActivity.workout, 0);
      expect(NibiPose.lerp(a, b, 0).leftArm, a.leftArm);
      expect(NibiPose.lerp(a, b, 1).leftArm, b.leftArm);
    });
  });

  group('Pintado', () {
    test('cada fotograma se graba en mucho menos de lo que permite 60 fps', () {
      final ScColors c = ScTheme.build('samsung_dark').extension<ScColors>()!;
      final ValueNotifier<NibiFrame> frame = ValueNotifier<NibiFrame>(nibiStaticFrame(NibiActivity.idle));
      final NibiPainter painter = NibiPainter(
        frame: frame,
        palette: NibiPalette.of(c, colorId: 'color_gold'),
        look: const NibiLook(hatId: 'hat_wizard', accessoryId: 'acc_scarf', colorId: 'color_gold'),
      );
      final Stopwatch sw = Stopwatch();
      int frames = 0;
      for (final NibiActivity a in NibiActivity.values) {
        for (int i = 0; i < 120; i++) {
          frame.value = NibiFrame(
            activity: a,
            pose: NibiChoreography.pose(a, i / 60, aura: true),
            t: i / 60,
            reaction: NibiReaction.values[i % NibiReaction.values.length],
            reactionAge: (i % 30) / 30,
          );
          final ui.PictureRecorder recorder = ui.PictureRecorder();
          sw.start();
          painter.paint(Canvas(recorder), const Size(260, 260));
          sw.stop();
          recorder.endRecording().dispose();
          frames++;
        }
      }
      final double msPerFrame = sw.elapsedMicroseconds / frames / 1000;
      // Presupuesto de 60 fps: 16,7 ms por fotograma para todo; Nibi debe usar una fracción.
      expect(msPerFrame, lessThan(4), reason: '$msPerFrame ms por fotograma');
    });
  });

  group('NibiView', () {
    Widget app(String theme, NibiActivity activity) => MaterialApp(
          theme: ScTheme.build(theme),
          home: Scaffold(body: Center(child: NibiView(activity: activity, size: 200, onReaction: (_) {}))),
        );

    testWidgets('en color se anima de forma continua', (WidgetTester tester) async {
      await tester.pumpWidget(app('samsung_dark', NibiActivity.idle));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpWidget(app('samsung_dark', NibiActivity.celebrating));
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 33));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('en papel no programa fotogramas (bajo movimiento) y la caricia se borra sola', (WidgetTester tester) async {
      await tester.pumpWidget(app('nxtpaper_eink_light', NibiActivity.idle));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.tap(find.byType(NibiView));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1600));
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(app('nxtpaper_eink_light', NibiActivity.sleeping));
      expect(tester.takeException(), isNull);
    });
  });

  group('Tienda y armario', () {
    late AppDatabase db;
    late ProviderContainer c;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.into(db.petStatus).insert(const PetStatusCompanion(coinsBalance: drift.Value(100)));
      c = createTestContainer(db);
    });

    tearDown(() async {
      c.dispose();
      await db.close();
    });

    PetItem item(String id) => PetCatalog.byId(id)!;

    test('comprar un sombrero lo desbloquea, lo pone y descuenta monedas', () async {
      expect(await c.read(petServiceProvider).buy(item('hat_crown')), PurchaseOutcome.purchased);
      final PetStatusData pet = (await PetDao(db).getPetStatus())!;
      expect(pet.coinsBalance, 40);
      expect(pet.equippedHatId, 'hat_crown');
      expect(decodeUnlockedItems(pet.unlockedItemsJson), contains('hat_crown'));
      expect(await c.read(petServiceProvider).buy(item('hat_crown')), PurchaseOutcome.alreadyOwned);
      expect((await PetDao(db).getPetStatus())!.coinsBalance, 40);
    });

    test('sin monedas suficientes no se compra nada', () async {
      await c.read(petServiceProvider).buy(item('hat_crown'));
      expect(await c.read(petServiceProvider).buy(item('bg_starry_dojo')), PurchaseOutcome.notEnoughCoins);
      expect((await PetDao(db).getPetStatus())!.coinsBalance, 40);
    });

    test('no se puede poner algo no comprado; quitar el sombrero sí', () async {
      expect(await c.read(petServiceProvider).equip(item('hat_chef')), isFalse);
      await c.read(petServiceProvider).buy(item('hat_chef'));
      await c.read(petServiceProvider).unequip(PetItemKind.hat);
      expect((await PetDao(db).getPetStatus())!.equippedHatId, isNull);
    });

    test('accesorio y color: cada uno en su ranura, sin tocar el sombrero', () async {
      final PetService s = c.read(petServiceProvider);
      await s.buy(item('hat_party'));
      await s.buy(item('acc_bowtie'));
      await s.buy(item('color_ocean'));
      PetStatusData pet = (await PetDao(db).getPetStatus())!;
      expect(pet.equippedHatId, 'hat_party');
      expect(pet.equippedAccessoryId, 'acc_bowtie');
      expect(pet.equippedColorId, 'color_ocean');
      expect(nibiLookOf(pet), const NibiLook(hatId: 'hat_party', accessoryId: 'acc_bowtie', colorId: 'color_ocean'));

      // Volver al verde de siempre (gratis, siempre suyo) y quitar el accesorio.
      expect(await s.equip(item(PetCatalog.defaultColor)), isTrue);
      await s.unequip(PetItemKind.accessory);
      pet = (await PetDao(db).getPetStatus())!;
      expect(pet.equippedColorId, isNull);
      expect(pet.equippedAccessoryId, isNull);
      expect(pet.equippedHatId, 'hat_party');
    });

    test('lo gratuito no se vende y los ids desconocidos no rompen el aspecto', () async {
      expect(await c.read(petServiceProvider).buy(item(PetCatalog.defaultColor)), PurchaseOutcome.unavailable);
      final PetStatusData pet = (await PetDao(db).getPetStatus())!.copyWith(
        equippedHatId: const drift.Value('hat_de_otra_version'),
        equippedColorId: const drift.Value('color_inexistente'),
      );
      expect(nibiLookOf(pet), const NibiLook());
    });

    test('los escudos se consumen: se pueden comprar varias veces', () async {
      for (int i = 0; i < 3; i++) {
        expect(await c.read(petServiceProvider).buy(item('shield_daily')), PurchaseOutcome.purchased);
      }
      final PetStatusData pet = (await PetDao(db).getPetStatus())!;
      expect(pet.coinsBalance, 100 - 75);
      expect(decodeUnlockedItems(pet.unlockedItemsJson), isNot(contains('shield_daily')));
    });

    test('catálogo sin la manzana; todo artículo tiene nombre e imagen', () {
      expect(PetCatalog.byId('snack_apple'), isNull);
      final Set<String> ids = PetCatalog.items.map((PetItem i) => i.id).toSet();
      expect(ids.length, PetCatalog.items.length, reason: 'ids repetidos');
      expect(PetCatalog.ofKind(PetItemKind.hat).length, greaterThanOrEqualTo(9));
      expect(PetCatalog.ofKind(PetItemKind.accessory).length, greaterThanOrEqualTo(5));
      expect(PetCatalog.ofKind(PetItemKind.color).length, greaterThanOrEqualTo(7));
      expect(PetCatalog.ofKind(PetItemKind.habitat).length, greaterThanOrEqualTo(9));
      for (final String color in PetCatalog.ofKind(PetItemKind.color).map((PetItem i) => i.id)) {
        expect(NibiSkin.byId, contains(color));
      }
    });

    test('respirar da monedas una sola vez al día', () async {
      final RewardGrant first = await c.read(petServiceProvider).completeBreathing();
      final RewardGrant second = await c.read(petServiceProvider).completeBreathing();
      expect(first.granted, isTrue);
      expect(first.coins, greaterThan(0));
      expect(second.granted, isFalse);
    });

    test('nombres vacíos o larguísimos', () async {
      expect(await c.read(petServiceProvider).rename('   '), isFalse);
      expect(await c.read(petServiceProvider).rename('  Dragoncito de la montaña andina  '), isTrue);
      expect((await PetDao(db).getPetStatus())!.petName.length, lessThanOrEqualTo(PetService.maxNameLength));
    });

    test('lista de desbloqueados corrupta no rompe el armario', () {
      expect(decodeUnlockedItems('no es json'), PetCatalog.starterItems);
      expect(decodeUnlockedItems('{"a":1}'), PetCatalog.starterItems);
      expect(decodeUnlockedItems('["hat_chef", 3, null]'), containsAll(<String>['hat_chef', PetCatalog.defaultHabitat]));
    });
  });
}
