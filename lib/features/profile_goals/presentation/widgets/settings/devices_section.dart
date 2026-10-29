import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/domain/care_enums.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_theme.dart';
import '../../../../../shared/theme/sc_tokens.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/health_card.dart';
import '../../../../../shared/widgets/section_head.dart';
import '../../../../care/application/care_preferences_service.dart';
import '../../../../care/presentation/care_l10n.dart';
import '../../../application/profile_service.dart';

/// Tus equipos: pantalla de papel, báscula, Health Connect y aparatos de signos
/// vitales. Lo que no se tiene, no aparece en la app.
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

  Set<VitalKind> get _vitals =>
      profile == null ? const <VitalKind>{} : ProfileSets.vitalDevices(profile!.vitalDevicesJson);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHead(
          title: context.l10n.settingsMyDevicesTitle,
          subtitle: context.l10n.settingsMyDevicesSubtitle,
          padding: const EdgeInsets.symmetric(vertical: 4),
        ),
        const SizedBox(height: 8),
        HealthCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: <Widget>[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.menu_book_outlined),
                title: Text(context.l10n.devicesEink),
                subtitle: Text(context.l10n.devicesEinkHint),
                value: profile?.hasEinkScreen ?? false,
                onChanged: (bool v) {
                  unawaited(HapticFeedback.selectionClick());
                  unawaited(ref.read(carePreferencesServiceProvider).setEinkScreen(v));
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(AppIcons.bascula),
                title: Text(context.l10n.devicesScale),
                subtitle: Text(
                  (profile?.hasSmartScale ?? false)
                      ? context.l10n.devicesScaleHint
                      : context.l10n.devicesNoScaleHint,
                ),
                value: profile?.hasSmartScale ?? false,
                onChanged: (bool v) {
                  unawaited(HapticFeedback.selectionClick());
                  unawaited(ref.read(carePreferencesServiceProvider).setSmartScale(v));
                },
              ),
              if (profile?.hasSmartScale ?? false) ...<Widget>[
                const SizedBox(height: 6),
                // Báscula Xiaomi
                Row(
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: c.isFlat ? c.bg3 : c.soft,
                        shape: BoxShape.circle,
                        border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
                      ),
                      child: Icon(AppIcons.bascula, color: c.isFlat ? c.text : c.accent, size: 22),
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
                            style: TextStyle(
                              fontFamily: ScFonts.ui,
                              fontSize: 11.5,
                              color: c.text2,
                            ),
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
                          border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
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
              ],
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
                      shape: BoxShape.circle,
                      border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
                    ),
                    child: Icon(AppIcons.corazon, color: c.isFlat ? c.text : c.accent, size: 22),
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
                  Flexible(
                    child: FilledButton.tonal(
                      onPressed: onConnectHealth,
                      style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          hasHealthConnect
                              ? context.l10n.settingsGestionar
                              : context.l10n.settingsConectar,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, color: c.line),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(context.l10n.devicesVitals, style: context.text.titleSmall),
              ),
              const SizedBox(height: 2),
              Text(
                context.l10n.devicesVitalsHint,
                style: TextStyle(fontFamily: ScFonts.ui, fontSize: 11.5, color: c.text2),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: <Widget>[
                    for (final VitalKind kind in VitalKind.values)
                      FilterChip(
                        avatar: Icon(kind.icon, size: 18),
                        label: Text(kind.device(context.l10n)),
                        selected: _vitals.contains(kind),
                        onSelected: (bool on) {
                          unawaited(HapticFeedback.selectionClick());
                          final Set<VitalKind> next = Set<VitalKind>.of(_vitals);
                          on ? next.add(kind) : next.remove(kind);
                          unawaited(ref.read(carePreferencesServiceProvider).setVitalDevices(next));
                        },
                      ),
                  ],
                ),
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
