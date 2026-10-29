import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../features/pet_gamification/application/pet_queries.dart';
import '../../shared/theme/sc_colors.dart';
import '../../shared/theme/sc_theme.dart';
import '../../shared/theme/sc_tokens.dart';
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
  NavDestinationData(label: 'Cuidado', icon: AppIcons.cuidado, activeIcon: AppIcons.cuidadoFilled),
  NavDestinationData(label: 'Mascota', icon: AppIcons.nibi, activeIcon: AppIcons.nibiFilled),
  NavDestinationData(label: 'Perfil', icon: AppIcons.perfil, activeIcon: AppIcons.perfilFilled),
];

/// Barra inferior de navegación.
///
/// Sólida (sin desenfoque de fondo: el blur se recalculaba en cada fotograma
/// del desplazamiento y era la mayor fuente de tirones en gama media). La
/// pestaña activa se marca con una píldora tonal que se desliza de una a otra.
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
      kNavDestinations[3],
      NavDestinationData(label: petLabel, icon: AppIcons.nibi, activeIcon: AppIcons.nibiFilled),
      kNavDestinations[5],
    ];

    return Container(
      decoration: BoxDecoration(
        color: c.isFlat ? c.bg : c.bg2,
        border: Border(
          top: BorderSide(color: c.isFlat ? c.line2 : c.line, width: c.isFlat ? 1.5 : 1),
        ),
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
    final Duration duration = ScMotion.of(context, ScMotion.standard);
    final Color color = active ? c.text : c.text3;
    final Color indicator = c.isFlat ? Colors.transparent : c.accent.withValues(alpha: 0.18);

    return Semantics(
      selected: active,
      button: true,
      label: data.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              AnimatedContainer(
                duration: duration,
                curve: ScMotion.ease,
                width: active ? 50 : 38,
                height: 30,
                decoration: BoxDecoration(
                  color: active ? indicator : Colors.transparent,
                  borderRadius: BorderRadius.circular(c.isFlat ? 6 : 15),
                  border: c.isFlat && active ? Border.all(color: c.line2, width: 1.5) : null,
                ),
                alignment: Alignment.center,
                child: AnimatedSwitcher(
                  duration: duration,
                  child: Icon(
                    active ? data.activeIcon : data.icon,
                    key: ValueKey<bool>(active),
                    size: 22,
                    color: active && !c.isFlat ? c.accent : color,
                  ),
                ),
              ),
              const SizedBox(height: 4),
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
                    fontSize: 11.5,
                    // Mismo peso activo e inactivo: la etiqueta no cambia de ancho al enfocar.
                    fontWeight: FontWeight.w700,
                    color: color,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
