import 'package:flutter/material.dart';

import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_theme.dart';
import '../../../../../shared/theme/sc_tokens.dart';
import '../../../../../shared/widgets/health_card.dart';

/// Selector de tema en cuadrícula compacta, con los modos papel (NXTPAPER) primero.
class ThemePicker extends StatelessWidget {
  const ThemePicker({super.key, required this.currentKey, required this.onSelect});

  final String currentKey;
  final ValueChanged<String> onSelect;

  static bool _isPaper(ScThemeDef d) => d.colors.isFlat || d.key.startsWith('nxtpaper');

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<ScThemeDef> paper = kScThemes.where(_isPaper).toList();
    final List<ScThemeDef> color = kScThemes.where((ScThemeDef d) => !_isPaper(d)).toList();
    final bool dynamicSelected = currentKey == kDynamicThemeKey;
    final ScThemeDef current = kScThemes.firstWhere((ScThemeDef d) => d.key == currentKey, orElse: () => kScThemes.first);

    return HealthCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(ScSpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(dynamicSelected ? l10n.settingsDynamicTheme : current.label, style: context.text.titleMedium),
          Text(dynamicSelected ? l10n.settingsDynamicThemeHint : current.description, style: context.text.bodySmall),
          const SizedBox(height: ScSpace.m),
          _DynamicChip(selected: dynamicSelected, onTap: () => onSelect(kDynamicThemeKey)),
          const SizedBox(height: ScSpace.l),
          Text(l10n.settingsThemesPaper, style: context.text.labelLarge),
          const SizedBox(height: ScSpace.s),
          _Grid(themes: paper, currentKey: currentKey, onSelect: onSelect),
          const SizedBox(height: ScSpace.l),
          Text(l10n.settingsThemesColor, style: context.text.labelLarge),
          const SizedBox(height: ScSpace.s),
          _Grid(themes: color, currentKey: currentKey, onSelect: onSelect),
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.themes, required this.currentKey, required this.onSelect});

  final List<ScThemeDef> themes;
  final String currentKey;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double gap = ScSpace.s;
        final double width = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final ScThemeDef d in themes)
              SizedBox(
                width: width,
                child: _ThemeChip(def: d, selected: d.key == currentKey, onTap: () => onSelect(d.key)),
              ),
          ],
        );
      },
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({required this.def, required this.selected, required this.onTap});

  final ScThemeDef def;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Semantics(
      selected: selected,
      button: true,
      label: def.label,
      excludeSemantics: true,
      child: Material(
        color: c.bg3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ScRadius.control),
          side: BorderSide(
            color: selected ? (c.isFlat ? c.text : c.accent) : (c.isFlat ? c.line2 : c.line),
            width: selected ? 2 : (c.isFlat ? 1.5 : 1),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: ScSpace.s + 2, vertical: ScSpace.s + 2),
            child: Row(
              children: <Widget>[
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: def.colors.bg,
                    shape: BoxShape.circle,
                    border: Border.all(color: def.colors.line2, width: 1.5),
                  ),
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: def.colors.accent, shape: BoxShape.circle),
                  ),
                ),
                const SizedBox(width: ScSpace.s),
                Expanded(
                  child: Text(
                    def.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 12.5,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: c.text,
                      height: 1.2,
                    ),
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

class _DynamicChip extends StatelessWidget {
  const _DynamicChip({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: c.bg3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ScRadius.control),
          side: BorderSide(
            color: selected ? (c.isFlat ? c.text : c.accent) : (c.isFlat ? c.line2 : c.line),
            width: selected ? 2 : (c.isFlat ? 1.5 : 1),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(ScSpace.m),
            child: Row(
              children: <Widget>[
                Icon(Icons.wallpaper_rounded, color: c.isFlat ? c.text : c.accent),
                const SizedBox(width: ScSpace.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(l10n.settingsDynamicTheme, style: context.text.titleSmall),
                      Text(l10n.settingsDynamicThemeHint, style: context.text.bodySmall),
                    ],
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
