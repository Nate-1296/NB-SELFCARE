import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/domain/enums.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_theme.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/health_card.dart';

/// Tarjeta Hero de Perfil con foto en grande en medio, decoración radial,
/// nombre destacado y datos biométricos dinámicos sin texto redundante.
class ProfileHeroCard extends StatelessWidget {
  const ProfileHeroCard({super.key, 
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
    final bool hasAvatar = profile.avatarPath != null &&
        File(profile.avatarPath!).existsSync();
    final String sexLabel =
        profile.biologicalSex == BiologicalSex.male ? context.l10n.perfilHombre: context.l10n.perfilMujer;

    return HealthCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: <Widget>[
          // Foto en grande rodeada de anillo decorativo reactivo al tema
          Center(
            child: GestureDetector(
              onTap: onPickPhoto,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  // Marco radial decorativo exterior
                  Container(
                    width: 126,
                    height: 126,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.isFlat ? c.bg3 : c.soft,
                      border: Border.all(
                        color: c.isFlat
                            ? c.line2
                            : c.accent.withValues(alpha: 0.45),
                        width: c.isFlat ? 2.0 : 1.8,
                      ),
                    ),
                  ),
                  // Avatar de usuario
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.bg3,
                      border: Border.all(
                        color: c.isFlat ? c.text : c.accent,
                        width: 2.2,
                      ),
                      image: hasAvatar
                          ? DecorationImage(
                              image: FileImage(File(profile.avatarPath!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: hasAvatar
                        ? null
                        : Center(
                            child: Text(
                              profile.name.isNotEmpty
                                  ? profile.name[0].toUpperCase()
                                  : 'U',
                              style: TextStyle(
                                fontFamily: ScFonts.display,
                                fontSize: 44,
                                fontWeight: FontWeight.w800,
                                color: c.accent,
                              ),
                            ),
                          ),
                  ),
                  // Botón flotante para cambiar foto
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: c.isFlat ? c.text : c.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.bg2, width: 2),
                      ),
                      child: Icon(
                        Icons.camera_alt_rounded,
                        size: 16,
                        color: c.isFlat ? c.bg : c.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Nombre de usuario en tipografía display destacada
          Text(
            profile.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: ScFonts.display,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: c.text,
            ),
          ),

          const SizedBox(height: 10),

          // Chips ordenados de datos biométricos dinámicos
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: <Widget>[
              _StatChip(
                icon: Icons.cake_rounded,
                label: context.l10n.perfilAnos(ageYears.floor().toString()),
              ),
              _StatChip(
                icon: profile.biologicalSex == BiologicalSex.male
                    ? Icons.male_rounded
                    : Icons.female_rounded,
                label: sexLabel,
              ),
              _StatChip(
                icon: Icons.height_rounded,
                label: context.l10n.perfilCm(profile.heightCm.toStringAsFixed(0).toString()),
              ),
              _StatChip(
                icon: AppIcons.cuerpo,
                label: context.l10n.perfilKgMeta(profile.targetWeightKg.toStringAsFixed(1).toString()),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Botón para editar perfil
          SizedBox(
            width: 170,
            child: OutlinedButton.icon(
              onPressed: onEditProfile,
              icon: Icon(AppIcons.edit, size: 15, color: c.accent),
              label: Text(
                context.l10n.perfilEditarPerfil,
                style: TextStyle(
                  fontFamily: ScFonts.ui,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                ),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                side: BorderSide(color: c.isFlat ? c.line2 : c.line2, width: c.isFlat ? 1.5 : 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.bg3,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: c.isFlat ? c.line2 : c.line,
          width: c.isFlat ? 1.3 : 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: c.isFlat ? c.text : c.accent),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: c.text2,
            ),
          ),
        ],
      ),
    );
  }
}
