import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_theme.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/health_card.dart';
import '../../../../../shared/widgets/section_head.dart';
import '../../../application/profile_service.dart';

/// Báscula y Health Connect.
class DevicesSection extends ConsumerWidget {
  const DevicesSection({
    super.key,
    required this.profile,
    required this.hasHealthConnect,
    required this.onConnectHealth,
  });

  final UserProfile? profile;
  final bool hasHealthConnect;
  final VoidCallback onConnectHealth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHead(
          title: context.l10n.settingsDispositivosYConectividad,
          subtitle: context.l10n.settingsBasculaXiaomiBleYPuente,
          padding: const EdgeInsets.symmetric(vertical: 4),
        ),
        const SizedBox(height: 8),
        HealthCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: <Widget>[
              // Báscula Xiaomi
              Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: c.isFlat ? c.bg3 : c.soft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: c.isFlat ? c.line2 : c.accent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Icon(AppIcons.bascula, color: c.accent, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          context.l10n.settingsXiaomiMiBodyCompositionScale,
                          style: TextStyle(
                            fontFamily: ScFonts.ui,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: c.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          (profile?.scaleMacAddress?.isNotEmpty ?? false)
                              ? context.l10n.settingsVinculada(profile!.scaleMacAddress!)
                              : context.l10n.settingsEscaneoPasivoDisponibleEnCuerpo,
                          style: TextStyle(fontFamily: ScFonts.ui, fontSize: 11.5, color: c.text2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (profile?.scaleMacAddress != null && profile!.scaleMacAddress!.isNotEmpty)
                    OutlinedButton(
                      onPressed: () async {
                        unawaited(HapticFeedback.selectionClick());
                        await ref
                            .read(profileServiceProvider)
                            .update(
                              const UserProfilesCompanion(scaleMacAddress: drift.Value(null)),
                            );
                      },
                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                      child: Text(context.l10n.settingsOlvidar),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: c.bg3,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: c.isFlat ? c.line2 : c.line),
                      ),
                      child: Text(
                        context.l10n.settingsBleListo,
                        style: TextStyle(
                          fontFamily: ScFonts.ui,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: c.text2,
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, color: c.line),
              ),
              // Health Connect
              Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: c.isFlat ? c.bg3 : c.soft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: c.isFlat ? c.line2 : c.accent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Icon(AppIcons.corazon, color: c.accent, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          context.l10n.settingsAndroidHealthConnect,
                          style: TextStyle(
                            fontFamily: ScFonts.ui,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: c.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasHealthConnect
                              ? context.l10n.settingsSincronizadoPesoGrasaPasosY
                              : context.l10n.settingsPuenteLocalNoConectadoAun,
                          style: TextStyle(fontFamily: ScFonts.ui, fontSize: 11.5, color: c.text2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: onConnectHealth,
                    style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                    child: Text(
                      hasHealthConnect
                          ? context.l10n.settingsGestionar
                          : context.l10n.settingsConectar,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ==========================================
      ],
    );
  }
}
