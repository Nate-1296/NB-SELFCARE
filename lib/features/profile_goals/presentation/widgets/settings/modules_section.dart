import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/domain/care_enums.dart';
import '../../../../../core/domain/enums.dart';
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

/// Secciones que el usuario puede mostrar u ocultar.
class ModulesSection extends ConsumerWidget {
  const ModulesSection({super.key, required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHead(
          title: context.l10n.settingsModulosYEnfoque,
          subtitle: context.l10n.settingsAdaptaLosPilaresVisiblesA,
          padding: const EdgeInsets.symmetric(vertical: 4),
        ),
        const SizedBox(height: 8),
        HealthCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: <Widget>[
              // Ayuno Intermitente
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
                    child: Icon(AppIcons.fasting, color: c.isFlat ? c.text : c.accent, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          context.l10n.settingsAyunoIntermitente,
                          style: TextStyle(
                            fontFamily: ScFonts.ui,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: c.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          (profile?.isFastingEnabled ?? true)
                              ? context.l10n.settingsCronometroYFasesCelularesActivos
                              : context.l10n.settingsModuloReplegadoParaSimplificarLa,
                          style: TextStyle(fontFamily: ScFonts.ui, fontSize: 11.5, color: c.text2),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: profile?.isFastingEnabled ?? true,
                    onChanged: (bool val) async {
                      unawaited(HapticFeedback.selectionClick());
                      await ref.read(profileServiceProvider).setFastingEnabled(val);
                    },
                  ),
                ],
              ),

              // Salud Femenina (ÚNICAMENTE visible si el sexo biológico es femenino)
              if (profile?.biologicalSex == BiologicalSex.female) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Divider(height: 1, color: c.line),
                ),
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
                      child: Icon(
                        Icons.female_rounded,
                        color: c.isFlat ? c.text : c.accent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            context.l10n.settingsSaludFemeninaYCicloMenstrual,
                            style: TextStyle(
                              fontFamily: ScFonts.ui,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: c.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            (profile?.isCycleTrackingEnabled ?? false)
                                ? context.l10n.settingsSincronizacionHormonalConTdeeY
                                : context.l10n.settingsDesactivado,
                            style: TextStyle(
                              fontFamily: ScFonts.ui,
                              fontSize: 11.5,
                              color: c.text2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: profile?.isCycleTrackingEnabled ?? false,
                      onChanged: (bool val) async {
                        unawaited(HapticFeedback.selectionClick());
                        await ref.read(profileServiceProvider).setCycleTrackingEnabled(val);
                      },
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 12),
        HealthCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: 6),
              Text(context.l10n.settingsCareModules, style: context.text.titleSmall),
              Text(
                context.l10n.settingsCareModulesHint,
                style: TextStyle(fontFamily: ScFonts.ui, fontSize: 11.5, color: c.text2),
              ),
              for (final CareModule module in CareModule.values)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(module.label(context.l10n)),
                  value: _modules.contains(module),
                  onChanged: (bool v) {
                    unawaited(HapticFeedback.selectionClick());
                    unawaited(
                      ref.read(carePreferencesServiceProvider).setCareModule(module, enabled: v),
                    );
                  },
                ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ==========================================
      ],
    );
  }

  Set<CareModule> get _modules =>
      profile == null ? CareModule.defaults : ProfileSets.careModules(profile!.careModulesJson);
}
