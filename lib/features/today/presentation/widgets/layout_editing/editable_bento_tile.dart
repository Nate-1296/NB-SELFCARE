import 'package:flutter/material.dart';

import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_theme.dart';
import '../../../domain/hoy_widget_config.dart';
import '../../hoy_widget_l10n.dart';

class EditableBentoTile extends StatelessWidget {
  const EditableBentoTile({
    super.key,
    required this.item,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.canHide,
    required this.onToggleSize,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onHide,
    required this.child,
  });

  final HoyWidgetItemConfig item;
  final bool canMoveUp;
  final bool canMoveDown;
  final bool canHide;
  final VoidCallback onToggleSize;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onHide;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final bool canResize = item.id.canResize;
    final String nextSizeLabel =
        item.size == HoyWidgetSize.w2x2 ? context.l10n.todayAmpliar42: context.l10n.todayReducir22;

    return Container(
      decoration: BoxDecoration(
        color: c.bg3,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: c.isFlat ? c.line2 : c.accent.withValues(alpha: 0.55),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 6, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        item.id.title(context.l10n),
                        softWrap: true,
                        style: TextStyle(
                          fontFamily: ScFonts.display,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: c.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: c.bg2,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: c.line2, width: 1.0),
                      ),
                      child: Text(
                        item.size.label,
                        style: TextStyle(
                          fontFamily: ScFonts.display,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: c.accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    if (canResize)
                      _MiniEditButton(
                        tooltip: context.l10n.todayCambiarTamano(item.id.title(context.l10n)),
                        icon: item.size == HoyWidgetSize.w2x2
                            ? Icons.open_in_full_rounded
                            : Icons.close_fullscreen_rounded,
                        label: nextSizeLabel,
                        onTap: onToggleSize,
                        accent: true,
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: c.bg2,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: c.line, width: 1.0),
                        ),
                        child: Text(
                          context.l10n.todayBloque44Unico,
                          style: TextStyle(
                            fontFamily: ScFonts.ui,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: c.text2,
                          ),
                        ),
                      ),
                    _MiniEditIconButton(
                      tooltip: context.l10n.todaySubir(item.id.title(context.l10n)),
                      icon: Icons.arrow_upward_rounded,
                      onTap: canMoveUp ? onMoveUp : null,
                    ),
                    _MiniEditIconButton(
                      tooltip: context.l10n.todayBajar(item.id.title(context.l10n)),
                      icon: Icons.arrow_downward_rounded,
                      onTap: canMoveDown ? onMoveDown : null,
                    ),
                    _MiniEditIconButton(
                      tooltip: context.l10n.todayOcultar(item.id.title(context.l10n)),
                      icon: Icons.visibility_off_outlined,
                      onTap: canHide ? onHide : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _MiniEditButton extends StatelessWidget {
  const _MiniEditButton({
    required this.tooltip,
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = false,
  });

  final String tooltip;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: c.bg2,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: accent ? c.accent : c.line2,
                width: 1.1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 13, color: accent ? c.accent : c.text),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniEditIconButton extends StatelessWidget {
  const _MiniEditIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final bool enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: c.bg2,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: enabled ? c.line2 : c.line,
                width: 1.0,
              ),
            ),
            child: Icon(
              icon,
              size: 15,
              color: enabled ? c.text : c.text3,
            ),
          ),
        ),
      ),
    );
  }
}
