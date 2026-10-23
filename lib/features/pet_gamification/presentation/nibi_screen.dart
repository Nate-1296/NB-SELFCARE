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
import '../../../shared/utils/date_time_extensions.dart';
import '../../../shared/widgets/app_icons.dart';
import '../../../shared/widgets/chip_pill.dart';
import '../../../shared/widgets/health_card.dart';
import '../../../shared/widgets/section_head.dart';
import '../../../shared/widgets/top_bar.dart';
import 'shop_modal.dart';
import 'widgets/animated_nibi_view.dart';

/// Pantalla dedicada al santuario de Nibi (estilo Pou / Widgetable / Tamagotchi).
///
/// La mascota es 100% reactiva a la biometría del usuario, fomenta el autocuidado
/// con positividad radical (nunca muere ni enferma) y gestiona el libro mayor de monedas.
class NibiScreen extends ConsumerStatefulWidget {
  const NibiScreen({super.key});

  @override
  ConsumerState<NibiScreen> createState() => _NibiScreenState();
}

class _NibiScreenState extends ConsumerState<NibiScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final Animation<double> _bounceAnimation;
  final GlobalKey<AnimatedNibiViewState> _nibiKey = GlobalKey<AnimatedNibiViewState>();

  String? _dialogText;
  bool _isPetting = false;
  NibiMood _currentMood = NibiMood.idle;

  final List<Map<String, String>> _availableHats = [
    {'id': 'none', 'title': 'Ninguno', 'icon': '🚫'},
    {'id': 'hat_chef', 'title': 'Chef Saludable', 'icon': '👨‍🍳'},
    {'id': 'hat_headband', 'title': 'Entrenamiento', 'icon': '🏃'},
    {'id': 'hat_zen_halo', 'title': 'Halo Zen', 'icon': '✨'},
    {'id': 'hat_crown', 'title': 'Corona Real', 'icon': '👑'},
  ];

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 50),
    ]).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void _openRenamePetDialog(String currentName) {
    final textCtrl = TextEditingController(text: currentName);
    unawaited(showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nombre de tu Compañero'),
        content: TextField(
          controller: textCtrl,
          decoration: const InputDecoration(
            labelText: 'Nombre personalizado',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              final newName = textCtrl.text.trim();
              if (newName.isNotEmpty) {
                await ref.read(petDaoProvider).updatePetName(newName);
                if (ctx.mounted) Navigator.of(ctx).pop();
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ));
  }

  Future<void> _interactWithPet({
    required PetStatusData pet,
    double? sleepHours,
    int? waterMl,
    int? waterGoalMl,
    bool isKetosis = false,
  }) async {
    _nibiKey.currentState?.triggerPetHearts();
    _bounceController.forward(from: 0.0);

    setState(() {
      _isPetting = true;
      _currentMood = NibiMood.happy;
      _dialogText = '¡A ${pet.petName} le encantan tus caricias! 💖✨';
    });

    // Otorgar pequeña recompensa en monedas por interactuar
    await ref.read(petDaoProvider).grantDailyReward(
      dateKey: DateTime.now().dateKey,
      actionType: 'pet_interact',
      baseAmount: 5,
    );

    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) {
        setState(() {
          _currentMood = NibiMood.idle;
          _isPetting = false;
        });
      }
    });
  }

  void _showZenBreathingDialog(BuildContext context) {
    unawaited(showDialog<void>(
      context: context,
      builder: (ctx) => _ZenBreathingDialog(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final String todayKey = DateTime.now().dateKey;

    final fastingDao = ref.watch(fastingDaoProvider);
    final hydrationDao = ref.watch(hydrationDaoProvider);
    final healthSyncDao = ref.watch(healthSyncDaoProvider);

    final AsyncValue<PetStatusData?> petAsync = ref.watch(petStatusStreamProvider);
    final AsyncValue<UserProfile?> profileAsync = ref.watch(userProfileStreamProvider);

    return StreamBuilder<FastingSession?>(
      stream: fastingDao.watchActiveSession(),
      builder: (context, fastingSnap) {
        return StreamBuilder<int>(
          stream: hydrationDao.watchTotalWaterMl(todayKey),
          builder: (context, waterSnap) {
            return StreamBuilder<DailySummary?>(
              stream: healthSyncDao.watchDailySummary(todayKey),
              builder: (context, summarySnap) {
                final pet = petAsync.value;
                final profile = profileAsync.value;
                final activeFast = fastingSnap.data;
                final summary = summarySnap.data;

                final int waterMl = waterSnap.data ?? 0;
                final int waterGoalMl = profile?.dailyWaterGoalMl ?? 2500;
                final double sleepGoal = profile?.dailySleepGoalHours ?? 7.5;
                final double sleepHours = (summary?.sleepDurationMinutes ?? 0) / 60.0;
                final bool isSleepGoalMet = sleepHours >= sleepGoal && sleepHours > 0;

                final bool isKetosis = activeFast != null &&
                    DateTime.now().difference(activeFast.startedAt).inHours >= 12;

                final double hydrationRatio =
                    waterGoalMl > 0 ? (waterMl / waterGoalMl).clamp(0.0, 1.0) : 0.5;

                final int coins = pet?.coinsBalance ?? 0;
                final int streak = pet?.currentStreakDays ?? 0;
                final int shields = pet?.streakShieldsAvailable ?? 0;
                final String? equippedHat = pet?.equippedHatId;

    final List<String> unlockedItems = <String>['none'];
    if (pet?.unlockedItemsJson != null) {
      try {
        final parsed = jsonDecode(pet!.unlockedItemsJson) as List<dynamic>;
        unlockedItems.addAll(parsed.map((e) => e.toString()));
      } catch (_) {}
    }

    final String initialDialog = _dialogText ??
        (isKetosis
            ? '¡Siento una claridad mental increíble por el ayuno! ✨'
            : (hydrationRatio >= 1.0
                ? '¡Completaste tu hidratación de hoy! Te sientes genial 💧'
                : '¡Toca a Nibi para recibir un consejo de bienestar! 🌿'));

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            TopBar(
              title: pet?.petName ?? 'Nibi',
              avatarText: '🐾',
              leading: GestureDetector(
                onTap: () {
                  if (pet != null) _openRenamePetDialog(pet.petName);
                },
                child: Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.bg3,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: c.isFlat ? c.line2 : c.line,
                      width: c.isFlat ? 1.5 : 1.2,
                    ),
                  ),
                  child: const Text('🐾', style: TextStyle(fontSize: 18)),
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit_outlined, size: 20, color: c.text2),
                    tooltip: 'Cambiar nombre',
                    onPressed: () {
                      if (pet != null) _openRenamePetDialog(pet.petName);
                    },
                  ),
                  ChipPill(
                    icon: AppIcons.moneda,
                    iconColor: const Color(0xFFFFB300),
                    label: '$coins',
                    onTap: () => ShopModal.show(context),
                  ),
                  const SizedBox(width: 8),
                  ChipPill(
                    icon: AppIcons.racha,
                    iconColor: const Color(0xFFFF7043),
                    label: '${streak}d',
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(AppIcons.tienda, color: c.accent),
                    tooltip: 'Tienda de Recompensas',
                    onPressed: () => ShopModal.show(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                children: <Widget>[
                  // 1. Escenario Principal de Nibi (Interactive Pet Stage)
                  HealthCard(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    child: Column(
                      children: [
                        // Diálogo / Globo de pensamiento de Nibi
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: c.bg2,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: c.line),
                          ),
                          child: Row(
                            children: [
                              Icon(AppIcons.chispa, color: c.accent, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _dialogText ?? initialDialog,
                                  style: TextStyle(
                                    fontFamily: ScFonts.ui,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: c.text,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Mascota Interactiva con Sprites Animados
                        ScaleTransition(
                          scale: _bounceAnimation,
                          child: AnimatedNibiView(
                            key: _nibiKey,
                            mood: _currentMood,
                            equippedHatId: equippedHat,
                            isEink: c.isFlat,
                            size: 210,
                            onPet: () {
                              if (pet != null) {
                                unawaited(_interactWithPet(
                                  pet: pet,
                                  sleepHours: sleepHours > 0 ? sleepHours : null,
                                  waterMl: waterMl,
                                  waterGoalMl: waterGoalMl,
                                  isKetosis: isKetosis,
                                ));
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _isPetting
                              ? '¡A ${pet?.petName ?? "Nibi"} le encantan tus caricias! 💖'
                              : 'Toca o acaricia para interactuar',
                          style: TextStyle(
                            fontFamily: ScFonts.ui,
                            fontSize: 12,
                            color: c.text3,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Estado de Bienestar (Vitals / Tamagotchi Stats)
                  const SectionHead(
                    title: 'Estado de Nibi',
                    subtitle: 'Basado en tus hábitos de hoy',
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _StatMiniCard(
                          icon: AppIcons.gota,
                          iconColor: c.water,
                          title: 'Agua',
                          value: '${(hydrationRatio * 100).toInt()}%',
                          subtitle: '$waterMl / $waterGoalMl ml',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatMiniCard(
                          icon: AppIcons.sueno,
                          iconColor: const Color(0xFF9FA8DA),
                          title: 'Sueño',
                          value: sleepHours > 0 ? '${sleepHours.toStringAsFixed(1)}h' : '-- h',
                          subtitle: isSleepGoalMet
                              ? 'x1.5 🪙 activo'
                              : 'Meta: ${sleepGoal.toStringAsFixed(1)}h',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatMiniCard(
                          icon: AppIcons.escudo,
                          iconColor: const Color(0xFF42A5F5),
                          title: 'Escudos',
                          value: '$shields',
                          subtitle: shields > 0 ? 'Protegido' : '0 activos',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 3. Cuidados y Acciones Rápidas
                  const SectionHead(
                    title: 'Cuidados de Nibi',
                    subtitle: 'Actividades para consentir a tu compañero',
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionTile(
                          icon: AppIcons.corazon,
                          color: const Color(0xFFEC407A),
                          title: 'Acariciar',
                          onTap: () {
                            if (pet != null) {
                              unawaited(_interactWithPet(
                                pet: pet,
                                sleepHours: sleepHours > 0 ? sleepHours : null,
                                waterMl: waterMl,
                                waterGoalMl: waterGoalMl,
                                isKetosis: isKetosis,
                              ));
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionTile(
                          icon: AppIcons.gota,
                          color: c.water,
                          title: 'Dar Agua',
                          onTap: () async {
                            _nibiKey.currentState?.triggerPetHearts();
                            setState(() {
                              _currentMood = NibiMood.drinking;
                              _dialogText = '¡Glup, glup! Hidratándose juntos con alegría 💧';
                            });
                            final hydrationDao = ref.read(hydrationDaoProvider);
                            await hydrationDao.logGlass(
                              dateKey: todayKey,
                              volumeMl: 250,
                              dailyGoalMl: waterGoalMl,
                            );
                            Future.delayed(const Duration(milliseconds: 2500), () {
                              if (mounted) setState(() => _currentMood = NibiMood.idle);
                            });
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('¡Le diste un vaso de agua (+250 ml) a ${pet?.petName ?? "Nibi"}! 💧'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionTile(
                          icon: AppIcons.comer,
                          color: c.calories,
                          title: 'Alimentar',
                          onTap: () {
                            _nibiKey.currentState?.triggerPetHearts();
                            setState(() {
                              _currentMood = NibiMood.eating;
                              _dialogText = '¡Ñam! Qué delicia de comida saludable y nutritiva 🍎';
                            });
                            Future.delayed(const Duration(milliseconds: 2500), () {
                              if (mounted) setState(() => _currentMood = NibiMood.idle);
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionTile(
                          icon: Icons.self_improvement_rounded,
                          color: c.accent,
                          title: 'Zen 60s',
                          onTap: () {
                            setState(() {
                              _currentMood = NibiMood.zen;
                              _dialogText = 'Pausa zen: inhala paz... exhala tensión... 🧘';
                            });
                            _showZenBreathingDialog(context);
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 4. Armario de Sombreros (Live Wardrobe Selector)
                  SectionHead(
                    title: 'Armario de Sombreros',
                    actionLabel: 'Ver Tienda',
                    onAction: () => ShopModal.show(context),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 94,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _availableHats.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final hat = _availableHats[index];
                        final String hatId = hat['id']!;
                        final bool isNone = hatId == 'none';
                        final bool isUnlocked = isNone || unlockedItems.contains(hatId);
                        final bool isEquipped = isNone ? equippedHat == null : equippedHat == hatId;

                        return GestureDetector(
                          onTap: () async {
                            await HapticFeedback.selectionClick();
                            final petDao = ref.read(petDaoProvider);
                            if (isEquipped) {
                              await petDao.equipItem(hatId: null);
                            } else if (isUnlocked) {
                              await petDao.equipItem(hatId: isNone ? null : hatId);
                            } else {
                              if (context.mounted) {
                                unawaited(ShopModal.show(context));
                              }
                            }
                          },
                          child: Container(
                            width: 84,
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                            decoration: BoxDecoration(
                              color: isEquipped ? c.accent.withValues(alpha: 0.15) : c.bg2,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isEquipped ? c.accent : c.line,
                                width: isEquipped ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  hat['icon']!,
                                  style: const TextStyle(fontSize: 24),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  hat['title']!,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: ScFonts.ui,
                                    fontSize: 10,
                                    fontWeight: isEquipped ? FontWeight.bold : FontWeight.w500,
                                    color: isEquipped ? c.accent : (isUnlocked ? c.text : c.text3),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Icon(
                                  isEquipped
                                      ? Icons.check_circle_rounded
                                      : (isUnlocked ? Icons.radio_button_unchecked : Icons.lock_rounded),
                                  size: 14,
                                  color: isEquipped ? c.accent : (isUnlocked ? c.text3 : Colors.amber),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 5. Banner de la Tienda de Recompensas
                  HealthCard(
                    padding: const EdgeInsets.all(16),
                    onTap: () => ShopModal.show(context),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.storefront_rounded, color: Colors.amber, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tienda de Recompensas',
                                style: TextStyle(
                                  fontFamily: ScFonts.display,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: c.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Canjea monedas por escudos y cosméticos',
                                style: TextStyle(
                                  fontFamily: ScFonts.ui,
                                  fontSize: 12,
                                  color: c.text2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, size: 16, color: c.text3),
                      ],
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
}
}

class _StatMiniCard extends StatelessWidget {
  const _StatMiniCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.bg2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontFamily: ScFonts.ui,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: c.text3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontFamily: ScFonts.display,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: c.text,
            ),
          ),
          const SizedBox(height: 2),
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
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: c.bg2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.line),
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: ScFonts.ui,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZenBreathingDialog extends StatefulWidget {
  @override
  State<_ZenBreathingDialog> createState() => _ZenBreathingDialogState();
}

class _ZenBreathingDialogState extends State<_ZenBreathingDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  String _phase = 'Inhala profundamente';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _controller.addStatusListener((status) {
      if (mounted) {
        setState(() {
          _phase = status == AnimationStatus.forward
              ? 'Inhala profundamente...'
              : 'Exhala suavemente...';
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;

    return Dialog(
      backgroundColor: c.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Respiración Consciente',
              style: TextStyle(
                fontFamily: ScFonts.display,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: c.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Toma un minuto para conectar contigo y calmar el sistema nervioso.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: ScFonts.ui,
                fontSize: 12,
                color: c.text2,
              ),
            ),
            const SizedBox(height: 28),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final scale = 1.0 + (_controller.value * 0.35);
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.accent.withValues(alpha: 0.15),
                      border: Border.all(color: c.accent, width: 2),
                    ),
                    child: Center(
                      child: Icon(Icons.spa_rounded, color: c.accent, size: 44),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 28),
            Text(
              _phase,
              style: TextStyle(
                fontFamily: ScFonts.display,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: c.accent,
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Completar',
                style: TextStyle(
                  fontFamily: ScFonts.ui,
                  fontWeight: FontWeight.bold,
                  color: c.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
