import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/fasting_dao.dart';
import '../../../core/database/daos/health_sync_dao.dart';
import '../../../core/database/daos/hydration_dao.dart';
import '../../../core/database/daos/pet_dao.dart';
import '../../../core/database/daos/user_profile_dao.dart';
import '../../../shared/theme/sc_colors.dart';
import '../../../shared/theme/sc_theme.dart';
import '../../../shared/utils/current_date_provider.dart';
import '../../../shared/utils/date_time_extensions.dart';
import '../../../shared/widgets/app_icons.dart';
import '../../../shared/widgets/section_head.dart';
import '../../../shared/widgets/top_bar.dart';
import 'shop_modal.dart';
import 'widgets/animated_nibi_view.dart';

/// Pantalla dedicada al Compañero Dragón de NB Selfcare ("Nibi").
///
/// Características principales:
/// 1. Dragón 100% ilustrado y reactivo a los hábitos de vida saludable.
/// 2. Positividad radical: Nibi no enferma ni muere; acompaña en primera persona.
/// 3. Escenario inmersivo con hábitats desbloqueables y compatibilidad total con Modo Papel NXTPAPER.
/// 4. Cuidados interactivos directos que transforman la forma del dragón de inmediato.
/// 5. Armario de accesorios, selección de hábitats y tienda integrada.
class NibiScreen extends ConsumerStatefulWidget {
  const NibiScreen({super.key});

  @override
  ConsumerState<NibiScreen> createState() => _NibiScreenState();
}

