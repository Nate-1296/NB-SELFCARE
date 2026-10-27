import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../features/pet_gamification/application/pet_queries.dart';
import '../../shared/theme/sc_colors.dart';
import '../../shared/theme/sc_theme.dart';
import '../../shared/widgets/app_icons.dart';

class NavDestinationData {
  const NavDestinationData({required this.label, required this.icon, required this.activeIcon});

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

const List<NavDestinationData> kNavDestinations = <NavDestinationData>[
  NavDestinationData(label: 'Inicio', icon: AppIcons.hoy, activeIcon: AppIcons.hoyFilled),
  NavDestinationData(label: 'Comida', icon: AppIcons.comer, activeIcon: AppIcons.comerFilled),
  NavDestinationData(label: 'Cuerpo', icon: AppIcons.cuerpo, activeIcon: AppIcons.cuerpoFilled),
  NavDestinationData(label: 'Mascota', icon: AppIcons.nibi, activeIcon: AppIcons.nibiFilled),
  NavDestinationData(label: 'Perfil', icon: AppIcons.perfil, activeIcon: AppIcons.perfilFilled),
];

/// Barra inferior de navegación con efecto blur (o sólida en E-Ink NXTPAPER).
class BottomNav extends ConsumerWidget {
  const BottomNav({super.key, required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final AsyncValue<PetStatusData?> petStatusAsync = ref.watch(petStatusStreamProvider);
    final String? rawPetName = petStatusAsync.value?.petName.trim();

    // Si el nombre es conciso (hasta 7 caracteres), lo mostramos en el dock;
    // si es largo o vacío, usamos 'Mascota' para asegurar que nunca se desborde ni se corte.
    final String petLabel;
    if (rawPetName != null && rawPetName.isNotEmpty && rawPetName.length <= 7) {
      petLabel = rawPetName;
    } else {
      petLabel = 'Mascota';
    }

    final List<NavDestinationData> destinations = <NavDestinationData>[
      kNavDestinations[0],
      kNavDestinations[1],
      kNavDestinations[2],
      NavDestinationData(label: petLabel, icon: AppIcons.nibi, activeIcon: AppIcons.nibiFilled),
      kNavDestinations[4],
    ];

    final Widget barContent = Container(
      decoration: BoxDecoration(
        color: c.isFlat ? c.bg : c.bg.withValues(alpha: 0.88),
        border: Border(top: BorderSide(color: c.isFlat ? c.line2 : c.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
          child: Row(
            children: <Widget>[
              for (int i = 0; i < destinations.length; i++)
                Expanded(
                  child: _NavItem(
                    data: destinations[i],
                    active: i == currentIndex,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (c.isFlat) {
      return barContent;
    }

    return ClipRect(
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), child: barContent),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.data, required this.active, required this.onTap});

  final NavDestinationData data;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final Color color = active ? (c.isFlat ? c.text : c.accent) : c.text3;

    return InkWell(
      onTap: onTap,
      splashColor: c.isFlat ? Colors.transparent : null,
      highlightColor: c.isFlat ? Colors.transparent : null,
      borderRadius: BorderRadius.circular(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(active ? data.activeIcon : data.icon, size: 22, color: color),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                data.label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: ScFonts.ui,
                  fontSize: 11.0,
                  // Peso estático consistente para evitar que la fuente se expanda o tiemble al enfocar
                  fontWeight: FontWeight.w700,
                  color: color,
                  height: 1.15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
