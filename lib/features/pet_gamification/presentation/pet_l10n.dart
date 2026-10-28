import '../../../core/l10n/l10n.dart';
import '../domain/nibi_activity.dart';
import '../domain/pet_catalog.dart';

/// Textos visibles del catálogo y de los saludos de Nibi.
extension PetItemL10n on PetItem {
  String title(AppLocalizations l10n) => switch (id) {
        'shield_daily' => l10n.petItemShieldDaily,
        'shield_weekend' => l10n.petItemShieldWeekend,
        'hat_party' => l10n.petItemHatParty,
        'hat_chef' => l10n.petItemHatChef,
        'hat_beanie' => l10n.petItemHatBeanie,
        'hat_cap' => l10n.petItemHatCap,
        'hat_headband' => l10n.petItemHatHeadband,
        'hat_flowers' => l10n.petItemHatFlowers,
        'hat_zen_halo' => l10n.petItemHatZenHalo,
        'hat_crown' => l10n.petItemHatCrown,
        'hat_wizard' => l10n.petItemHatWizard,
        'acc_bowtie' => l10n.petItemAccBowtie,
        'acc_scarf' => l10n.petItemAccScarf,
        'acc_bell' => l10n.petItemAccBell,
        'acc_glasses' => l10n.petItemAccGlasses,
        'acc_sunglasses' => l10n.petItemAccSunglasses,
        'color_jade' => l10n.petItemColorJade,
        'color_ocean' => l10n.petItemColorOcean,
        'color_lilac' => l10n.petItemColorLilac,
        'color_coral' => l10n.petItemColorCoral,
        'color_ember' => l10n.petItemColorEmber,
        'color_midnight' => l10n.petItemColorMidnight,
        'color_gold' => l10n.petItemColorGold,
        'bg_zen_garden' => l10n.petItemBgZenGarden,
        'bg_beach' => l10n.petItemBgBeach,
        'bg_forest' => l10n.petItemBgForest,
        'bg_mountain_dawn' => l10n.petItemBgMountainDawn,
        'bg_snow' => l10n.petItemBgSnow,
        'bg_starry_dojo' => l10n.petItemBgStarryDojo,
        'bg_sakura' => l10n.petItemBgSakura,
        'bg_space' => l10n.petItemBgSpace,
        _ => l10n.petItemBgDefaultRoom,
      };
}

extension NibiActivityL10n on NibiActivity {
  /// Lo que Nibi dice en el escenario según lo que está haciendo.
  String speech(AppLocalizations l10n) => switch (this) {
        NibiActivity.idle => l10n.nibiSayIdle,
        NibiActivity.happy => l10n.nibiSayHappy,
        NibiActivity.celebrating => l10n.nibiSayCelebrating,
        NibiActivity.zen => l10n.nibiSayZen,
        NibiActivity.sleeping => l10n.nibiSaySleeping,
        NibiActivity.curious => l10n.nibiSayCurious,
        NibiActivity.drinking => l10n.nibiSayWater,
        NibiActivity.eating => l10n.nibiSaySnack,
        NibiActivity.playing => l10n.nibiSayPlay,
        NibiActivity.workout => l10n.nibiSayHappy,
        NibiActivity.weighing => l10n.nibiSayIdle,
      };
}

extension NibiReactionL10n on NibiReaction {
  /// Lo que dice al tocarlo (las manías no se anuncian).
  String speech(AppLocalizations l10n) => switch (this) {
        NibiReaction.pat => l10n.nibiSayPat,
        NibiReaction.giggle => l10n.nibiSayGiggle,
        NibiReaction.spin => l10n.nibiSaySpin,
        NibiReaction.hop => l10n.nibiSayHop,
        NibiReaction.puff => l10n.nibiSayPuff,
        NibiReaction.purr => l10n.nibiSayPurr,
        NibiReaction.yawn || NibiReaction.lookAround || NibiReaction.stretch || NibiReaction.snort => l10n.nibiSayIdle,
      };
}
