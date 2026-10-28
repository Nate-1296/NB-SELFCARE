// Galería de Nibi, en color y en papel: actividades sobre cada escenario,
// sombreros, accesorios, colores y reacciones. Genera
// tool/screenshots/goldens/nibi_*.png.
//
//   flutter test tool/screenshots/nibi_gallery_test.dart --update-goldens
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/features/pet_gamification/domain/nibi_activity.dart';
import 'package:nb_selfcare/features/pet_gamification/domain/pet_catalog.dart';
import 'package:nb_selfcare/features/pet_gamification/presentation/nibi/habitat_painter.dart';
import 'package:nb_selfcare/features/pet_gamification/presentation/nibi/nibi_painter.dart';
import 'package:nb_selfcare/features/pet_gamification/presentation/nibi/nibi_palette.dart';
import 'package:nb_selfcare/features/pet_gamification/presentation/nibi/nibi_pose.dart';
import 'package:nb_selfcare/features/pet_gamification/presentation/nibi/nibi_view.dart';
import 'package:nb_selfcare/shared/theme/sc_colors.dart';
import 'package:nb_selfcare/shared/theme/sc_theme.dart';

Widget _cell(
  ScColors c,
  NibiActivity a, {
  NibiLook look = const NibiLook(),
  String habitat = 'bg_default_room',
  double t = 0.7,
  NibiReaction? reaction,
  String? caption,
}) {
  NibiPose pose = NibiChoreography.pose(a, t, aura: a == NibiActivity.zen);
  final double age = reaction == null ? 0 : reaction.seconds * (reaction == NibiReaction.spin ? 0.35 : 0.5);
  if (reaction != null) pose = NibiChoreography.react(pose, reaction, age);
  return SizedBox(
    width: 180,
    height: 200,
    child: Stack(
      children: <Widget>[
        Positioned.fill(child: CustomPaint(painter: HabitatPainter(habitatId: habitat, colors: c))),
        Positioned(
          left: 0,
          right: 0,
          top: 4,
          child: Center(
            child: CustomPaint(
              size: const Size.square(170),
              painter: NibiPainter(
                frame: ValueNotifier<NibiFrame>(
                  NibiFrame(activity: a, pose: pose, t: t, reaction: reaction, reactionAge: age),
                ),
                palette: NibiPalette.of(c, colorId: look.colorId),
                look: look,
              ),
            ),
          ),
        ),
        Positioned(
          left: 4,
          bottom: 2,
          child: Text(caption ?? a.name, style: TextStyle(fontSize: 10, color: c.text)),
        ),
      ],
    ),
  );
}

Future<void> _gallery(WidgetTester tester, String theme, String name, List<Widget> Function(ScColors) cells) async {
  tester.view.physicalSize = const Size(1100, 1260);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final ThemeData data = ScTheme.build(theme);
  final ScColors c = data.extension<ScColors>()!;
  await tester.pumpWidget(
    MaterialApp(theme: data, home: Scaffold(body: Wrap(children: cells(c)))),
  );
  await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/nibi_${name}_$theme.png'));
}

void main() {
  final List<String> habitats = PetCatalog.ofKind(PetItemKind.habitat).map((PetItem i) => i.id).toList();
  final List<String> hats = PetCatalog.ofKind(PetItemKind.hat).map((PetItem i) => i.id).toList();
  final List<String> accessories = PetCatalog.ofKind(PetItemKind.accessory).map((PetItem i) => i.id).toList();
  final List<String> colors = PetCatalog.ofKind(PetItemKind.color).map((PetItem i) => i.id).toList();

  for (final String theme in <String>['samsung_dark', 'nxtpaper_eink_light']) {
    testWidgets('actividades y escenarios $theme', (WidgetTester tester) async {
      await _gallery(tester, theme, 'activities', (ScColors c) => <Widget>[
            for (final NibiActivity a in NibiActivity.values)
              _cell(c, a, habitat: habitats[a.index % habitats.length], caption: '${a.name} · ${habitats[a.index % habitats.length]}'),
            for (final NibiActivity a in <NibiActivity>[NibiActivity.idle, NibiActivity.sleeping])
              Padding(
                padding: const EdgeInsets.all(8),
                child: NibiAvatar(size: 64, activity: a),
              ),
          ]);
    });

    testWidgets('armario $theme', (WidgetTester tester) async {
      await _gallery(tester, theme, 'wardrobe', (ScColors c) => <Widget>[
            for (int i = 0; i < hats.length; i++)
              _cell(c, NibiActivity.idle, look: NibiLook(hatId: hats[i], colorId: colors[i % colors.length]), caption: hats[i]),
            for (final String acc in accessories)
              _cell(c, NibiActivity.happy, look: NibiLook(accessoryId: acc), caption: acc),
            for (final String color in colors)
              Padding(
                padding: const EdgeInsets.all(6),
                child: NibiAvatar(size: 64, look: NibiLook(colorId: color, accessoryId: 'acc_glasses')),
              ),
          ]);
    });

    testWidgets('reacciones $theme', (WidgetTester tester) async {
      await _gallery(tester, theme, 'reactions', (ScColors c) => <Widget>[
            for (final NibiReaction r in NibiReaction.values)
              _cell(c, NibiActivity.idle, reaction: r, habitat: habitats[r.index % habitats.length], caption: r.name),
            _cell(c, NibiActivity.playing, t: 0.6, caption: 'playing'),
          ]);
    });
  }
}
