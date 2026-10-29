import 'package:flutter/material.dart';

import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_tokens.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/card_header.dart';
import '../../../../../shared/widgets/health_card.dart';
import '../../../../../shared/widgets/quick_action_button.dart';

/// Pesaje sin báscula inteligente: el peso a mano y la cinta métrica.
class ManualWeighInCard extends StatelessWidget {
  const ManualWeighInCard({super.key, required this.onManual, required this.onTape});

  final VoidCallback onManual;
  final VoidCallback onTape;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    return HealthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          CardHeader(
            icon: AppIcons.bascula,
            title: l10n.cuerpoManualTitle,
            subtitle: l10n.cuerpoManualHint,
          ),
          const SizedBox(height: ScSpace.m),
          Row(
            children: <Widget>[
              Expanded(
                child: QuickActionButton(
                  emphasized: true,
                  icon: Icons.edit_outlined,
                  label: l10n.cuerpoManualLog,
                  onPressed: onManual,
                ),
              ),
              const SizedBox(width: ScSpace.s),
              Expanded(
                child: QuickActionButton(
                  tone: c.water,
                  icon: Icons.straighten_rounded,
                  label: l10n.cuerpoTapeButton,
                  onPressed: onTape,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
