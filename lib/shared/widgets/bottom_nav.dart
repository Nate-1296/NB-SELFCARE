import 'dart:ui';
import 'package:flutter/material.dart';

import '../theme/sc_colors.dart';
import '../theme/sc_theme.dart';
import 'app_icons.dart';

class NavDestinationData {
  const NavDestinationData({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

const List<NavDestinationData> kNavDestinations = <NavDestinationData>[
  NavDestinationData(
    label: 'Hoy',
    icon: AppIcons.hoy,
    activeIcon: AppIcons.hoyFilled,
  ),
  NavDestinationData(
    label: 'Comer',
    icon: AppIcons.comer,
    activeIcon: AppIcons.comerFilled,
  ),
  NavDestinationData(
    label: 'Cuerpo',
    icon: AppIcons.cuerpo,
    activeIcon: AppIcons.cuerpoFilled,
  ),
  NavDestinationData(
    label: 'Nibi',
    icon: AppIcons.nibi,
    activeIcon: AppIcons.nibiFilled,
  ),
  NavDestinationData(
    label: 'Perfil',
    icon: AppIcons.perfil,
    activeIcon: AppIcons.perfilFilled,
  ),
];

/// Barra inferior de navegación con efecto blur (o sólida en E-Ink NXTPAPER).
class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;

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
              for (int i = 0; i < kNavDestinations.length; i++)
                Expanded(
                  child: _NavItem(
                    data: kNavDestinations[i],
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
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: barContent,
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.data,
    required this.active,
    required this.onTap,
  });

  final NavDestinationData data;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final Color color = active ? (c.isFlat ? c.text : c.accent) : c.text3;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              active ? data.activeIcon : data.icon,
              size: 23,
              color: color,
            ),
            const SizedBox(height: 3),
            Text(
              data.label,
              style: TextStyle(
                fontFamily: ScFonts.ui,
                fontSize: 11.0,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

