import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/theme/sc_tokens.dart';
import '../../../../shared/utils/date_formats.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../journal/application/journal_queries.dart';

/// Cinco estados de ánimo del diario, del más bajo al más alto.
List<({String emoji, String label})> journalMoodOptions(AppLocalizations l10n) =>
    <({String emoji, String label})>[
      (emoji: '😞', label: l10n.todayDificil),
      (emoji: '😐', label: l10n.todayNeutro),
      (emoji: '🙂', label: l10n.todayBien),
      (emoji: '😊', label: l10n.todayGenial),
      (emoji: '🤩', label: l10n.todayRadiante),
    ];

List<String> _decodeTags(String rawJson) {
  try {
    final Object? decoded = jsonDecode(rawJson);
    if (decoded is List<dynamic>) {
      return decoded.map((Object? e) => e.toString()).where((String s) => s.isNotEmpty).toList();
    }
  } on FormatException {
    return const <String>[];
  }
  return const <String>[];
}

/// Selector de ánimo de cinco tarjetas (puntuación 1–5).
class JournalMoodPicker extends StatelessWidget {
  const JournalMoodPicker({super.key, required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final List<({String emoji, String label})> options = journalMoodOptions(context.l10n);
    return Row(
      children: <Widget>[
        for (int i = 0; i < options.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: ScSpace.xs + 2),
          Expanded(
            child: Semantics(
              selected: selected == i + 1,
              button: true,
              label: options[i].label,
              excludeSemantics: true,
              child: Material(
                color: selected == i + 1 ? (c.isFlat ? c.bg3 : c.soft) : (c.isFlat ? c.bg2 : c.bg3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ScRadius.tileOf(c) - 4),
                  side: selected == i + 1
                      ? BorderSide(color: c.isFlat ? c.text : c.accent, width: 2)
                      : (c.isFlat ? BorderSide(color: c.line2, width: 1.5) : BorderSide.none),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(ScRadius.tileOf(c) - 4),
                  onTap: () => onChanged(i + 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: ScSpace.s,
                      horizontal: ScSpace.xs,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(options[i].emoji, style: const TextStyle(fontSize: 20)),
                        const SizedBox(height: ScSpace.xs),
                        // Una sola línea que se encoge: "Radiante" no se parte.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            options[i].label,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: ScFonts.ui,
                              fontSize: 10.5,
                              fontWeight: selected == i + 1 ? FontWeight.w700 : FontWeight.w600,
                              color: selected == i + 1 ? c.text : c.text2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Últimas entradas del diario (2, o 6 al desplegar).
class JournalRecentEntries extends ConsumerStatefulWidget {
  const JournalRecentEntries({super.key, required this.onDelete});

  final ValueChanged<JournalEntry> onDelete;

  @override
  ConsumerState<JournalRecentEntries> createState() => _JournalRecentEntriesState();
}

class _JournalRecentEntriesState extends ConsumerState<JournalRecentEntries> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<JournalEntry> all =
        ref.watch(recentJournalEntriesProvider).value ?? const <JournalEntry>[];
    final List<JournalEntry> entries = all.take(_showAll ? 6 : 2).toList();
    if (entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: ScSpace.l),
        const Divider(height: 1),
        const SizedBox(height: ScSpace.m),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Flexible(child: Text(l10n.todayReflexionesRecientes, style: context.text.titleSmall)),
            if (all.length > 2)
              TextButton(
                onPressed: () => setState(() => _showAll = !_showAll),
                child: Text(_showAll ? l10n.todayVerMenos : l10n.todayVerMas),
              ),
          ],
        ),
        const SizedBox(height: ScSpace.xs),
        for (final JournalEntry entry in entries)
          _EntryCard(entry: entry, onDelete: () => widget.onDelete(entry)),
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.onDelete});

  final JournalEntry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final List<String> tags = _decodeTags(entry.tagsJson);
    final Uint8List? photo = entry.progressPhoto;
    final String? legacyPhotoPath = entry.progressPhotoPath;
    return Container(
      margin: const EdgeInsets.only(bottom: ScSpace.s + 2),
      padding: const EdgeInsets.all(ScSpace.m),
      decoration: BoxDecoration(
        color: c.isFlat ? c.bg2 : c.bg3,
        borderRadius: BorderRadius.circular(ScRadius.tileOf(c) - 4),
        border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                journalMoodOptions(l10n)[((entry.moodScore ?? 3) - 1).clamp(0, 4)].emoji,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: ScSpace.s),
              Expanded(
                child: Text(
                  l10n.todayEnergia5Estres5(
                    DateFormats.shortDate(DateTime.parse(entry.dateKey), l10n.localeName),
                    (entry.energyLevel ?? 3).toString(),
                    (entry.stressLevel ?? 2).toString(),
                  ),
                  style: TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: c.text3,
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.todayEliminarEntrada,
                icon: Icon(AppIcons.delete, size: 18, color: c.text3),
                onPressed: onDelete,
              ),
            ],
          ),
          Text(
            entry.content,
            style: TextStyle(fontFamily: ScFonts.ui, fontSize: 13.5, color: c.text, height: 1.4),
          ),
          if (photo != null || legacyPhotoPath != null) ...<Widget>[
            const SizedBox(height: ScSpace.s),
            ClipRRect(
              borderRadius: BorderRadius.circular(ScRadius.control - 2),
              child: photo != null
                  ? Image.memory(
                      photo,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      cacheHeight: 360,
                      errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
                          const SizedBox.shrink(),
                    )
                  // Entradas anteriores a v6: la foto vivía en un archivo.
                  : Image.file(
                      File(legacyPhotoPath!),
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      cacheHeight: 360,
                      errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
                          const SizedBox.shrink(),
                    ),
            ),
          ],
          if (entry.aiInsightSummary?.isNotEmpty ?? false) ...<Widget>[
            const SizedBox(height: ScSpace.s),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: ScSpace.s + 2,
                vertical: ScSpace.s - 1,
              ),
              decoration: BoxDecoration(
                color: c.isFlat ? c.bg3 : c.bg2,
                borderRadius: BorderRadius.circular(ScRadius.controlOf(c) - 2),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(AppIcons.suggest, size: 14, color: c.isFlat ? c.text : c.accent),
                  ),
                  const SizedBox(width: ScSpace.xs + 2),
                  Expanded(
                    child: Text(
                      entry.aiInsightSummary!,
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 12,
                        color: c.text2,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: ScSpace.xs + 2),
              child: Wrap(
                spacing: ScSpace.xs + 2,
                runSpacing: ScSpace.xs,
                children: <Widget>[
                  for (final String t in tags)
                    Text(
                      '#$t',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: c.isFlat ? c.text : c.accent,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
