import 'package:flutter/material.dart';

import '../../../core/domain/metabolic_phase.dart';
import '../../../core/l10n/l10n.dart';
import '../../../shared/theme/sc_colors.dart';

extension MetabolicPhaseL10n on MetabolicPhase {
  String label(AppLocalizations l10n) => switch (this) {
        MetabolicPhase.anabolic => l10n.fastingPhaseAnabolic,
        MetabolicPhase.glycogenolysis => l10n.fastingPhaseGlycogenolysis,
        MetabolicPhase.fatBurning => l10n.fastingPhaseFatBurning,
        MetabolicPhase.ketosis => l10n.fastingPhaseKetosis,
        MetabolicPhase.autophagy => l10n.fastingPhaseAutophagy,
      };

  String description(AppLocalizations l10n) => switch (this) {
        MetabolicPhase.anabolic => l10n.fastingPhaseAnabolicInfo,
        MetabolicPhase.glycogenolysis => l10n.fastingPhaseGlycogenolysisInfo,
        MetabolicPhase.fatBurning => l10n.fastingPhaseFatBurningInfo,
        MetabolicPhase.ketosis => l10n.fastingPhaseKetosisInfo,
        MetabolicPhase.autophagy => l10n.fastingPhaseAutophagyInfo,
      };

  /// Color de la fase; en Modo Papel, tinta.
  Color color(ScColors c) {
    if (c.isFlat) return c.text;
    return switch (this) {
      MetabolicPhase.anabolic => c.water,
      MetabolicPhase.glycogenolysis => c.steps,
      MetabolicPhase.fatBurning => c.carbs,
      MetabolicPhase.ketosis => c.calories,
      MetabolicPhase.autophagy => c.fasting,
    };
  }
}
