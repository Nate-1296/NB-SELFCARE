import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/pet_dao.dart';
import '../../../../shared/widgets/nxtpaper_card.dart';
import '../../../pet_gamification/presentation/shop_modal.dart';
import '../../../pet_gamification/presentation/widgets/procedural_pet_canvas.dart';

/// Widget interactivo del hábitat de la mascota Nibi con burbuja de diálogo contextual.
class PetHabitatWidget extends ConsumerWidget {
  const PetHabitatWidget({
    required this.profile,
    super.key,
    this.isFastingKetosis = false,
    this.hydrationRatio = 0.8,
    this.isWeighingIn = false,
  });

  final UserProfile profile;
  final bool isFastingKetosis;
  final double hydrationRatio;
  final bool isWeighingIn;

  String _getDeterministicDialogue(PetStatusData? pet) {
    final int streak = pet?.currentStreakDays ?? 0;
    if (isFastingKetosis) {
      return '¡Cetosis activa! Tu cuerpo está renovando células con autofagia profunda ✨';
    }
    if (hydrationRatio >= 1.0) {
      return '¡Meta de agua completada! Tu cuerpo y tu energía te lo agradecen 💧';
    }
    if (streak > 3) {
      return '¡$streak días de racha imparable! Cuidarte es tu mejor hábito 🌟';
    }
    return '¡Hola, ${profile.name}! Estoy listo para acompañar tu día de bienestar 🌿';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final String engine = ref.watch(themeEngineProvider);
    final bool isEink = engine == 'nxtpaper_eink';
    final AsyncValue<PetStatusData?> petAsync = ref.watch(petStatusStreamProvider);

    final PetStatusData? pet = petAsync.asData?.value;
    final String dialogue = _getDeterministicDialogue(pet);

    return NxtpaperCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.favorite_rounded, color: Colors.pinkAccent, size: 20),
                  const SizedBox(width: 6.0),
                  Text(
                    'Nibi · Tu Compañero de Hábitos',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              FilledButton.tonalIcon(
                onPressed: () => ShopModal.show(context),
                icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                label: const Text('Tienda'),
                style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
            ],
          ),
          const SizedBox(height: 12.0),

          // Burbuja de diálogo contextual
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: isEink
                  ? theme.colorScheme.surface
                  : theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16.0),
              border: isEink ? Border.all(color: theme.colorScheme.outline, width: 1.2) : null,
            ),
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Colors.teal),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text(
                    dialogue,
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16.0),

          // Mascota Procedural a 60 fps
          Center(
            child: ProceduralPetCanvas(
              isFastingKetosis: isFastingKetosis,
              hydrationRatio: hydrationRatio,
              sleepHours: profile.dailySleepGoalHours,
              isWeighingIn: isWeighingIn,
              equippedHatId: pet?.equippedHatId,
              isEink: isEink,
              size: 130.0,
            ),
          ),
        ],
      ),
    );
  }
}