class _NibiScreenState extends ConsumerState<NibiScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final Animation<double> _bounceAnimation;
  final GlobalKey<AnimatedNibiViewState> _nibiKey =
      GlobalKey<AnimatedNibiViewState>();

  Timer? _moodResetTimer;
  String? _dialogText;
  NibiMood _currentMood = NibiMood.idle;

  static const List<Map<String, String>> _availableHats = [
    {'id': 'none', 'title': 'Ninguno', 'icon': '🚫'},
    {'id': 'hat_chef', 'title': 'Chef Saludable', 'icon': '👨‍🍳'},
    {'id': 'hat_headband', 'title': 'Entrenamiento', 'icon': '🏃'},
    {'id': 'hat_zen_halo', 'title': 'Halo Zen', 'icon': '✨'},
    {'id': 'hat_crown', 'title': 'Corona Real', 'icon': '👑'},
  ];

  static const List<Map<String, String>> _availableBackgrounds = [
    {'id': 'bg_default_room', 'title': 'Santuario Base', 'icon': '🏡'},
    {'id': 'bg_zen_garden', 'title': 'Jardín Zen', 'icon': '🎋'},
    {'id': 'bg_mountain_dawn', 'title': 'Alba Andina', 'icon': '🏔️'},
    {'id': 'bg_starry_dojo', 'title': 'Dojo Estelar', 'icon': '🌌'},
  ];

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.10), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.10, end: 1.0), weight: 50),
    ]).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _moodResetTimer?.cancel();
    _bounceController.dispose();
    super.dispose();
  }

  void _scheduleMoodReset() {
    _moodResetTimer?.cancel();
    _moodResetTimer = Timer(const Duration(milliseconds: 3200), () {
      if (mounted) {
        setState(() {
          _currentMood = NibiMood.idle;
        });
      }
    });
  }

  Future<void> _openRenamePetDialog(String currentName) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _RenamePetDialog(
        initialName: currentName,
        onSave: (newName) async {
          await ref.read(petDaoProvider).updatePetName(newName);
          if (mounted) {
            setState(() {
              _dialogText = '¡Me encanta mi nuevo nombre, $newName! 🐉✨';
            });
          }
        },
      ),
    );
  }

  void _triggerDragonAction({
    required NibiMood mood,
    required String speechText,
    required bool isFlat,
  }) {
    _nibiKey.currentState?.triggerPetHearts();
    if (!isFlat) {
      unawaited(_bounceController.forward(from: 0.0));
    }
    unawaited(HapticFeedback.selectionClick());

    setState(() {
      _currentMood = mood;
      _dialogText = speechText;
    });

    _scheduleMoodReset();
  }

  BoxDecoration _stageDecoration(String bgId, ScColors c) {
    if (c.isFlat) {
      return BoxDecoration(
        color: c.bg2,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.line2, width: 1.5),
      );
    }

    final List<Color> gradientColors;
    switch (bgId) {
      case 'bg_zen_garden':
        gradientColors = [
          c.bg2,
          const Color(0xFF10B981).withValues(alpha: 0.16),
          const Color(0xFF047857).withValues(alpha: 0.08),
        ];
      case 'bg_mountain_dawn':
        gradientColors = [
          c.bg2,
          const Color(0xFFF59E0B).withValues(alpha: 0.16),
          const Color(0xFFB45309).withValues(alpha: 0.08),
        ];
      case 'bg_starry_dojo':
        gradientColors = [
          c.bg2,
          const Color(0xFF8B5CF6).withValues(alpha: 0.20),
          const Color(0xFF6D28D9).withValues(alpha: 0.10),
        ];
      default:
        gradientColors = [
          c.bg2,
          c.bg3.withValues(alpha: 0.75),
          c.accent.withValues(alpha: 0.06),
        ];
    }

    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: gradientColors,
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: c.line, width: 1.2),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final currentDate = ref.watch(currentDateProvider);
    final String todayKey = currentDate.dateKey;

    final profileStream = ref.watch(userProfileDaoProvider).watchProfile();
    final petStream = ref.watch(petDaoProvider).watchPetStatus();
    final healthSummaryStream =
        ref.watch(healthSyncDaoProvider).watchDailySummary(todayKey);
    final waterStream =
        ref.watch(hydrationDaoProvider).watchTotalWaterMl(todayKey);
    final fastingStream = ref.watch(fastingDaoProvider).watchActiveSession();

    return StreamBuilder<UserProfile?>(
      stream: profileStream,
      builder: (context, profSnap) {
        final profile = profSnap.data;
        return StreamBuilder<PetStatusData?>(
          stream: petStream,
          builder: (context, petSnap) {
            final pet = petSnap.data;
            return StreamBuilder<DailySummary?>(
              stream: healthSummaryStream,
              builder: (context, summarySnap) {
                final summary = summarySnap.data;
                return StreamBuilder<int>(
                  stream: waterStream,
                  builder: (context, waterSnap) {
                    return StreamBuilder<FastingSession?>(
                      stream: fastingStream,
                      builder: (context, fastSnap) {
                        final activeFast = fastSnap.data;

                        final int waterMl = waterSnap.data ?? 0;
                        final int waterGoalMl =
                            profile?.dailyWaterGoalMl ?? 2500;
                        final double sleepGoal =
                            profile?.dailySleepGoalHours ?? 7.5;
                        final double sleepHours =
                            (summary?.sleepDurationMinutes ?? 0) / 60.0;
                        final bool isSleepGoalMet =
                            sleepHours >= sleepGoal && sleepHours > 0;

                        final bool isKetosis = activeFast != null &&
                            DateTime.now()
                                    .difference(activeFast.startedAt)
                                    .inHours >=
                                12;

                        final double hydrationRatio = waterGoalMl > 0
                            ? (waterMl / waterGoalMl).clamp(0.0, 1.0)
                            : 0.5;

                        final int coins = pet?.coinsBalance ?? 0;
                        final int streak = pet?.currentStreakDays ?? 0;
                        final int shields = pet?.streakShieldsAvailable ?? 0;
                        final String? equippedHat = pet?.equippedHatId;
                        final String equippedBg =
                            pet?.equippedBackgroundId ?? 'bg_default_room';

                        final Set<String> unlockedItems = <String>{
                          'none',
                          'bg_default_room',
                        };
                        if (pet?.unlockedItemsJson != null) {
                          try {
                            final parsed = jsonDecode(pet!.unlockedItemsJson)
                                as List<dynamic>;
                            unlockedItems
                                .addAll(parsed.map((e) => e.toString()));
                          } catch (_) {}
                        }

                        final String petName = pet?.petName ?? 'Nibi';

                        final String initialDialog = _dialogText ??
                            (isKetosis
                                ? '¡Siento una claridad mental increíble durante tu cetosis! ⚡✨'
                                : (hydrationRatio >= 1.0
                                    ? '¡Completaste tu hidratación de hoy! Me siento radiante 💧'
                                    : '¡Me llena de alegría compartir este día contigo! 🌿✨'));

                        return Scaffold(
                          backgroundColor: c.bg,
                          body: SafeArea(
                            bottom: false,
                            child: Column(
                              children: <Widget>[
                                // ==========================================
                                // Barra superior: Avatar del Dragón y Nombre
                                // ==========================================
                                TopBar(
                                  title: petName,
                                  avatarFoto: const AssetImage(
                                      'assets/images/nibi_avatar.png'),
                                  large: true,
                                ),

                                Expanded(
                                  child: ListView(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 6, 16, 120),
                                    children: <Widget>[
                                      // ==========================================
                                      // 3 Mini Tarjetas: Monedas, Protección, Racha
                                      // ==========================================
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 14),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: _PetHeaderMetricCard(
                                                icon: AppIcons.moneda,
                                                iconColor: c.isFlat
                                                    ? c.text
                                                    : c.warning,
                                                value: '$coins',
                                                onTap: () =>
                                                    unawaited(ShopModal.show(context)),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: _PetHeaderMetricCard(
                                                icon: AppIcons.escudo,
                                                iconColor: c.isFlat
                                                    ? c.text
                                                    : c.accent,
                                                value: '$shields',
                                                onTap: () =>
                                                    unawaited(ShopModal.show(context)),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: _PetHeaderMetricCard(
                                                icon: Icons
                                                    .local_fire_department_rounded,
                                                iconColor: c.isFlat
                                                    ? c.text
                                                    : c.calories,
                                                value: '$streak',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // ==========================================
                                      // 1. Escenario Principal del Dragón (Hábitat)
                                      // ==========================================
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 22, horizontal: 18),
                                        decoration:
                                            _stageDecoration(equippedBg, c),
                                        child: Column(
                                          children: [
                                            // Globo de texto (1ª persona, sin icono)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    width: double.infinity,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 18,
                                                        vertical: 13),
                                                    decoration: BoxDecoration(
                                                      color: c.isFlat
                                                          ? c.bg2
                                                          : c.bg3,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              18),
                                                      border: Border.all(
                                                        color: c.isFlat
                                                            ? c.line2
                                                            : c.line,
                                                        width: c.isFlat
                                                            ? 1.5
                                                            : 1.1,
                                                      ),
                                                      boxShadow: c.isFlat
                                                          ? null
                                                          : [
                                                              BoxShadow(
                                                                color: Colors
                                                                    .black
                                                                    .withValues(
                                                                        alpha:
                                                                            0.04),
                                                                blurRadius: 10,
                                                                offset:
                                                                    const Offset(
                                                                        0, 3),
                                                              ),
                                                            ],
                                                    ),
                                                    child: Text(
                                                      _dialogText ??
                                                          initialDialog,
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: TextStyle(
                                                        fontFamily: ScFonts.ui,
                                                        fontSize: 13.5,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: c.text,
                                                        height: 1.35,
                                                      ),
                                                    ),
                                                  ),
                                                  CustomPaint(
                                                    size: const Size(14, 8),
                                                    painter:
                                                        _SpeechBubbleTailPainter(
                                                      color: c.isFlat
                                                          ? c.bg2
                                                          : c.bg3,
                                                      borderColor: c.isFlat
                                                          ? c.line2
                                                          : c.line,
                                                      borderWidth: c.isFlat
                                                          ? 1.5
                                                          : 1.1,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            const SizedBox(height: 14),

                                            // Dragón Ilustrado con soporte a caricia
                                            ScaleTransition(
                                              scale: _bounceAnimation,
                                              child: AnimatedNibiView(
                                                key: _nibiKey,
                                                mood: _currentMood,
                                                equippedHatId: equippedHat,
                                                isEink: c.isFlat,
                                                size: 218,
                                                onPet: () {
                                                  _triggerDragonAction(
                                                    mood: NibiMood.happy,
                                                    speechText:
                                                        '¡Me llena de alegría compartir este día contigo! 💖✨',
                                                    isFlat: c.isFlat,
                                                  );
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(height: 20),

                                      // ==========================================
                                      // 2. Estado de Bienestar del Dragón
                                      // ==========================================
                                      const SectionHead(
                                        title: 'Bienestar del Dragón',
                                        padding:
                                            EdgeInsets.symmetric(vertical: 4),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _StatMiniCard(
                                              icon: AppIcons.gota,
                                              iconColor: c.water,
                                              title: 'Hidratación',
                                              value:
                                                  '${(hydrationRatio * 100).toInt()}%',
                                              subtitle:
                                                  '$waterMl / $waterGoalMl ml',
                                              progress: hydrationRatio,
                                              progressColor: c.water,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: _StatMiniCard(
                                              icon: AppIcons.sueno,
                                              iconColor: c.fasting,
                                              title: 'Sueño',
                                              value: sleepHours > 0
                                                  ? '${sleepHours.toStringAsFixed(1)}h'
                                                  : '-- h',
                                              subtitle: isSleepGoalMet
                                                  ? 'Meta cumplida ✨'
                                                  : 'Meta: ${sleepGoal.toStringAsFixed(1)}h',
                                              progress: sleepGoal > 0
                                                  ? (sleepHours / sleepGoal)
                                                      .clamp(0.0, 1.0)
                                                  : 0.0,
                                              progressColor: c.fasting,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: _StatMiniCard(
                                              icon: AppIcons.escudo,
                                              iconColor: c.accent,
                                              title: 'Protección',
                                              value: '$shields',
                                              subtitle: shields > 0
                                                  ? 'Racha blindada'
                                                  : 'Sin escudos',
                                              progress: (shields / 3.0)
                                                  .clamp(0.0, 1.0),
                                              progressColor: c.accent,
                                              onTap: () =>
                                                  unawaited(ShopModal.show(context)),
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 20),

                                      // ==========================================
                                      // 3. Cuidados del Dragón
                                      // ==========================================
                                      const SectionHead(
                                        title: 'Cuidados del Dragón',
                                        padding:
                                            EdgeInsets.symmetric(vertical: 4),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _ActionTile(
                                              icon: AppIcons.corazon,
                                              color: c.fat,
                                              title: 'Acariciar',
                                              onTap: () {
                                                _triggerDragonAction(
                                                  mood: NibiMood.happy,
                                                  speechText:
                                                      '¡Me llena de alegría compartir este día contigo! 💖✨',
                                                  isFlat: c.isFlat,
                                                );
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: _ActionTile(
                                              icon: AppIcons.gota,
                                              color: c.water,
                                              title: 'Dar Agua',
                                              onTap: () {
                                                _triggerDragonAction(
                                                  mood: NibiMood.drinking,
                                                  speechText:
                                                      '¡Glup, glup! ¡Qué agua tan fresca y deliciosa! 💧✨',
                                                  isFlat: c.isFlat,
                                                );
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: _ActionTile(
                                              icon: AppIcons.comer,
                                              color: c.calories,
                                              title: 'Nutrir',
                                              onTap: () {
                                                _triggerDragonAction(
                                                  mood: NibiMood.eating,
                                                  speechText:
                                                      '¡Ñam, ñam! ¡Qué bocado tan nutritivo y lleno de energía! 🍎✨',
                                                  isFlat: c.isFlat,
                                                );
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: _ActionTile(
                                              icon: AppIcons.air,
                                              color: c.accent,
                                              title: 'Zen',
                                              onTap: () {
                                                _triggerDragonAction(
                                                  mood: NibiMood.zen,
                                                  speechText:
                                                      'Inhalando paz... exhalando gratitud y serenidad 🧘🌿',
                                                  isFlat: c.isFlat,
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 20),

                                      // ==========================================
                                      // 4. Armario y Hábitats (Bespoke Atelier)
                                      // ==========================================
                                      const SectionHead(
                                        title: 'Armario y Hábitats',
                                        padding:
                                            EdgeInsets.symmetric(vertical: 4),
                                      ),
                                      const SizedBox(height: 8),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: 2, bottom: 8),
                                        child: Text(
                                          'Sombreros y Accesorios',
                                          style: TextStyle(
                                            fontFamily: ScFonts.ui,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: c.text2,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        height: 110,
                                        child: ListView.separated(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: _availableHats.length,
                                          separatorBuilder: (_, _) =>
                                              const SizedBox(width: 10),
                                          itemBuilder: (context, index) {
                                            final hat = _availableHats[index];
                                            final String hatId = hat['id']!;
                                            final bool isNone = hatId == 'none';
                                            final bool isUnlocked = isNone ||
                                                unlockedItems.contains(hatId);
                                            final bool isEquipped = isNone
                                                ? equippedHat == null
                                                : equippedHat == hatId;

                                            return _HatWardrobeCard(
                                              icon: hat['icon']!,
                                              title: hat['title']!,
                                              isUnlocked: isUnlocked,
                                              isEquipped: isEquipped,
                                              onTap: () async {
                                                unawaited(HapticFeedback
                                                    .selectionClick());
                                                final petDao =
                                                    ref.read(petDaoProvider);
                                                if (isEquipped && !isNone) {
                                                  await petDao.equipItem(
                                                      hatId: null);
                                                } else if (isUnlocked) {
                                                  await petDao.equipItem(
                                                      hatId: isNone
                                                          ? null
                                                          : hatId);
                                                } else if (context.mounted) {
                                                  unawaited(
                                                      ShopModal.show(context));
                                                }
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: 2, bottom: 8),
                                        child: Text(
                                          'Fondos del Santuario',
                                          style: TextStyle(
                                            fontFamily: ScFonts.ui,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: c.text2,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        height: 115,
                                        child: ListView.separated(
                                          scrollDirection: Axis.horizontal,
                                          itemCount:
                                              _availableBackgrounds.length,
                                          separatorBuilder: (_, _) =>
                                              const SizedBox(width: 10),
                                          itemBuilder: (context, index) {
                                            final bg =
                                                _availableBackgrounds[index];
                                            final String bgId = bg['id']!;
                                            final bool isUnlocked =
                                                unlockedItems.contains(bgId);
                                            final bool isEquipped =
                                                equippedBg == bgId;

                                            return _BackgroundWardrobeCard(
                                              icon: bg['icon']!,
                                              title: bg['title']!,
                                              isUnlocked: isUnlocked,
                                              isEquipped: isEquipped,
                                              onTap: () async {
                                                unawaited(HapticFeedback
                                                    .selectionClick());
                                                if (isUnlocked) {
                                                  await ref
                                                      .read(petDaoProvider)
                                                      .equipItem(bgId: bgId);
                                                } else if (context.mounted) {
                                                  unawaited(
                                                      ShopModal.show(context));
                                                }
                                              },
                                            );
                                          },
                                        ),
                                      ),

                                      const SizedBox(height: 24),

                                      // ==========================================
                                      // 5. Botón Principal: Tienda del Santuario
                                      // ==========================================
                                      InkWell(
                                        onTap: () {
                                          unawaited(
                                              HapticFeedback.mediumImpact());
                                          unawaited(ShopModal.show(context));
                                        },
                                        borderRadius: BorderRadius.circular(18),
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16, horizontal: 20),
                                          decoration: BoxDecoration(
                                            color: c.isFlat ? c.bg2 : c.accent,
                                            borderRadius:
                                                BorderRadius.circular(18),
                                            border: Border.all(
                                              color:
                                                  c.isFlat ? c.line2 : c.accent,
                                              width: c.isFlat ? 1.5 : 1.0,
                                            ),
                                            boxShadow: c.isFlat
                                                ? null
                                                : [
                                                    BoxShadow(
                                                      color: c.accent
                                                          .withValues(
                                                              alpha: 0.28),
                                                      blurRadius: 14,
                                                      offset:
                                                          const Offset(0, 5),
                                                    ),
                                                  ],
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                AppIcons.tienda,
                                                color: c.isFlat
                                                    ? c.text
                                                    : Colors.white,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 10),
                                              Flexible(
                                                child: Text(
                                                  'Tienda del Santuario',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontFamily:
                                                        ScFonts.display,
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.w800,
                                                    color: c.isFlat
                                                        ? c.text
                                                        : Colors.white,
                                                    letterSpacing: 0.3,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 12),

                                      // ==========================================
                                      // 6. Botón Secundario: Renombrar Mascota
                                      // ==========================================
                                      InkWell(
                                        onTap: () {
                                          unawaited(
                                              HapticFeedback.selectionClick());
                                          if (pet != null) {
                                            unawaited(_openRenamePetDialog(
                                                pet.petName));
                                          }
                                        },
                                        borderRadius:
                                            BorderRadius.circular(18),
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 14, horizontal: 20),
                                          decoration: BoxDecoration(
                                            color: c.isFlat ? c.bg3 : c.soft,
                                            borderRadius:
                                                BorderRadius.circular(18),
                                            border: Border.all(
                                              color: c.isFlat
                                                  ? c.line2
                                                  : c.line,
                                              width: c.isFlat ? 1.5 : 1.0,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                AppIcons.edit,
                                                color: c.isFlat
                                                    ? c.text
                                                    : c.accent,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                  'Renombrar Mascota',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontFamily: ScFonts.ui,
                                                    fontSize: 14,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    color: c.text,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Mini tarjeta de cabecera que muestra únicamente el símbolo y el valor numérico.
class _PetHeaderMetricCard extends StatelessWidget {
  const _PetHeaderMetricCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        decoration: BoxDecoration(
          color: c.bg2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: c.isFlat ? c.line2 : c.line,
            width: c.isFlat ? 1.5 : 1.1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 19,
              color: iconColor,
            ),
            const SizedBox(width: 7),
            Text(
              value,
              style: TextStyle(
                fontFamily: ScFonts.display,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: c.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Piquito triangular que conecta el globo de texto con el dragón.
class _SpeechBubbleTailPainter extends CustomPainter {
  const _SpeechBubbleTailPainter({
    required this.color,
    required this.borderColor,
    required this.borderWidth,
  });

  final Color color;
  final Color borderColor;
  final double borderWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width, 0);
    path.close();

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final borderPath = Path();
    borderPath.moveTo(0, 0);
    borderPath.lineTo(size.width / 2, size.height);
    borderPath.lineTo(size.width, 0);
    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _SpeechBubbleTailPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth;
  }
}

class _StatMiniCard extends StatelessWidget {
  const _StatMiniCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.progress,
    required this.progressColor,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String subtitle;
  final double progress;
  final Color progressColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: c.bg2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: c.isFlat ? c.line2 : c.line,
            width: c.isFlat ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 16),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: c.text3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: ScFonts.display,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: c.text,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: c.bg3,
                valueColor: AlwaysStoppedAnimation<Color>(
                    c.isFlat ? c.text : progressColor),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: ScFonts.ui,
                fontSize: 10,
                color: c.text2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: c.bg2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: c.isFlat ? c.line2 : c.line,
            width: c.isFlat ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: c.isFlat ? c.bg3 : color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border:
                    c.isFlat ? Border.all(color: c.line2, width: 1.2) : null,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: ScFonts.ui,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: c.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HatWardrobeCard extends StatelessWidget {
  const _HatWardrobeCard({
    required this.icon,
    required this.title,
    required this.isUnlocked,
    required this.isEquipped,
    required this.onTap,
  });

  final String icon;
  final String title;
  final bool isUnlocked;
  final bool isEquipped;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: BoxDecoration(
          color: isEquipped
              ? (c.isFlat ? c.bg3 : c.soft)
              : c.bg2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isEquipped ? c.accent : (c.isFlat ? c.line2 : c.line),
            width: isEquipped ? 2.0 : (c.isFlat ? 1.5 : 1.0),
          ),
          boxShadow: isEquipped && !c.isFlat
              ? [
                  BoxShadow(
                    color: c.accent.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.isFlat ? c.bg2 : c.bg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isEquipped ? c.accent : (c.isFlat ? c.line2 : c.line),
                  width: 1.0,
                ),
              ),
              child: Text(icon, style: const TextStyle(fontSize: 19)),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: ScFonts.ui,
                fontSize: 10.5,
                fontWeight: isEquipped ? FontWeight.w800 : FontWeight.w600,
                color: isEquipped ? c.accent : (isUnlocked ? c.text : c.text3),
              ),
            ),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isEquipped
                    ? (c.isFlat ? c.line2 : c.accent.withValues(alpha: 0.12))
                    : (isUnlocked
                        ? (c.isFlat ? c.bg3 : c.soft)
                        : (c.isFlat
                            ? c.bg3
                            : c.warning.withValues(alpha: 0.12))),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isEquipped ? 'Activo' : (isUnlocked ? 'Usar' : 'Bloqueado'),
                style: TextStyle(
                  fontFamily: ScFonts.ui,
                  fontSize: 9.0,
                  fontWeight: FontWeight.w700,
                  color: isEquipped
                      ? c.accent
                      : (isUnlocked
                          ? c.text3
                          : (c.isFlat ? c.text2 : c.warning)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackgroundWardrobeCard extends StatelessWidget {
  const _BackgroundWardrobeCard({
    required this.icon,
    required this.title,
    required this.isUnlocked,
    required this.isEquipped,
    required this.onTap,
  });

  final String icon;
  final String title;
  final bool isUnlocked;
  final bool isEquipped;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 124,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: BoxDecoration(
          color: isEquipped
              ? (c.isFlat ? c.bg3 : c.soft)
              : c.bg2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isEquipped ? c.accent : (c.isFlat ? c.line2 : c.line),
            width: isEquipped ? 2.0 : (c.isFlat ? 1.5 : 1.0),
          ),
          boxShadow: isEquipped && !c.isFlat
              ? [
                  BoxShadow(
                    color: c.accent.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.isFlat ? c.bg2 : c.bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isEquipped ? c.accent : (c.isFlat ? c.line2 : c.line),
                  width: 1.0,
                ),
              ),
              child: Text(icon, style: const TextStyle(fontSize: 19)),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: ScFonts.ui,
                fontSize: 10.5,
                fontWeight: isEquipped ? FontWeight.w800 : FontWeight.w600,
                color: isEquipped ? c.accent : (isUnlocked ? c.text : c.text3),
              ),
            ),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isEquipped
                    ? (c.isFlat ? c.line2 : c.accent.withValues(alpha: 0.12))
                    : (isUnlocked
                        ? (c.isFlat ? c.bg3 : c.soft)
                        : (c.isFlat
                            ? c.bg3
                            : c.warning.withValues(alpha: 0.12))),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isEquipped ? 'Activo' : (isUnlocked ? 'Usar' : 'Bloqueado'),
                style: TextStyle(
                  fontFamily: ScFonts.ui,
                  fontSize: 9.0,
                  fontWeight: FontWeight.w700,
                  color: isEquipped
                      ? c.accent
                      : (isUnlocked
                          ? c.text3
                          : (c.isFlat ? c.text2 : c.warning)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RenamePetDialog extends StatefulWidget {
  const _RenamePetDialog({
    required this.initialName,
    required this.onSave,
  });

  final String initialName;
  final Future<void> Function(String) onSave;

  @override
  State<_RenamePetDialog> createState() => _RenamePetDialogState();
}

class _RenamePetDialogState extends State<_RenamePetDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Dialog(
      backgroundColor: c.bg2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: c.isFlat ? c.line2 : c.line,
          width: c.isFlat ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(AppIcons.edit, color: c.accent, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Nombre de tu Dragón',
                  style: TextStyle(
                    fontFamily: ScFonts.display,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: c.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _ctrl,
              style: TextStyle(
                fontFamily: ScFonts.ui,
                fontSize: 15,
                color: c.text,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: c.isFlat ? c.bg3 : c.soft,
                hintText: 'Ej. Ignis, Draco, Ethan...',
                hintStyle: TextStyle(color: c.text3),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: c.isFlat ? c.line2 : c.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: c.isFlat ? c.line2 : c.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: c.accent, width: 1.8),
                ),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontWeight: FontWeight.w600,
                      color: c.text2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final clean = _ctrl.text.trim();
                    if (clean.isNotEmpty) {
                      await widget.onSave(clean);
                      if (context.mounted) Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
