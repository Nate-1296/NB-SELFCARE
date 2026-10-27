import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_tokens.dart';
import '../../../../shared/widgets/health_card.dart';

/// Invitación dominical a la revisión semanal con Nibi (docs/14 Fase 7).
class SundayCeremonyBanner extends StatelessWidget {
  const SundayCeremonyBanner({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    return HealthCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(ScSpace.m),
      backgroundColor: c.isFlat ? c.bg3 : c.soft,
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Icon(Icons.auto_awesome_rounded, color: c.isFlat ? c.text : c.accent),
          const SizedBox(width: ScSpace.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l10n.todaySundayTitle, style: context.text.titleMedium),
                Text(l10n.todaySundaySubtitle, style: context.text.bodySmall),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: c.text2),
        ],
      ),
    );
  }
}
