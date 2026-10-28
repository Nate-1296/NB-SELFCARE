import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/domain/enums.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_tokens.dart';
import '../../../../../shared/utils/number_formats.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/health_card.dart';
import '../../../../../shared/widgets/tonal_badge.dart';

/// Tarjeta Hero de Perfil con foto en grande en medio, decoración radial,
/// nombre destacado y datos biométricos dinámicos sin texto redundante.
class ProfileHeroCard extends StatelessWidget {
  const ProfileHeroCard({
    super.key,
    required this.profile,
    required this.ageYears,
    required this.onPickPhoto,
    required this.onEditProfile,
  });

  final UserProfile profile;
  final double ageYears;
  final VoidCallback onPickPhoto;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final bool hasAvatar = profile.avatarPath != null && File(profile.avatarPath!).existsSync();
    final String sexLabel = profile.biologicalSex == BiologicalSex.male
        ? context.l10n.perfilHombre
        : context.l10n.perfilMujer;

    final String initial = profile.name.isNotEmpty ? profile.name[0].toUpperCase() : 'U';
    final String facts = <String>[
      context.l10n.perfilAnos(ageYears.floor().toString()),
      sexLabel,
      context.l10n.perfilCm(NumberFormats.fixed(profile.heightCm, 0)),
    ].join(' · ');

    return HealthCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(ScSpace.l + 2),
      child: Row(
        children: <Widget>[
          Semantics(
            button: true,
            label: context.l10n.perfilChangePhoto,
            excludeSemantics: true,
            child: GestureDetector(
              onTap: onPickPhoto,
              child: SizedBox.square(
                dimension: 84,
                child: Stack(
                  children: <Widget>[
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.isFlat ? c.bg2 : c.soft,
                        border: Border.all(
                          color: c.isFlat ? c.line2 : c.accent.withValues(alpha: 0.6),
                          width: 2,
                        ),
                        image: hasAvatar
                            ? DecorationImage(
                                image: ResizeImage(
                                  FileImage(File(profile.avatarPath!)),
                                  width: 256,
                                ),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: hasAvatar
                          ? null
                          : Text(
                              initial,
                              style: context.type.metricL.copyWith(
                                color: c.isFlat ? c.text : c.accent,
                              ),
                            ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: c.isFlat ? c.text : c.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: c.bg2, width: 2.5),
                        ),
                        child: Icon(
                          Icons.camera_alt_rounded,
                          size: 14,
                          color: c.isFlat ? c.bg : c.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: ScSpace.l + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  profile.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.displaySmall,
                ),
                const SizedBox(height: ScSpace.xs),
                Text(facts, style: context.type.caption),
                const SizedBox(height: ScSpace.s),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TonalBadge(
                    icon: Icons.flag_rounded,
                    label: context.l10n.perfilKgMeta(NumberFormats.fixed(profile.targetWeightKg, 1)),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.l10n.perfilEditarPerfil,
            onPressed: onEditProfile,
            icon: Icon(AppIcons.edit, color: c.text2),
          ),
        ],
      ),
    );
  }
}
