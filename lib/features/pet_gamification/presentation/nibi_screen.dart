import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../shared/theme/sc_colors.dart';
import '../../../shared/theme/sc_tokens.dart';
import '../../../shared/widgets/app_icons.dart';
import '../../../shared/widgets/entrance.dart';
import '../../../shared/widgets/quick_action_button.dart';
import '../../../shared/widgets/section_head.dart';
import '../../../shared/widgets/top_bar.dart';
import '../../care/application/care_session_service.dart';
import '../application/nibi_overview.dart';
import '../application/pet_service.dart';
import '../application/reward_service.dart';
import '../domain/breathing.dart';
import '../domain/nibi_activity.dart';
import '../domain/pet_catalog.dart';
import 'nibi/nibi_view.dart';
import 'pet_l10n.dart';
import 'shop_modal.dart';
import 'widgets/breathing.dart';
import 'widgets/nibi_stage.dart';
import 'widgets/nibi_status.dart';
import 'widgets/nibi_wardrobe.dart';

/// Pestaña de Nibi: su santuario (escenario, monedas, escudos y racha,
/// cuidados y respiración guiada), cómo refleja tus hábitos de hoy, el
/// armario y la tienda.
///
/// Su ánimo de base sale de los datos reales ([NibiMoodResolver]); los
/// toques, los cuidados y lo que registras en la app le provocan reacciones de
/// unos segundos. Siempre está bien (ADR-08).
class NibiScreen extends ConsumerStatefulWidget {
  const NibiScreen({super.key});

  @override
  ConsumerState<NibiScreen> createState() => _NibiScreenState();
}

class _NibiScreenState extends ConsumerState<NibiScreen> {
  static const Duration _reactionLength = Duration(milliseconds: 3800);
  static const Duration _playLength = Duration(seconds: 6);

  final GlobalKey<NibiViewState> _nibiKey = GlobalKey<NibiViewState>();
  NibiActivity? _reaction;
  String? _speech;
  Timer? _reactionTimer;

  @override
  void dispose() {
    _reactionTimer?.cancel();
    super.dispose();
  }

  /// Reacción breve; luego vuelve a su ánimo de base. Sin [activity] solo
  /// cambia lo que dice (las reacciones al toque las anima el propio Nibi).
  void _react(NibiActivity? activity, String speech, {Duration length = _reactionLength}) {
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _reaction = activity;
      _speech = speech;
    });
    _reactionTimer?.cancel();
    _reactionTimer = Timer(length, () {
      if (mounted) {
        setState(() {
          _reaction = null;
          _speech = null;
        });
      }
    });
  }

  void _care(NibiCare care) {
    final AppLocalizations l10n = context.l10n;
    switch (care) {
      case NibiCare.water:
        _react(NibiActivity.drinking, l10n.nibiSayWater);
      case NibiCare.snack:
        _react(NibiActivity.eating, l10n.nibiSaySnack);
      case NibiCare.play:
        _react(NibiActivity.playing, l10n.nibiSayPlay, length: _playLength);
      case NibiCare.pet:
      case NibiCare.breathe:
        break;
    }
  }

  Future<void> _breathingDone(String petName, BreathingSession session) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AppLocalizations l10n = context.l10n;
    // Se guarda como sesión de cuidado (y en Health Connect, si está conectado).
    final RewardGrant grant = await ref
        .read(careSessionServiceProvider)
        .complete(
          kind: CareSessionKind.breathing,
          variant: session.pattern.id,
          durationSeconds: session.totalSeconds,
          healthTitle: session.pattern.title(l10n),
        );
    if (grant.granted && mounted) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.breathCoins('${grant.coins}', petName))));
    }
  }

  Future<void> _rename(String current) async {
    final String? name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: current),
    );
    if (name == null || !mounted) return;
    if (await ref.read(petServiceProvider).rename(name) && mounted) {
      _react(NibiActivity.happy, context.l10n.nibiSayRenamed);
    }
  }

  void _openShop() => unawaited(ShopModal.show(context));

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;

    // Lo que registras en la app le llega a Nibi.
    ref.listen<AsyncValue<NibiOverview?>>(nibiOverviewProvider, (
      AsyncValue<NibiOverview?>? prev,
      AsyncValue<NibiOverview?> next,
    ) {
      final NibiOverview? a = prev?.value;
      final NibiOverview? b = next.value;
      if (a == null || b == null) return;
      if (b.waterMl > a.waterMl) {
        _react(NibiActivity.drinking, l10n.nibiSayDrinkLogged);
      } else if (b.mealsLogged > a.mealsLogged) {
        _react(NibiActivity.eating, l10n.nibiSayMealLogged);
      }
    });

    final NibiOverview? data = ref.watch(nibiOverviewProvider).value;
    if (data == null) {
      return Scaffold(
        backgroundColor: c.bg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final NibiActivity activity = _reaction ?? data.mood.activity;
    final String speech = _speech ?? data.mood.activity.speech(l10n);
    final PetService pets = ref.read(petServiceProvider);

    int order = 0;
    Widget enter(Widget child) => Entrance(index: order++, child: child);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: ScSpace.bottomInset),
          children: <Widget>[
            TopBar(
              title: data.pet.petName,
              large: true,
              trailing: TopBarAction(
                icon: Icons.edit_outlined,
                tooltip: l10n.nibiRename,
                onPressed: () => unawaited(_rename(data.pet.petName)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: ScSpace.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  enter(
                    NibiStage(
                      nibiKey: _nibiKey,
                      overview: data,
                      activity: activity,
                      speech: speech,
                      semanticsLabel: l10n.nibiPetSemantics(data.pet.petName),
                      onReaction: (NibiReaction r) => _react(null, r.speech(l10n)),
                      onCare: _care,
                      onBreathingDone: (BreathingSession session) =>
                          unawaited(_breathingDone(data.pet.petName, session)),
                    ),
                  ),
                  SectionHead(
                    title: l10n.nibiTodayTitle,
                    subtitle: l10n.nibiTodaySubtitle,
                    padding: const EdgeInsets.fromLTRB(
                      ScSpace.xs,
                      ScSpace.sectionGap,
                      ScSpace.xs,
                      ScSpace.m,
                    ),
                  ),
                  NibiTodayCard(overview: data),
                  SectionHead(
                    title: l10n.nibiWardrobeTitle,
                    subtitle: l10n.nibiWardrobeSubtitle,
                    actionLabel: l10n.nibiShop,
                    onAction: _openShop,
                    padding: const EdgeInsets.fromLTRB(
                      ScSpace.xs,
                      ScSpace.sectionGap,
                      0,
                      ScSpace.m,
                    ),
                  ),
                  NibiWardrobe(
                    overview: data,
                    onEquip: (PetItem item) {
                      unawaited(HapticFeedback.selectionClick());
                      unawaited(pets.equip(item));
                    },
                    onUnequip: (PetItemKind kind) {
                      unawaited(HapticFeedback.selectionClick());
                      unawaited(pets.unequip(kind));
                    },
                    onShop: _openShop,
                  ),
                  QuickActionButton(
                    label: l10n.nibiShop,
                    icon: AppIcons.tienda,
                    tone: c.warning,
                    onPressed: _openShop,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Diálogo de nombre. Es dueño de su controlador: se libera cuando el diálogo
/// termina de cerrarse (liberarlo antes rompía la animación de salida).
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.nibiRename),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        maxLength: PetService.maxNameLength,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(hintText: l10n.nibiRenameHint),
        onSubmitted: (String v) => Navigator.of(context).pop(v),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.commonCancel)),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_ctrl.text),
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}
