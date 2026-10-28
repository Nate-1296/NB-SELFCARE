import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock/clock.dart';
import '../../../core/database/app_database.dart';
import '../../../shared/utils/current_date_provider.dart';
import '../../../shared/utils/date_time_extensions.dart';
import '../../body_metrics/application/body_queries.dart';
import '../../fasting/application/fasting_queries.dart';
import '../../nutrition_hydration/application/nutrition_queries.dart';
import '../../profile_goals/application/profile_queries.dart';
import '../../today/application/today_queries.dart';
import '../domain/nibi_activity.dart';
import '../domain/pet_catalog.dart';
import 'pet_queries.dart';

/// Todo lo que la pantalla de Nibi necesita, combinado en un solo modelo
/// (antes eran cinco `StreamBuilder` anidados leyendo DAOs).
class NibiOverview {
  const NibiOverview({
    required this.pet,
    required this.mood,
    required this.waterMl,
    required this.waterGoalMl,
    required this.sleepHours,
    required this.sleepGoalHours,
    required this.mealsLogged,
    required this.unlocked,
  });

  final PetStatusData pet;
  final NibiMood mood;
  final int waterMl;
  final int waterGoalMl;
  final double sleepHours;
  final double sleepGoalHours;
  final int mealsLogged;

  /// Artículos permanentes desbloqueados (incluye el hábitat inicial).
  final Set<String> unlocked;

  String get habitatId => PetCatalog.validId(pet.equippedBackgroundId, PetItemKind.habitat) ?? PetCatalog.defaultHabitat;
  String? get hatId => PetCatalog.validId(pet.equippedHatId, PetItemKind.hat);
  NibiLook get look => nibiLookOf(pet);
  double get hydrationRatio => waterGoalMl > 0 ? (waterMl / waterGoalMl).clamp(0.0, 1.0) : 0;
  bool get sleepGoalMet => sleepHours > 0 && sleepHours >= sleepGoalHours;
  bool owns(PetItem item) => item.isConsumable || unlocked.contains(item.id);

  /// Si el cosmético está puesto ahora mismo.
  bool isEquipped(PetItem item) => switch (item.kind) {
        PetItemKind.hat => look.hatId == item.id,
        PetItemKind.accessory => look.accessoryId == item.id,
        PetItemKind.color => look.colorId == item.id,
        PetItemKind.habitat => habitatId == item.id,
        PetItemKind.shield => false,
      };
}

/// Lo que lleva puesto la mascota; ids desconocidos se ignoran.
NibiLook nibiLookOf(PetStatusData? pet) => NibiLook(
      hatId: PetCatalog.validId(pet?.equippedHatId, PetItemKind.hat),
      accessoryId: PetCatalog.validId(pet?.equippedAccessoryId, PetItemKind.accessory),
      colorId: PetCatalog.validId(pet?.equippedColorId, PetItemKind.color) ?? PetCatalog.defaultColor,
    );

/// Aspecto de Nibi para cualquier pantalla (Hoy, Cuerpo, avatar).
final nibiLookProvider = Provider<NibiLook>((Ref ref) => nibiLookOf(ref.watch(petStatusStreamProvider).value));

/// Artículos desbloqueados guardados como JSON; un valor corrupto no rompe nada.
Set<String> decodeUnlockedItems(String raw) {
  final Set<String> items = <String>{...PetCatalog.starterItems};
  try {
    final Object? decoded = jsonDecode(raw);
    if (decoded is List<Object?>) items.addAll(decoded.whereType<String>());
  } on FormatException {
    return items;
  }
  return items;
}

final nibiOverviewProvider = Provider<AsyncValue<NibiOverview?>>((Ref ref) {
  final String today = ref.watch(currentDateProvider).dateKey;
  final AsyncValue<PetStatusData?> pet = ref.watch(petStatusStreamProvider);
  final AsyncValue<UserProfile?> profile = ref.watch(userProfileStreamProvider);
  final AsyncValue<DailySummary?> summary = ref.watch(dailySummaryProvider(today));
  final AsyncValue<List<HydrationLog>> water = ref.watch(waterLogsForDateProvider(today));
  final AsyncValue<List<FoodLog>> meals = ref.watch(foodLogsForDateProvider(today));
  final AsyncValue<List<WorkoutBlock>> workouts = ref.watch(workoutsForDateProvider(today));
  final AsyncValue<FastingSession?> fast = ref.watch(activeFastingSessionStreamProvider);

  for (final AsyncValue<Object?> v in <AsyncValue<Object?>>[pet, profile, summary, water, meals, workouts, fast]) {
    if (v.hasError) return AsyncValue<NibiOverview?>.error(v.error!, v.stackTrace ?? StackTrace.empty);
  }
  if (!pet.hasValue || !profile.hasValue) return const AsyncValue<NibiOverview?>.loading();
  final PetStatusData? p = pet.value;
  if (p == null) return const AsyncValue<NibiOverview?>.data(null);

  final DateTime now = ref.watch(clockProvider).now();
  final int waterMl = (water.value ?? const <HydrationLog>[]).fold(0, (int s, HydrationLog l) => s + l.volumeMl);
  final int waterGoal = profile.value?.dailyWaterGoalMl ?? 2500;
  final double sleepHours = (summary.value?.sleepDurationMinutes ?? 0) / 60;
  final double sleepGoal = profile.value?.dailySleepGoalHours ?? 7.5;
  final FastingSession? activeFast = fast.value;
  final int mealsLogged = (meals.value ?? const <FoodLog>[]).length;

  final NibiMood mood = NibiMoodResolver.resolve(
    NibiVitals(
      hour: now.hour,
      hydrationRatio: waterGoal > 0 ? waterMl / waterGoal : 0,
      sleptWell: sleepHours > 0 && sleepHours >= sleepGoal,
      fastingHours: activeFast == null ? null : now.difference(activeFast.startedAt).inMinutes / 60,
      workedOutToday: (workouts.value ?? const <WorkoutBlock>[]).isNotEmpty,
      streakDays: p.currentStreakDays,
      mealsLoggedToday: mealsLogged,
    ),
  );

  return AsyncValue<NibiOverview?>.data(
    NibiOverview(
      pet: p,
      mood: mood,
      waterMl: waterMl,
      waterGoalMl: waterGoal,
      sleepHours: sleepHours,
      sleepGoalHours: sleepGoal,
      mealsLogged: mealsLogged,
      unlocked: decodeUnlockedItems(p.unlockedItemsJson),
    ),
  );
});
