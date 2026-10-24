import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum NibiMood {
  idle,
  happy,
  eating,
  drinking,
  sleeping,
  zen,
  workout,
  weighing,
  curious,
}

class AnimatedNibiView extends StatefulWidget {
  const AnimatedNibiView({
    super.key,
    required this.mood,
    this.equippedHatId,
    this.isEink = false,
    this.size = 220,
    this.onPet,
  });

  final NibiMood mood;
  final String? equippedHatId;
  final bool isEink;
  final double size;
  final VoidCallback? onPet;

  @override
  State<AnimatedNibiView> createState() => AnimatedNibiViewState();
}

class AnimatedNibiViewState extends State<AnimatedNibiView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatController;
  late final Animation<double> _floatAnimation;

  final List<_HeartParticle> _particles = [];
  final Random _rnd = Random();
  Timer? _particleTimer;
  DateTime? _lastPetAt;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _floatAnimation = Tween<double>(begin: -5.0, end: 5.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
    _syncAnimationMode();
  }

  @override
  void didUpdateWidget(covariant AnimatedNibiView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isEink != widget.isEink) {
      _syncAnimationMode();
    }
  }

  void _syncAnimationMode() {
    if (widget.isEink) {
      _floatController.stop();
      _floatController.value = 0.5;
      _particleTimer?.cancel();
      _particles.clear();
    } else if (!_floatController.isAnimating) {
      unawaited(_floatController.repeat(reverse: true));
    }
  }

  @override
  void dispose() {
    _particleTimer?.cancel();
    _floatController.dispose();
    super.dispose();
  }

  void _handleGesturePet() {
    final DateTime now = DateTime.now();
    if (_lastPetAt != null &&
        now.difference(_lastPetAt!).inMilliseconds < 600) {
      return;
    }
    _lastPetAt = now;
    triggerPetHearts();
    widget.onPet?.call();
  }

  void triggerPetHearts() {
    unawaited(HapticFeedback.lightImpact());
    if (widget.isEink) {
      return;
    }

    setState(() {
      for (int i = 0; i < 4; i++) {
        _particles.add(
          _HeartParticle(
            x: (_rnd.nextDouble() - 0.5) * (widget.size * 0.7),
            y: widget.size * 0.2,
            symbol: const ['💖', '💕', '✨', '🌸'][_rnd.nextInt(4)],
            createdAt: DateTime.now(),
          ),
        );
      }
    });

    _particleTimer?.cancel();
    _particleTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final now = DateTime.now();
      setState(() {
        _particles.removeWhere(
          (p) => now.difference(p.createdAt).inMilliseconds > 1200,
        );
      });
      if (_particles.isEmpty) {
        timer.cancel();
      }
    });
  }

  /// Mapeo canónico verificado de sprites limpios de Nibi (positividad radical).
  String _getSpritePath() {
    switch (widget.mood) {
      case NibiMood.idle:
        return 'assets/images/nibi_sprites/sprite_01.png';
      case NibiMood.workout:
        return 'assets/images/nibi_sprites/sprite_02.png';
      case NibiMood.zen:
        return 'assets/images/nibi_sprites/sprite_03.png';
      case NibiMood.drinking:
        return 'assets/images/nibi_sprites/sprite_04.png';
      case NibiMood.weighing:
        return 'assets/images/nibi_sprites/sprite_05.png';
      case NibiMood.curious:
        return 'assets/images/nibi_sprites/sprite_06.png';
      case NibiMood.happy:
        return 'assets/images/nibi_sprites/sprite_07.png';
      case NibiMood.eating:
        return 'assets/images/nibi_sprites/sprite_10.png';
      case NibiMood.sleeping:
        return 'assets/images/nibi_hero.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final String spriteAsset = _getSpritePath();
    final double s = widget.size;

    return GestureDetector(
      onTap: _handleGesturePet,
      onPanUpdate: (_) => _handleGesturePet(),
      child: SizedBox(
        width: s,
        height: s,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (!widget.isEink)
              Positioned(
                bottom: 8,
                child: Container(
                  width: s * 0.55,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.08),
                    borderRadius:
                        BorderRadius.all(Radius.elliptical(s * 0.55, 16)),
                  ),
                ),
              ),
            AnimatedBuilder(
              animation: _floatAnimation,
              builder: (context, child) {
                final double dy =
                    (widget.isEink || widget.mood == NibiMood.sleeping)
                        ? 0.0
                        : _floatAnimation.value;
                return Transform.translate(
                  offset: Offset(0, dy),
                  child: child,
                );
              },
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Image.asset(
                    spriteAsset,
                    width: s * 0.88,
                    height: s * 0.88,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, _, _) => Image.asset(
                      'assets/images/nibi_hero.png',
                      width: s * 0.88,
                      height: s * 0.88,
                      fit: BoxFit.contain,
                    ),
                  ),
                  if (widget.equippedHatId != null &&
                      widget.equippedHatId != 'none' &&
                      widget.mood != NibiMood.sleeping)
                    Positioned(
                      top: 4,
                      child: _buildHatOverlay(widget.equippedHatId!, s),
                    ),
                ],
              ),
            ),
            if (!widget.isEink)
              ..._particles.map((p) {
                final int elapsed =
                    DateTime.now().difference(p.createdAt).inMilliseconds;
                final double progress = (elapsed / 1200.0).clamp(0.0, 1.0);
                final double currentY = p.y - (progress * 70.0);
                final double opacity = (1.0 - progress).clamp(0.0, 1.0);

                return Positioned(
                  left: (s / 2) + p.x,
                  top: currentY,
                  child: Opacity(
                    opacity: opacity,
                    child: Text(
                      p.symbol,
                      style: TextStyle(fontSize: 22 + (progress * 8)),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildHatOverlay(String hatId, double s) {
    final String emoji;
    switch (hatId) {
      case 'hat_chef':
        emoji = '👨‍🍳';
      case 'hat_headband':
        emoji = '🏃';
      case 'hat_zen_halo':
        emoji = '✨';
      case 'hat_crown':
        emoji = '👑';
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: widget.isEink ? 1.0 : 0.9),
        shape: BoxShape.circle,
        border: widget.isEink
            ? Border.all(color: const Color(0xFF121212), width: 1.5)
            : null,
      ),
      child: Text(emoji, style: TextStyle(fontSize: s * 0.16)),
    );
  }
}

class _HeartParticle {
  _HeartParticle({
    required this.x,
    required this.y,
    required this.symbol,
    required this.createdAt,
  });

  final double x;
  final double y;
  final String symbol;
  final DateTime createdAt;
}
